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
            path: "Sources/NSLauncherApp",
            // Story and Abyss data stays here for the web companion. The
            // launcher does not bundle it; excluding it keeps SwiftPM from
            // warning about every file in the target directory.
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "IconGen",
            dependencies: ["AppIconKit"],
            path: "Sources/IconGen"
        ),
        .testTarget(
            name: "NSLauncherAppTests",
            dependencies: ["NSLauncherApp"],
            path: "Tests/NSLauncherAppTests",
            // The web planner tests import this JSON from disk.
            exclude: ["Fixtures"]
        ),
    ]
)
