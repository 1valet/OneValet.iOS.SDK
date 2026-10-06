//
//  callsApp.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import SwiftUI

/// Entry point of the demo app.
///
/// Hosts a single `ContentView` scene and installs `AppDelegate` so the app can
/// receive VoIP pushes — SwiftUI's `App` lifecycle has no PushKit hook of its own.
@main
struct callsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
