// DXVKBridge.swift
//
// DXVK: Direct3D 11 translated to Vulkan, which CrossOver's MoltenVK then translates to Metal.
//
// Use only the DXVK build bundled with the selected CrossOver-derived Wine. Upstream DXVK 2.7.1
// rejects Apple GPUs because MoltenVK does not expose Vulkan geometryShader, even for games that
// do not use geometry shaders. CrossOver ships a different DXVK build matched to its Wine and
// MoltenVK stack under `lib/dxvk`; mixing the upstream DLLs with that stack fails during adapter
// discovery before the game starts.
//
// Selection is non-destructive: `CX_GRAPHICS_BACKEND=dxvk` points CrossOver's own selector at the
// bundled payload, so nothing is copied into the shared Wine installation or the game prefix.

import Foundation

struct DXVKBridge: RenderBridge {
    let backend: RuntimeBackend = .dxvk
    let crossOverGraphicsBackend = "dxvk"

    func launchEnvironment(settings: AppSettings) -> [String: String] {
        [
            "WINEESYNC": "1",
            // Force Wine builtins so CrossOver's selected payload wins even when an older launcher
            // left upstream DXVK DLLs in the prefix.
            "WINEDLLOVERRIDES": RenderBridges.builtinD3DOverrides()
        ]
    }

    /// Picks the newest installed Wine build carrying CrossOver's matched DXVK payload.
    func resolveWineBuild(
        preferredPath: String,
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws -> WineBuild {
        let search = await WineBinaryLocator.search(
            preferredPath: preferredPath,
            processRunner: processRunner,
            onDiagnostic: onDiagnostic
        )

        for build in search.builds {
            if Self.dxvkWindowsDirectory(for: build) != nil {
                return build
            }
            onDiagnostic("no compatible DXVK payload under lib/dxvk: \(build.binaryPath)")
        }

        if let quarantined = search.quarantinedPaths.first {
            throw WineServiceError.binaryQuarantined(quarantined)
        }
        let checked = search.builds.isEmpty ? preferredPath : search.builds.map(\.binaryPath).joined(separator: ", ")
        throw WineServiceError.dxvkBootstrapFailed(
            "No CrossOver Wine build with bundled DXVK was found. Checked: \(checked)"
        )
    }

    func prepare(
        wineBuild: WineBuild,
        prefixDirectory: URL,
        environment: inout [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let dxvkWindows = Self.dxvkWindowsDirectory(for: wineBuild) else {
            throw WineServiceError.dxvkBootstrapFailed(
                "No compatible DXVK payload under lib/dxvk in \(wineBuild.root.path)"
            )
        }

        onDiagnostic("DXVK bundled payload=\(dxvkWindows.path)")
    }

    private static func dxvkWindowsDirectory(for build: WineBuild) -> URL? {
        let directory = build.root.appendingPathComponent("lib/dxvk/x86_64-windows", isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent("d3d11.dll").path)
            ? directory
            : nil
    }
}
