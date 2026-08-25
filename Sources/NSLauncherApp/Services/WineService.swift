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
    case d3dMetalUnavailable(String)
    case unsupportedKernelDriver(String)

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
        case let .d3dMetalUnavailable(path):
            return "This Wine build does not ship Apple D3DMetal at \(path); switch the render backend back to DXMT."
        case let .unsupportedKernelDriver(driver):
            return "Wine cannot load the Windows kernel driver \(driver)."
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
        Self.raiseFileDescriptorLimit(onDiagnostic: { emitDiagnostic($0, request: request) })
        emitDiagnostic("launch request executable=\(request.executablePath.path)", request: request)
        emitDiagnostic("launch request currentDirectory=\(request.currentDirectory?.path ?? "nil") prefix=\(request.prefixDirectory.path)", request: request)
        emitDiagnostic("launch request runtime=\(request.runtimeRequirements.map(\.rawValue).joined(separator: ",")) args=\(request.arguments.joined(separator: " "))", request: request)
        let bridge = RenderBridges.bridge(for: request.renderBackend)
        emitDiagnostic("render backend=\(request.renderBackend.rawValue)", request: request)

        let resolvedWineBinary: String
        if let bridge {
            emitDiagnostic("resolve Wine for \(request.renderBackend.rawValue) from preferred=\(request.wineBinaryPath)", request: request)
            resolvedWineBinary = try await bridge.resolveWineBinary(
                preferredPath: request.wineBinaryPath,
                processRunner: processRunner
            )
        } else {
            emitDiagnostic("resolve Wine executable preferred=\(request.wineBinaryPath)", request: request)
            guard let binary = BinaryLocator.resolveExecutable(
                preferredPath: request.wineBinaryPath,
                candidateNames: BinaryLocator.candidateNames(forExecutable: request.wineBinaryPath)
            ) else {
                throw ProcessRunnerError.executableNotFound(request.wineBinaryPath)
            }
            resolvedWineBinary = binary
        }
        emitDiagnostic("resolved Wine binary=\(resolvedWineBinary)", request: request)

        if let quarantinedPath = WineBinaryLocator.quarantinedPath(forExecutableAtPath: resolvedWineBinary) {
            emitDiagnostic("quarantine detected path=\(quarantinedPath)", request: request)
            throw WineServiceError.binaryQuarantined(quarantinedPath)
        }
        request.onOutput?(ProcessOutputChunk(stream: .stdout, text: "NSLauncher selected Wine binary: \(resolvedWineBinary)\n"))

        // Caller-supplied environment values win except for WINEPREFIX, which must match settings.
        // Enforce WINEARCH and WINEDEBUG defaults if caller did not supply them.
        var baseEnv: [String: String] = [
            "WINEARCH": "win64",
            "WINEDEBUG": "fixme-all,err-unwind,+timestamp"
        ]
        baseEnv.merge(request.environment) { _, new in new }
        baseEnv["WINEPREFIX"] = request.prefixDirectory.path
        DXMTBridge.createSupportDirectories()

        if let bridge {
            emitDiagnostic("prepare \(request.renderBackend.rawValue) runtime", request: request)
            try await bridge.prepare(
                wineRoot: try WineBinaryLocator.wineRootDirectory(forBinaryAtPath: resolvedWineBinary),
                wineBinaryPath: resolvedWineBinary,
                prefixDirectory: request.prefixDirectory,
                environment: &baseEnv,
                processRunner: processRunner,
                onDiagnostic: { emitDiagnostic($0, request: request) }
            )
            emitDiagnostic("\(request.renderBackend.rawValue) runtime ready", request: request)
        }

        let env = baseEnv
        emitDiagnostic("environment WINEPREFIX=\(env["WINEPREFIX"] ?? "") WINEARCH=\(env["WINEARCH"] ?? "") WINEDEBUG=\(env["WINEDEBUG"] ?? "") customKeys=\(request.environment.keys.sorted().joined(separator: ","))", request: request)

        // Apply Wine Mac Driver and game registry settings (Retina, left-Cmd-as-Ctrl,
        // custom resolution, HDR) before the game process starts. Best-effort: a registry
        // write failure must not block the launch (mirrors YAAGL's ignore-on-error behavior).
        do {
            try await applyRegistrySettings(
                request: request,
                wineBinaryPath: resolvedWineBinary,
                environment: env
            )
        } catch {
            emitDiagnostic("registry settings best-effort failed: \(error.localizedDescription)", request: request)
        }

        emitDiagnostic("snapshot existing game processes", request: request)
        let alreadyRunningGamePIDs = await runningExecutableProcessIDs(request.executablePath)
        emitDiagnostic("existing game process count=\(alreadyRunningGamePIDs.count)", request: request)
        let launchResult: ProcessResult
        do {
            var processArguments: [String]
            if request.useSteamLauncher {
                // Launch through a real `steam.exe` parent process (with `lsteamclient.dll` present):
                // miHoYo's anti-cheat (MHYPBase) skips loading its HoYoKProtect kernel driver when the
                // game's parent process is `steam.exe` and a Steam client is detected. Wine cannot load
                // that WDF driver, so this is the working path.
                if try await ensureSteamStub(prefixDirectory: request.prefixDirectory) {
                    let gameWindowsPath = windowsPath(for: request.executablePath)
                    processArguments = ["C:\\windows\\system32\\steam.exe", gameWindowsPath] + request.arguments
                    emitDiagnostic("launch via real steam.exe parent: \(gameWindowsPath) \(request.arguments.joined(separator: " "))", request: request)
                } else if try ensureSteamLauncher(prefixDirectory: request.prefixDirectory, wineBinaryPath: resolvedWineBinary) {
                    // Fallback: a Wine builtin `cmd.exe` copied to `steam.exe` still satisfies the
                    // parent-process name check when the real Valve stubs cannot be downloaded.
                    let commandLine = ([request.executablePath.lastPathComponent] + request.arguments).joined(separator: " ")
                    processArguments = ["C:\\windows\\system32\\steam.exe", "/c", commandLine]
                    emitDiagnostic("launch via cmd.exe steam parent fallback: \(commandLine)", request: request)
                } else {
                    emitDiagnostic("steam.exe parent unavailable; falling back to direct launch", request: request)
                    processArguments = [request.executablePath.path] + request.arguments
                }
            } else {
                processArguments = [request.executablePath.path] + request.arguments
            }
            emitDiagnostic("start process command=\(resolvedWineBinary) \(processArguments.joined(separator: " "))", request: request)
            launchResult = try await processRunner.run(
                executable: resolvedWineBinary,
                arguments: processArguments,
                environment: env,
                currentDirectory: request.currentDirectory,
                onOutput: request.onOutput
            )
        } catch let ProcessRunnerError.nonZeroExit(result) {
            emitDiagnostic("process exited non-zero code=\(result.exitCode); checking whether game stayed alive", request: request)
            if await hasNewLaunchedExecutableProcess(request.executablePath, excluding: alreadyRunningGamePIDs) {
                emitDiagnostic("detected launched game process after Wine exit; treating launch as successful", request: request)
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if result.exitCode == 15, Self.outputIndicatesGameStarted(result.stdout + "\n" + result.stderr) {
                emitDiagnostic("Wine exit 15 with started-game signal; treating launch as successful", request: request)
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if request.runtimeRequirements.contains(.dxmt),
               Self.outputIndicatesDXMTUnsupportedWine(result.stdout + "\n" + result.stderr) {
                emitDiagnostic("DXMT unsupported Wine signal detected", request: request)
                throw WineServiceError.dxmtUnsupportedWine(resolvedWineBinary)
            } else if let driverName = Self.unsupportedKernelDriverName(in: result.stdout + "\n" + result.stderr) {
                emitDiagnostic("unsupported kernel driver detected=\(driverName)", request: request)
                throw WineServiceError.unsupportedKernelDriver(driverName)
            } else {
                emitDiagnostic("non-zero process exit remains failure code=\(result.exitCode)", request: request)
                throw ProcessRunnerError.nonZeroExit(result)
            }
        }

        // Best-effort wineserver -w: flush registry and wait for Wine processes to exit.
        await waitForWineserver(wineBinaryPath: resolvedWineBinary, environment: env, request: request)

        return launchResult
    }

    private func emitDiagnostic(_ message: String, request: WineLaunchRequest) {
        request.onOutput?(ProcessOutputChunk(stream: .stdout, text: "[NSLauncher][launch-detail] \(message)\n"))
    }

    /// Best-effort wait for wineserver to exit, flushing registry writes and logs.
    private func waitForWineserver(wineBinaryPath: String, environment: [String: String], request: WineLaunchRequest) async {
        do {
            let wineRoot = try WineBinaryLocator.wineRootDirectory(forBinaryAtPath: wineBinaryPath)
            let wineserverPath = wineRoot.appendingPathComponent("bin/wineserver").path
            guard FileManager.default.isExecutableFile(atPath: wineserverPath) else {
                emitDiagnostic("wineserver not found at \(wineserverPath); skipping wait", request: request)
                return
            }
            emitDiagnostic("wineserver -w wait start", request: request)
            _ = try await processRunner.run(
                executable: wineserverPath,
                arguments: ["-w"],
                environment: environment,
                currentDirectory: nil
            )
            emitDiagnostic("wineserver -w completed", request: request)
        } catch {
            emitDiagnostic("wineserver -w best-effort failed: \(error.localizedDescription)", request: request)
        }
    }

    /// Copies the Wine builtin `cmd.exe` into the prefix as `steam.exe` so the game runs with a
    /// `steam.exe` parent process. This is the FALLBACK when the real Valve stubs cannot be
    /// downloaded; the anti-cheat only checks the parent-process *name*, so a renamed cmd.exe is
    /// enough to satisfy it. Do not remove this fallback — if the stub download fails, the game must
    /// still get a steam.exe parent or it aborts during the anti-cheat driver-load phase.
    private func ensureSteamLauncher(prefixDirectory: URL, wineBinaryPath: String) throws -> Bool {
        let wineRoot = try WineBinaryLocator.wineRootDirectory(forBinaryAtPath: wineBinaryPath)
        let source = wineRoot.appendingPathComponent("lib/wine/x86_64-windows/cmd.exe")
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

    /// Converts a macOS absolute path into the `Z:` drive path Wine presents to Windows programs.
    private func windowsPath(for url: URL) -> String {
        "Z:" + url.path.replacingOccurrences(of: "/", with: "\\")
    }

    /// Writes Wine Mac Driver and game registry values (Retina scaling, left-Cmd-as-Ctrl, custom
    /// resolution, HDR) into the prefix before the game process starts. Best-effort by design: these
    /// are quality-of-life settings, so a registry write failure must never block the launch.
    ///
    /// The value names with `_h<digits>` suffixes are Unity's hashed `PlayerPrefs` registry keys for
    /// Genshin Impact (e.g. `Screenmanager Resolution Width_h182942802`, `WINDOWS_HDR_ON_h3132281285`).
    /// They are written straight to `HKCU\Software\miHoYo\Genshin Impact` and match YAAGL's
    /// `applyResolutionRegistry` / `applyHDRRegistry` / `setProps`. Do not rename the keys or change
    /// the value-name suffixes without re-deriving them from Unity's hashing — the game will silently
    /// ignore an unknown key.
    private func applyRegistrySettings(
        request: WineLaunchRequest,
        wineBinaryPath: String,
        environment: [String: String]
    ) async throws {
        try await setRegistryString(
            key: "HKEY_CURRENT_USER\\Software\\Wine\\Mac Driver",
            valueName: "RetinaMode",
            data: request.macDriverRetina ? "y" : "n",
            wineBinaryPath: wineBinaryPath,
            environment: environment
        )
        try await setRegistryString(
            key: "HKEY_CURRENT_USER\\Software\\Wine\\Mac Driver",
            valueName: "LeftCommandIsCtrl",
            data: request.leftCommandIsCtrl ? "y" : "n",
            wineBinaryPath: wineBinaryPath,
            environment: environment
        )

        // Unity persists display changes made inside the game into these PlayerPrefs keys, so
        // the flag is rewritten before every launch to keep it sticky. Both display modes run
        // Unity windowed: the Fullscreen mode enters native macOS fullscreen at the AppKit
        // level after launch (see MacNativeFullscreenActivator), and a persisted fullscreen
        // flag here would fight that by making the game cover the screen borderlessly itself.
        try await setRegistryDWord(
            key: "HKEY_CURRENT_USER\\Software\\miHoYo\\Genshin Impact",
            valueName: "Screenmanager Is Fullscreen mode_h3981298716",
            data: 0,
            wineBinaryPath: wineBinaryPath,
            environment: environment
        )
        if let resolution = request.resolutionOverride {
            try await setRegistryDWord(
                key: "HKEY_CURRENT_USER\\Software\\miHoYo\\Genshin Impact",
                valueName: "Screenmanager Resolution Width_h182942802",
                data: UInt32(resolution.width),
                wineBinaryPath: wineBinaryPath,
                environment: environment
            )
            try await setRegistryDWord(
                key: "HKEY_CURRENT_USER\\Software\\miHoYo\\Genshin Impact",
                valueName: "Screenmanager Resolution Height_h2627697771",
                data: UInt32(resolution.height),
                wineBinaryPath: wineBinaryPath,
                environment: environment
            )
        }

        if request.enableHDR {
            try await setRegistryDWord(
                key: "HKEY_CURRENT_USER\\Software\\miHoYo\\Genshin Impact",
                valueName: "WINDOWS_HDR_ON_h3132281285",
                data: 1,
                wineBinaryPath: wineBinaryPath,
                environment: environment
            )
        }
    }

    /// Writes a REG_SZ value using `wine reg add`.
    private func setRegistryString(
        key: String,
        valueName: String,
        data: String,
        wineBinaryPath: String,
        environment: [String: String]
    ) async throws {
        _ = try await processRunner.run(
            executable: wineBinaryPath,
            arguments: ["reg", "add", key, "/v", valueName, "/t", "REG_SZ", "/d", data, "/f"],
            environment: environment,
            currentDirectory: nil
        )
    }

    /// Writes a REG_DWORD value using `wine reg add`.
    private func setRegistryDWord(
        key: String,
        valueName: String,
        data: UInt32,
        wineBinaryPath: String,
        environment: [String: String]
    ) async throws {
        _ = try await processRunner.run(
            executable: wineBinaryPath,
            arguments: ["reg", "add", key, "/v", valueName, "/t", "REG_DWORD", "/d", String(data), "/f"],
            environment: environment,
            currentDirectory: nil
        )
    }

    /// Wine can return a non-zero wrapper code after successfully spawning the Windows GUI process.
    private func hasNewLaunchedExecutableProcess(_ executablePath: URL, excluding existingPIDs: Set<Int32>) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let currentPIDs = await runningExecutableProcessIDs(executablePath)
            return !currentPIDs.subtracting(existingPIDs).isEmpty
        } catch {
            return false
        }
    }

    /// Returns running process IDs for the exact executable path, ignoring older unrelated Wine processes.
    private func runningExecutableProcessIDs(_ executablePath: URL) async -> Set<Int32> {
        do {
            let result = try await processRunner.run(
                executable: "/bin/ps",
                arguments: ["axo", "pid=,command="],
                environment: [:],
                currentDirectory: nil
            )
            return Set(result.stdout
                .split(whereSeparator: \.isNewline)
                .compactMap { line -> Int32? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard let firstSpace = trimmed.firstIndex(where: \.isWhitespace),
                          trimmed[trimmed.index(after: firstSpace)...].contains(executablePath.path) else {
                        return nil
                    }
                    return Int32(trimmed[..<firstSpace])
                })
        } catch {
            return []
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

private struct DXMTPayloadCopy {
    var names: [String]
    var sourceDirectory: URL
    var destinationDirectory: URL
}
