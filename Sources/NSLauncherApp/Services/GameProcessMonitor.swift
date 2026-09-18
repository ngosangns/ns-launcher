// GameProcessMonitor.swift
//
// Tracks the actual game executable — not the Wine wrapper — so the launcher's
// "playing / stopped" state follows the real game process. Wine's wrapper chain
// (wine64 → steam.exe stub → game) can keep the wrapper alive briefly after the
// game quits in-game, or drop the wrapper while the game keeps running under
// wineserver; the game executable is the only reliable session signal.

import Foundation

/// Watches one game executable and reports when it is running and when it stops.
struct GameProcessMonitor: Sendable {
    /// How long the monitor sleeps between process-table probes while waiting
    /// for the game to come up. Kept short: this window is the delay between the
    /// player pressing Play and the UI admitting the game started.
    static let pollIntervalNanoseconds: UInt64 = 500_000_000

    /// The interval used for the rest of the session, once the game is up.
    ///
    /// Each probe walks the whole process table and reads the arguments of every
    /// PID on the system, which is hundreds of syscalls — and it runs for the
    /// entire play session, competing with the game itself. Noticing the game
    /// quit a second or two later costs nothing: nothing is waiting on that edge
    /// but a status label.
    static let runningPollIntervalNanoseconds: UInt64 = 2_000_000_000

    /// Probe returning true while the game executable is running.
    let isGameRunning: @Sendable () async -> Bool
    /// Sleep seam so tests can stay fast; production uses the task sleep.
    let sleep: @Sendable (UInt64) async throws -> Void

    init(
        isGameRunning: @escaping @Sendable () async -> Bool,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.isGameRunning = isGameRunning
        self.sleep = sleep
    }

    /// Blocks until the game process is observed running. Throws
    /// `CancellationError` when the surrounding task is cancelled so callers can
    /// stop waiting (for example when Wine exits first) without treating the
    /// abort as the game stopping.
    func waitUntilRunning() async throws {
        while true {
            try Task.checkCancellation()
            if await isGameRunning() { return }
            try await sleep(Self.pollIntervalNanoseconds)
        }
    }

    /// Blocks until the game process is no longer running. Throws
    /// `CancellationError` when the surrounding task is cancelled so an aborted
    /// wait cannot be mistaken for a clean game exit.
    func waitUntilStopped() async throws {
        while true {
            try Task.checkCancellation()
            if !(await isGameRunning()) { return }
            try await sleep(Self.runningPollIntervalNanoseconds)
        }
    }
}