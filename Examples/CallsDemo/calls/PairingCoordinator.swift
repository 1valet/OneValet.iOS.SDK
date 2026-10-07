//
//  PairingCoordinator.swift
//  calls
//

import Foundation
import CallKit
import Combine

/// What the root screen renders — the pairing/connection state of this device.
enum PairingState {
    /// Startup, before the first connection attempt.
    case loading
    /// Not paired: `code` is what the user enters on the portal's Demo app page
    /// (nil while a code is being requested), `hasError` when the portal is
    /// unreachable.
    case unpaired(code: String?, hasError: Bool)
    /// Paired; `connected` is whether the event stream is currently open.
    case paired(occupantName: String, buildingName: String, connected: Bool)
}

/// Owns the demo's connection to the Developer Portal: pairs the device, then
/// holds the SSE event stream open **while the app is in the foreground** and
/// turns `video-call` events into CallKit rings and dismissals. This is the
/// demo's stand-in for a push service — a production integration receives these
/// events as VoIP pushes from its own backend and can ring from the background;
/// a stream the app holds cannot, which is why the root screen says the app must
/// stay open.
@MainActor
final class PairingCoordinator: ObservableObject {
    /// Shared instance: `CallKitManager` reports declines through it, and the
    /// scene lifecycle drives it — both without a view in scope.
    static let shared = PairingCoordinator()

    @Published private(set) var state: PairingState = .loading

    /// The connection loop, alive exactly while the app is foregrounded.
    private var connectionTask: Task<Void, Never>?

    /// The pairing code currently on screen. Kept across background/foreground
    /// cycles so the code the user may already be typing into the portal stays
    /// valid — a fresh one is only minted when this expires (or its token is
    /// rejected). In memory on purpose: codes are short-lived.
    private var pendingSession: PendingSession?

    private struct PendingSession {
        let code: String
        let token: String
        let expiresAt: Date

        /// A code about to expire isn't worth showing — the user would type it in vain.
        var isUsable: Bool { expiresAt.timeIntervalSinceNow > 30 }
    }

    private init() {}

    /// The saved pairing token, for the call actions (token/status/unlock).
    var pairingToken: String? { PairingStore.load()?.token }

    /// Called from the scene lifecycle: `.active` starts the connection loop,
    /// leaving the foreground cancels it.
    func setForegrounded(_ foregrounded: Bool) {
        if foregrounded {
            guard connectionTask == nil else { return }
            connectionTask = Task { await runConnectionLoop() }
        } else {
            connectionTask?.cancel()
            connectionTask = nil
        }
    }

    func unpair() {
        PairingStore.clear()
        pendingSession = nil
        connectionTask?.cancel()
        connectionTask = nil
        setForegrounded(true)
    }

    /// Declining a ring: fetch call credentials (for the participant id) and
    /// report Busy, which stops the resident's other devices ringing.
    /// Best-effort — a 404 means the call already ended.
    func reportDecline(roomId: String, entrySystemId: String) {
        guard let token = pairingToken else { return }
        Task {
            do {
                guard let credentials = try await APICalls.getTokenAndParticipant(roomId: roomId, pairingToken: token) else {
                    return
                }
                _ = try await APICalls.updateStatus(
                    roomId: roomId,
                    participantId: credentials.participantId,
                    entrySystemId: entrySystemId,
                    status: .busy,
                    pairingToken: token
                )
            } catch {
                print("Decline report skipped: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Connection loop

    private func runConnectionLoop() async {
        while !Task.isCancelled {
            let pairing = PairingStore.load()
            print("\u{1F501} Connection loop: \(pairing == nil ? "awaiting pairing" : "listening for calls")")
            do {
                if let pairing {
                    try await listenForCalls(pairing: pairing)
                } else {
                    try await awaitPairing()
                }
            } catch is CancellationError {
                return
            } catch NetworkError.unauthorized {
                // Expired or invalidated token — back to (or restart) the code screen.
                if pairing != nil {
                    print("Pairing token rejected; unpairing.")
                    PairingStore.clear()
                } else {
                    pendingSession = nil
                }
                continue
            } catch {
                if Task.isCancelled { return }
                print("Event stream failed: \(error.localizedDescription)")
                markDisconnected(pairing: pairing)
            }

            // Also reached when the server closes a healthy stream — reconnect calmly.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    /// Shows a pairing code (reusing the current one while it lasts) and waits on
    /// its stream until the "paired" event lands — delivered live, or immediately
    /// on connect when the code was activated while this app wasn't listening.
    private func awaitPairing() async throws {
        let session: PendingSession
        if let cached = pendingSession, cached.isUsable {
            session = cached
        } else {
            state = .unpaired(code: nil, hasError: false)
            guard let created = try await APICalls.createPairing() else {
                throw NetworkError.invalidResponse
            }
            session = PendingSession(
                code: created.code,
                token: created.pendingToken,
                expiresAt: Self.parsePortalDate(created.expiresAt) ?? Date().addingTimeInterval(15 * 60)
            )
            pendingSession = session
        }

        state = .unpaired(code: session.code, hasError: false)

        try await APICalls.listenForEvents(token: session.token) { event, data in
            guard event == "paired" else {
                print("\u{23ED}\u{FE0F} Ignoring '\(event)' while waiting to pair")
                return true
            }

            let paired: PairedEventData
            do {
                paired = try JSONDecoder().decode(PairedEventData.self, from: Data(data.utf8))
            } catch {
                print("\u{274C} Decoding PairedEventData failed: \(error)")
                return true
            }

            PairingStore.save(Pairing(
                token: paired.pairingToken,
                occupantName: paired.occupant.name ?? "",
                buildingName: paired.building.name ?? ""
            ))
            print("\u{1F4BE} Pairing saved; reloads as \(PairingStore.load() == nil ? "nil \u{2014} SAVE FAILED" : "a pairing")")
            await MainActor.run { self.pendingSession = nil }
            // Stop this stream; the loop reconnects with the activated token.
            return false
        }

        // Stream over without pairing: drop the session if it has run out, so the
        // next iteration mints a fresh code instead of re-showing a dead one.
        if pendingSession?.isUsable != true {
            pendingSession = nil
        }
    }

    private func listenForCalls(pairing: Pairing) async throws {
        state = .paired(occupantName: pairing.occupantName, buildingName: pairing.buildingName, connected: true)
        print("\u{1F5A5}\u{FE0F} State \u{2192} paired(\(pairing.occupantName), connected: true)")

        try await APICalls.listenForEvents(token: pairing.token) { event, data in
            if event == "video-call" {
                do {
                    let payload = try JSONDecoder().decode(CallEventPayload.self, from: Data(data.utf8))
                    self.handleCallEvent(payload)
                } catch {
                    print("\u{274C} Decoding CallEventPayload failed: \(error)")
                }
            }
            return true
        }
    }

    /// One "Calling" event starts a call; exactly one other state ends it.
    /// Anything that is not the ring means the ringing CallKit call for that room
    /// must come down — the state says how:
    ///  - Answered: somebody took the call. If it was THIS device, the event is
    ///    our own status report echoed back — ignore it. Otherwise end the ring
    ///    as "answered elsewhere".
    ///  - Busy (declined elsewhere) / Cancelled (visitor gave up): end quietly.
    ///  - MissedCall: nobody answered — end as unanswered.
    /// An unknown state is treated as a dismiss: a ring must never outlive its
    /// call. (The SDK isn't involved until the user answers — see CallView.)
    private func handleCallEvent(_ payload: CallEventPayload) {
        let callKit = CallKitManager.sharedInstance
        print("Call event: state=\(payload.videoCallState) room=\(payload.room)")

        switch payload.videoCallState {
        case "Calling":
            callKit.reportIncomingCall(
                uuid: UUID(),
                roomId: payload.room,
                entryConsoleId: payload.entrySystemId ?? ""
            )

        case "Answered":
            if callKit.roomId == payload.room && callKit.isCallActive {
                print("Answered echo for our own call — ignored")
            } else {
                callKit.dismissRinging(roomId: payload.room, reason: .answeredElsewhere)
            }

        case "MissedCall":
            callKit.dismissRinging(roomId: payload.room, reason: .unanswered)

        default:
            callKit.dismissRinging(roomId: payload.room, reason: .remoteEnded)
        }
    }

    private func markDisconnected(pairing: Pairing?) {
        if let pairing {
            state = .paired(occupantName: pairing.occupantName, buildingName: pairing.buildingName, connected: false)
        } else {
            state = .unpaired(code: nil, hasError: true)
        }
    }

    /// Parses the portal's ISO-8601 timestamps, whose fractional seconds can be
    /// longer than `ISO8601DateFormatter` accepts — trim them to milliseconds.
    private static func parsePortalDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let trimmed = value.replacingOccurrences(
            of: #"(\.\d{3})\d+"#,
            with: "$1",
            options: .regularExpression
        )
        if let date = formatter.date(from: trimmed) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value.replacingOccurrences(
            of: #"\.\d+"#,
            with: "",
            options: .regularExpression
        ))
    }
}
