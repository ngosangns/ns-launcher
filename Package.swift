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
                // Golden values generated once from the Python reference
                // implementation (see Resources/Abyss/README.md) — the Swift
                // Abyss engine is checked against them.
                .copy("Fixtures")
            ]
        ),
    ]
)
