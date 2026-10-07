// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OneValetSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // The product bundles the closed-source binary plus the Twilio link anchor.
        .library(name: "OneValetSDK", targets: ["OneValetSDK", "TwilioLink"])
    ],
    dependencies: [
        .package(url: "https://github.com/twilio/twilio-video-ios", from: "5.5.0")
    ],
    targets: [
        // The compiled, closed-source SDK. Consumers `import OneValetSDK`.
        // Two variants below; exactly one is active at a time.

        // LOCAL DEVELOPMENT (active): the xcframework produced by
        // ../OneValet.CallsSDK.iOS/build-xcframework.sh. Keeps the package graph
        // resolvable before any release has been published.
        // .binaryTarget(
        //     name: "OneValetSDK",
        //     path: "../OneValet.CallsSDK.iOS/build/OneValetSDK.xcframework"
        // ),

        // RELEASE (inactive): the published artifact consumers download. Before
        // cutting a release, swap the two — comment the local one out and
        // uncomment this one. The release workflow fills in `url` and `checksum`
        // (see RELEASE.md); it matches those two lines by their leading
        // indentation, so keep each on its own line. While this block stays
        // commented out the workflow stops with an error rather than publishing a
        // manifest that points at a local path.
        .binaryTarget(
            name: "OneValetSDK",
            url: "https://github.com/1valet/OneValet.iOS.SDK/releases/download/0.0.3/OneValetSDK.xcframework.zip",
            checksum: "7c633d61081da82c5eadb949bbc46f15e1e4eeede79f7c3aa2012e41a1de9837"
        ),
        // binaryTargets cannot declare dependencies, so this tiny target forces
        // TwilioVideo (which the binary references) to link into the consumer app.
        .target(
            name: "TwilioLink",
            dependencies: [
                .product(name: "TwilioVideo", package: "twilio-video-ios")
            ]
        )
    ]
)
