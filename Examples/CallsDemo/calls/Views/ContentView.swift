//
//  ContentView.swift
//  calls
//
//  Created by Justin Ngo on 2025-12-17.
//

import SwiftUI

/// Root screen of the demo.
///
/// Deliberately minimal — its real job is to request notification permission
/// and present `CallView` as a sheet when a call is answered. Everything that
/// makes a call happen lives in `AppDelegate` (VoIP push) and `CallKitManager`.
struct ContentView: View {
    /// Shared CallKit state. Observed so `isCallActive` can drive the call sheet.
    @ObservedObject var callManager = CallKitManager.sharedInstance

    /// Placeholder content, plus the call sheet and the on-appear setup work.
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .sheet(isPresented: $callManager.isCallActive) {
            CallView(
                occupantId: APICalls.occupantId,
                roomId: callManager.roomId ?? ""
            )
        }
        .onAppear {            
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("Permission granted")
                } else if let error = error {
                    print("Error requesting permission: \(error)")
                }
            }

            
        }
    }
}

#Preview {
    ContentView()
}
