// ProcessRunner.swift
//
// Async wrapper around Foundation.Process with executable lookup, stdout/stderr
// capture, streaming output chunks, and cancellation (terminates the process when
// the surrounding task is cancelled). `ProcessOutputBuffer` is thread-safe (NSLock)
// because readability/termination handlers run on background queues, and bounded
// because a game session streams output for hours.

import Foundation

/// Captured output and exit status from an external process.
struct ProcessResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

/// A process output chunk emitted while a command is still running.
struct ProcessOutputChunk: Sendable {
    enum Stream: Sendable {
        case stdout
        case stderr
    }

    var stream: Stream
    var text: String
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

/// Async boundary for running external tools such as Wine.
protocol ProcessRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
    ) async throws -> ProcessResult
}

extension ProcessRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?
    ) async throws -> ProcessResult {
        try await run(
            executable: executable,
            arguments: arguments,
            environment: environment,
            currentDirectory: currentDirectory,
            onOutput: nil
        )
    }
}

/// Foundation.Process wrapper with executable lookup, output capture, and cancellation.
struct ProcessRunner: ProcessRunning {
    /// Runs a command and throws when the executable is missing or exits non-zero.
    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectory: URL? = nil,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)? = nil
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
                let outputBuffer = ProcessOutputBuffer()
                stdoutPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    outputBuffer.append(data, stream: .stdout)
                    onOutput?(ProcessOutputChunk(stream: .stdout, text: String(decoding: data, as: UTF8.self)))
                }
                stderrPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    outputBuffer.append(data, stream: .stderr)
                    onOutput?(ProcessOutputChunk(stream: .stderr, text: String(decoding: data, as: UTF8.self)))
                }

                process.terminationHandler = { proc in
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    outputBuffer.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile(), stream: .stdout)
                    outputBuffer.append(stderrPipe.fileHandleForReading.readDataToEndOfFile(), stream: .stderr)
                    let result = ProcessResult(
                        exitCode: proc.terminationStatus,
                        stdout: outputBuffer.stdout,
                        stderr: outputBuffer.stderr
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

/// Retains a bounded head and tail of one stream.
///
/// A game session runs for hours and Wine writes to stderr the whole time, so retaining every byte
/// grows without limit. Callers classify failures from launch-time signals (`ensureDXMTInstalled`,
/// `unsupportedKernelDriverName`) and from whatever the process said last, so the head and the tail
/// are what matter; the middle is dropped once the stream grows past the cap.
struct BoundedStreamBuffer {
    /// Bytes kept from the start of the stream, where startup diagnostics appear.
    private static let headLimit = 512 * 1024
    /// Bytes kept from the end of the stream, where a crash or exit message appears.
    private static let tailLimit = 512 * 1024
    private static let elisionMarker = "\n[NSLauncher] ... middle of output omitted ...\n"

    private var head = Data()
    private var tail = Data()
    private var droppedBytes = 0

    var text: String {
        guard droppedBytes > 0 else {
            return String(decoding: head + tail, as: UTF8.self)
        }
        return String(decoding: head, as: UTF8.self)
            + Self.elisionMarker
            + String(decoding: tail, as: UTF8.self)
    }

    mutating func append(_ data: Data) {
        guard !data.isEmpty else { return }
        if head.count < Self.headLimit {
            let take = min(Self.headLimit - head.count, data.count)
            head.append(data.prefix(take))
            let remainder = data.dropFirst(take)
            guard !remainder.isEmpty else { return }
            tail.append(remainder)
        } else {
            tail.append(data)
        }
        guard tail.count > Self.tailLimit else { return }
        let overflow = tail.count - Self.tailLimit
        tail = Data(tail.dropFirst(overflow))
        droppedBytes += overflow
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var stdoutBuffer = BoundedStreamBuffer()
    private var stderrBuffer = BoundedStreamBuffer()

    var stdout: String {
        lock.withLock { stdoutBuffer.text }
    }

    var stderr: String {
        lock.withLock { stderrBuffer.text }
    }

    func append(_ data: Data, stream: ProcessOutputChunk.Stream) {
        guard !data.isEmpty else { return }
        lock.withLock {
            switch stream {
            case .stdout:
                stdoutBuffer.append(data)
            case .stderr:
                stderrBuffer.append(data)
            }
        }
    }
}
