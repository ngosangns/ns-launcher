import Foundation

/// Complete request needed to launch a Windows executable through Wine.
struct WineLaunchRequest {
    var wineBinaryPath: String
    var prefixDirectory: URL
    var executablePath: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectory: URL?
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
        // Caller-supplied environment values win except for WINEPREFIX, which must match settings.
        let env = request.environment.merging([
            "WINEPREFIX": request.prefixDirectory.path
        ]) { _, new in new }

        return try await processRunner.run(
            executable: request.wineBinaryPath,
            arguments: [request.executablePath.path] + request.arguments,
            environment: env,
            currentDirectory: request.currentDirectory
        )
    }
}
