//
//  ContentView.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import SwiftUI

/// Root screen of the demo.
///
/// Unpaired, it shows the pairing code to enter on the Developer Portal's Demo
/// app page; paired, it shows who this device rings for and that calls only
/// arrive while the app is open. Presents `CallView` as a sheet when a call is
/// answered — the ringing itself is CallKit's native UI, driven by
/// `PairingCoordinator` and `CallKitManager`.
struct ContentView: View {
    /// Shared CallKit state. Observed so `isCallActive` can drive the call sheet.
    @ObservedObject var callManager = CallKitManager.sharedInstance
    /// Pairing/connection state driving everything on this screen.
    @ObservedObject var coordinator = PairingCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OneValetSDK Demo")
                .font(.headline)

            switch coordinator.state {
            case .loading:
                ProgressView()

            case .unpaired(let code, let hasError):
                Text("Pair this device")
                    .font(.subheadline.weight(.semibold))
                Text("Sign in to the 1VALET Developer Portal, open Mobile SDK → Demo app, and enter this code to choose which resident this device rings for:")

                if let code {
                    Text(code)
                        .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                        .kerning(8)
                    Text("Waiting for the code to be entered…")
                } else if hasError {
                    Text("Could not reach the Developer Portal — retrying…")
                } else {
                    ProgressView()
                }

            case .paired(let occupantName, let buildingName, let connected):
                Text("Paired")
                    .font(.subheadline.weight(.semibold))
                Text(pairedDescription(occupantName: occupantName, buildingName: buildingName))
                Text(connected ? "Listening for calls." : "Reconnecting…")
                Text("Rings arrive while this app is open. A production integration delivers rings as VoIP push notifications instead, so they also arrive in the background.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Unpair") {
                    coordinator.unpair()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $callManager.isCallActive) {
            CallView(roomId: callManager.roomId ?? "")
        }
    }

    private func pairedDescription(occupantName: String, buildingName: String) -> String {
        var text = "This device rings for "
        text += occupantName.isEmpty ? "the paired resident" : occupantName
        if !buildingName.isEmpty {
            text += " in \(buildingName)"
        }
        return text + "."
    }
}

#Preview {
    ContentView()
}
