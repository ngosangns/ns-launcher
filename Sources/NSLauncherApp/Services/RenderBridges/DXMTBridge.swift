// DXMTBridge.swift
//
// DXMT: open-source Direct3D 11-to-Metal translation layer, bundled into CrossOver-derived Wine
// builds under `lib/dxmt` alongside Apple's own D3DMetal (`lib64/apple_gptk`) — confirmed on a
// real CrossOver install, same `x86_64-windows`/`i386-windows`/`x86_64-unix` layout D3DMetalBridge
// already knows how to detect.
//
// This replaces an earlier DXMTBridge that downloaded DXMT from GitHub and gated it behind a
// minimum Wine version plus an `nm` symbol check (both needed because that payload had to work
// against ANY Wine build the user might have). None of that applies here: CrossOver ships its own
// DXMT build matched to its own Wine, exactly like D3DMetal, so detection is just "does this Wine
// build carry the payload" — see `resolveWineBuild`.
//
// Offered as a second choice alongside D3DMetal (`AppSettings.metalRenderBackend`) simply because it
// is a different translator: when one backend renders a given effect wrong, the other is the cheapest
// thing to try. It is NOT here because of a proven D3DMetal bug. An earlier version of this comment
// claimed D3DMetal bit-reinterprets `texture_buffer<uint>` inputs through a `float` hack, citing
// `SPIRV-Cross: applying texture_buffer<float> hack, original pixel type was uint!` from real game
// logs. That line is emitted by `libMoltenVK.dylib` (the only binary in a CrossOver install that
// contains it), so it came from a DXVK-on-MoltenVK render path, never from D3DMetal — see
// `RenderBridges.builtinD3DOverrides` for why that path was running at all.

import Foundation

struct DXMTBridge: RenderBridge {
    let backend: RuntimeBackend = .dxmt
    let crossOverGraphicsBackend = "dxmt"

    /// Directory DXMT writes `d3d11.log` and reads `dxmt.conf` from.
    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/NSLauncher/DXMT", isDirectory: true)
    }

    func launchEnvironment(settings: AppSettings) -> [String: String] {
        // esync + builtin D3D overrides — shared by every Metal-native backend; see
        // RenderBridges.baseMetalNativeEnvironment.
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

        onDiagnostic("DXMT payload=\(dxmtWindows.path)")

        // `winemetal.dll` has to be resolvable from inside the prefix: CrossOver's graphics-backend
        // selection covers the Direct3D DLLs but not DXMT's own Unix-side bridge library.
        let dxmtRoot = wineBuild.root.appendingPathComponent("lib/dxmt", isDirectory: true)
        try Self.copyDLLs(
            ["winemetal.dll"],
            from: dxmtRoot.appendingPathComponent("x86_64-windows", isDirectory: true),
            to: prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        )
        try Self.copyDLLs(
            ["winemetal.dll"],
            from: dxmtRoot.appendingPathComponent("i386-windows", isDirectory: true),
            to: prefixDirectory.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
        )
    }

    /// Copies selected DLLs into a Wine Windows system directory inside the game's prefix.
    private static func copyDLLs(_ names: [String], from sourceDirectory: URL, to destinationDirectory: URL) throws {
        for name in names {
            let source = sourceDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = destinationDirectory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    /// The directory DXMT's Windows-side DLLs live in, or nil when this build does not carry
    /// CrossOver's bundled DXMT payload at all.
    /// Checks both `d3d11.dll` (selected by CrossOver) and `winemetal.dll` (copied into the prefix
    /// by `prepare` — see the comment there): a build missing either one is not usable,
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
