//
//  CallView.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import SwiftUI
import OneValetSDK

/// The in-call screen: remote video plus end / unlock / mute controls.
///
/// Shows the division of labour between your app and the SDK. This view fetches
/// the access token from your backend and reports call status; the SDK's
/// `CallManager` owns the media session and the video track.
struct CallView: View {
    /// Dismisses the sheet once the call reaches `.ended`.
    @Environment(\.dismiss) var dismiss

    /// The SDK's call manager. Observed for `state` and `remoteVideoTrack`.
    @StateObject var callsManager = CallManager.sharedInstance
    /// Local mirror of the microphone state, flipped only after the backend
    /// accepts the corresponding status change.
    @State var isMuted: Bool = false
    /// Whether a call action is in flight, driving the loading overlay.
    @State var isLoading = false
    /// Occupant placing the call, needed to request a token.
    let occupantId: String
    /// Video room to join, taken from the VoIP push payload.
    let roomId: String

    /// Remote video with the call controls beneath it. Joins the room on appear
    /// and reacts to SDK state changes.
    var body: some View {
        VStack {
            CallVideoView(track: callsManager.remoteVideoTrack)
                .frame(maxWidth: .infinity, maxHeight: 400)
            
            HStack {
                Button("End Call") {
                    if let callUUID = CallKitManager.sharedInstance.currentCallIdentifier {
                        CallKitManager.sharedInstance.performEndCallAction(uuid: callUUID)
                        isLoading = true
                        Task {
                            do {
                                // Answered on this device → hangup. Never connected → busy (a decline).
                                _ = try await updateStatus(status: callsManager.state == .active ? .hangup : .busy)
                            } catch {
                                // Non-fatal in the demo: the call is already
                                // ending locally; only the console's display lags.
                            }
                            isLoading = false
                        }
                    }
                }
                Button("Unlock") {
                    isLoading = true
                    Task {
                        do {
                            let success = try await APICalls.unlock(
                                buildingId: APICalls.buildingId,
                                occupantId: APICalls.occupantId,
                                entryConsoleId: CallKitManager.sharedInstance.entryConsoleId ?? ""
                            )
                            if success {
                                print("Unlock success")
                            } else {
                                print("Unlock Fail")
                            }
                            
                        } catch {
                            print("Unlock Fail " + error.localizedDescription)
                        }
                        isLoading = false
                    }
                }
                
                Button(isMuted ? "Unmute" : "Mute") {
                    var tempIsMuted = isMuted
                    tempIsMuted.toggle()
                    isLoading = true
                    Task {
                        do {
                            let response = try await updateStatus(status: tempIsMuted ? .hold : .talking)
                            
                            if response {
                                isMuted.toggle()
                                callsManager.setMuteMicrophone(mute: isMuted)
                            }
                        } catch {
                            // Non-fatal in the demo: `isMuted` stays as it was,
                            // so the button keeps showing the real mic state.
                        }
                        isLoading = false
                    }
                }
            }
        }
        .loading(isShowing: $isLoading, text: "Loading...")
        .onAppear {
            Task {
                do {
                    // Your code: fetch the access token from your backend. The SDK
                    // never talks to a backend — token acquisition is your job.
                    let response = try await APICalls.getTokenAndParticipant(roomId: roomId, occupantId: occupantId)
                    CallKitManager.sharedInstance.participantId = response?.data.participantId ?? ""

                    try await callsManager.joinRoom(
                        roomId: roomId,
                        token: response?.data.token ?? "",
                        callId: CallKitManager.sharedInstance.currentCallIdentifier ?? UUID()
                    )

                } catch {
                    // Unlike the status reports elsewhere in this view, this one
                    // is NOT harmless: no token means no room, and the call sits
                    // in `.connecting` with nothing on screen. A real app should
                    // surface it — the Android sample's CallScreen binds the same
                    // failure to an `error` shown above the controls.
                }
            }
        }
        .onChange(of: callsManager.state) { newState in
            switch newState {
            case .active:
                Task {
                    do {
                        _ = try await updateStatus(status: .answered)
                    } catch {
                        // Non-fatal in the demo: media is already flowing; only
                        // the entry console's "answered" display is affected.
                    }
                }
            case .ended:
                CallKitManager.sharedInstance.endCall()
                dismiss()
            case .idle, .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    /// Reports a call status change to the backend.
    ///
    /// Convenience wrapper that fills in the participant and entry console from
    /// `CallKitManager`, since every call site needs the same context.
    ///
    /// - Parameter status: The new status to report.
    /// - Returns: `true` if the backend accepted the change.
    /// - Throws: A `NetworkError` if the request fails.
    func updateStatus(status: CallStatus) async throws -> Bool {
        return try await APICalls.updateStatus(
            occupantId: APICalls.occupantId,
            roomId: roomId,
            participantId: CallKitManager.sharedInstance.participantId ?? "",
            entryConsoleId: CallKitManager.sharedInstance.entryConsoleId ?? "",
            status: status
        )
    }
}
