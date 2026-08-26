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

import Darwin
import Foundation

struct D3DMetalBridge: RenderBridge {
    let backend: RuntimeBackend = .d3dMetal

    func launchEnvironment(settings: AppSettings) -> [String: String] {
        // esync + vulkan-1 disabled — shared by every Metal-native backend; see
        // RenderBridges.baseMetalNativeEnvironment for why both are needed.
        var env = RenderBridges.baseMetalNativeEnvironment()

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

        // D3DMetal maintains its own on-disk pipeline cache with no *environment* configuration at
        // all — verified by running `strings` on a real D3DMetal.framework binary installed via
        // CrossOver: every `D3DM_*` string it contains (device identity spoofing, NaN/RTZ float
        // handling, DXR support, the two flags above, etc.) was enumerated, and none of them is a
        // cache path, pre-warm switch, or any other shader/pipeline-cache control. This is a closed
        // line of investigation, not an oversight — don't re-derive it from the name of some other
        // D3DM_* string without re-running the same check against the actual binary.
        //
        // The cache still lives at a fixed, discoverable *location* though (same binary's strings:
        // `%s/d3dm/%s/shaders.cache/`, holding `pipeline_cache.bin`/`bytecode_cache.bin`/
        // `rootsignature_cache.bin`/`stage_cache.bin` per Metal GPU family) — see
        // `shaderCacheDirectory` below, which is what the launcher's cache-clearing feature uses.

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

    /// Where D3DMetal keeps its compiled-shader cache for one game executable, or nil if this
    /// process's Darwin per-user cache directory cannot be resolved.
    ///
    /// Derived from the `%s/d3dm/%s/shaders.cache/` format string in a real D3DMetal.framework
    /// binary: the first `%s` is macOS's per-user cache directory (`confstr(3)` with
    /// `_CS_DARWIN_USER_CACHE_DIR` — NOT `~/Library/Caches`, this is the `/var/folders/.../C/`
    /// directory `getconf DARWIN_USER_CACHE_DIR` prints), the second is the executable's own file
    /// name (`GenshinImpact.exe`, matching what was found on disk at
    /// `.../C/d3dm/GenshinImpact.exe/shaders.cache/`). D3DMetal recreates every file under this
    /// directory the next time each shader is used, so removing it only costs a fresh round of
    /// compile-on-first-use stutter — worth it if the cache itself has gone stale or corrupt.
    static func shaderCacheDirectory(forExecutable executableName: String) -> URL? {
        var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
        let length = confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, buffer.count)
        guard length > 0, length <= buffer.count else { return nil }
        let path = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        let cacheRoot = URL(fileURLWithPath: path, isDirectory: true)
        return cacheRoot
            .appendingPathComponent("d3dm", isDirectory: true)
            .appendingPathComponent(executableName, isDirectory: true)
    }
}
