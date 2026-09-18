// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VocalCue",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "VocalCue",
            path: "VocalCue",
            exclude: ["Info.plist", "VocalCue.entitlements"],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
