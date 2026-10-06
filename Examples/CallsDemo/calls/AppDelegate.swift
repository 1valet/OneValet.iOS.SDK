//
//  AppDelegate.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import UIKit
import PushKit
import CallKit

// The SDK connects media (`CallManager.joinRoom`); receiving the VoIP push and
// reporting the call to CallKit are your app's responsibility. This shows one
// way to do it (PushKit + CallKit). iOS *terminates* the app if a VoIP push
// does not report a CallKit call, so this layer is mandatory in your own app —
// but how you implement it is up to you.
class AppDelegate: NSObject, UIApplicationDelegate, PKPushRegistryDelegate {
    
    // Keep a strong reference to the registry so it isn't deallocated
    var voipRegistry: PKPushRegistry?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize the Registry
        self.voipRegistry = PKPushRegistry(queue: .main)
        self.voipRegistry?.delegate = self
        self.voipRegistry?.desiredPushTypes = [.voIP]
        
        return true
    }

    // MARK: - PKPushRegistryDelegate Methods
    // 1. Handle the token update
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        
        print("\(#function)")
        let appleDeviceId = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
        print("VoIP Token: \(appleDeviceId)")
        Task {
            do {
                _ = try await APICalls.registerDevice(
                    buildingId: APICalls.buildingId,
                    occupantId: APICalls.occupantId,
                    apnsDeviceToken: appleDeviceId
                )
            } catch {
                // Non-fatal in the demo: without a registered token this device
                // simply never receives call pushes.
            }
            
        }
    }

    // 2. Handle the incoming notification
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        
        let userInfo = payload.dictionaryPayload
        print("VoIP payload: \(userInfo)")

        let room = userInfo["room"] as? String
        // The push names this "entrySystemId" while the API calls the same value
        // "entryConsoleId" — keep the local name aligned with the API, and do not
        // "correct" the key below to match it. Reading the wrong key here yields
        // nil, and the `?? ""` further down turns that into an empty string that
        // only fails server-side, as $.entryConsoleId failing Guid conversion.
        let entryConsoleId = userInfo["entrySystemId"] as? String
        
        CallKitManager.sharedInstance.reportIncomingCall(
            uuid: UUID(),
            roomId: room ?? "",
            entryConsoleId: entryConsoleId ?? "",
            completion: completion
        )
    }
    
    // Handle token invalidation
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("Token invalidated")
    }
}

// MARK: - Standard remote notifications
extension AppDelegate {
    
    /// Called when APNs issues a standard (non-VoIP) remote notification token.
    ///
    /// This demo only logs it — incoming calls arrive over the VoIP channel
    /// handled above.
    ///
    /// Not currently reached: nothing in this app calls
    /// registerForRemoteNotifications(), so APNs never issues a standard token.
    /// Kept as a reference point for apps that do want non-VoIP push.
    ///
    /// - Parameters:
    ///   - application: The singleton app instance.
    ///   - deviceToken: The raw APNs token bytes.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("AppDelegate - didRegisterForRemoteNotifications")
        
        let tokenParts = deviceToken.map { data in
            String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
    }
    
    /// Called when APNs registration fails, typically from a provisioning or
    /// entitlement problem. Logged only, since the demo can still run without
    /// standard push.
    ///
    /// - Parameters:
    ///   - application: The singleton app instance.
    ///   - error: The failure reported by the system.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    
    // Receive the push notification
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("AppDelegate didReceiveRemoteNotification")
    }
}
