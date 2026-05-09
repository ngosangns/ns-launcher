import Foundation

/// Cooperative pause/stop controller shared by long-running async operations.
actor OperationController {
    private var isPaused = false
    private var isStopped = false
    private var pauseHandler: (@Sendable () -> Void)?
    private var resumeHandler: (@Sendable () -> Void)?
    private var stopHandler: (@Sendable () -> Void)?

    /// Registers operation-specific handlers for APIs that need explicit cancellation.
    func setHandlers(
        pause: (@Sendable () -> Void)?,
        resume: (@Sendable () -> Void)?,
        stop: (@Sendable () -> Void)?
    ) {
        self.pauseHandler = pause
        self.resumeHandler = resume
        self.stopHandler = stop
    }

    /// Requests a pause and lets the active operation persist any resume state.
    func pause() {
        isPaused = true
        pauseHandler?()
    }

    /// Clears the pause flag so checkpoint loops can continue.
    func resume() {
        isPaused = false
        resumeHandler?()
    }

    /// Requests a terminal stop and triggers operation-specific cleanup.
    func stop() {
        isStopped = true
        isPaused = false
        stopHandler?()
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
