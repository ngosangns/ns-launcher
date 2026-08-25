// MacNativeFullscreenActivator.swift
//
// Puts the game's Wine window into native macOS fullscreen (its own Mission
// Control Space) shortly after launch.
//
// Why this exists: Wine's Mac driver implements Win32 fullscreen only as a
// borderless window covering the screen — it never calls NSWindow's
// -toggleFullScreen:, so `-screen-fullscreen 1` can never produce real macOS
// fullscreen. The launcher therefore starts Unity windowed (see
// LaunchDisplayMode.fullscreen) and flips the resulting AppKit window to
// fullscreen through the System Events accessibility attribute once it appears.

import Foundation

/// Activates native macOS fullscreen for the game window after a Wine launch.
struct MacNativeFullscreenActivator: Sendable {
    /// Total time spent looking for the game window before giving up. The client
    /// can take tens of seconds to open its first window (splash screen, anti-cheat
    /// initialization), so the budget must be generous.
    private static let timeout: TimeInterval = 180
    /// Delay between window-search attempts.
    private static let pollInterval: TimeInterval = 2
    /// Grace period before the first attempt so Wine has time to spawn its processes.
    private static let initialDelay: TimeInterval = 5

    let processRunner: ProcessRunning

    /// Sets AXFullScreen on the first window of a matching process and reads the value
    /// back to confirm the window actually entered native fullscreen. Prints `true`
    /// on confirmed success, `false` when no eligible window exists yet. Exits
    /// non-zero when macOS refuses the automation (missing permission).
    ///
    /// Matches on process name containing "wine" (stock/WineHQ builds report themselves
    /// this way) OR containing the game's own executable name. CrossOver-derived Wine —
    /// required for DXMT (see `RuntimeBackend`) — renames its window-owning process to the
    /// wrapped Windows executable (e.g. `GenshinImpact.exe`), which never contains "wine",
    /// so relying on the "wine" match alone silently never finds the window on those builds.
    private static let fullscreenScript = """
    on run argv
        set gameHint to item 1 of argv
        tell application "System Events"
            repeat with wineProcess in (application processes whose (name contains "wine" or name contains gameHint))
                try
                    if (count of windows of wineProcess) > 0 then
                        set targetWindow to window 1 of wineProcess
                        set value of attribute "AXFullScreen" of targetWindow to true
                        delay 0.3
                        if (value of attribute "AXFullScreen" of targetWindow) as boolean then
                            return true
                        end if
                    end if
                end try
            end repeat
            return false
        end tell
    end run
    """

    /// Starts polling in the background and returns the task handle. Best-effort by
    /// design: fullscreen is cosmetic, so failures only emit diagnostics and never
    /// affect the launch result.
    /// - Parameter gameExecutablePath: the launched game's executable; its basename (without
    ///   extension) is used to recognize the window-owning process on CrossOver-derived Wine.
    func activateWhenWindowAppears(
        gameExecutablePath: URL,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
    ) -> Task<Void, Never> {
        let gameHint = gameExecutablePath.deletingPathExtension().lastPathComponent
        return Task.detached(priority: .utility) {
            await run(gameHint: gameHint, onOutput: onOutput)
        }
    }

    private func run(gameHint: String, onOutput: (@Sendable (ProcessOutputChunk) -> Void)?) async {
        emit("waiting for the game window to apply native macOS fullscreen", onOutput: onOutput)
        try? await Task.sleep(nanoseconds: UInt64(Self.initialDelay * 1_000_000_000))
        let deadline = Date().addingTimeInterval(Self.timeout)
        while Date() < deadline {
            do {
                let result = try await processRunner.run(
                    executable: "/usr/bin/osascript",
                    arguments: ["-e", Self.fullscreenScript, gameHint],
                    environment: [:],
                    currentDirectory: nil
                )
                if result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
                    emit("native macOS fullscreen applied", onOutput: onOutput)
                    return
                }
            } catch let ProcessRunnerError.nonZeroExit(result) {
                // osascript exits non-zero when macOS refuses the automation; retrying
                // cannot fix a missing permission grant, so stop early with guidance.
                if Self.outputIndicatesMissingPermission(result.stderr) {
                    emit(
                        "native fullscreen needs permission: allow NS Launcher under "
                            + "System Settings > Privacy & Security > Automation and Accessibility",
                        onOutput: onOutput
                    )
                    return
                }
                // Transient scripting errors (System Events not ready yet): keep polling.
            } catch is CancellationError {
                return
            } catch {
                // Unknown osascript failure: keep retrying until the timeout.
            }
            try? await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
        }
        emit("gave up waiting for the game window; staying in windowed mode", onOutput: onOutput)
    }

    private static func outputIndicatesMissingPermission(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains("assistive access")
            || text.localizedCaseInsensitiveContains("not allowed")
    }

    private func emit(_ message: String, onOutput: (@Sendable (ProcessOutputChunk) -> Void)?) {
        onOutput?(ProcessOutputChunk(stream: .stdout, text: "[NSLauncher][fullscreen] \(message)\n"))
    }
}
