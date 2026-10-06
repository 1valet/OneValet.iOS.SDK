//
//  LoadingOverlayView.swift
//  calls
//
//  Created by Justin Ngo on 2026-01-05.
//

import SwiftUI

/// The spinner card shown while a call action is in flight.
struct LoadingOverlay: View {
    /// Text shown beneath the spinner, describing what is in progress.
    var message: String

    /// A spinner and label on a translucent rounded card.
    var body: some View {
        VStack(spacing: 15) {
            ProgressView()
                .scaleEffect(1.5) // Makes the spinner slightly larger
                .tint(.white)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(30)
        .background(RoundedRectangle(cornerRadius: 15).fill(.ultraThinMaterial).brightness(-0.3))
        .shadow(radius: 10)
    }
}

/// Overlays `LoadingOverlay` on a view and blocks interaction while active.
///
/// Used to stop the user firing a second call action — unlock, mute, hang up —
/// while the first is still round-tripping to the backend.
struct LoadingModifier: ViewModifier {
    /// Whether the overlay is visible. A binding so callers can clear it when
    /// their async work finishes.
    @Binding var isShowing: Bool
    /// Message passed through to the overlay.
    var text: String

    /// Wraps `content` in a `ZStack`, disabling and blurring it while showing.
    ///
    /// - Parameter content: The view being modified.
    /// - Returns: The view with the loading overlay applied.
    func body(content: Content) -> some View {
        ZStack {
            content // Your actual app screen
                .disabled(isShowing) // Prevents buttons from being clicked
                .blur(radius: isShowing ? 3 : 0)

            if isShowing {
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .ignoresSafeArea()
                
                LoadingOverlay(message: text)
            }
        }
        .animation(.easeInOut, value: isShowing)
    }
}

extension View {
    /// Applies the loading overlay to this view.
    ///
    /// - Parameters:
    ///   - isShowing: Binding controlling overlay visibility.
    ///   - text: Message to display; defaults to `"Loading..."`.
    /// - Returns: The view with the overlay attached.
    func loading(isShowing: Binding<Bool>, text: String = "Loading...") -> some View {
        self.modifier(LoadingModifier(isShowing: isShowing, text: text))
    }
}
