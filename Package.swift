// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ns-launcher",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "AppIconKit",
            path: "Sources/AppIconKit"
        ),
        .executableTarget(
            name: "NSLauncherApp",
            dependencies: ["AppIconKit"],
            path: "Sources/NSLauncherApp"
        ),
        .executableTarget(
            name: "IconGen",
            dependencies: ["AppIconKit"],
            path: "Sources/IconGen"
        ),
        .testTarget(
            name: "NSLauncherAppTests",
            dependencies: ["NSLauncherApp"],
            path: "Tests/NSLauncherAppTests"
        ),
    ]
)
