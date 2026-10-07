# OneValetSDK for iOS

Calls (two-way audio/video) for the 1VALET platform, distributed as a binary
(closed-source) Swift package. `TwilioVideo` is pulled in automatically as a
transitive dependency — you never add it yourself.

The iOS SDK owns the call itself: joining the call media with the token your
backend minted, rendering the visitor's video, and the in-call controls.
Everything before that moment — the push, the incoming-call UI, answering — is
your app's, and everything your backend reports or unlocks goes through the
1VALET Public API.

- [Requirements](#requirements)
- [Installation](#installation)
- [Permissions](#permissions)
- [Quickstart](#quickstart)
- [Threading & lifecycle](#threading--lifecycle)
- [What the SDK does *not* do](#what-the-sdk-does-not-do)
- [API reference](#api-reference)
- [Error handling](#error-handling)
- [Troubleshooting](#troubleshooting)
- [Sample app](#sample-app)

---

## Requirements

| | |
|---|---|
| iOS | 15.0+ |
| Xcode | 16+ |
| Swift tools | 6.2 |
| Dependency | `TwilioVideo` 5.x (resolved automatically) |

---

## Installation

### Swift Package Manager (Xcode)

1. **File ▸ Add Package Dependencies…**
2. Enter the package URL:
   ```
   https://github.com/YOURORG/OneValetSDK.git
   ```
3. Pick a version rule — **Up to Next Major** from `1.0.0` is recommended.
4. Add the **OneValetSDK** library product to your app target.

`TwilioVideo` resolves transitively — do not add it as a separate dependency.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/YOURORG/OneValetSDK.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "OneValetSDK", package: "OneValetSDK")
        ]
    )
]
```

---

## Permissions

Add the usage-description keys to your app's `Info.plist`. Missing keys cause an
immediate crash the first time the camera or microphone is accessed:

| Key | Needed for |
|---|---|
| `NSCameraUsageDescription` | Local camera video in calls. |
| `NSMicrophoneUsageDescription` | Microphone audio in calls. |

```xml
<key>NSCameraUsageDescription</key>
<string>Video calls from your building's entrance show the visitor.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Talk to visitors calling from your building's entrance.</string>
```

**Requesting the runtime permissions is the integrating app's responsibility** —
request camera and microphone access before calling `joinRoom`.

Then import the SDK anywhere you use it:

```swift
import OneValetSDK
```

---

## Quickstart

Calls run through a shared, observable `CallManager`. Your backend obtains the
room credentials from the 1VALET API; the SDK connects, publishes local audio,
and exposes the remote video track for rendering.

> **You provide the credentials.** `token` comes from the 1VALET API via **your**
> backend, and `roomId` arrives in the incoming-call push (or from your backend).
> Never hardcode or ship an access token in the app.
>
> `callId` is **not** a credential and does not come from the API — it is the
> CallKit call UUID your app mints when it reports the incoming call, passed here
> so the system call and the media session refer to the same call. Reuse the UUID
> you gave `CXProvider.reportNewIncomingCall(with:update:)`; a fresh one here
> would decouple the two.

### 1. Observe the manager

`CallManager` is `@MainActor` and an `ObservableObject`, so SwiftUI views can
drive themselves from its published properties.

```swift
import SwiftUI
import OneValetSDK

struct CallScreen: View {
    @StateObject private var calls = CallManager.sharedInstance

    let roomId: String   // from the call push, or your backend
    let token: String    // from the 1VALET API, via your backend
    let callId: UUID     // the CallKit UUID your app reported the call with

    var body: some View {
        ZStack {
            // Remote party's video fills the screen once the call is active.
            CallVideoView(track: calls.remoteVideoTrack)
                .ignoresSafeArea()

            switch calls.state {
            case .idle, .connecting:
                ProgressView("Connecting…")
            case .active:
                CallControls(calls: calls)
            case .ended:
                Text("Call ended")
            }
        }
        .task {
            do {
                try await calls.joinRoom(
                    roomId: roomId,
                    token: token,
                    callId: callId
                )
            } catch {
                // Handle CallError — see Error handling below.
                print("Failed to join: \(error)")
            }
        }
        .onDisappear { calls.disconnect() }
    }
}
```

### 2. Call controls

```swift
struct CallControls: View {
    @ObservedObject var calls: CallManager
    @State private var muted = false

    var body: some View {
        HStack(spacing: 24) {
            Button(muted ? "Unmute" : "Mute") {
                muted.toggle()
                calls.setMuteMicrophone(mute: muted)
            }
            Button("Hang up") { calls.disconnect() }
        }
    }
}
```

---

## Threading & lifecycle

- All observable state is exposed as `@Published` properties on an
  `ObservableObject`; bind them from SwiftUI (`@StateObject`, `@ObservedObject`).
  `CallManager` is `@MainActor`, so every published value updates on the main
  actor and is safe to read directly from a view.
- `CallManager` is **not a forced singleton** — build one, hold it while the
  call UI lives, and call `release()` when done. A process-wide convenience
  instance is available via `CallManager.sharedInstance` for apps that only ever
  run one call at a time, which is often what the push and CallKit layers want
  since they need to reach the live call without a view in scope.
- `joinRoom` is an `async throws` function that returns once the room is
  connected and throws `CallError` otherwise. `state` reaches `.active` only when
  remote media arrives — after the call returns — so drive UI from `state`.
- `disconnect()` ends the call and leaves the manager reusable; `release()` is
  the full teardown (room, tracks, camera) for a manager you own. Prefer
  `disconnect()` on `sharedInstance`, which lives for the process.
- Joining does not start your camera. Local video is explicit: `activateCamera()`
  creates the track, `initiateLocalVideo()` publishes it.

---

## What the SDK does *not* do

The SDK is the **media engine only**. Your app owns everything around it:

- **Access tokens.** The SDK does not talk to any backend. Fetch the access
  token from your own backend and pass it to `joinRoom`.
- **Incoming-call push and call presentation.** There is no PushKit or CallKit
  handling in the SDK — report the call to CallKit and call `joinRoom` when the
  user answers. In production, rings arrive as **VoIP pushes** (see the Developer
  Portal's "Ring your app" page), and iOS terminates an app that receives a VoIP
  push without reporting a CallKit call. The sample rings over a foreground event
  stream instead — the CallKit reporting code is the same either way; only the
  trigger differs. You also own the audio session — route CallKit's
  `didActivate` / `didDeactivate` to `enableAudioDevice()` /
  `disableAudioDevice()`, or the call connects with no audio.
- **Door unlock and other business actions.** These are plain requests your app
  makes through your backend. The SDK only provides `sendData(_:)` if you want
  to signal the other participant over the in-call data channel.
- **Call-status reporting.** Telling the entry console what the resident is doing
  — answered, on hold, hung up — is your backend call, not an SDK one.
  `setMuteMicrophone(mute:)` changes the local mic and nothing else.

---

## API reference

### `CallManager` (`@MainActor`, `ObservableObject`)

Construct one with `CallManager()` and own its lifecycle, or use the
process-wide `CallManager.sharedInstance` if you only ever run one call at
a time.

**Published properties** (observe from SwiftUI; all read-only)

| Property | Type | Meaning |
|---|---|---|
| `state` | `CallState` | Call lifecycle — the single source of truth for UI. |
| `remoteVideoTrack` | `CallVideoTrack?` | Remote party's video, or `nil`. |
| `localVideoTrack` | `CallVideoTrack?` | Local camera track, or `nil`. |
| `isRemoteCameraAvailable` | `Bool` | Whether the remote party is publishing video. |
| `isLocalCameraAvailable` | `Bool` | Whether the local camera is capturing. |
| `isUsingFrontCamera` | `Bool` | Bind a local `CallVideoView`'s `mirror` to this. |
| `isMuted` | `Bool` | Whether the local mic is muted. |

**Methods**

| Member | Description |
|---|---|
| `init()` | Creates a manager you own; pair with `release()`. |
| `CallManager.sharedInstance` | Process-wide convenience instance. |
| `joinRoom(roomId:token:callId:) async throws` | Connects; returns once established, throws `CallError`. `callId` is your CallKit call UUID, not an API value. |
| `disconnect()` | Leaves the room; `state` transitions to `.ended`. Manager stays reusable. |
| `release()` | Full teardown — room, local tracks, camera; `state` returns to `.idle`. |
| `setMuteMicrophone(mute:)` | Mute/unmute the local mic; reflected in `isMuted`. |
| `holdCall(onHold:)` | Hold/resume by toggling local audio + video; the room stays connected. |
| `activateCamera()` | Create the local camera track (published as `localVideoTrack`) without publishing it yet. |
| `initiateLocalVideo() async -> Bool` | Publish the local camera track to the room; `true` if there's a camera to show. |
| `deactivateCamera()` | Stop and tear down the local camera. |
| `flipCamera()` | Switch front ↔ back camera; updates `isUsingFrontCamera`. |
| `enableAudioDevice()` / `disableAudioDevice()` | Route / restore call audio (e.g. from CallKit's `didActivate` / `didDeactivate`). |
| `isLocalAudioEnabled()` / `isLocalVideoEnabled() -> Bool` | Current enabled state of the local tracks. |
| `sendData(_:)` | Send a string to other participants over the in-call data channel. |

### `CallState`

| State | Meaning |
|---|---|
| `.idle` | No call in progress. |
| `.connecting` | Connecting to the room; waiting for remote media. |
| `.active` | Remote media is flowing — the call is live. |
| `.ended` | Remote party left or the connection failed. |

### `CallVideoView`

An opaque renderer for a `CallVideoTrack` (the underlying video view is kept
private inside it, scaled to fill).

```swift
CallVideoView(track: calls.remoteVideoTrack)              // remote
CallVideoView(track: calls.localVideoTrack, mirror: true) // mirrored self-view
```

`init(track: CallVideoTrack? = nil, mirror: Bool = false)` — pass `nil` to show
nothing; set `mirror` for the local front camera.

### `CallVideoTrack`

An opaque handle to a video track (`Equatable`). You never construct it — read
it from `remoteVideoTrack` / `localVideoTrack` and hand it to a `CallVideoView`.

---

## Error handling

`joinRoom` throws `CallError`:

| Case | When |
|---|---|
| `failedToConnect(Error)` | The room failed to connect; underlying error attached. |
| `disconnectedBeforeConnecting` | Disconnected before the connection finished establishing. |

```swift
do {
    try await calls.joinRoom(roomId: roomId, token: token, callId: callId)
} catch CallError.failedToConnect(let underlying) {
    // Show a retry UI; log `underlying`.
} catch CallError.disconnectedBeforeConnecting {
    // The other side hung up before connecting.
} catch {
    // Unexpected.
}
```

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| App crashes on first camera/mic use | Missing `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`. |
| Undefined symbols for `TwilioVideo` at link time | You added a bare XCFramework instead of the SPM package — use the package URL so it links transitively. |
| Black remote video but audio works | Remote party isn't publishing video — check `isRemoteCameraAvailable`. |
| Call never leaves `.connecting` | Bad/expired `token`, wrong `roomId`, or the room isn't open yet — verify with your backend. |

---

## Sample app

[`Examples/CallsDemo`](Examples/CallsDemo) (`calls.xcodeproj`) is a complete,
runnable iOS app showing how to integrate the SDK end-to-end — incoming calls
surfaced through the system call UI (**CallKit**), then connected with the SDK's
`CallManager`. It consumes this package the same way your app will.

The demo pairs with the **1VALET Developer Portal**: it displays a short code,
you enter it on the portal's Demo app page (Mobile SDK → Demo app) and pick the
resident it rings for, and from then on it receives real intercom calls — no
backend of your own, no push certificates, no configuration beyond the portal
URL in `APICalls.swift`.

Rings arrive over an event stream the app holds open, so the demo rings **while
the app is in the foreground**. A production integration delivers rings as
**VoIP pushes** from its own backend (PushKit), which is what the Developer
Portal's "Ring your app" page documents — the CallKit reporting, answering, and
audio-session code in `CallKitManager.swift` is the same either way; only the
trigger differs.

### Project layout

| File | What it shows |
|---|---|
| `calls/PairingCoordinator.swift` | Pairs the device with the portal and holds the event stream open while the app is foregrounded, turning ring events into CallKit calls and dismissals. |
| `calls/CallKitManager.swift` | Wraps `CXProvider` / `CXCallController` — reporting, answering, and ending calls, then driving `CallManager`. This is the code a VoIP push handler drives in production. |
| `calls/Views/CallView.swift` | In-call UI: renders remote video and wires up call controls (including the door-unlock request). |

> **Networking model:** in production your app talks to **your own backend
> API**, which in turn calls the **1VALET Public API** — the app never calls
> 1VALET directly. In this demo, the Developer Portal's demo backend plays your
> backend's role: it mints call tokens, relays call events, and triggers door
> unlock. (Door unlock is a plain request your app makes through your backend;
> it is **not** part of OneValetSDK.)

### Running the demo

1. Open `Examples/CallsDemo/calls.xcodeproj` in Xcode 16+.
2. Set your **Team** and a unique **bundle ID** under *Signing & Capabilities*.
3. If you are not using the default portal, set `portalBaseUrl` in
   `calls/Networking/APICalls.swift`.
4. Build and run on a **real device** — CallKit does not work in the Simulator.
5. Pair the app from the portal's Demo app page, then place a call from an
   intercom in the building.

---

## Support

Questions or integration help: **developer support @ 1VALET** (add your real
support channel / SLA here before publishing).
