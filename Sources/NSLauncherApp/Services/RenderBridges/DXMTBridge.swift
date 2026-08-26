// DXMTBridge.swift
//
// DXMT: open-source Direct3D 11-to-Metal translation layer, bundled into CrossOver-derived Wine
// builds under `lib/dxmt` alongside Apple's own D3DMetal (`lib64/apple_gptk`) — confirmed on a
// real CrossOver install, same `x86_64-windows`/`i386-windows`/`x86_64-unix` layout D3DMetalBridge
// already knows how to select through WINEDLLPATH.
//
// This replaces an earlier DXMTBridge that downloaded DXMT from GitHub and gated it behind a
// minimum Wine version plus an `nm` symbol check (both needed because that payload had to work
// against ANY Wine build the user might have). None of that applies here: CrossOver ships its own
// DXMT build matched to its own Wine, exactly like D3DMetal, so detection is just "does this Wine
// build carry the payload" — see `resolveWineBuild`.
//
// Selected as a second choice alongside D3DMetal (`AppSettings.metalRenderBackend`) because
// D3DMetal has a confirmed shader-translation bug of its own: `texture_buffer<uint>` inputs get
// bit-reinterpreted through a `float` "hack" (seen in real game logs as `SPIRV-Cross: applying
// texture_buffer<float> hack, original pixel type was uint!`), which shows up as wrong colors on
// specific effects/objects. DXMT is a different translator and may not carry the same bug.

import Foundation

struct DXMTBridge: RenderBridge {
    let backend: RuntimeBackend = .dxmt

    /// Directory DXMT writes `d3d11.log` and reads `dxmt.conf` from.
    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/NSLauncher/DXMT", isDirectory: true)
    }

    func launchEnvironment(settings: AppSettings) -> [String: String] {
        // esync + vulkan-1 disabled — shared by every Metal-native backend; see
        // RenderBridges.baseMetalNativeEnvironment for why both are needed.
        var env = RenderBridges.baseMetalNativeEnvironment()

        // DXMT_LOG_PATH names the directory `d3d11.log` is written into, not a file — confirmed by
        // the strings in a real bundled dxmt d3d11.dll (`DXMT_LOG_PATH`, `DXMT_CONFIG_FILE` both
        // present; `DXMT_SHADER_CACHE`/`DXMT_SHADER_CACHE_PATH` from the old GitHub-downloaded
        // build are NOT — this build's pipeline cache is internal with no path to configure, same
        // situation as D3DMetal's own cache).
        env["DXMT_LOG_PATH"] = Self.supportDirectory.path
        env["DXMT_CONFIG_FILE"] = Self.supportDirectory.appendingPathComponent("dxmt.conf").path

        // Rank GStreamer's H.264 decoders (Apple AudioToolbox + FFmpeg) so in-game/cutscene video
        // never selects a broken decoder. Mirrors YAAGL's always-on launch config.
        env["GST_PLUGIN_FEATURE_RANK"] = "atdec:MAX,avdec_h264:MAX"
        return env
    }

    /// Picks the newest installed Wine build that carries DXMT under `lib/dxmt`.
    ///
    /// Never falls back to auto-installing a Wine build, for the same reason as D3DMetalBridge: the
    /// managed download this launcher can fetch on its own is a plain Wine build with no CrossOver
    /// payload at all.
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
            if Self.dxmtWindowsDirectory(for: build) != nil {
                return build
            }
            onDiagnostic("no DXMT payload under lib/dxmt: \(build.binaryPath)")
        }

        if let quarantined = search.quarantinedPaths.first {
            throw WineServiceError.binaryQuarantined(quarantined)
        }
        throw WineServiceError.dxmtUnavailable(
            search.builds.isEmpty ? preferredPath : search.builds.map(\.binaryPath).joined(separator: ", ")
        )
    }

    /// DXMT's DLLs are builtins selected through `WINEDLLPATH`, so native overrides must be absent.
    func registryEntries() -> [RegistryEntry] {
        ["d3d10core", "d3d11", "dxgi", "nvapi64", "nvngx", "winemetal"].map(RegistryEntry.removingDLLOverride)
    }

    func prepare(
        wineBuild: WineBuild,
        prefixDirectory: URL,
        environment: inout [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let dxmtWindows = Self.dxmtWindowsDirectory(for: wineBuild) else {
            throw WineServiceError.dxmtUnavailable(wineBuild.binaryPath)
        }
        try FileManager.default.createDirectory(at: Self.supportDirectory, withIntermediateDirectories: true)

        RenderBridgePayload.prependToDLLPath([dxmtWindows], wineRoot: wineBuild.root, environment: &environment)
        onDiagnostic("WINEDLLPATH=\(environment["WINEDLLPATH"] ?? "")")

        // `winemetal.dll` also has to be resolvable from inside the prefix — WINEDLLPATH alone is
        // not enough for it, the same reason the earlier DXMT bridge copied it in.
        let dxmtRoot = wineBuild.root.appendingPathComponent("lib/dxmt", isDirectory: true)
        try RenderBridgePayload.copyDLLs(
            ["winemetal.dll"],
            from: dxmtRoot.appendingPathComponent("x86_64-windows", isDirectory: true),
            to: prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        )
        try RenderBridgePayload.copyDLLs(
            ["winemetal.dll"],
            from: dxmtRoot.appendingPathComponent("i386-windows", isDirectory: true),
            to: prefixDirectory.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
        )
    }

    /// The directory DXMT's Windows-side DLLs live in, or nil when this build does not carry
    /// CrossOver's bundled DXMT payload at all.
    /// Checks both `d3d11.dll` (selected through `WINEDLLPATH`) and `winemetal.dll` (copied into
    /// the prefix by `prepare` — see the comment there): a build missing either one is not usable,
    /// and `prepare`'s own `copyDLLs` silently skips a missing source file rather than erroring, so
    /// this is the only place that would ever catch a payload shipped without `winemetal.dll`.
    private static func dxmtWindowsDirectory(for build: WineBuild) -> URL? {
        let directory = build.root.appendingPathComponent("lib/dxmt/x86_64-windows", isDirectory: true)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.appendingPathComponent("d3d11.dll").path),
              fileManager.fileExists(atPath: directory.appendingPathComponent("winemetal.dll").path) else {
            return nil
        }
        return directory
    }
}
