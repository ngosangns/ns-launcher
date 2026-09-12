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
            resources: [
                .copy("Resources/Story"),
                // Abyss team-planning data. `.copy` (not `.process`) because the
                // loader resolves characters/, weapons/ and abyss-monsters/ as
                // real subdirectories and `.process` may flatten them.
                .copy("Resources/Abyss")
            ]
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
            resources: [
                // The Abyss engine's regression baseline — see
                // Tests/NSLauncherAppTests/AbyssGoldenDump.swift, which is what
                // rewrites it.
                .copy("Fixtures")
            ]
        ),
    ]
)
