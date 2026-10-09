//
//  APICalls.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation

/// The Developer Portal's demo API — the sample's whole backend.
///
/// Every call after pairing carries the pairing token; the portal knows from it
/// which building and resident this device is bound to, and proxies the calls to
/// the 1VALET Public API. In a real integration all of this is *your* backend's
/// job — the SDK handles media only and never contacts a backend itself.
struct APICalls {
    /// The only configuration the sample needs: where the 1VALET Developer
    /// Portal lives. Everything else — which building and resident this device
    /// rings for — is decided when you pair the app on the portal's Demo app page.
    static let portalBaseUrl = "https://developers.1valet.com"

    /// Starts a pairing: returns the code the app displays and the pending token
    /// it listens with until the code is activated.
    ///
    /// - Returns: The pairing code, pending token, and expiry, or `nil` if the
    ///   URL was malformed.
    /// - Throws: A `NetworkError` if the request or decoding fails.
    static func createPairing() async throws -> CreatePairingResponse? {
        guard let url = URL(string: portalBaseUrl + "/api/demo/pairings") else {
            print("Invalid POST URL")
            return nil
        }

        let client = NetworkClient()
        return try await client.post(to: url, responseType: CreatePairingResponse.self)
    }

    /// Listens for events. With the pending token this yields the "paired"
    /// event; with the activated token it carries the "video-call" events
    /// (verbatim 1VALET webhook payloads). Suspends until `onEvent` returns
    /// `false` or the connection ends; callers reconnect with backoff.
    ///
    /// - Parameters:
    ///   - token: The pending or activated pairing token.
    ///   - onEvent: Receives `(event, data)` per event; return `false` to stop.
    /// - Throws: A `NetworkError` — `.unauthorized` when the token was rejected.
    static func listenForEvents(token: String, onEvent: (String, String) async -> Bool) async throws {
        guard let url = URL(string: portalBaseUrl + "/api/demo/events") else {
            print("Invalid stream URL")
            return
        }

        let client = NetworkClient()
        try await client.readEventStream(from: url, bearerToken: token, onEvent: onEvent)
    }

    /// Requests an access token for a video room.
    ///
    /// Call this before `CallManager.joinRoom` — the SDK expects a token it did
    /// not fetch. A 404 means the room has no live call anymore — show
    /// "call ended", not an error.
    ///
    /// - Parameters:
    ///   - roomId: The video room to get a token for.
    ///   - pairingToken: The activated pairing token.
    /// - Returns: The token and participant identifier, or `nil` if the URL was
    ///   malformed.
    /// - Throws: A `NetworkError` if the request or decoding fails.
    static func getTokenAndParticipant(roomId: String, pairingToken: String) async throws -> TokenAndParticipantResponse? {
        guard let url = URL(string: portalBaseUrl + "/api/demo/rooms/\(roomId)/tokens") else {
            print("Invalid POST URL")
            return nil
        }

        let client = NetworkClient()
        return try await client.post(to: url, bearerToken: pairingToken, responseType: TokenAndParticipantResponse.self)
    }

    /// Reports a call status change so the entry console can update its display.
    ///
    /// - Parameters:
    ///   - roomId: The video room the call is using.
    ///   - participantId: Participant identifier from `getTokenAndParticipant`.
    ///   - entrySystemId: The calling intercom, from the ring event's payload.
    ///   - status: The new call status.
    ///   - pairingToken: The activated pairing token.
    /// - Returns: `true` on success, `false` if the URL was malformed.
    /// - Throws: A `NetworkError` if the request fails.
    static func updateStatus(roomId: String, participantId: String, entrySystemId: String, status: CallStatus, pairingToken: String) async throws -> Bool {
        guard let url = URL(string: portalBaseUrl + "/api/demo/rooms/\(roomId)/status") else {
            print("Invalid POST URL")
            return false
        }

        let client = NetworkClient()
        let request = UpdateCallStatusRequest(
            participantId: participantId,
            callStatus: status,
            entrySystemId: entrySystemId
        )

        return try await client.post(to: url, payload: request, bearerToken: pairingToken)
    }

    /// Unlocks the calling intercom's door for the active call.
    ///
    /// - Parameters:
    ///   - roomId: The video room of the call, tying the unlock to it.
    ///   - entrySystemId: The calling intercom, from the ring event's payload.
    ///   - pairingToken: The activated pairing token.
    /// - Returns: `true` if the door was unlocked, `false` if the URL was malformed.
    /// - Throws: A `NetworkError` if the request fails.
    static func unlock(roomId: String, entrySystemId: String, pairingToken: String) async throws -> Bool {
        guard let url = URL(string: portalBaseUrl + "/api/demo/unlock") else {
            print("Invalid POST URL")
            return false
        }

        let client = NetworkClient()
        let request = UnlockRequest(room: roomId, entrySystemId: entrySystemId)
        return try await client.post(to: url, payload: request, bearerToken: pairingToken)
    }
}
