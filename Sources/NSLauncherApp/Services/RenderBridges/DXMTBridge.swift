// DXMTBridge.swift
//
// DXMT: Direct3D 11 translated straight to Metal. The bundled Genshin definition's default.
//
// DXMT needs a Wine whose `winemac` bridge exports the Metal view interface, which is verified
// with `nm` before launching rather than discovered as a crash.
//
// The payload used to be copied over the Wine build's own `d3d11.dll`/`dxgi.dll`. That was a
// one-way change to an installation shared with anything else using that Wine, and it left no way
// back — the originals were simply gone. The payload now stays in its own directory and is
// selected through `WINEDLLPATH`, so switching backends is just a different search path, and any
// files an older launcher version copied in are reported so they can be cleaned up.

import Foundation

struct DXMTBridge: RenderBridge {
    static let version = "v0.80"
    private static let archiveName = "dxmt-v0.80-builtin.tar.gz"
    private static let archiveURL = URL(string: "https://github.com/3Shain/dxmt/releases/download/v0.80/dxmt-v0.80-builtin.tar.gz")!

    /// Marker an older launcher left in the Wine tree after copying the payload in.
    private static let legacyMarkerName = ".nslauncher-dxmt-\(version)"

    /// Oldest Wine this DXMT release can bind to.
    ///
    /// The symbol check below only proves `macdrv_functions` is exported, not that its fields sit
    /// where DXMT expects them. Game Porting Toolkit 1.1 is wine-7.7 and exports the 2022 layout:
    /// DXMT loads, then faults inside the loader while holding ntdll's loader lock, so the game
    /// deadlocks at startup with no error at all — `RtlpWaitForCriticalSection ... loader_section`
    /// retrying forever. A version floor is the cheap way to tell that apart from a build that
    /// simply lacks the symbol.
    private static let minimumWineMajorVersion = 10

    /// Directory holding DXMT's persistent Metal pipeline cache across launches.
    static var shaderCacheDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NSLauncher/DXMTShaderCache", isDirectory: true)
    }

    /// Directory DXMT writes `d3d11.log` and reads `dxmt.conf` from.
    static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/NSLauncher/DXMT", isDirectory: true)
    }

    let backend: RuntimeBackend = .dxmt

    func launchEnvironment(settings: AppSettings, displayRefreshRate: Int) -> [String: String] {
        var env: [String: String] = [:]

        // Sync primitive selection. esync is the safe default: on the DXMT-patched Wine build used
        // here, msync (`WINEMSYNC=1`) surfaced as `wine client error:308: partial wakeup read 0`
        // immediately followed by `err:virtual:virtual_setup_exception nested exception on signal
        // stack` — a hard render-path crash. YAAGL also ships esync for Genshin and msync only for
        // its other game clients. `useMsync` is an opt-in escape hatch for Wine builds where the
        // marzent msync patches work.
        env[settings.useMsync ? "WINEMSYNC" : "WINEESYNC"] = "1"
        // An empty override list keeps the DXMT builtin D3D10/D3D11/DXGI DLLs authoritative and
        // prevents any shell-level WINEDLLOVERRIDES from leaking into the launch.
        env["WINEDLLOVERRIDES"] = ""

        // DXMT_LOG_PATH names the DIRECTORY that `d3d11.log` is written into, not a file. Passing a
        // file path left DXMT unable to open its log, so every DXMT message fell through to stderr.
        env["DXMT_LOG_PATH"] = Self.supportDirectory.path
        env["DXMT_CONFIG_FILE"] = Self.supportDirectory.appendingPathComponent("dxmt.conf").path

        // Persistent Metal pipeline cache. DXMT translates each D3D11 pipeline state into a Metal
        // pipeline the first time the game draws with it; without a cache that cost is paid again
        // every session, so switching to a character whose materials, weapon and skill VFX have not
        // been drawn yet stalls while its pipelines compile. DXMT ships the cache off, and YAAGL
        // never enables it either.
        env["DXMT_SHADER_CACHE"] = "1"
        env["DXMT_SHADER_CACHE_PATH"] = Self.shaderCacheDirectory.path

        var config = ""
        // `d3d11.preferredMaxFrameRate` must be a FACTOR of the display refresh rate; a non-factor
        // value contributed to a render-path crash, so the request is snapped down.
        let frameCap = AppSettings.supportedFrameCap(
            requested: settings.maxFrameRate,
            refreshRate: displayRefreshRate
        )
        if frameCap > 0 {
            config += "d3d11.preferredMaxFrameRate=\(frameCap);"
        }
        // MetalFX spatial upscaling only does something when the game is told to render below the
        // window size, which is what `resolutionCustom` sets up. Without it the game still renders
        // at its own resolution and the MetalFX pass is pure GPU cost.
        if settings.metalFXUpscaling, settings.resolutionCustom {
            env["DXMT_METALFX_SPATIAL_SWAPCHAIN"] = "1"
            config += "d3d11.metalSpatialUpscaleFactor=\(max(settings.metalFXScaleFactor, 1.0));"
        }
        if !config.isEmpty {
            env["DXMT_CONFIG"] = config
        }

        // Rank GStreamer's H.264 decoders (Apple AudioToolbox + FFmpeg) so in-game/cutscene video
        // never selects a broken decoder. Mirrors YAAGL's always-on DXMT launch config.
        env["GST_PLUGIN_FEATURE_RANK"] = "atdec:MAX,avdec_h264:MAX"
        return env
    }

    func resolveWineBuild(
        preferredPath: String,
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws -> WineBuild {
        do {
            return try await selectBuild(
                preferredPath: preferredPath,
                processRunner: processRunner,
                onDiagnostic: onDiagnostic
            )
        } catch let error as WineServiceError {
            // A quarantined build is the user's to unblock; downloading several hundred megabytes
            // would not change the outcome.
            if case .binaryQuarantined = error { throw error }
            onDiagnostic("no DXMT-capable Wine installed (\(error.localizedDescription))")
            try await WineDistribution.ensureInstalled(
                processRunner: processRunner,
                onDiagnostic: onDiagnostic
            )
            return try await selectBuild(
                preferredPath: preferredPath,
                processRunner: processRunner,
                onDiagnostic: onDiagnostic
            )
        }
    }

    /// Picks the newest installed build that is both new enough and exports the Metal interface.
    private func selectBuild(
        preferredPath: String,
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws -> WineBuild {
        let search = await WineBinaryLocator.search(
            preferredPath: preferredPath,
            processRunner: processRunner,
            onDiagnostic: onDiagnostic
        )

        var tooOld: [String] = []
        var withoutSymbols: [String] = []

        for build in search.builds {
            guard build.majorVersion >= Self.minimumWineMajorVersion else {
                onDiagnostic("wine-\(build.majorVersion) is older than the wine-\(Self.minimumWineMajorVersion) DXMT \(Self.version) needs: \(build.binaryPath)")
                tooOld.append("\(build.binaryPath) (wine-\(build.majorVersion))")
                continue
            }
            do {
                try await verifyMetalSymbols(
                    wineLibrary: build.root.appendingPathComponent("lib/wine", isDirectory: true),
                    wineBinaryPath: build.binaryPath,
                    processRunner: processRunner
                )
                return build
            } catch {
                onDiagnostic("winemac has no DXMT Metal symbols: \(build.binaryPath)")
                withoutSymbols.append(build.binaryPath)
            }
        }

        if let quarantined = search.quarantinedPaths.first {
            throw WineServiceError.binaryQuarantined(quarantined)
        }
        if withoutSymbols.isEmpty, !tooOld.isEmpty {
            throw WineServiceError.dxmtWineTooOld(tooOld.joined(separator: ", "))
        }
        let attempted = withoutSymbols + tooOld
        throw WineServiceError.dxmtUnsupportedWine(
            attempted.isEmpty ? preferredPath : attempted.joined(separator: ", ")
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
        do {
            Self.createSupportDirectories()
            let payload = try await extractedPayload(processRunner: processRunner)
            onDiagnostic("DXMT payload path=\(payload.path)")

            RenderBridgePayload.prependToDLLPath(
                [
                    payload.appendingPathComponent("x86_64-windows", isDirectory: true),
                    payload.appendingPathComponent("i386-windows", isDirectory: true)
                ],
                wineRoot: wineBuild.root,
                environment: &environment
            )
            onDiagnostic("WINEDLLPATH=\(environment["WINEDLLPATH"] ?? "")")

            // `winemetal.dll` also has to be resolvable from inside the prefix. The prefix belongs
            // to the launcher, so writing there is fine; the Wine installation is not touched.
            try RenderBridgePayload.copyDLLs(
                ["winemetal.dll"],
                from: payload.appendingPathComponent("x86_64-windows", isDirectory: true),
                to: prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
            )
            try RenderBridgePayload.copyDLLs(
                ["winemetal.dll"],
                from: payload.appendingPathComponent("i386-windows", isDirectory: true),
                to: prefixDirectory.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
            )

            reportLegacyInstall(in: wineBuild.root, onDiagnostic: onDiagnostic)
        } catch let wineError as WineServiceError {
            throw wineError
        } catch {
            throw WineServiceError.dxmtBootstrapFailed(error.localizedDescription)
        }
    }

    /// Ensures the shader-cache and log directories exist; DXMT creates neither, and a missing
    /// cache path shows up only as `[CacheReader] Failed to resolve cache path`.
    private static func createSupportDirectories() {
        for directory in [shaderCacheDirectory, supportDirectory] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let configFile = supportDirectory.appendingPathComponent("dxmt.conf")
        if !FileManager.default.fileExists(atPath: configFile.path) {
            FileManager.default.createFile(atPath: configFile.path, contents: nil)
        }
    }

    private func extractedPayload(processRunner: ProcessRunning) async throws -> URL {
        try await RenderBridgePayload.extractedPayload(
            archiveURL: Self.archiveURL,
            archiveName: Self.archiveName,
            into: RenderBridgePayload.root.appendingPathComponent("DXMT", isDirectory: true),
            extractedDirectoryName: Self.version,
            isComplete: { url in
                ["x86_64-windows/d3d11.dll", "x86_64-windows/winemetal.dll", "x86_64-unix/winemetal.so"]
                    .allSatisfy { FileManager.default.fileExists(atPath: url.appendingPathComponent($0).path) }
            },
            processRunner: processRunner,
            failure: { WineServiceError.dxmtBootstrapFailed($0) }
        )
    }

    /// DXMT needs Wine's Unix-side winemac bridge to export the macOS/Metal view symbols.
    private func verifyMetalSymbols(
        wineLibrary: URL,
        wineBinaryPath: String,
        processRunner: ProcessRunning
    ) async throws {
        let unixDirectory = wineLibrary.appendingPathComponent("x86_64-unix", isDirectory: true)
        // Stock Wine names the mac bridge `winemac.so`; CrossOver-derived builds use `winemac.drv.so`.
        let winemacBridge = ["winemac.so", "winemac.drv.so"]
            .map { unixDirectory.appendingPathComponent($0, isDirectory: false) }
            .first { FileManager.default.fileExists(atPath: $0.path) }

        guard let winemacBridge else {
            throw WineServiceError.dxmtUnsupportedWine(wineBinaryPath)
        }

        do {
            let result = try await processRunner.run(
                executable: "/usr/bin/nm",
                arguments: ["-gU", winemacBridge.path],
                environment: [:],
                currentDirectory: nil
            )
            // DXMT resolves the mac driver interface through the `macdrv_functions` table on modern
            // Wine; older DXMT-patched builds exported `macdrv_view_create_metal_view` instead.
            if !result.stdout.contains("macdrv_functions"),
               !result.stdout.contains("macdrv_view_create_metal_view") {
                throw WineServiceError.dxmtUnsupportedWine(wineBinaryPath)
            }
        } catch let wineError as WineServiceError {
            throw wineError
        } catch {
            throw WineServiceError.dxmtUnsupportedWine(wineBinaryPath)
        }
    }

    /// Surfaces DLLs an older launcher version copied into the Wine build.
    ///
    /// They are inert now that `WINEDLLPATH` wins, but they still shadow the build's own DLLs for
    /// anything else using that Wine, and only a reinstall can restore the originals.
    private func reportLegacyInstall(in wineRoot: URL, onDiagnostic: (String) -> Void) {
        let marker = wineRoot.appendingPathComponent("lib/wine/\(Self.legacyMarkerName)")
        guard FileManager.default.fileExists(atPath: marker.path) else { return }
        onDiagnostic(
            "an earlier launcher version copied DXMT DLLs into \(wineRoot.appendingPathComponent("lib/wine").path); "
                + "they are no longer used but still shadow this Wine build's own d3d11/dxgi — reinstall the Wine build to restore them"
        )
    }
}
