// D3DMetalBridge.swift
//
// Apple's D3DMetal, shipped inside CrossOver-derived Wine builds under `lib64/apple_gptk`.
//
// It is worth having as an alternative to DXMT because it keeps a pipeline cache on disk
// (`pipeline_cache.bin`) with no configuration at all — one less thing that can silently be off.
//
// Nothing is installed: CrossOver's own launcher script selects D3DMetal by putting
// `lib64/apple_gptk/wine/x86_64-windows` first on `WINEDLLPATH`, and this does the same. That is
// also why D3DMetal survived DXMT overwriting the `lib/wine` builtins — it never lived there.

import Foundation

struct D3DMetalBridge: RenderBridge {
    let backend: RuntimeBackend = .d3dMetal

    func launchEnvironment(settings: AppSettings, displayRefreshRate: Int) -> [String: String] {
        var env: [String: String] = [:]
        env[settings.useMsync ? "WINEMSYNC" : "WINEESYNC"] = "1"
        env["WINEDLLOVERRIDES"] = ""
        // Same reasoning as DXMT: upscaling only helps when the game renders below the window size.
        if settings.metalFXUpscaling, settings.resolutionCustom {
            env["D3DM_ENABLE_METALFX"] = "1"
        }
        if settings.showMetalHUD {
            env["D3DM_SHOW_HUD_STATS"] = "1"
        }
        env["GST_PLUGIN_FEATURE_RANK"] = "atdec:MAX,avdec_h264:MAX"
        return env
    }

    /// D3DMetal has no requirement of its own beyond being inside a Wine build that ships it,
    /// which `prepare` checks.
    func resolveWineBinary(preferredPath: String, processRunner: ProcessRunning) async throws -> String {
        for candidate in WineBinaryLocator.candidatePaths(preferredPath: preferredPath) {
            guard FileManager.default.isExecutableFile(atPath: candidate) else { continue }
            if let quarantinedPath = WineBinaryLocator.quarantinedPath(forExecutableAtPath: candidate) {
                throw WineServiceError.binaryQuarantined(quarantinedPath)
            }
            guard let wineRoot = try? WineBinaryLocator.wineRootDirectory(forBinaryAtPath: candidate) else { continue }
            if FileManager.default.fileExists(atPath: Self.gptkWindowsDirectory(in: wineRoot).appendingPathComponent("d3d11.dll").path) {
                return candidate
            }
        }
        throw WineServiceError.d3dMetalUnavailable(preferredPath)
    }

    func prepare(
        wineRoot: URL,
        wineBinaryPath: String,
        prefixDirectory: URL,
        environment: inout [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: (String) -> Void
    ) async throws {
        let gptkWindows = Self.gptkWindowsDirectory(in: wineRoot)
        guard FileManager.default.fileExists(atPath: gptkWindows.appendingPathComponent("d3d11.dll").path) else {
            throw WineServiceError.d3dMetalUnavailable(gptkWindows.path)
        }

        RenderBridgePayload.prependToDLLPath([gptkWindows], wineRoot: wineRoot, environment: &environment)
        onDiagnostic("WINEDLLPATH=\(environment["WINEDLLPATH"] ?? "")")

        // libd3dshared is loaded whether or not D3DMetal is active; CrossOver exports its path the
        // same way.
        let libD3DShared = wineRoot
            .appendingPathComponent("lib64/apple_gptk/external/libd3dshared.dylib")
        if FileManager.default.fileExists(atPath: libD3DShared.path) {
            environment["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = libD3DShared.path
        }

        for dllName in ["d3d10core", "d3d11", "dxgi"] {
            try await RenderBridgePayload.deleteDLLOverride(
                dllName,
                wineBinaryPath: wineBinaryPath,
                environment: environment,
                processRunner: processRunner
            )
        }
    }

    private static func gptkWindowsDirectory(in wineRoot: URL) -> URL {
        wineRoot.appendingPathComponent("lib64/apple_gptk/wine/x86_64-windows", isDirectory: true)
    }
}
