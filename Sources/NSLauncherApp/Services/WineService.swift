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
    /// Custom starting resolution written to the game's registry keys before launch.
    var resolutionOverride: (width: Int, height: Int)? = nil
    /// Enable the game's HDR registry flag.
    var enableHDR: Bool = false
    var onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
}

/// Wine launch failures that need targeted user remediation.
enum WineServiceError: LocalizedError {
    case binaryQuarantined(String)
    case dxvkBootstrapFailed(String)
    case dxmtBootstrapFailed(String)
    case dxmtUnsupportedWine(String)
    case dxmtWineTooOld(String)
    case unsupportedKernelDriver(String)
    case wineDistributionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .binaryQuarantined(path):
            return "Wine is blocked by macOS quarantine at \(path)."
        case let .dxvkBootstrapFailed(details):
            return "DXVK setup failed: \(details)"
        case let .dxmtBootstrapFailed(details):
            return "DXMT setup failed: \(details)"
        case let .dxmtUnsupportedWine(path):
            return "Wine at \(path) does not expose the winemac.drv symbols required by DXMT."
        case let .dxmtWineTooOld(details):
            return "The installed Wine is too old for DXMT: \(details)."
        case let .unsupportedKernelDriver(driver):
            return "Wine cannot load the Windows kernel driver \(driver)."
        case let .wineDistributionFailed(details):
            return "Installing the managed Wine build failed: \(details)"
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
            "WINEDEBUG": "fixme-all,err-unwind,+timestamp"
        ]
        baseEnv.merge(request.environment) { _, new in new }
        baseEnv["WINEPREFIX"] = request.prefixDirectory.path
        if let crossOverRoot = WineBinaryLocator.crossOverRoot(for: wineBuild) {
            baseEnv["CX_ROOT"] = crossOverRoot.path
            diagnose("CX_ROOT=\(crossOverRoot.path)")
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
        let entries = (bridge?.registryEntries() ?? []) + Self.launchRegistryEntries(for: request)
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
        let alreadyRunningGamePIDs = await GameProcessInspector.runningProcessIDs(
            forExecutable: request.executablePath,
            processRunner: processRunner
        )
        diagnose("existing game process count=\(alreadyRunningGamePIDs.count)")

        let launchResult: ProcessResult
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
            launchResult = try await processRunner.run(
                executable: wineBuild.binaryPath,
                arguments: processArguments,
                environment: env,
                currentDirectory: request.currentDirectory,
                logFileURL: gameLogURL,
                onOutput: request.onOutput
            )
        } catch let ProcessRunnerError.nonZeroExit(result) {
            diagnose("process exited non-zero code=\(result.exitCode); checking whether game stayed alive")
            if await hasNewLaunchedExecutableProcess(request.executablePath, excluding: alreadyRunningGamePIDs) {
                diagnose("detected launched game process after Wine exit; treating launch as successful")
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if result.exitCode == 15, Self.outputIndicatesGameStarted(result.stdout + "\n" + result.stderr) {
                diagnose("Wine exit 15 with started-game signal; treating launch as successful")
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if request.runtimeRequirements.contains(.dxmt),
               Self.outputIndicatesDXMTUnsupportedWine(result.stdout + "\n" + result.stderr) {
                diagnose("DXMT unsupported Wine signal detected")
                throw WineServiceError.dxmtUnsupportedWine(wineBuild.binaryPath)
            } else if let driverName = Self.unsupportedKernelDriverName(in: result.stdout + "\n" + result.stderr) {
                diagnose("unsupported kernel driver detected=\(driverName)")
                throw WineServiceError.unsupportedKernelDriver(driverName)
            } else {
                diagnose("non-zero process exit remains failure code=\(result.exitCode)")
                throw ProcessRunnerError.nonZeroExit(result)
            }
        }

        // Best-effort wineserver -w: flush registry and wait for Wine processes to exit.
        await waitForWineserver(wineBuild: wineBuild, environment: env, onDiagnostic: diagnose)

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

    /// Registry values the launcher itself applies before the game starts.
    ///
    /// The value names with `_h<digits>` suffixes are Unity's hashed `PlayerPrefs` registry keys for
    /// Genshin Impact (e.g. `Screenmanager Resolution Width_h182942802`, `WINDOWS_HDR_ON_h3132281285`).
    /// They are written straight to `HKCU\Software\miHoYo\Genshin Impact` and match YAAGL's
    /// `applyResolutionRegistry` / `applyHDRRegistry` / `setProps`. Do not rename the keys or change
    /// the value-name suffixes without re-deriving them from Unity's hashing — the game will silently
    /// ignore an unknown key.
    private static func launchRegistryEntries(for request: WineLaunchRequest) -> [RegistryEntry] {
        let macDriver = #"HKEY_CURRENT_USER\Software\Wine\Mac Driver"#
        let genshin = #"HKEY_CURRENT_USER\Software\miHoYo\Genshin Impact"#

        var entries: [RegistryEntry] = [
            RegistryEntry(key: macDriver, name: "RetinaMode", value: .string(request.macDriverRetina ? "y" : "n")),
            RegistryEntry(key: macDriver, name: "LeftCommandIsCtrl", value: .string(request.leftCommandIsCtrl ? "y" : "n")),
            // Unity persists display changes made inside the game into these PlayerPrefs keys, so
            // the flag is rewritten before every launch to keep it sticky. Both display modes run
            // Unity windowed: the Fullscreen mode enters native macOS fullscreen at the AppKit
            // level after launch (see MacNativeFullscreenActivator), and a persisted fullscreen
            // flag here would fight that by making the game cover the screen borderlessly itself.
            RegistryEntry(key: genshin, name: "Screenmanager Is Fullscreen mode_h3981298716", value: .dword(0))
        ]

        if let resolution = request.resolutionOverride {
            entries.append(RegistryEntry(key: genshin, name: "Screenmanager Resolution Width_h182942802", value: .dword(UInt32(resolution.width))))
            entries.append(RegistryEntry(key: genshin, name: "Screenmanager Resolution Height_h2627697771", value: .dword(UInt32(resolution.height))))
        }
        if request.enableHDR {
            entries.append(RegistryEntry(key: genshin, name: "WINDOWS_HDR_ON_h3132281285", value: .dword(1)))
        }
        return entries
    }

    /// Best-effort wait for wineserver to exit, flushing registry writes and logs.
    private func waitForWineserver(
        wineBuild: WineBuild,
        environment: [String: String],
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async {
        let wineserverPath = wineBuild.root.appendingPathComponent("bin/wineserver").path
        guard FileManager.default.isExecutableFile(atPath: wineserverPath) else {
            onDiagnostic("wineserver not found at \(wineserverPath); skipping wait")
            return
        }
        do {
            onDiagnostic("wineserver -w wait start")
            _ = try await processRunner.run(
                executable: wineserverPath,
                arguments: ["-w"],
                environment: environment,
                currentDirectory: nil
            )
            onDiagnostic("wineserver -w completed")
        } catch {
            onDiagnostic("wineserver -w best-effort failed: \(error.localizedDescription)")
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
            let currentPIDs = await GameProcessInspector.runningProcessIDs(
                forExecutable: executablePath,
                processRunner: processRunner
            )
            return !currentPIDs.subtracting(existingPIDs).isEmpty
        } catch {
            return false
        }
    }

    /// Wine's esync (`WINEESYNC=1`, used by both the DXMT and DXVK backends) allocates a file
    /// descriptor per sync object. A GUI app launched via Finder/LaunchServices inherits launchd's
    /// default soft limit of 256 — far below what esync needs under load — even though a Terminal
    /// shell on the same machine typically has a much higher limit from its profile. Raise the
    /// soft limit once before spawning Wine so esync does not degrade. Best-effort: this must never
    /// block the launch.
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

    /// Gatekeeper quarantine commonly causes Wine to terminate before it can launch the game.
    private static func outputIndicatesDXMTUnsupportedWine(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("no exported symbols needed by DXMT")
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
