// WineShutdownWatchdog.swift
//
// Keeps wineserver from outliving the game after the launcher itself has quit.
//
// `WineService.launch()` already tears wineserver down once the game exits (see
// `WineService.waitForWineserver`), but that cleanup runs as a plain in-process `Task` tied to the
// launcher app's lifetime. The launcher and the Wine process tree are independent from the moment
// launch succeeds (a Wine wrapper can detach immediately while the game keeps running under
// wineserver), so quitting the launcher while the game is still up kills that `Task` along with it
// — nobody is left to notice the game exit and run `wineserver -k`.
//
// This re-invokes the launcher's own binary with a hidden flag so the watchdog is a detached child
// process, not a Task: it survives the launcher quitting exactly the way the game/wineserver
// process tree already does (macOS reparents orphaned children to launchd rather than killing
// them). It is a belt-and-suspenders backstop, not a replacement — `WineService`'s in-process
// cleanup still runs the show whenever the launcher stays open (UI Play/Stop state, D3DMetal shader
// cache checkpointing).

import Foundation

enum WineShutdownWatchdog {
    /// Hidden CLI flag that switches the launcher binary into watchdog mode instead of the UI.
    static let launchArgument = "--wine-shutdown-watchdog"

    private static let pollInterval: TimeInterval = 3
    /// Gives the in-process cleanup (if the launcher is still open) a chance to win the race before
    /// this watchdog also tries to shut wineserver down.
    private static let shutdownGracePeriod: TimeInterval = 5
    /// Safety cap so a detection bug cannot keep this process running forever.
    private static let maxWait: TimeInterval = 24 * 60 * 60

    private struct Options {
        let executablePath: URL
        let wineserverPath: String
        let prefixDirectory: URL
    }

    /// Spawns a detached copy of the current binary in watchdog mode. Fire-and-forget: does not
    /// wait for it, and the child keeps running after this process (the launcher) exits.
    static func spawn(
        executablePath: URL,
        wineserverPath: String,
        prefixDirectory: URL,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) {
        guard let ownExecutable = resolveOwnExecutablePath() else {
            onDiagnostic("wine shutdown watchdog not spawned: could not resolve own executable path")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ownExecutable)
        process.arguments = [launchArgument, executablePath.path, wineserverPath, prefixDirectory.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            onDiagnostic("wine shutdown watchdog spawned pid=\(process.processIdentifier)")
        } catch {
            onDiagnostic("wine shutdown watchdog spawn failed: \(error.localizedDescription)")
        }
    }

    /// Entry point when the binary is re-invoked with `launchArgument`. Blocks until the watched
    /// game executable is gone, then shuts wineserver down for its prefix. Returns the process exit
    /// code; the caller must `exit()` with it immediately without falling through to app startup.
    static func runBlocking(arguments: [String]) -> Int32 {
        guard let options = parseOptions(arguments) else {
            FileHandle.standardError.write(Data("wine-shutdown-watchdog: invalid arguments\n".utf8))
            return 1
        }
        let log = makeLogger()
        log("watchdog started executable=\(options.executablePath.path) wineserver=\(options.wineserverPath) prefix=\(options.prefixDirectory.path)")

        let deadline = Date().addingTimeInterval(maxWait)
        while isExecutableRunning(options.executablePath), Date() < deadline {
            Thread.sleep(forTimeInterval: pollInterval)
        }
        log("game executable no longer detected; waiting grace period before checking wineserver")

        Thread.sleep(forTimeInterval: shutdownGracePeriod)
        guard wineserverStillRunning(wineserverPath: options.wineserverPath) else {
            log("wineserver already stopped (likely by the launcher itself); nothing to do")
            return 0
        }
        log("wineserver still running; shutting it down")
        killWineserver(wineserverPath: options.wineserverPath, prefixDirectory: options.prefixDirectory, log: log)
        return 0
    }

    // MARK: - Private

    /// Positional after the flag: executable path, wineserver path, prefix path. Not user-facing,
    /// so a small fixed contract with `spawn` above is enough — no need for named flags.
    private static func parseOptions(_ arguments: [String]) -> Options? {
        guard let flagIndex = arguments.firstIndex(of: launchArgument),
              arguments.count >= flagIndex + 4 else { return nil }
        return Options(
            executablePath: URL(fileURLWithPath: arguments[flagIndex + 1]),
            wineserverPath: arguments[flagIndex + 2],
            prefixDirectory: URL(fileURLWithPath: arguments[flagIndex + 3])
        )
    }

    /// Resolves an absolute path to the currently running binary so the watchdog can re-invoke it.
    /// `Bundle.main.executablePath` covers both the bundled `.app` and a plain `swift run` binary;
    /// falling back to `CommandLine.arguments[0]` covers the rare case it is unavailable.
    private static func resolveOwnExecutablePath() -> String? {
        if let bundleExecutable = Bundle.main.executablePath {
            return bundleExecutable
        }
        guard let first = CommandLine.arguments.first else { return nil }
        if first.hasPrefix("/") { return first }
        return FileManager.default.currentDirectoryPath + "/" + first
    }

    /// Excludes this watchdog's own PID from the scan: its own argv literally contains
    /// `executablePath.path` (passed to it by `spawn`), which would otherwise self-match every time
    /// and make the game look permanently "running".
    private static func isExecutableRunning(_ executablePath: URL) -> Bool {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let needles = [executablePath.path, GameProcessInspector.windowsPath(for: executablePath)]
        return GameProcessInspector.allPIDs().contains { pid in
            guard pid != ownPID, let commandLine = GameProcessInspector.commandLine(forPID: pid) else { return false }
            return needles.contains { commandLine.contains($0) }
        }
    }

    /// Same self-match hazard as `isExecutableRunning`: this watchdog's own argv contains
    /// `wineserverPath` too, so its own PID must be excluded from the scan.
    private static func wineserverStillRunning(wineserverPath: String) -> Bool {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return GameProcessInspector.allPIDs().contains { pid in
            pid != ownPID && GameProcessInspector.commandLine(forPID: pid)?.contains(wineserverPath) == true
        }
    }

    private static func killWineserver(wineserverPath: String, prefixDirectory: URL, log: (String) -> Void) {
        guard FileManager.default.isExecutableFile(atPath: wineserverPath) else {
            log("wineserver binary missing at \(wineserverPath); nothing to kill")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: wineserverPath)
        process.arguments = ["-k"]
        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = prefixDirectory.path
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            log("wineserver -k exited with status \(process.terminationStatus)")
        } catch {
            log("wineserver -k failed: \(error.localizedDescription)")
        }
    }

    /// Appends timestamped lines to the same log directory `GameLogFile` uses, so Console.app (or a
    /// user digging for why wineserver disappeared) has somewhere to look.
    private static func makeLogger() -> (String) -> Void {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/NSLauncher", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("wine-shutdown-watchdog.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
        let formatter = ISO8601DateFormatter()
        return { message in
            handle?.write(Data("[\(formatter.string(from: Date()))] \(message)\n".utf8))
        }
    }
}
