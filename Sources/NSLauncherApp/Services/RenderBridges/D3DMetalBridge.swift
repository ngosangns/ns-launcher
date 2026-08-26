// D3DMetalBridge.swift
//
// D3DMetal: Apple's own Direct3D-to-Metal translation layer, shipped as part of the Game Porting
// Toolkit and bundled into CrossOver-derived Wine builds under `lib64/apple_gptk`.
//
// Unlike DXVK (or the DXMT this replaced), D3DMetal cannot be downloaded and installed by the
// launcher: it is Apple's own redistributable, gated behind CrossOver (CodeWeavers) or Apple's
// Game Porting Toolkit (Homebrew, Apple Developer sign-in required). The launcher can only detect
// and use a build the user already has — see `resolveWineBuild` — and must say so plainly when
// none is found, rather than failing with a generic launch error.
//
// Selection needs no file surgery: CrossOver's own launcher script picks D3DMetal by putting
// `lib64/apple_gptk/wine/x86_64-windows` first on `WINEDLLPATH`, ahead of the build's own
// `lib/wine` builtins, and this does the same.

import Foundation

struct D3DMetalBridge: RenderBridge {
    let backend: RuntimeBackend = .d3dMetal

    func launchEnvironment(settings: AppSettings) -> [String: String] {
        var env: [String: String] = [:]

        // esync is the safe default; see DXVKBridge for the same choice and why msync is not
        // offered here.
        env["WINEESYNC"] = "1"
        // An empty override list keeps D3DMetal's builtin D3D10/D3D11/DXGI DLLs authoritative and
        // prevents any shell-level WINEDLLOVERRIDES from leaking into the launch.
        env["WINEDLLOVERRIDES"] = ""

        // Both confirmed by reading the strings in a real D3DMetal.framework binary — CrossOver's
        // own D3DM_* variables have no public documentation, so their exact effect is inferred from
        // the name alone. Async commit is expected to overlap encoding the next Metal command
        // buffer with submitting the previous one instead of stalling the CPU thread on each
        // submit; the multithreaded interface flag is expected to stop D3DMetal serializing D3D11
        // context access more conservatively than the game's own threading needs. Default on, but
        // gated on settings (rather than unconditional) so a stutter/instability report can be
        // isolated to one of these flags without a rebuild — see AppSettings.d3dMetalAsyncCommit.
        if settings.d3dMetalAsyncCommit {
            env["D3DM_ENABLE_ASYNC_COMMIT"] = "1"
        }
        if settings.d3dMetalMultithreadedInterface {
            env["D3DM_MULTITHREADED_INTERFACE_ENABLE"] = "1"
        }

        // D3DMetal maintains its own on-disk pipeline cache with no configuration at all — verified
        // by running `strings` on a real D3DMetal.framework binary installed via CrossOver: every
        // `D3DM_*` string it contains (device identity spoofing, NaN/RTZ float handling, DXR
        // support, the two flags above, etc.) was enumerated, and none of them is a cache path,
        // pre-warm switch, or any other shader/pipeline-cache control. This is a closed line of
        // investigation, not an oversight — don't re-derive it from the name of some other D3DM_*
        // string without re-running the same check against the actual binary.

        // MetalFX spatial upscaling only does something when the game is told to render below the
        // window size, which is what `resolutionCustom` sets up. Without it the game still renders
        // at its own resolution and the MetalFX pass is pure GPU cost. D3DMetal exposes no upscale
        // factor of its own — Metal picks it — unlike DXMT's `metalSpatialUpscaleFactor`.
        if settings.metalFXUpscaling, settings.resolutionCustom {
            env["D3DM_ENABLE_METALFX"] = "1"
        }
        if settings.showMetalHUD {
            env["D3DM_SHOW_HUD_STATS"] = "1"
        }

        // Rank GStreamer's H.264 decoders (Apple AudioToolbox + FFmpeg) so in-game/cutscene video
        // never selects a broken decoder. Mirrors YAAGL's always-on launch config.
        env["GST_PLUGIN_FEATURE_RANK"] = "atdec:MAX,avdec_h264:MAX"
        return env
    }

    /// Picks the newest installed Wine build that carries D3DMetal under `lib64/apple_gptk`.
    ///
    /// Never falls back to auto-installing a Wine build: the managed download the launcher can
    /// fetch on its own (see `WineDistribution`) is a plain Wine build with no Apple Game Porting
    /// Toolkit payload, so installing it would still leave D3DMetal unavailable — just slower to
    /// find out.
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
            if Self.appleGPTKWindowsDirectory(for: build) != nil {
                return build
            }
            onDiagnostic("no Apple D3DMetal payload under lib64/apple_gptk: \(build.binaryPath)")
        }

        if let quarantined = search.quarantinedPaths.first {
            throw WineServiceError.binaryQuarantined(quarantined)
        }
        throw WineServiceError.d3dMetalUnavailable(
            search.builds.isEmpty ? preferredPath : search.builds.map(\.binaryPath).joined(separator: ", ")
        )
    }

    /// D3DMetal's DLLs are builtins selected through `WINEDLLPATH`, so native overrides must be
    /// absent — the same set DXMT declared, minus `winemetal`, which is specific to DXMT's own
    /// Unix-side bridge.
    func registryEntries() -> [RegistryEntry] {
        ["d3d10core", "d3d11", "dxgi", "nvapi64", "nvngx"].map(RegistryEntry.removingDLLOverride)
    }

    func prepare(
        wineBuild: WineBuild,
        prefixDirectory: URL,
        environment: inout [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let gptkWindows = Self.appleGPTKWindowsDirectory(for: wineBuild) else {
            throw WineServiceError.d3dMetalUnavailable(wineBuild.binaryPath)
        }

        RenderBridgePayload.prependToDLLPath([gptkWindows], wineRoot: wineBuild.root, environment: &environment)
        onDiagnostic("WINEDLLPATH=\(environment["WINEDLLPATH"] ?? "")")

        // `libd3dshared.dylib` is loaded regardless of which backend is active; CrossOver's own
        // launcher script exports its path the same way.
        let libD3DShared = wineBuild.root.appendingPathComponent("lib64/apple_gptk/external/libd3dshared.dylib")
        if FileManager.default.fileExists(atPath: libD3DShared.path) {
            environment["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = libD3DShared.path
            onDiagnostic("CX_APPLEGPTK_LIBD3DSHARED_PATH=\(libD3DShared.path)")
        }
    }

    /// The directory D3DMetal's Windows-side DLLs live in, or nil when this build does not carry
    /// Apple's Game Porting Toolkit payload at all.
    private static func appleGPTKWindowsDirectory(for build: WineBuild) -> URL? {
        let directory = build.root.appendingPathComponent("lib64/apple_gptk/wine/x86_64-windows", isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent("d3d11.dll").path)
            ? directory
            : nil
    }
}
