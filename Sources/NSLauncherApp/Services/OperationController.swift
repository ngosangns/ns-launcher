import Foundation

actor OperationController {
    private var isPaused = false
    private var isStopped = false
    private var pauseHandler: (@Sendable () -> Void)?
    private var resumeHandler: (@Sendable () -> Void)?
    private var stopHandler: (@Sendable () -> Void)?

    func setHandlers(
        pause: (@Sendable () -> Void)?,
        resume: (@Sendable () -> Void)?,
        stop: (@Sendable () -> Void)?
    ) {
        self.pauseHandler = pause
        self.resumeHandler = resume
        self.stopHandler = stop
    }

    func pause() {
        isPaused = true
        pauseHandler?()
    }

    func resume() {
        isPaused = false
        resumeHandler?()
    }

    func stop() {
        isStopped = true
        isPaused = false
        stopHandler?()
    }

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
