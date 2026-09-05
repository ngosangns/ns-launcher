// ProcessRunner.swift
//
// Async wrapper around Foundation.Process with executable lookup, stdout/stderr
// capture, streaming output chunks, and cancellation (terminates the process when
// the surrounding task is cancelled). `ProcessOutputBuffer` is thread-safe (NSLock)
// because readability/termination handlers run on background queues, and bounded
// because a game session streams output for hours.

import Darwin
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
            let details = result.stderr.isEmpty ? result.stdout : result.stderr
            return "Process failed with code \(result.exitCode): \(details)"
        }
    }
}

/// Async boundary for running external tools such as Wine.
protocol ProcessRunning: Sendable {
    /// - Parameter logFileURL: when set, both streams are redirected straight to this file and
    ///   nothing is piped through the launcher. A game session writes for hours, and every chunk
    ///   read here costs the main thread the game is competing with; the file is read back once at
    ///   exit so failures can still be classified.
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?,
        logFileURL: URL?,
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
            logFileURL: nil,
            onOutput: nil
        )
    }

    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
    ) async throws -> ProcessResult {
        try await run(
            executable: executable,
            arguments: arguments,
            environment: environment,
            currentDirectory: currentDirectory,
            logFileURL: nil,
            onOutput: onOutput
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
        logFileURL: URL? = nil,
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

                let collectResult: @Sendable (Process) -> ProcessResult
                if let logFileURL, let logHandle = Self.openLogFile(at: logFileURL) {
                    // Straight to disk: no pipes, no reader callbacks, nothing crossing into the
                    // launcher while the game runs.
                    process.standardOutput = logHandle
                    process.standardError = logHandle
                    collectResult = { proc in
                        try? logHandle.close()
                        return ProcessResult(
                            exitCode: proc.terminationStatus,
                            stdout: Self.boundedContents(of: logFileURL),
                            stderr: ""
                        )
                    }
                } else {
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
                    collectResult = { proc in
                        stdoutPipe.fileHandleForReading.readabilityHandler = nil
                        stderrPipe.fileHandleForReading.readabilityHandler = nil
                        outputBuffer.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile(), stream: .stdout)
                        outputBuffer.append(stderrPipe.fileHandleForReading.readDataToEndOfFile(), stream: .stderr)
                        return ProcessResult(
                            exitCode: proc.terminationStatus,
                            stdout: outputBuffer.stdout,
                            stderr: outputBuffer.stderr
                        )
                    }
                }

                process.terminationHandler = { proc in
                    let result = collectResult(proc)

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
                    // Move the child into its own process group so a signal aimed at the launcher's
                    // group (Ctrl+C from a `swift run` terminal, a closed terminal's SIGHUP) does not
                    // also reach it. Wine/wineserver/the game must survive the launcher's own exit —
                    // see `WineShutdownWatchdog` — and inheriting the launcher's process group defeats
                    // that the moment the launcher is stopped from a terminal rather than quit via the
                    // Dock/Cmd+Q.
                    setpgid(process.processIdentifier, 0)
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

extension ProcessRunner {
    /// Creates the log file and opens it for writing, returning nil when the path is unusable so
    /// the caller falls back to pipes rather than losing the launch.
    fileprivate static func openLogFile(at url: URL) -> FileHandle? {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { return nil }
        return try? FileHandle(forWritingTo: url)
    }

    /// Reads back a bounded head and tail of a log file for failure classification.
    fileprivate static func boundedContents(of url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        var buffer = BoundedStreamBuffer()
        while let chunk = try? handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
            buffer.append(chunk)
        }
        return buffer.text
    }
}

/// Retains a bounded head and tail of one stream.
///
/// A game session runs for hours and Wine writes to stderr the whole time, so retaining every byte
/// grows without limit. Callers classify failures from launch-time signals (see `RenderBridge`'s
/// `prepare`, `unsupportedKernelDriverName`) and from whatever the process said last, so the head
/// and the tail are what matter; the middle is dropped once the stream grows past the cap.
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
