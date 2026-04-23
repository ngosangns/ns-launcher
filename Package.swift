// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ns-launcher",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NSLauncherApp",
            path: "Sources/NSLauncherApp"
        ),
    ]
)
