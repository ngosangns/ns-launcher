// OperationController.swift
//
// Cooperative pause/stop control for long-running install/update/launch tasks.
//
// Swift concurrency has no built-in "pause", so long loops call `checkpoint()` to
// (a) throw on cancellation/stop and (b) sleep while paused. Purely cooperative: nothing is
// interrupted mid-flight, an operation only yields at its next checkpoint.

import Foundation

/// Cooperative pause/stop controller shared by long-running async operations.
actor OperationController {
    private var isPaused = false
    private var isStopped = false

    /// Requests a pause; the operation stops at its next checkpoint.
    func pause() {
        isPaused = true
    }

    /// Clears the pause flag so checkpoint loops can continue.
    func resume() {
        isPaused = false
    }

    /// Requests a terminal stop; the next checkpoint throws `CancellationError`.
    func stop() {
        isStopped = true
        isPaused = false
    }

    /// Throws on cancellation/stop and waits while the operation is paused.
    func checkpoint() async throws {
        try Task.checkCancellation()

        while isPaused && !isStopped {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        if isStopped {
            throw CancellationError()
        }
    }
}
