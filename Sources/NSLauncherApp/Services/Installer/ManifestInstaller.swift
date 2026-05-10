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
    func planUpdate(
        for game: GameDefinition,
        manifest: RemoteGameManifest,
        installedMetadata: InstalledGameMetadata?
    ) async throws -> GameUpdatePlan
    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        files: [RemoteGameFile],
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

/// Downloads manifest files concurrently and verifies them before moving into place.
actor ManifestInstaller: ManifestInstalling {
    /// Upper bound for concurrent file downloads from a manifest.
    private static let maxConcurrentDownloads = 32
    /// Upper bound for all active HTTP requests, including segmented large-file ranges.
    private static let maxActiveRequests = 64
    /// Files at or above this size are downloaded with multiple ranged requests.
    private static let segmentedDownloadThreshold: Int64 = 32 * 1024 * 1024
    /// Target byte range size for each large-file segment.
    private static let segmentSize: Int64 = 16 * 1024 * 1024
    /// Per-file segment parallelism. Global request parallelism is still capped separately.
    private static let maxSegmentsPerFile = 4
    /// Delay between retries after transient connection failures.
    private static let connectionRetryDelayNanoseconds: UInt64 = 5_000_000_000

    private let session: URLSession
    private let fileManager: FileManager
    private let requestLimiter = DownloadRequestLimiter(maxConcurrentRequests: maxActiveRequests)

    /// Creates a manifest installer with an optimized download session by default.
    init(session: URLSession? = nil, fileManager: FileManager = .default) {
        self.session = session ?? Self.makeDownloadSession()
        self.fileManager = fileManager
    }

    /// Builds the URLSession used for high-concurrency manifest downloads.
    private static func makeDownloadSession() -> URLSession {
        URLSession(configuration: makeDownloadConfiguration())
    }

    /// Builds URLSession configuration shared by manifest metadata and file downloads.
    private static func makeDownloadConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = maxActiveRequests
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }

    /// Actor-backed work queue that lets many tasks pull files without races.
    private actor FileWorkQueue {
        private let files: [RemoteGameFile]
        private var nextIndex = 0

        init(files: [RemoteGameFile]) {
            // Start larger files first so the tail of the install is not dominated by one huge asset.
            self.files = files.sorted { lhs, rhs in
                if lhs.size == rhs.size {
                    return lhs.path < rhs.path
                }
                return lhs.size > rhs.size
            }
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

    /// Computes the subset of manifest files that are missing or no longer match local metadata.
    func planUpdate(
        for game: GameDefinition,
        manifest: RemoteGameManifest,
        installedMetadata: InstalledGameMetadata?
    ) async throws -> GameUpdatePlan {
        var filesToDownload: [RemoteGameFile] = []
        var skippedFiles = 0

        for file in manifest.files {
            let destination = game.installDirectory.appendingPathComponent(file.path)
            if try existingFileMatches(file, at: destination) {
                skippedFiles += 1
            } else {
                filesToDownload.append(file)
            }
        }

        let bytesToDownload = filesToDownload.reduce(Int64(0)) { $0 + $1.size }
        let metadataNeedsUpdate = installedMetadata?.gameID != game.id
            || installedMetadata?.installMode != game.installerStrategy
            || installedMetadata?.executableRelativePath != game.executableRelativePath
            || installedMetadata?.version != manifest.version

        return GameUpdatePlan(
            installedVersion: installedMetadata?.version,
            latestVersion: manifest.version,
            targetFiles: manifest.files,
            filesToDownload: filesToDownload,
            skippedFiles: skippedFiles,
            bytesToDownload: bytesToDownload,
            peakTemporaryBytes: filesToDownload.map(\.size).max() ?? 0,
            metadataNeedsUpdate: metadataNeedsUpdate
        )
    }

    /// Downloads all manifest files, validates the executable, and writes install metadata.
    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await install(
            game: game,
            manifest: manifest,
            files: manifest.files,
            operationController: operationController,
            onEvent: onEvent
        )
    }

    /// Downloads selected manifest files, validates the executable, and writes install metadata.
    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        files: [RemoteGameFile],
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try fileManager.createDirectory(at: game.installDirectory, withIntermediateDirectories: true)
        let progressTracker = ManifestDownloadProgressTracker(totalBytes: files.reduce(Int64(0)) { $0 + $1.size })
        try await operationController?.checkpoint()
        try InstallTargetPruner.pruneBeforeApplyingTarget(
            installDirectory: game.installDirectory,
            targetRelativePaths: Set(manifest.files.map(\.path)),
            protectedURLs: [game.winePrefixDirectory],
            fileManager: fileManager
        )
        try await operationController?.checkpoint()
        try await downloadFiles(
            files,
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

        if try existingFileMatches(file, at: destination) {
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

        if fileManager.fileExists(atPath: destination.path) {
            // A mismatched final file is safer to discard than to patch in place.
            try fileManager.removeItem(at: destination)
        }

        await onEvent(.preparing(file.path))
        await progressTracker.beginFile(
            file.path,
            fileTotal: file.size,
            onEvent: onEvent
        )

        if shouldUseSegmentedDownload(for: file) {
            try await resumeSegmentedFile(
                file,
                to: partial,
                operationController: operationController,
                progressTracker: progressTracker,
                onEvent: onEvent
            )
        } else {
            let startingBytes = normalizedPartialSize(at: partial, expectedBytes: file.size)
            await progressTracker.registerExistingBytes(
                for: file.path,
                bytes: startingBytes,
                fileTotal: file.size,
                onEvent: onEvent
            )
            try await resumeStreamingFile(
                file,
                to: partial,
                startingAt: startingBytes,
                operationController: operationController,
                progressTracker: progressTracker,
                onEvent: onEvent
            )
        }

        let finalSize = normalizedPartialSize(at: partial, expectedBytes: nil)
        guard finalSize == file.size else {
            throw ManifestInstallerError.invalidResponse
        }

        await onEvent(.downloading(path: file.path, received: finalSize, total: file.size))

        if let md5 = file.md5, !md5.isEmpty {
            await onEvent(.verifying(path: file.path))
            try verifyMD5(of: partial, expectedHex: md5, path: file.path)
        } else if let sha256 = file.sha256 {
            await onEvent(.verifying(path: file.path))
            try verifySHA256(of: partial, expectedHex: sha256, path: file.path)
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: partial, to: destination)
        removeSegmentState(for: partial)
    }

    /// Whether a file is large enough to benefit from multiple ranged requests.
    private func shouldUseSegmentedDownload(for file: RemoteGameFile) -> Bool {
        file.size >= Self.segmentedDownloadThreshold
    }

    /// Downloads a large file as several independently resumable byte ranges.
    private func resumeSegmentedFile(
        _ file: RemoteGameFile,
        to partial: URL,
        operationController: OperationController?,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try fileManager.createDirectory(at: partial.deletingLastPathComponent(), withIntermediateDirectories: true)
        try prepareSparsePartial(at: partial, expectedBytes: file.size)

        var state = loadSegmentState(for: partial, file: file)
        let completedBytes = state.completedSegments.reduce(Int64(0)) { total, index in
            total + segmentRange(index: index, fileSize: file.size).length
        }
        await progressTracker.registerExistingBytes(
            for: file.path,
            bytes: completedBytes,
            fileTotal: file.size,
            onEvent: onEvent
        )

        while state.completedSegments.count < state.segmentCount {
            try await operationController?.checkpoint()

            let completed = Set(state.completedSegments)
            let pending = (0..<state.segmentCount).filter { !completed.contains($0) }
            let batch = Array(pending.prefix(Self.maxSegmentsPerFile))

            try await withThrowingTaskGroup(of: Int.self) { group in
                for segmentIndex in batch {
                    group.addTask {
                        try await self.downloadSegmentWithRetry(
                            index: segmentIndex,
                            file: file,
                            to: partial,
                            operationController: operationController,
                            progressTracker: progressTracker,
                            onEvent: onEvent
                        )
                        return segmentIndex
                    }
                }

                for try await segmentIndex in group {
                    if !state.completedSegments.contains(segmentIndex) {
                        state.completedSegments.append(segmentIndex)
                        state.completedSegments.sort()
                        try saveSegmentState(state, for: partial)
                    }
                }
            }
        }

        removeSegmentState(for: partial)
    }

    /// Retries one byte range after transient failures.
    private func downloadSegmentWithRetry(
        index: Int,
        file: RemoteGameFile,
        to partial: URL,
        operationController: OperationController?,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        while true {
            try await operationController?.checkpoint()

            do {
                try await downloadSegment(
                    index: index,
                    file: file,
                    to: partial,
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
            }
        }
    }

    /// Downloads one byte range and writes it at its final offset in the partial file.
    private func downloadSegment(
        index: Int,
        file: RemoteGameFile,
        to partial: URL,
        operationController: OperationController?,
        progressTracker: ManifestDownloadProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        let range = segmentRange(index: index, fileSize: file.size)
        try await operationController?.checkpoint()
        await requestLimiter.acquire()

        var request = URLRequest(url: file.url)
        request.setValue("bytes=\(range.start)-\(range.end)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        let delegate = ManifestChunkDownloadDelegate(
            destinationURL: partial,
            writeOffset: range.start,
            expectedBytes: range.length,
            responsePolicy: .byteRange,
            progress: { _, receivedBytes in
                waitForManifestProgressUpdate {
                    await progressTracker.updateSegmentProgress(
                        index: index,
                        bytes: receivedBytes,
                        segmentTotal: range.length,
                        for: file.path,
                        fileTotal: file.size,
                        onEvent: onEvent
                    )
                }
            }
        )
        let downloadSession = URLSession(
            configuration: Self.makeDownloadConfiguration(),
            delegate: delegate,
            delegateQueue: nil
        )
        defer {
            downloadSession.invalidateAndCancel()
        }

        try await operationController?.checkpoint()
        do {
            try await delegate.start(session: downloadSession, request: request)
        } catch {
            await requestLimiter.release()
            throw error
        }
        await requestLimiter.release()
        await progressTracker.completeSegment(
            index: index,
            bytes: range.length,
            for: file.path,
            fileTotal: file.size,
            onEvent: onEvent
        )
    }

    /// Returns the inclusive byte range for one segment index.
    private func segmentRange(index: Int, fileSize: Int64) -> DownloadSegmentRange {
        let start = Int64(index) * Self.segmentSize
        let end = min(start + Self.segmentSize, fileSize) - 1
        return DownloadSegmentRange(start: start, end: end)
    }

    /// Creates or resets the partial file used by segmented writes.
    private func prepareSparsePartial(at partial: URL, expectedBytes: Int64) throws {
        let stateURL = segmentStateURL(for: partial)
        let partialExists = fileManager.fileExists(atPath: partial.path)
        if !fileManager.fileExists(atPath: stateURL.path), fileManager.fileExists(atPath: partial.path) {
            // Without segment state, a full-sized sparse partial cannot be trusted.
            try fileManager.removeItem(at: partial)
        }
        if fileManager.fileExists(atPath: stateURL.path), !partialExists {
            // Segment state is only meaningful together with the sparse partial it describes.
            try fileManager.removeItem(at: stateURL)
        }

        if !fileManager.fileExists(atPath: partial.path) {
            fileManager.createFile(atPath: partial.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: partial)
        defer { try? handle.close() }
        try handle.truncate(atOffset: UInt64(expectedBytes))
    }

    /// Loads persisted segment completion state or starts a new one.
    private func loadSegmentState(for partial: URL, file: RemoteGameFile) -> SegmentedDownloadState {
        let stateURL = segmentStateURL(for: partial)
        let segmentCount = Int((file.size + Self.segmentSize - 1) / Self.segmentSize)
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(SegmentedDownloadState.self, from: data),
              state.fileSize == file.size,
              state.segmentSize == Self.segmentSize,
              state.segmentCount == segmentCount else {
            return SegmentedDownloadState(
                fileSize: file.size,
                segmentSize: Self.segmentSize,
                segmentCount: segmentCount,
                completedSegments: []
            )
        }
        return state
    }

    /// Persists segment completion after every completed range.
    private func saveSegmentState(_ state: SegmentedDownloadState, for partial: URL) throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: segmentStateURL(for: partial), options: .atomic)
    }

    /// Removes sidecar state after the file has fully downloaded or moved into place.
    private func removeSegmentState(for partial: URL) {
        let stateURL = segmentStateURL(for: partial)
        if fileManager.fileExists(atPath: stateURL.path) {
            try? fileManager.removeItem(at: stateURL)
        }
    }

    /// Sidecar path used for segmented resume metadata.
    private func segmentStateURL(for partial: URL) -> URL {
        partial.appendingPathExtension("segments.json")
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
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        await requestLimiter.acquire()

        if startOffset == 0 {
            let handle = try FileHandle(forWritingTo: partial)
            try handle.truncate(atOffset: 0)
            try? handle.close()
        }

        let expectedRemainingBytes = max(file.size - startOffset, 0)
        let delegate = ManifestChunkDownloadDelegate(
            destinationURL: partial,
            writeOffset: startOffset,
            expectedBytes: expectedRemainingBytes,
            responsePolicy: .fullFile(startOffset: startOffset),
            progress: { bytesWritten, _ in
                waitForManifestProgressUpdate {
                    await progressTracker.advance(
                        bytes: bytesWritten,
                        for: file.path,
                        fileTotal: file.size,
                        onEvent: onEvent
                    )
                }
            }
        )
        let downloadSession = URLSession(
            configuration: Self.makeDownloadConfiguration(),
            delegate: delegate,
            delegateQueue: nil
        )
        defer {
            downloadSession.invalidateAndCancel()
        }

        try await operationController?.checkpoint()
        do {
            try await delegate.start(session: downloadSession, request: request)
        } catch ManifestDownloadInterruption.rangeIgnored {
            await requestLimiter.release()
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
        } catch {
            await requestLimiter.release()
            throw error
        }
        await requestLimiter.release()
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

    /// Checks a final installed file using size first and checksum when the manifest provides one.
    private func existingFileMatches(_ file: RemoteGameFile, at url: URL) throws -> Bool {
        guard normalizedPartialSize(at: url, expectedBytes: file.size) == file.size else {
            return false
        }

        do {
            if let md5 = file.md5, !md5.isEmpty {
                try verifyMD5(of: url, expectedHex: md5, path: file.path)
            } else if let sha256 = file.sha256, !sha256.isEmpty {
                try verifySHA256(of: url, expectedHex: sha256, path: file.path)
            }
            return true
        } catch ManifestInstallerError.checksumMismatch {
            return false
        }
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

    /// Verifies a downloaded file against the MD5 hash published by HoYoPlay metadata.
    private func verifyMD5(of fileURL: URL, expectedHex: String, path: String) throws {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = Insecure.MD5()
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

/// Inclusive byte range for one segmented file request.
private struct DownloadSegmentRange {
    let start: Int64
    let end: Int64

    var length: Int64 {
        end - start + 1
    }
}

/// Resume sidecar for large files downloaded with parallel range requests.
private struct SegmentedDownloadState: Codable {
    var fileSize: Int64
    var segmentSize: Int64
    var segmentCount: Int
    var completedSegments: [Int]
}

/// Control-flow errors used by manifest chunk downloads.
private enum ManifestDownloadInterruption: Error {
    case rangeIgnored
}

/// Expected HTTP response shape for a manifest file request.
private enum ManifestDownloadResponsePolicy {
    case fullFile(startOffset: Int64)
    case byteRange
}

/// Runs async progress accounting synchronously from URLSession delegate callbacks to preserve ordering.
private func waitForManifestProgressUpdate(_ operation: @escaping @Sendable () async -> Void) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
        await operation()
        semaphore.signal()
    }
    semaphore.wait()
}

/// URLSession delegate that writes manifest response chunks directly to disk.
private final class ManifestChunkDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private static let progressIntervalBytes: Int64 = 1024 * 1024

    private let destinationURL: URL
    private let writeOffset: Int64
    private let expectedBytes: Int64
    private let responsePolicy: ManifestDownloadResponsePolicy
    private let progressHandler: @Sendable (Int64, Int64) -> Void

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var task: URLSessionDataTask?
    private var handle: FileHandle?
    private var receivedBytes: Int64 = 0
    private var pendingProgressBytes: Int64 = 0
    private var didResume = false
    private var isCancelRequested = false

    init(
        destinationURL: URL,
        writeOffset: Int64,
        expectedBytes: Int64,
        responsePolicy: ManifestDownloadResponsePolicy,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) {
        self.destinationURL = destinationURL
        self.writeOffset = writeOffset
        self.expectedBytes = expectedBytes
        self.responsePolicy = responsePolicy
        self.progressHandler = progress
    }

    /// Opens the destination file and starts the URLSession task.
    func start(session: URLSession, request: URLRequest) async throws {
        let handle = try FileHandle(forWritingTo: destinationURL)
        try handle.seek(toOffset: UInt64(writeOffset))
        self.handle = handle

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    lock.lock()
                    self.continuation = continuation
                    let task = session.dataTask(with: request)
                    self.task = task
                    lock.unlock()
                    task.resume()
                }
            } onCancel: {
                cancel()
            }
        } catch {
            try? handle.synchronize()
            try? handle.close()
            self.handle = nil
            throw error
        }
    }

    /// Cancels the active request when the surrounding task is stopped.
    func cancel() {
        lock.lock()
        isCancelRequested = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    /// Appends received data and emits chunk-level progress.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let bytesWritten = Int64(data.count)
        guard receivedBytes + bytesWritten <= expectedBytes else {
            resume(with: .failure(ManifestInstallerError.invalidResponse))
            dataTask.cancel()
            return
        }

        do {
            try handle?.write(contentsOf: data)
        } catch {
            resume(with: .failure(error))
            dataTask.cancel()
            return
        }

        receivedBytes += bytesWritten
        pendingProgressBytes += bytesWritten
        if pendingProgressBytes >= Self.progressIntervalBytes {
            emitProgress()
        }
    }

    /// Validates that the server honored full or ranged response requirements.
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse
    ) async -> URLSession.ResponseDisposition {
        guard let http = response as? HTTPURLResponse else {
            resume(with: .failure(ManifestInstallerError.invalidResponse))
            return .cancel
        }

        switch responsePolicy {
        case let .fullFile(startOffset):
            if startOffset > 0 && http.statusCode == 200 {
                resume(with: .failure(ManifestDownloadInterruption.rangeIgnored))
                return .cancel
            }

            let validStatusCode =
                (startOffset > 0 && http.statusCode == 206) ||
                (startOffset == 0 && 200..<300 ~= http.statusCode)
            guard validStatusCode else {
                resume(with: .failure(ManifestInstallerError.invalidResponse))
                return .cancel
            }
        case .byteRange:
            guard http.statusCode == 206 else {
                resume(with: .failure(ManifestInstallerError.invalidResponse))
                return .cancel
            }
        }

        return .allow
    }

    /// Translates URLSession completion into the async continuation result.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle?.synchronize()
        try? handle?.close()
        handle = nil

        if let error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                if didResume {
                    return
                }
                if isCancelRequested {
                    resume(with: .failure(CancellationError()))
                    return
                }
            }
            resume(with: .failure(error))
            return
        }

        emitProgress()

        guard receivedBytes == expectedBytes else {
            resume(with: .failure(ManifestInstallerError.invalidResponse))
            return
        }

        resume(with: .success(()))
    }

    /// Emits accumulated progress in larger chunks to avoid high-frequency UI churn.
    private func emitProgress() {
        guard pendingProgressBytes > 0 else { return }
        let bytesWritten = pendingProgressBytes
        pendingProgressBytes = 0
        progressHandler(bytesWritten, receivedBytes)
    }

    /// Resumes the continuation exactly once across delegate callbacks.
    private func resume(with result: Result<Void, Error>) {
        lock.lock()
        guard !didResume, let continuation else {
            lock.unlock()
            return
        }
        didResume = true
        self.continuation = nil
        lock.unlock()

        continuation.resume(with: result)
    }
}

/// Async limiter used to keep total range/file requests below the CDN-friendly cap.
private actor DownloadRequestLimiter {
    private let maxConcurrentRequests: Int
    private var activeRequests = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrentRequests: Int) {
        self.maxConcurrentRequests = maxConcurrentRequests
    }

    func acquire() async {
        if activeRequests < maxConcurrentRequests {
            activeRequests += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            activeRequests = max(activeRequests - 1, 0)
        }
    }
}

/// Actor that aggregates per-file progress into manifest-wide progress events.
actor ManifestDownloadProgressTracker {
    private let totalBytes: Int64
    private var totalReceivedBytes: Int64 = 0
    private var fileBytes: [String: Int64] = [:]
    private var activeSegmentBytes: [String: [Int: Int64]] = [:]

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

    /// Emits a zero-byte progress snapshot so the UI can show file-level detail immediately.
    func beginFile(
        _ path: String,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        guard fileBytes[path] == nil else { return }
        fileBytes[path] = 0
        await onEvent(.downloadingManifest(
            path: path,
            overallReceived: totalReceivedBytes,
            overallTotal: totalBytes,
            fileReceived: 0,
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

    /// Updates visible progress for an in-flight byte-range segment without double-counting retries.
    func updateSegmentProgress(
        index: Int,
        bytes: Int64,
        segmentTotal: Int64,
        for path: String,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        let previousFileBytes = fileBytes[path] ?? 0
        let previousActiveBytes = activeBytes(for: path)
        var segments = activeSegmentBytes[path, default: [:]]
        segments[index] = min(max(bytes, 0), segmentTotal)
        activeSegmentBytes[path] = segments

        let committedBytes = max(previousFileBytes - previousActiveBytes, 0)
        let nextFileBytes = min(committedBytes + activeBytes(for: path), fileTotal)
        guard nextFileBytes != previousFileBytes else { return }

        fileBytes[path] = nextFileBytes
        totalReceivedBytes = min(max(totalReceivedBytes + nextFileBytes - previousFileBytes, 0), totalBytes)
        await onEvent(.downloadingManifest(
            path: path,
            overallReceived: totalReceivedBytes,
            overallTotal: totalBytes,
            fileReceived: nextFileBytes,
            fileTotal: fileTotal
        ))
    }

    /// Commits a completed byte-range segment and removes its transient progress state.
    func completeSegment(
        index: Int,
        bytes: Int64,
        for path: String,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        let previousFileBytes = fileBytes[path] ?? 0
        let previousActiveBytes = activeBytes(for: path)
        activeSegmentBytes[path]?[index] = nil
        if activeSegmentBytes[path]?.isEmpty == true {
            activeSegmentBytes[path] = nil
        }

        let committedBytes = max(previousFileBytes - previousActiveBytes, 0)
        let nextFileBytes = min(committedBytes + bytes + activeBytes(for: path), fileTotal)
        fileBytes[path] = nextFileBytes
        totalReceivedBytes = min(max(totalReceivedBytes + nextFileBytes - previousFileBytes, 0), totalBytes)
        await onEvent(.downloadingManifest(
            path: path,
            overallReceived: totalReceivedBytes,
            overallTotal: totalBytes,
            fileReceived: nextFileBytes,
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

    private func activeBytes(for path: String) -> Int64 {
        activeSegmentBytes[path]?.values.reduce(Int64(0), +) ?? 0
    }
}
