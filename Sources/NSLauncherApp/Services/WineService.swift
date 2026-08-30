// WineService.swift
//
// Launches the Windows game through Wine: picks the render bridge, applies the environment,
// writes the Wine Mac Driver / game registry settings, launches (optionally through a steam.exe
// parent), streams output, and maps failures to targeted errors.
//
// Which Direct3D translation layer runs, what it needs from the Wine build, and how it is put in
// place all belong to `RenderBridge` (see Services/RenderBridges). This service only asks the
// bridge for the backend the profile resolved and then gets on with launching.
//
// Every registry value a launch needs — the bridge's DLL overrides and the launcher's own Mac
// Driver and PlayerPrefs settings — is collected and imported in a single `wine regedit` run. Each
// `wine reg` invocation is a whole Wine process, and nine of them back to back cost 3.8s of dead
// time before the game window could appear; see `RegistryScript`.
//
// Wine cannot load Windows kernel drivers, so output is scanned for known protection
// driver names (`HoYoKProtect.sys`, `HoYoProtect.sys`, `mhyprot2.sys`) and surfaced
// as `.unsupportedKernelDriver` instead of a generic process failure.
//
// Anti-cheat parent-process bypass: miHoYo's anti-cheat (MHYPBase) skips loading its
// HoYoKProtect kernel driver when the game's parent process is `steam.exe`. Wine cannot
// load that WDF driver at all, so the game is launched through a `steam.exe` parent —
// preferably the real Valve stub + `lsteamclient.dll` (see `ensureSteamStub`), falling
// back to a Wine builtin `cmd.exe` copied to `steam.exe` (see `ensureSteamLauncher`).
// DO NOT launch the game directly as the default path; without the steam.exe parent the
// client aborts during the anti-cheat driver-load phase.

import Foundation

/// Complete request needed to launch a Windows executable through Wine.
struct WineLaunchRequest {
    var wineBinaryPath: String
    var prefixDirectory: URL
    var executablePath: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectory: URL?
    var runtimeRequirements: [RuntimeRequirement]
    /// Translation layer the profile resolved for this launch; decides which bridge is installed
    /// and which DLL search path the game runs with.
    var renderBackend: RuntimeBackend = .plainWine
    /// Launch the game through a `steam.exe` parent process (miHoYo anti-cheat workaround).
    var useSteamLauncher: Bool = false
    /// Wine Mac Driver: enable Retina scaling for HiDPI displays.
    var macDriverRetina: Bool = true
    /// Wine Mac Driver: treat the left Command key as Ctrl for games that assume Windows bindings.
    var leftCommandIsCtrl: Bool = false
    /// Starting resolution written to the game's registry keys before launch — the same size the
    /// launch arguments ask for (see `LaunchRuntimeProfile.renderSize`).
    var renderSize: RenderSize? = nil
    /// Enable the game's HDR registry flag.
    var enableHDR: Bool = false
    /// Run the game in Win32 exclusive fullscreen.
    ///
    /// Drives both halves of it: Unity's own persisted fullscreen flag, and macdrv's
    /// `CaptureDisplaysForFullscreen`, which lets macdrv capture the display for real fullscreen
    /// (hidden menu bar/dock, exclusive access) once the window's frame covers the whole screen.
    /// They have to move together — a captured display with the game believing it is windowed is
    /// how a stale window size ends up scanned out stretched across the screen.
    var fullscreen: Bool = false
    var onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
}

/// Wine launch failures that need targeted user remediation.
enum WineServiceError: LocalizedError {
    case binaryQuarantined(String)
    case d3dMetalUnavailable(String)
    case dxmtUnavailable(String)
    case unsupportedKernelDriver(String)
    case wineRootNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .binaryQuarantined(path):
            return "Wine is blocked by macOS quarantine at \(path)."
        case let .d3dMetalUnavailable(path):
            return "No Wine build with Apple D3DMetal was found. Checked: \(path). D3DMetal ships only inside CrossOver — install it, then try again."
        case let .dxmtUnavailable(path):
            return "No Wine build with DXMT was found. Checked: \(path). DXMT ships only inside CrossOver — install it, then try again."
        case let .unsupportedKernelDriver(driver):
            return "Wine cannot load the Windows kernel driver \(driver)."
        case let .wineRootNotFound(path):
            return "Unable to locate Wine's lib/wine directory for \(path)."
        }
    }
}

/// Boundary for Wine launch behavior.
protocol WineServicing: Sendable {
    func launch(_ request: WineLaunchRequest) async throws -> ProcessResult
}

/// Uses ProcessRunner to start a configured executable with WINEPREFIX applied.
struct WineService: WineServicing {

    let processRunner: ProcessRunning

    init(processRunner: ProcessRunning) {
        self.processRunner = processRunner
    }

    /// Launches the game executable through Wine and returns the completed process result.
    func launch(_ request: WineLaunchRequest) async throws -> ProcessResult {
        // Capturing only the output sink, rather than the whole request, keeps this closure
        // Sendable — the bridges hand it to a URLSession delegate to report download progress.
        let onOutput = request.onOutput
        let diagnose: @Sendable (String) -> Void = { message in
            onOutput?(ProcessOutputChunk(stream: .stdout, text: "[NSLauncher][launch-detail] \(message)\n"))
        }

        Self.raiseFileDescriptorLimit(onDiagnostic: diagnose)
        diagnose("launch request executable=\(request.executablePath.path)")
        diagnose("launch request currentDirectory=\(request.currentDirectory?.path ?? "nil") prefix=\(request.prefixDirectory.path)")
        diagnose("launch request runtime=\(request.runtimeRequirements.map(\.rawValue).joined(separator: ",")) args=\(request.arguments.joined(separator: " "))")

        let bridge = RenderBridges.bridge(for: request.renderBackend)
        diagnose("render backend=\(request.renderBackend.rawValue)")
        diagnose("resolve Wine for \(request.renderBackend.rawValue) from preferred=\(request.wineBinaryPath)")
        let wineBuild = try await resolveWineBuild(bridge: bridge, request: request, onDiagnostic: diagnose)
        diagnose("resolved Wine binary=\(wineBuild.binaryPath) wine-\(wineBuild.majorVersion) root=\(wineBuild.root.path)")
        onOutput?(ProcessOutputChunk(stream: .stdout, text: "NSLauncher selected Wine binary: \(wineBuild.binaryPath)\n"))

        // Caller-supplied environment values win except for WINEPREFIX, which must match settings.
        // Enforce WINEARCH and WINEDEBUG defaults if caller did not supply them.
        var baseEnv: [String: String] = [
            "WINEARCH": "win64",
            // See LaunchRuntimeProfile.build's WINEDEBUG comment for why `err` stays on
            // (the launcher's own failure detection reads it) while everything else is off.
            "WINEDEBUG": "-all,+err,err-unwind"
        ]
        baseEnv.merge(request.environment) { _, new in new }
        baseEnv["WINEPREFIX"] = request.prefixDirectory.path
        // CX_ROOT is what lets a CrossOver-derived build find its compatibility database, whose
        // `set_graphics_backend` step is the only thing that actually puts a translation layer on the
        // DLL search path. Without CX_ROOT it logs `prepend_cx_root_dll_path CX_ROOT not set` and
        // skips that step, and the game runs on whatever `d3d11.dll` happens to resolve. Which layer
        // it picks would otherwise come from the CrossOver BOTTLE config, so the backend this launch
        // resolved is pinned explicitly right after.
        if let crossOverRoot = Self.crossOverRootToApply(for: wineBuild, bridge: bridge) {
            baseEnv["CX_ROOT"] = crossOverRoot.path
            diagnose("CX_ROOT=\(crossOverRoot.path)")
            if let graphicsBackend = bridge?.crossOverGraphicsBackend {
                baseEnv["CX_GRAPHICS_BACKEND"] = graphicsBackend
                diagnose("CX_GRAPHICS_BACKEND=\(graphicsBackend)")
            }
        }

        var d3dMetalCacheGeneration: String?
        if request.renderBackend == .d3dMetal {
            do {
                d3dMetalCacheGeneration = try D3DMetalBridge.prepareShaderCache(
                    forExecutable: request.executablePath.lastPathComponent,
                    wineBuild: wineBuild,
                    onDiagnostic: diagnose
                )
            } catch {
                diagnose("D3DMetal cache prepare best-effort failed: \(error.localizedDescription)")
            }
        }

        if let bridge {
            diagnose("prepare \(request.renderBackend.rawValue) runtime")
            try await bridge.prepare(
                wineBuild: wineBuild,
                prefixDirectory: request.prefixDirectory,
                environment: &baseEnv,
                processRunner: processRunner,
                onDiagnostic: diagnose
            )
            diagnose("\(request.renderBackend.rawValue) runtime ready")
        }

        let env = baseEnv
        diagnose("environment WINEPREFIX=\(env["WINEPREFIX"] ?? "") WINEARCH=\(env["WINEARCH"] ?? "") WINEDEBUG=\(env["WINEDEBUG"] ?? "") customKeys=\(request.environment.keys.sorted().joined(separator: ","))")

        // Apply the bridge's DLL overrides together with the launcher's Mac Driver and game
        // registry settings, in one import. Best-effort: a registry write failure must not block
        // the launch (mirrors YAAGL's ignore-on-error behavior).
        let entries = Self.launchRegistryEntries(for: request)
        do {
            diagnose("apply \(entries.count) registry values in one import")
            try await RegistryScript.apply(
                entries,
                wineBinaryPath: wineBuild.binaryPath,
                environment: env,
                processRunner: processRunner
            )
        } catch {
            diagnose("registry settings best-effort failed: \(error.localizedDescription)")
        }

        diagnose("snapshot existing game processes")
        let alreadyRunningGamePIDs = await GameProcessInspector.runningProcessIDs(forExecutable: request.executablePath)
        diagnose("existing game process count=\(alreadyRunningGamePIDs.count)")

        // The game process — not the Wine wrapper — is the source of truth for a
        // running session. The wrapper can outlive the game (in-game quit) or die
        // while the game keeps running under wineserver.
        let gameMonitor = GameProcessMonitor(
            isGameRunning: {
                await GameProcessInspector.runningProcessIDs(forExecutable: request.executablePath).isEmpty == false
            }
        )

        var launchResult: ProcessResult
        do {
            var processArguments: [String]
            if request.useSteamLauncher {
                // Launch through a real `steam.exe` parent process (with `lsteamclient.dll` present):
                // miHoYo's anti-cheat (MHYPBase) skips loading its HoYoKProtect kernel driver when the
                // game's parent process is `steam.exe` and a Steam client is detected. Wine cannot load
                // that WDF driver, so this is the working path.
                if try await ensureSteamStub(prefixDirectory: request.prefixDirectory) {
                    let gameWindowsPath = GameProcessInspector.windowsPath(for: request.executablePath)
                    processArguments = ["C:\\windows\\system32\\steam.exe", gameWindowsPath] + request.arguments
                    diagnose("launch via real steam.exe parent: \(gameWindowsPath) \(request.arguments.joined(separator: " "))")
                } else if try ensureSteamLauncher(prefixDirectory: request.prefixDirectory, wineBuild: wineBuild) {
                    // Fallback: a Wine builtin `cmd.exe` copied to `steam.exe` still satisfies the
                    // parent-process name check when the real Valve stubs cannot be downloaded.
                    let commandLine = ([request.executablePath.lastPathComponent] + request.arguments).joined(separator: " ")
                    processArguments = ["C:\\windows\\system32\\steam.exe", "/c", commandLine]
                    diagnose("launch via cmd.exe steam parent fallback: \(commandLine)")
                } else {
                    diagnose("steam.exe parent unavailable; falling back to direct launch")
                    processArguments = [request.executablePath.path] + request.arguments
                }
            } else {
                processArguments = [request.executablePath.path] + request.arguments
            }
            diagnose("start process command=\(wineBuild.binaryPath) \(processArguments.joined(separator: " "))")
            let gameLogURL = GameLogFile.prepare()
            if let gameLogURL {
                diagnose("game output -> \(gameLogURL.path)")
            }
            launchResult = try await runGameSession(
                wineBinaryPath: wineBuild.binaryPath,
                arguments: processArguments,
                environment: env,
                currentDirectory: request.currentDirectory,
                logFileURL: gameLogURL,
                gameMonitor: gameMonitor,
                onOutput: request.onOutput,
                onDiagnostic: diagnose
            )
        } catch let ProcessRunnerError.nonZeroExit(result) {
            diagnose("process exited non-zero code=\(result.exitCode); checking whether game stayed alive")
            if await hasNewLaunchedExecutableProcess(request.executablePath, excluding: alreadyRunningGamePIDs) {
                diagnose("detected launched game process after Wine exit; treating launch as successful")
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if result.exitCode == 15, Self.outputIndicatesGameStarted(result.stdout + "\n" + result.stderr) {
                diagnose("Wine exit 15 with started-game signal; treating launch as successful")
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if let driverName = Self.unsupportedKernelDriverName(in: result.stdout + "\n" + result.stderr) {
                diagnose("unsupported kernel driver detected=\(driverName)")
                throw WineServiceError.unsupportedKernelDriver(driverName)
            } else {
                diagnose("non-zero process exit remains failure code=\(result.exitCode)")
                throw ProcessRunnerError.nonZeroExit(result)
            }
        }

        // Belt-and-suspenders: spawn a detached watchdog that outlives this launcher process, so
        // wineserver still gets torn down even if the launcher quits before the game does. See
        // `WineShutdownWatchdog` — this does not replace the in-process cleanup below, which still
        // drives the UI's Play/Stop state and the D3DMetal shader cache checkpoint.
        WineShutdownWatchdog.spawn(
            executablePath: request.executablePath,
            wineserverPath: wineBuild.root.appendingPathComponent("bin/wineserver").path,
            prefixDirectory: request.prefixDirectory,
            onDiagnostic: diagnose
        )

        // Session truth: if the actual game executable is still running after the
        // Wine wrapper exited (wrapper detached early, or Wine returned non-zero
        // while the game kept going), keep the launch session alive until the game
        // itself stops. Otherwise the launcher would flip back to "Play" while the
        // game is still up — or, conversely, stay on "Stop" because a lingering
        // wrapper never exits. Cancellation (user Stop) propagates from here.
        do {
            if await gameMonitor.isGameRunning() {
                diagnose("game process still running after Wine exit; monitoring until it stops")
                try await gameMonitor.waitUntilStopped()
                diagnose("game process stopped; ending launch session")
                launchResult = ProcessResult(exitCode: 0, stdout: launchResult.stdout, stderr: launchResult.stderr)
            }
        } catch {
            // `waitUntilStopped()` throws `CancellationError` on Stop, which used to skip the
            // wineserver shutdown below entirely (a thrown error unwinds past the rest of this
            // function). wineserver never exits on its own once winedevice.exe/services.exe are
            // attached to it, so every Stop leaked that wineserver — and its now-orphaned service
            // processes — for the lifetime of the Mac session. Each later launch then reused that
            // same increasingly stale, single-tenant-violating wineserver instead of a clean one.
            // Kill it here too before rethrowing, so a stopped launch tears down exactly like a
            // completed one.
            _ = await Self.waitForWineserver(wineBuild: wineBuild, environment: env, processRunner: processRunner, onDiagnostic: diagnose)
            throw error
        }

        // A durable snapshot is safe only after wineserver confirms every writer has exited.
        let wineServerStopped = await Self.waitForWineserver(
            wineBuild: wineBuild,
            environment: env,
            processRunner: processRunner,
            onDiagnostic: diagnose
        )

        if request.renderBackend == .d3dMetal,
           wineServerStopped,
           let d3dMetalCacheGeneration {
            do {
                try D3DMetalBridge.checkpointShaderCache(
                    forExecutable: request.executablePath.lastPathComponent,
                    wineBuild: wineBuild,
                    expectedGeneration: d3dMetalCacheGeneration,
                    onDiagnostic: diagnose
                )
            } catch {
                diagnose("D3DMetal cache checkpoint best-effort failed: \(error.localizedDescription)")
            }
        } else if request.renderBackend == .d3dMetal, wineServerStopped {
            diagnose("D3DMetal cache checkpoint skipped: prepare generation unavailable")
        } else if request.renderBackend == .d3dMetal {
            diagnose("D3DMetal cache checkpoint skipped: Wine shutdown not confirmed")
        }

        return launchResult
    }

    /// Resolves the Wine build for this launch.
    ///
    /// A bridge decides for itself, because only it knows what it additionally requires. Without
    /// one (`plainWine`) the newest usable build wins.
    private func resolveWineBuild(
        bridge: RenderBridge?,
        request: WineLaunchRequest,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws -> WineBuild {
        if let bridge {
            return try await bridge.resolveWineBuild(
                preferredPath: request.wineBinaryPath,
                processRunner: processRunner,
                onDiagnostic: onDiagnostic
            )
        }
        let search = await WineBinaryLocator.search(
            preferredPath: request.wineBinaryPath,
            processRunner: processRunner,
            onDiagnostic: onDiagnostic
        )
        if let build = search.builds.first { return build }
        if let quarantined = search.quarantinedPaths.first {
            throw WineServiceError.binaryQuarantined(quarantined)
        }
        throw ProcessRunnerError.executableNotFound(request.wineBinaryPath)
    }

    /// The CrossOver root to expose as `CX_ROOT`, or nil for a build that is not CrossOver-derived.
    ///
    /// Every launch gets it, bridged or not. This used to be withheld from bridged launches, to stop
    /// CrossOver's compatibility database from prepending the bottle's own Direct3D layer ahead of
    /// the bridge's `WINEDLLPATH`. That inverted the truth: `cxcompatdb.so` is the *only* thing that
    /// selects a translation layer, and withholding `CX_ROOT` disabled it — leaving the game on
    /// whatever `d3d11.dll` happened to resolve, never on the backend the user picked. The bottle
    /// config is no longer a hazard because the backend is now pinned explicitly through
    /// `CX_GRAPHICS_BACKEND`; see `RenderBridge.crossOverGraphicsBackend`.
    static func crossOverRootToApply(for build: WineBuild, bridge: RenderBridge?) -> URL? {
        WineBinaryLocator.crossOverRoot(for: build)
    }

    /// Registry values the launcher itself applies before the game starts.
    ///
    /// The value names with `_h<digits>` suffixes are Unity's hashed `PlayerPrefs` registry keys for
    /// Genshin Impact (e.g. `Screenmanager Resolution Width_h182942802`, `WINDOWS_HDR_ON_h3132281285`).
    /// They are written straight to `HKCU\Software\miHoYo\Genshin Impact` and match YAAGL's
    /// `applyResolutionRegistry` / `applyHDRRegistry` / `setProps`. Do not rename the keys or change
    /// the value-name suffixes without re-deriving them from Unity's hashing — the game will silently
    /// ignore an unknown key.
    ///
    /// Every value here is written on every launch, including the "off" state. None of these is a
    /// value the launcher alone owns: Unity writes its own `Screenmanager` keys back whenever the
    /// display is changed inside the game, and the HDR flag is likewise set by the game's own
    /// graphics settings. Writing a value only when the setting is on therefore does not mean "leave
    /// it alone", it means "let whatever the game last wrote win" — which is how turning the
    /// launcher's HDR toggle off left the game still rendering through its HDR path, and how a
    /// resolution picked in-game survived into a fullscreen launch it does not fit.
    static func launchRegistryEntries(for request: WineLaunchRequest) -> [RegistryEntry] {
        let macDriver = #"HKEY_CURRENT_USER\Software\Wine\Mac Driver"#
        let genshin = #"HKEY_CURRENT_USER\Software\miHoYo\Genshin Impact"#

        var entries: [RegistryEntry] = [
            RegistryEntry(key: macDriver, name: "RetinaMode", value: .string(request.macDriverRetina ? "y" : "n")),
            RegistryEntry(key: macDriver, name: "LeftCommandIsCtrl", value: .string(request.leftCommandIsCtrl ? "y" : "n")),
            // `CaptureDisplaysForFullscreen` (undocumented outside Wine's own source, see
            // dlls/winemac.drv/macdrv_main.c) is off by default in macdrv. Without it, a window
            // whose frame covers the whole screen is still just an ordinary borderless window —
            // the menu bar and dock stay interactive on top of it, and macdrv never seizes the
            // display. Turning it on is what makes `-screen-fullscreen 1` (see
            // `LaunchDisplayMode.fullscreen`) actually behave like fullscreen instead of a
            // full-size window. This does NOT depend on AppKit's Spaces-based fullscreen — that
            // path requires the window to carry `NSWindowStyleMaskResizable`, which Unity's
            // player window never does, so `-toggleFullScreen:`/`AXFullScreen` can never succeed
            // on it (confirmed against macdrv's `adjustFullScreenBehavior:`). Do not reintroduce
            // an AXFullScreen-based flip for this reason.
            RegistryEntry(key: macDriver, name: "CaptureDisplaysForFullscreen", value: .string(request.fullscreen ? "y" : "n")),
            // Unity persists display changes made inside the game into these PlayerPrefs keys, so
            // the flag is rewritten before every launch to keep it sticky, seeded from the same
            // display mode that produced the `-screen-fullscreen` command-line argument.
            //
            // It used to be pinned to 0 regardless. That was correct while fullscreen was entered at
            // the AppKit level with the game itself windowed, and became wrong when fullscreen moved
            // to Win32 exclusive mode: the game was then told to go fullscreen on the command line
            // while its persisted state said windowed, so anything that made Unity re-apply its
            // saved display state mid-session (the in-game graphics settings do) dropped it back to
            // a window while macdrv still held the captured display — a small backbuffer scanned out
            // stretched over the whole screen.
            RegistryEntry(key: genshin, name: "Screenmanager Is Fullscreen mode_h3981298716", value: .dword(request.fullscreen ? 1 : 0)),
            // Always written, never merely when enabled: the game turns this on itself from its own
            // graphics settings, and once on it renders through an HDR path whose output the Wine
            // swapchain presents unconverted — washed-out, wrong-looking colour. Writing 0 is what
            // makes the launcher's toggle able to turn it back off.
            RegistryEntry(key: genshin, name: "WINDOWS_HDR_ON_h3132281285", value: .dword(request.enableHDR ? 1 : 0))
        ]

        if let renderSize = request.renderSize {
            // Clamped rather than converted: these come from a persisted settings file that a user
            // can edit by hand, and a plain UInt32 conversion traps on a value outside its range.
            entries.append(RegistryEntry(key: genshin, name: "Screenmanager Resolution Width_h182942802", value: .dword(UInt32(clamping: renderSize.width))))
            entries.append(RegistryEntry(key: genshin, name: "Screenmanager Resolution Height_h2627697771", value: .dword(UInt32(clamping: renderSize.height))))
        }
        return entries
    }

    /// Shuts wineserver down for this prefix, returning true only when cache writers are confirmed
    /// quiescent.
    ///
    /// Uses `-k` (kill), not `-w` (wait-only). Wine auto-starts background service processes
    /// (`winedevice.exe`, `services.exe`, `plugplay.exe`) under wineserver that never exit on their
    /// own — `-w` would block on those forever instead of confirming shutdown, and previously left
    /// wineserver (and those services) running indefinitely after every launch, silently violating
    /// the single-tenant-prefix assumption documented on `LauncherCoordinator`'s preflight check for
    /// every subsequent launch. `-k` terminates the server and all its clients outright.
    static func waitForWineserver(
        wineBuild: WineBuild,
        environment: [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async -> Bool {
        let wineserverPath = wineBuild.root.appendingPathComponent("bin/wineserver").path
        guard FileManager.default.isExecutableFile(atPath: wineserverPath) else {
            onDiagnostic("wineserver not found at \(wineserverPath); skipping shutdown")
            return false
        }
        do {
            onDiagnostic("wineserver -k shutdown start")
            _ = try await processRunner.run(
                executable: wineserverPath,
                arguments: ["-k"],
                environment: environment,
                currentDirectory: nil
            )
            onDiagnostic("wineserver -k completed")
            return true
        } catch {
            onDiagnostic("wineserver -k best-effort failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Copies the Wine builtin `cmd.exe` into the prefix as `steam.exe` so the game runs with a
    /// `steam.exe` parent process. This is the FALLBACK when the real Valve stubs cannot be
    /// downloaded; the anti-cheat only checks the parent-process *name*, so a renamed cmd.exe is
    /// enough to satisfy it. Do not remove this fallback — if the stub download fails, the game must
    /// still get a steam.exe parent or it aborts during the anti-cheat driver-load phase.
    private func ensureSteamLauncher(prefixDirectory: URL, wineBuild: WineBuild) throws -> Bool {
        let source = wineBuild.root.appendingPathComponent("lib/wine/x86_64-windows/cmd.exe")
        guard FileManager.default.fileExists(atPath: source.path) else { return false }
        let system32 = prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        try FileManager.default.createDirectory(at: system32, withIntermediateDirectories: true)
        let destination = system32.appendingPathComponent("steam.exe")
        if FileManager.default.fileExists(atPath: destination.path) {
            if FileManager.default.contentsEqual(atPath: source.path, andPath: destination.path) { return true }
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return true
    }

    /// Downloads and installs real Valve `steam.exe` + `lsteamclient.dll` stubs into the Wine prefix
    /// (mirroring YAAGL's `protonextras` payload) so the game launches with a `steam.exe` parent and a
    /// Steam client presence. Returns `false` (leaving the caller to fall back to the cmd.exe copy)
    /// when the stubs cannot be downloaded.
    ///
    /// WHY this exists: miHoYo's anti-cheat (MHYPBase) skips loading its HoYoKProtect kernel driver
    /// when the game's parent process is named `steam.exe`. Wine cannot load that WDF driver, so this
    /// parent-process handoff is what lets the client start. A real Valve stub is preferred over a
    /// renamed `cmd.exe` because it also provides `lsteamclient.dll`, the Steam client interface some
    /// anti-cheat components probe for. DO NOT remove this and launch the game directly as the default.
    ///
    /// These stubs are Valve Corporation binaries (~10 MB total); they are downloaded once into
    /// `~/Library/Caches/NSLauncher/protonextras/` and reused.
    private func ensureSteamStub(prefixDirectory: URL) async throws -> Bool {
        let cacheDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/NSLauncher/protonextras", isDirectory: true)
        let payloads: [(name: String, url: URL)] = [
            ("steam64.exe", URL(string: "https://raw.githubusercontent.com/yaagl/yet-another-anime-game-launcher/main/sidecar/protonextras/steam64.exe")!),
            ("steam32.exe", URL(string: "https://raw.githubusercontent.com/yaagl/yet-another-anime-game-launcher/main/sidecar/protonextras/steam32.exe")!),
            ("lsteamclient64.dll", URL(string: "https://raw.githubusercontent.com/yaagl/yet-another-anime-game-launcher/main/sidecar/protonextras/lsteamclient64.dll")!),
            ("lsteamclient32.dll", URL(string: "https://raw.githubusercontent.com/yaagl/yet-another-anime-game-launcher/main/sidecar/protonextras/lsteamclient32.dll")!)
        ]

        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            var cached: [String: URL] = [:]
            for payload in payloads {
                let cachedURL = cacheDirectory.appendingPathComponent(payload.name)
                if !FileManager.default.fileExists(atPath: cachedURL.path) {
                    let (temporaryURL, response) = try await URLSession.shared.download(from: payload.url)
                    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return false }
                    if FileManager.default.fileExists(atPath: cachedURL.path) {
                        try FileManager.default.removeItem(at: cachedURL)
                    }
                    try FileManager.default.moveItem(at: temporaryURL, to: cachedURL)
                }
                cached[payload.name] = cachedURL
            }

            let system32 = prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
            let syswow64 = prefixDirectory.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
            try FileManager.default.createDirectory(at: system32, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: syswow64, withIntermediateDirectories: true)

            let copies: [(source: String, destination: URL)] = [
                ("steam64.exe", system32.appendingPathComponent("steam.exe")),
                ("steam32.exe", syswow64.appendingPathComponent("steam.exe")),
                ("lsteamclient64.dll", system32.appendingPathComponent("lsteamclient.dll")),
                ("lsteamclient32.dll", syswow64.appendingPathComponent("lsteamclient.dll"))
            ]
            for copy in copies {
                guard let source = cached[copy.source] else { return false }
                if FileManager.default.fileExists(atPath: copy.destination.path) {
                    if FileManager.default.contentsEqual(atPath: source.path, andPath: copy.destination.path) { continue }
                    try FileManager.default.removeItem(at: copy.destination)
                }
                try FileManager.default.copyItem(at: source, to: copy.destination)
            }
            return true
        } catch {
            return false
        }
    }

    /// Wine can return a non-zero wrapper code after successfully spawning the Windows GUI process.
    private func hasNewLaunchedExecutableProcess(_ executablePath: URL, excluding existingPIDs: Set<Int32>) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let currentPIDs = await GameProcessInspector.runningProcessIDs(forExecutable: executablePath)
            return !currentPIDs.subtracting(existingPIDs).isEmpty
        } catch {
            return false
        }
    }

    /// Runs the Wine wrapper and the game-process monitor as a race, so the
    /// launch session ends on whichever stops first: the wrapper exiting (today's
    /// behavior) or the actual game process disappearing (an in-game quit while
    /// the wrapper lingers). A worker failure (non-zero Wine exit) surfaces
    /// through the group's `next()` and is classified by the caller exactly as
    /// before. When the game exits first the wrapper is cancelled so Wine
    /// unwinds, and a clean result is returned.
    private func runGameSession(
        wineBinaryPath: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?,
        logFileURL: URL?,
        gameMonitor: GameProcessMonitor,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)?,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult {
        struct GameSessionEnd: Sendable {
            var result: ProcessResult
            var endedViaGameProcess: Bool
        }

        let processRunner = self.processRunner
        let end = try await withThrowingTaskGroup(of: GameSessionEnd.self) { group in
            group.addTask {
                GameSessionEnd(
                    result: try await processRunner.run(
                        executable: wineBinaryPath,
                        arguments: arguments,
                        environment: environment,
                        currentDirectory: currentDirectory,
                        logFileURL: logFileURL,
                        onOutput: onOutput
                    ),
                    endedViaGameProcess: false
                )
            }
            group.addTask {
                try await gameMonitor.waitUntilRunning()
                try await gameMonitor.waitUntilStopped()
                return GameSessionEnd(
                    result: ProcessResult(exitCode: 0, stdout: "", stderr: ""),
                    endedViaGameProcess: true
                )
            }

            guard let first = try await group.next() else {
                throw CancellationError()
            }
            // Whichever branch ended the session first is the truth; stop the other.
            group.cancelAll()
            return first
        }

        if end.endedViaGameProcess {
            onDiagnostic("game process exited while Wine wrapper still alive; wrapper cancelled")
        }
        return end.result
    }

    /// Wine still opens more file descriptors under load than launchd's default soft limit of 256
    /// comfortably covers — esync (both bridges' sync primitive) allocates one fd per sync object.
    /// A GUI app launched via Finder/LaunchServices inherits that 256 limit, unlike a Terminal
    /// shell's usually higher one. Raise the soft limit once before spawning Wine. Best-effort:
    /// this must never block the launch.
    private static func raiseFileDescriptorLimit(onDiagnostic: (String) -> Void) {
        var limit = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &limit) == 0 else {
            onDiagnostic("getrlimit failed; skipping file descriptor limit raise")
            return
        }
        let desired: rlim_t = 10_240
        let target = min(desired, limit.rlim_max)
        guard target > limit.rlim_cur else {
            onDiagnostic("file descriptor limit already sufficient cur=\(limit.rlim_cur) max=\(limit.rlim_max)")
            return
        }
        limit.rlim_cur = target
        if setrlimit(RLIMIT_NOFILE, &limit) == 0 {
            onDiagnostic("raised file descriptor limit to \(target)")
        } else {
            onDiagnostic("setrlimit failed to raise file descriptor limit to \(target)")
        }
    }

    /// Detects Windows kernel drivers that Wine cannot load, most commonly anti-cheat/protection drivers.
    private static func unsupportedKernelDriverName(in output: String) -> String? {
        let driverNames = ["HoYoKProtect.sys", "HoYoProtect.sys", "mhyprot2.sys"]
        return driverNames.first { output.localizedCaseInsensitiveContains($0) }
    }

    /// Some Wine builds return 15 when the GUI game session closes cleanly.
    private static func outputIndicatesGameStarted(_ output: String) -> Bool {
        output.contains("MultiThreadStackTrace init success")
            || output.contains("GCGMAH active")
            || output.contains("\"message\":\"app running\"")
    }

}
