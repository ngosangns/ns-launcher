import Foundation

struct WineLaunchRequest {
    var wineBinaryPath: String
    var prefixDirectory: URL
    var executablePath: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectory: URL?
}

protocol WineServicing: Sendable {
    func launch(_ request: WineLaunchRequest) async throws -> ProcessResult
}

struct WineService: WineServicing {
    let processRunner: ProcessRunning

    init(processRunner: ProcessRunning) {
        self.processRunner = processRunner
    }

    func launch(_ request: WineLaunchRequest) async throws -> ProcessResult {
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
