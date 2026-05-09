import Foundation

/// Captured output and exit status from an external process.
struct ProcessResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

/// Errors surfaced by the process runner before localization.
enum ProcessRunnerError: LocalizedError {
    case executableNotFound(String)
    case nonZeroExit(ProcessResult)

    var errorDescription: String? {
        switch self {
        case let .executableNotFound(path):
            return "Executable not found at \(path)"
        case let .nonZeroExit(result):
            return "Process failed with code \(result.exitCode): \(result.stderr)"
        }
    }
}

/// Async boundary for running external tools such as Wine and 7-Zip.
protocol ProcessRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) async throws -> ProcessResult
}

/// Foundation.Process wrapper with executable lookup, output capture, and cancellation.
struct ProcessRunner: ProcessRunning {
    /// Runs a command and throws when the executable is missing or exits non-zero.
    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil
    ) async throws -> ProcessResult {
        let resolvedExecutable = BinaryLocator.resolveExecutable(
            preferredPath: executable,
            candidateNames: BinaryLocator.candidateNames(forExecutable: executable)
        )

        guard let resolvedExecutable else {
            throw ProcessRunnerError.executableNotFound(executable)
        }

        let process = Process()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Configure pipes before launch so both stdout and stderr are captured.
                process.executableURL = URL(fileURLWithPath: resolvedExecutable)
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectory
                process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                process.terminationHandler = { proc in
                    // Read process output only after termination to avoid partial text snapshots.
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let result = ProcessResult(
                        exitCode: proc.terminationStatus,
                        stdout: String(decoding: stdoutData, as: UTF8.self),
                        stderr: String(decoding: stderrData, as: UTF8.self)
                    )

                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else if result.exitCode == 0 {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: ProcessRunnerError.nonZeroExit(result))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}
