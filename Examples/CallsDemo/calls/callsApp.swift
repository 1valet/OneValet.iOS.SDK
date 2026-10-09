//
//  callsApp.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import SwiftUI

/// Entry point of the demo app.
///
/// Hosts a single `ContentView` scene and drives the pairing coordinator from
/// the scene lifecycle: the portal event stream is held open exactly while the
/// app is in the foreground — the demo's stand-in for the VoIP push a
/// production integration uses.
@main
struct callsApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { newPhase in
                    PairingCoordinator.shared.setForegrounded(newPhase == .active)
                }
        }
    }
}
