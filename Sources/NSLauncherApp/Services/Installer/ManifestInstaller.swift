import CryptoKit
import Foundation

/// Manifest installation failures reported before localization.
enum ManifestInstallerError: LocalizedError {
    case manifestURLMissing
    case invalidResponse
    case checksumMismatch(path: String)
    case expectedExecutableMissing(String)

    var errorDescription: String? {
        switch self {
        case .manifestURLMissing:
            return "The selected game does not have a manifest URL."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .checksumMismatch(path):
            return "Checksum mismatch for \(path)"
        case let .expectedExecutableMissing(path):
            return "Expected executable was not found after install: \(path)"
        }
    }
}

/// Boundary for metadata-driven installs.
protocol ManifestInstalling: Sendable {
    func fetchManifest(for game: GameDefinition) async throws -> RemoteGameManifest
    func planInstall(for game: GameDefinition, manifest: RemoteGameManifest) async throws -> InstallPlan
    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

/// Downloads manifest files concurrently and verifies them before moving into place.
actor ManifestInstaller: ManifestInstalling {
    /// Upper bound for concurrent file downloads from a manifest.
    private static let maxConcurrentDownloads = 32
    /// Delay between retries after transient connection failures.
    private static let connectionRetryDelayNanoseconds: UInt64 = 5_000_000_000

    private let session: URLSession
    private let fileManager: FileManager

    /// Creates a manifest installer with an optimized download session by default.
    init(session: URLSession? = nil, fileManager: FileManager = .default) {
        self.session = session ?? Self.makeDownloadSession()
        self.fileManager = fileManager
    }

    /// Builds the URLSession used for high-concurrency manifest downloads.
    private static func makeDownloadSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = maxConcurrentDownloads
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    /// Actor-backed work queue that lets many tasks pull files without races.
    private actor FileWorkQueue {
        private let files: [RemoteGameFile]
        private var nextIndex = 0

        init(files: [RemoteGameFile]) {
            self.files = files
        }

        /// Number of worker tasks needed for this batch.
        nonisolated var workerCount: Int {
            min(ManifestInstaller.maxConcurrentDownloads, files.count)
        }

        /// Returns the next file to download, or nil when the queue is drained.
        func next() -> RemoteGameFile? {
            guard nextIndex < files.count else { return nil }
            let file = files[nextIndex]
            nextIndex += 1
            return file
        }
    }

    /// Fetches and decodes the manifest configured on a game definition.
    func fetchManifest(for game: GameDefinition) async throws -> RemoteGameManifest {
        guard let manifestURL = game.manifestURL else {
            throw ManifestInstallerError.manifestURLMissing
        }

        let (data, response) = try await session.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ManifestInstallerError.invalidResponse
        }

        return try JSONDecoder().decode(RemoteGameManifest.self, from: data)
    }

    /// Converts a manifest into a visible install plan and byte estimate.
    func planInstall(for game: GameDefinition, manifest: RemoteGameManifest) async throws -> InstallPlan {
        let peakTemp = manifest.files.map(\.size).max() ?? 0
        let steps = manifest.files.flatMap { file in
            [
                InstallStep(kind: .createDirectory, relativePath: (file.path as NSString).deletingLastPathComponent, bytes: 0),
                InstallStep(kind: .downloadFile, relativePath: file.path, bytes: file.size),
                InstallStep(kind: .moveIntoPlace, relativePath: file.path, bytes: file.size),
                InstallStep(kind: .verifyChecksum, relativePath: file.path, bytes: file.size)
            ]
        }

        let total = manifest.files.reduce(Int64(0)) { $0 + $1.size }
        return InstallPlan(version: manifest.version, steps: steps, estimatedBytesToDownload: total, peakTemporaryBytes: peakTemp)
    }

    /// Downloads all manifest files, validates the executable, and writes install metadata.
    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try fileManager.createDirectory(at: game.installDirectory, withIntermediateDirectories: true)
        let progressTracker = ManifestDownloadProgressTracker(totalBytes: manifest.files.reduce(Int64(0)) { $0 + $1.size })
        try await operationController?.checkpoint()
        try await downloadFiles(
            manifest.files,
            for: game,
            operationController: operationController,
            progressTracker: progressTracker,
            onEvent: onEvent
        )

        let executable = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        guard fileManager.fileExists(atPath: executable.path) else {
            throw ManifestInstallerError.expectedExecutableMissing(game.executableRelativePath)
        }

        let metadata = InstalledGameMetadata(
            gameID: game.id,
            installMode: game.installerStrategy,
            installedAt: Date(),
            sourceArchiveFileName: nil,
            executableRelativePath: game.executableRelativePath,
            version: manifest.version
        )
        let metadataURL = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
        await onEvent(.finished(version: manifest.version))
    }

    /// Runs concurrent worker tasks until every manifest file is processed.
    private func downloadFiles(
        _ files: [RemoteGameFile],
        for game: GameDefinition,
        operationController: OperationController?,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        guard !files.isEmpty else { return }

        let queue = FileWorkQueue(files: files)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<queue.workerCount {
                group.addTask {
                    // Each worker repeatedly pulls from the actor queue, avoiding shared index races.
                    while let file = await queue.next() {
                        try await self.installFile(
                            file,
                            for: game,
                            operationController: operationController,
                            progressTracker: progressTracker,
                            onEvent: onEvent
                        )
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    /// Downloads one file to a partial path, verifies it, and atomically moves it into place.
    private func installFile(
        _ file: RemoteGameFile,
        for game: GameDefinition,
        operationController: OperationController?,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await operationController?.checkpoint()
        let destination = game.installDirectory.appendingPathComponent(file.path)
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let partial = destination.appendingPathExtension("partial")
        let existingDestinationBytes = normalizedPartialSize(at: destination, expectedBytes: file.size)

        if existingDestinationBytes == file.size {
            // Already-installed files are counted in progress so resumed runs start at the right total.
            if fileManager.fileExists(atPath: partial.path) {
                try? fileManager.removeItem(at: partial)
            }
            await progressTracker.registerExistingBytes(
                for: file.path,
                bytes: file.size,
                fileTotal: file.size,
                onEvent: onEvent
            )
            return
        }

        if fileManager.fileExists(atPath: destination.path), existingDestinationBytes != file.size {
            // A mismatched final file is safer to discard than to patch in place.
            try fileManager.removeItem(at: destination)
        }

        let startingBytes = normalizedPartialSize(at: partial, expectedBytes: file.size)
        await progressTracker.registerExistingBytes(
            for: file.path,
            bytes: startingBytes,
            fileTotal: file.size,
            onEvent: onEvent
        )
        await onEvent(.preparing(file.path))

        try await resumeStreamingFile(
            file,
            to: partial,
            startingAt: startingBytes,
            operationController: operationController,
            progressTracker: progressTracker,
            onEvent: onEvent
        )

        let finalSize = normalizedPartialSize(at: partial, expectedBytes: nil)
        guard finalSize == file.size else {
            throw ManifestInstallerError.invalidResponse
        }

        await onEvent(.downloading(path: file.path, received: finalSize, total: file.size))

        if let sha256 = file.sha256 {
            await onEvent(.verifying(path: file.path))
            try verifySHA256(of: partial, expectedHex: sha256, path: file.path)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: partial, to: destination)
    }

    /// Streams one file into a partial file, resuming from the requested offset when supported.
    private func streamFile(
        _ file: RemoteGameFile,
        to partial: URL,
        startingAt requestedOffset: Int64,
        operationController: OperationController?,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try fileManager.createDirectory(at: partial.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: partial.path) {
            fileManager.createFile(atPath: partial.path, contents: nil)
        }

        let startOffset = requestedOffset
        var request = URLRequest(url: file.url)
        if startOffset > 0 {
            request.setValue("bytes=\(startOffset)-", forHTTPHeaderField: "Range")
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ManifestInstallerError.invalidResponse
        }

        if startOffset > 0 && http.statusCode == 200 {
            // The server ignored the Range header, so restart the partial file from scratch.
            if fileManager.fileExists(atPath: partial.path) {
                try fileManager.removeItem(at: partial)
            }
            await progressTracker.resetBytes(for: file.path, fileTotal: file.size, onEvent: onEvent)
            return try await streamFile(
                file,
                to: partial,
                startingAt: 0,
                operationController: operationController,
                progressTracker: progressTracker,
                onEvent: onEvent
            )
        }

        let validStatusCode =
            (startOffset > 0 && http.statusCode == 206) ||
            (startOffset == 0 && 200..<300 ~= http.statusCode)
        guard validStatusCode else {
            throw ManifestInstallerError.invalidResponse
        }

        let handle = try FileHandle(forWritingTo: partial)
        defer {
            try? handle.synchronize()
            try? handle.close()
        }
        if startOffset == 0 {
            try handle.truncate(atOffset: 0)
        } else {
            try handle.seekToEnd()
        }

        var buffer = Data()
        buffer.reserveCapacity(256 * 1024)

        for try await byte in bytes {
            try Task.checkCancellation()
            try await operationController?.checkpoint()
            buffer.append(byte)

            if buffer.count >= 256 * 1024 {
                // Buffer writes reduce FileHandle overhead while keeping progress responsive.
                try writeBuffer(
                    &buffer,
                    to: handle,
                    filePath: file.path,
                    fileTotal: file.size,
                    progressTracker: progressTracker,
                    onEvent: onEvent
                )
            }
        }

        if !buffer.isEmpty {
            try writeBuffer(
                &buffer,
                to: handle,
                filePath: file.path,
                fileTotal: file.size,
                progressTracker: progressTracker,
                onEvent: onEvent
            )
        }
    }

    /// Retries a streaming file download after transient connection failures.
    private func resumeStreamingFile(
        _ file: RemoteGameFile,
        to partial: URL,
        startingAt initialOffset: Int64,
        operationController: OperationController?,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        var currentOffset = initialOffset

        while currentOffset < file.size {
            try await operationController?.checkpoint()

            do {
                try await streamFile(
                    file,
                    to: partial,
                    startingAt: currentOffset,
                    operationController: operationController,
                    progressTracker: progressTracker,
                    onEvent: onEvent
                )
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                guard shouldRetryAfterConnectionLoss(error) else {
                    throw error
                }

                try await waitForRetryDelay(operationController: operationController)
                currentOffset = normalizedPartialSize(at: partial, expectedBytes: file.size)
            }
        }
    }

    /// Writes buffered bytes and forwards progress through the actor tracker.
    private func writeBuffer(
        _ buffer: inout Data,
        to handle: FileHandle,
        filePath: String,
        fileTotal: Int64,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) throws {
        try handle.write(contentsOf: buffer)
        let writtenBytes = Int64(buffer.count)
        buffer.removeAll(keepingCapacity: true)
        Task {
            await progressTracker.advance(
                bytes: writtenBytes,
                for: filePath,
                fileTotal: fileTotal,
                onEvent: onEvent
            )
        }
    }

    /// Returns a local file size, deleting partials that are larger than the manifest entry.
    private func normalizedPartialSize(at url: URL, expectedBytes: Int64?) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let actualSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        if let expectedBytes, actualSize > expectedBytes {
            try? fileManager.removeItem(at: url)
            return 0
        }

        return actualSize
    }

    /// Identifies URL loading errors that are likely transient.
    private func shouldRetryAfterConnectionLoss(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            return false
        }

        switch nsError.code {
        case NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorTimedOut,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorInternationalRoamingOff,
             NSURLErrorCallIsActive,
             NSURLErrorDataNotAllowed,
             NSURLErrorSecureConnectionFailed,
             NSURLErrorCannotLoadFromNetwork:
            return true
        default:
            return false
        }
    }

    /// Sleeps in short chunks so pause/stop requests remain responsive during retry backoff.
    private func waitForRetryDelay(operationController: OperationController?) async throws {
        let retryDelayStepNanoseconds: UInt64 = 250_000_000
        var remaining = Self.connectionRetryDelayNanoseconds

        while remaining > 0 {
            try await operationController?.checkpoint()
            let nextDelay = min(remaining, retryDelayStepNanoseconds)
            try await Task.sleep(nanoseconds: nextDelay)
            remaining -= nextDelay
        }
    }

    /// Verifies a downloaded file against the manifest's SHA-256 hash when provided.
    private func verifySHA256(of fileURL: URL, expectedHex: String, path: String) throws {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 1024 * 1024)
            guard let data, !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(expectedHex) == .orderedSame else {
            throw ManifestInstallerError.checksumMismatch(path: path)
        }
    }
}

/// Actor that aggregates per-file progress into manifest-wide progress events.
actor ManifestDownloadProgressTracker {
    private let totalBytes: Int64
    private var totalReceivedBytes: Int64 = 0
    private var fileBytes: [String: Int64] = [:]

    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }

    /// Counts bytes already present on disk during resumed installs.
    func registerExistingBytes(
        for path: String,
        bytes: Int64,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        guard bytes > 0 else { return }
        let previous = fileBytes[path] ?? 0
        guard bytes > previous else { return }
        fileBytes[path] = bytes
        totalReceivedBytes += (bytes - previous)
        await onEvent(.downloadingManifest(
            path: path,
            overallReceived: totalReceivedBytes,
            overallTotal: totalBytes,
            fileReceived: bytes,
            fileTotal: fileTotal
        ))
    }

    /// Removes previously counted bytes when a partial must restart from zero.
    func resetBytes(
        for path: String,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        let previous = fileBytes[path] ?? 0
        guard previous > 0 else { return }
        fileBytes[path] = 0
        totalReceivedBytes -= previous
        await onEvent(.downloadingManifest(
            path: path,
            overallReceived: totalReceivedBytes,
            overallTotal: totalBytes,
            fileReceived: 0,
            fileTotal: fileTotal
        ))
    }

    /// Adds newly written bytes and emits a combined progress event.
    func advance(
        bytes: Int64,
        for path: String,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        guard bytes > 0 else { return }
        fileBytes[path, default: 0] += bytes
        totalReceivedBytes += bytes
        await onEvent(.downloadingManifest(
            path: path,
            overallReceived: totalReceivedBytes,
            overallTotal: totalBytes,
            fileReceived: fileBytes[path] ?? 0,
            fileTotal: fileTotal
        ))
    }
}
