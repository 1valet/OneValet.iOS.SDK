//
//  CallKitManager.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import Foundation
import CallKit
import AVKit
import Combine
import OneValetSDK

// Wraps CallKit (`CXProvider` / `CXCallController`) to report, answer, and end
// system calls, then drives the SDK's `CallManager` on answer/end. CallKit
// integration is your app's responsibility; this is one example of wiring it to
// the SDK.
class CallKitManager: NSObject, ObservableObject {
    /// Shared instance. CallKit expects a single long-lived provider per app,
    /// and the push handler needs to reach it without a view in scope.
    static let sharedInstance = CallKitManager()

    /// Reports call events *to* the system (incoming call, connected, ended).
    let callKitProvider: CXProvider
    /// Requests call actions *from* the system, such as ending the active call.
    let callKitCallController: CXCallController
    /// UUID of the call currently reported to CallKit, used to address later
    /// actions against it. `nil` when no call is in flight.
    var currentCallIdentifier: UUID?
    /// Participant identifier returned by the backend when joining the room,
    /// required when reporting call status changes.
    var participantId: String?
    /// Identifier of the video room carried in the VoIP push payload.
    var roomId: String?
    /// Identifier of the entry console that placed the call, used to unlock the
    /// door it controls.
    var entryConsoleId: String?

    /// Drives presentation of the in-call UI. Set when the user answers and
    /// cleared when the call ends, so SwiftUI can show or dismiss `CallView`.
    @Published var isCallActive: Bool = false

    /// Builds the CallKit provider and becomes its delegate.
    ///
    /// Private to enforce the singleton — a second provider would compete for
    /// the same system call slots.
    private override init() {
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = true
        providerConfiguration.includesCallsInRecents = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        
        callKitProvider = CXProvider(configuration: providerConfiguration)
        callKitCallController = CXCallController()


        super.init()
        
        callKitProvider.setDelegate(self, queue: nil)
    }

    /// Presents the native incoming-call screen and stores the call's context.
    ///
    /// Must be called from the VoIP push handler — iOS terminates the app if a
    /// VoIP push does not result in a reported call.
    ///
    /// - Parameters:
    ///   - uuid: Identifier to track this call by for its lifetime.
    ///   - roomId: Video room the call will join once answered.
    ///   - entryConsoleId: Entry console that placed the call.
    ///   - completion: Invoked once the call has been reported; hand this the
    ///     completion handler PushKit gave you so iOS knows the push was handled.
    func reportIncomingCall(uuid: UUID, roomId: String, entryConsoleId: String, completion: @escaping (() -> Void)) {
        let callerName = "Demo Caller"
        let update = CXCallUpdate()
        update.hasVideo = true
        update.localizedCallerName = callerName
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.supportsHolding = true
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = true
        currentCallIdentifier = uuid
        callKitProvider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("Failed to report incoming call successfully: \(String(describing: error.localizedDescription)).")
            }
            self.roomId = roomId
            self.entryConsoleId = entryConsoleId
            completion()
        }
    }

    /// Ends the call currently in flight, if any. No-op when there is none.
    func endCall() {
        if let currentCallIdentifier {
            performEndCallAction(uuid: currentCallIdentifier)
        }
    }

    /// Asks the system to end a specific call.
    ///
    /// The hang-up is routed through CallKit rather than torn down directly so
    /// the system UI, Recents, and the SDK all end up in the same state — the
    /// actual disconnect happens in the resulting `CXEndCallAction` callback.
    ///
    /// - Parameter uuid: Identifier of the call to end.
    func performEndCallAction(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                print("EndCallAction transaction request failed: \(error.localizedDescription).")
            }
        }
    }
}

/// Handles system-initiated call events and forwards them to the SDK's
/// `CallManager`, which owns the media session.
extension CallKitManager : CXProviderDelegate {
    /// Called when the system discards all calls, e.g. after a provider crash.
    /// Tears down audio and media so nothing is left running.
    ///
    /// - Parameter provider: The provider that reset.
    func providerDidReset(_ provider: CXProvider) {
        print("providerDidReset:")

        // AudioDevice is enabled by default
        CallManager.sharedInstance.disableAudioDevice()
        CallManager.sharedInstance.disconnect()
    }

    /// Called once the provider is ready to handle call actions.
    ///
    /// - Parameter provider: The provider that started.
    func providerDidBegin(_ provider: CXProvider) {
        print("providerDidBegin")
    }

    /// Called when the system has activated the audio session for the call.
    ///
    /// Audio must not be started before this point, so the SDK's audio device is
    /// enabled here rather than when the call is answered.
    ///
    /// - Parameters:
    ///   - provider: The provider reporting the change.
    ///   - audioSession: The now-active session, managed by the system.
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("provider:didActivateAudioSession:")

        CallManager.sharedInstance.enableAudioDevice()
    }

    /// Called when the system has deactivated the call's audio session, after
    /// the call ends or is interrupted.
    ///
    /// - Parameters:
    ///   - provider: The provider reporting the change.
    ///   - audioSession: The session that was deactivated.
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("provider:didDeactivateAudioSession:")
        
        CallManager.sharedInstance.disableAudioDevice()
    }

    /// Called when an action was not fulfilled in time. Logged only in this demo.
    ///
    /// - Parameters:
    ///   - provider: The provider reporting the timeout.
    ///   - action: The action that timed out.
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        print("provider:timedOutPerformingAction:")
    }

    /// Called when the user answers. Flips `isCallActive` so `CallView` is
    /// presented, which is where the room is actually joined.
    ///
    /// - Parameters:
    ///   - provider: The provider requesting the action.
    ///   - action: The answer action; must be fulfilled or the call is dropped.
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("provider:performAnswerCallAction:")

        isCallActive = true
        action.fulfill(withDateConnected: Date())
    }

    /// Called when the user declines or hangs up, from either the system UI or
    /// `performEndCallAction`. Disconnects media and dismisses the in-call UI.
    ///
    /// - Parameters:
    ///   - provider: The provider requesting the action.
    ///   - action: The end-call action; must be fulfilled or the call is dropped.
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("provider:performEndCallAction:")
        
        CallManager.sharedInstance.disconnect()
        isCallActive = false
        action.fulfill(withDateEnded: Date())
    }

    /// Called when the user mutes or unmutes from the system call UI.
    ///
    /// - Parameters:
    ///   - provider: The provider requesting the action.
    ///   - action: The mute action, carrying the requested state.
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("provier:performSetMutedCallAction:")

        // TODO: Mute microphone
//        muteAudio(isMuted: action.isMuted)
        
        action.fulfill()
    }

    /// Called when the user presses a key on the in-call keypad, which is how a
    /// door unlock could be triggered from the system UI.
    ///
    /// - Parameters:
    ///   - provider: The provider requesting the action.
    ///   - action: The DTMF action, carrying the digits and tone type.
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        let cxObserver = callKitCallController.callObserver
        let calls = cxObserver.calls

        guard calls.first(where: { $0.uuid == action.callUUID }) != nil else {
            action.fail()
            return
        }
        
        // tapped a number
        if action.type == .singleTone {
            // TODO: Unlock
        }
        
        action.fulfill()
    }
}
