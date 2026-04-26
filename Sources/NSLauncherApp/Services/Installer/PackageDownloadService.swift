import Foundation

enum PackageDownloadError: LocalizedError {
    case packageSourceMissing
    case remoteURLMissing
    case invalidResponse
    case downloadedPartIntegrityMismatch(fileName: String, expectedBytes: Int64, actualBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .packageSourceMissing:
            return "The selected game does not define a package source."
        case .remoteURLMissing:
            return "The selected package source does not include a remote URL."
        case .invalidResponse:
            return "The package server returned an invalid response."
        case let .downloadedPartIntegrityMismatch(fileName, expectedBytes, actualBytes):
            return "Downloaded part \(fileName) is incomplete or mismatched: expected \(expectedBytes), found \(actualBytes)."
        }
    }
}

enum PackageDownloadInterruption: Error {
    case paused
}

protocol PackageDownloading: Sendable {
    func planInstall(for game: GameDefinition) async throws -> InstallPlan
    func downloadPackage(
        for game: GameDefinition,
        settings: AppSettings,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws -> URL
}

actor PackageDownloadService: PackageDownloading {
    private static let connectionRetryDelayNanoseconds: UInt64 = 3_000_000_000

    private let fileManager: FileManager
    private let session: URLSession
    private let downloadStateStore: DownloadStateStoring

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        downloadStateStore: DownloadStateStoring = DownloadStateStore()
    ) {
        self.fileManager = fileManager
        self.session = session
        self.downloadStateStore = downloadStateStore
    }

    func planInstall(for game: GameDefinition) async throws -> InstallPlan {
        guard let package = game.packageSource else {
            throw PackageDownloadError.packageSourceMissing
        }

        let archiveSize = package.expectedArchiveSize ?? 0
        return InstallPlan(
            version: "package",
            steps: [
                InstallStep(kind: .downloadFile, relativePath: package.archiveFileName, bytes: archiveSize),
                InstallStep(kind: .moveIntoPlace, relativePath: game.installDirectory.path, bytes: archiveSize),
                InstallStep(kind: .verifyChecksum, relativePath: game.executableRelativePath, bytes: 0)
            ],
            estimatedBytesToDownload: archiveSize,
            peakTemporaryBytes: archiveSize
        )
    }

    func downloadPackage(
        for game: GameDefinition,
        settings: AppSettings,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws -> URL {
        guard let package = game.packageSource else {
            throw PackageDownloadError.packageSourceMissing
        }

        try await operationController?.checkpoint()
        let cacheDirectory = URL(fileURLWithPath: settings.downloadCacheDirectory, isDirectory: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        if package.archiveFormat == .multipartZip,
           let partURLs = package.partURLs,
           !partURLs.isEmpty {
            return try await downloadMultipartPackage(
                game: game,
                fileName: package.archiveFileName,
                partURLs: partURLs,
                expectedArchiveSize: package.expectedArchiveSize,
                cacheDirectory: cacheDirectory,
                operationController: operationController,
                onEvent: onEvent
            )
        }

        guard let remoteURL = package.remoteURL else {
            throw PackageDownloadError.remoteURLMissing
        }

        let destination = cacheDirectory.appendingPathComponent(package.archiveFileName)
        let metadata = try await contentMetadataWithRetry(
            for: remoteURL,
            operationController: operationController
        )
        if let persistedState = try? downloadStateStore.load(for: game.id),
           shouldResetPartialDownload(
                persistedState: persistedState,
                remoteURL: remoteURL,
                remoteMetadata: metadata
           ) {
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: destination)
            }
            try? downloadStateStore.clear(for: game.id)
        }
        let totalBytes = package.expectedArchiveSize ?? metadata.contentLength ?? 0
        let initialBytes = normalizedExistingSize(at: destination, expectedBytes: metadata.contentLength)

        if let expected = metadata.contentLength, initialBytes == expected {
            await onEvent(.downloadingPackage(
                path: package.archiveFileName,
                received: totalBytes == 0 ? expected : totalBytes,
                total: totalBytes == 0 ? expected : totalBytes,
                currentPart: nil,
                totalParts: nil,
                currentPartReceived: expected,
                currentPartTotal: expected,
                speedBytesPerSecond: nil
            ))
            try? downloadStateStore.clear(for: game.id)
            return destination
        }

        await emitPackageProgress(
            path: package.archiveFileName,
            received: initialBytes,
            total: totalBytes,
            currentPart: nil,
            totalParts: nil,
            currentPartReceived: initialBytes,
            currentPartTotal: metadata.contentLength,
            speedBytesPerSecond: nil,
            onEvent: onEvent
        )

        try await retryOnConnectionLoss(
            operationController: operationController
        ) {
            try await self.streamDownload(
                game: game,
                archiveFileName: package.archiveFileName,
                archiveFormat: package.archiveFormat,
                remoteURL: remoteURL,
                destination: destination,
                totalExpectedBytes: totalBytes,
                downloadedBytesBaseline: 0,
                currentPart: nil,
                totalParts: nil,
                remoteMetadata: metadata,
                operationController: operationController
            ) { received, total, speed in
                await onEvent(.downloadingPackage(
                    path: package.archiveFileName,
                    received: received,
                    total: totalBytes == 0 ? total : totalBytes,
                    currentPart: nil,
                    totalParts: nil,
                    currentPartReceived: received,
                    currentPartTotal: total > 0 ? total : nil,
                    speedBytesPerSecond: speed
                ))
            }
        }

        try? downloadStateStore.clear(for: game.id)
        let finalBytes = normalizedExistingSize(at: destination, expectedBytes: nil)
        await onEvent(.verifying(path: package.archiveFileName))
        try verifyDownloadedPart(
            fileName: package.archiveFileName,
            actualBytes: finalBytes,
            expectedBytes: metadata.contentLength
        )
        await onEvent(.downloadingPackage(
            path: package.archiveFileName,
            received: finalBytes,
            total: totalBytes == 0 ? finalBytes : totalBytes,
            currentPart: nil,
            totalParts: nil,
            currentPartReceived: finalBytes,
            currentPartTotal: metadata.contentLength,
            speedBytesPerSecond: nil
        ))
        return destination
    }

    private func downloadMultipartPackage(
        game: GameDefinition,
        fileName: String,
        partURLs: [URL],
        expectedArchiveSize: Int64?,
        cacheDirectory: URL,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws -> URL {
        let persistedState = try? downloadStateStore.load(for: game.id)
        let totalParts = partURLs.count
        var completedBytes: Int64 = 0
        var firstPartURL: URL?

        for (index, partURL) in partURLs.enumerated() {
            try await operationController?.checkpoint()

            let currentPart = index + 1
            let destination = cacheDirectory.appendingPathComponent(partURL.lastPathComponent)
            let metadata = try await contentMetadataWithRetry(
                for: partURL,
                operationController: operationController
            )
            if let persistedState,
               persistedState.currentPart == currentPart,
               shouldResetPartialDownload(
                    persistedState: persistedState,
                    remoteURL: partURL,
                    remoteMetadata: metadata
               ) {
                if fileManager.fileExists(atPath: destination.path) {
                    try? fileManager.removeItem(at: destination)
                }
                try? downloadStateStore.clear(for: game.id)
            }
            let localBytes = normalizedExistingSize(at: destination, expectedBytes: metadata.contentLength)

            if firstPartURL == nil {
                firstPartURL = destination
            }

            if let expected = metadata.contentLength, localBytes == expected {
                completedBytes += expected
                await onEvent(.downloadingPackage(
                    path: fileName,
                    received: resolvedTotalBytes(completedBytes, expectedArchiveSize),
                    total: resolvedTotalBytes(expectedArchiveSize ?? 0, expectedArchiveSize),
                    currentPart: currentPart,
                    totalParts: totalParts,
                    currentPartReceived: expected,
                    currentPartTotal: expected,
                    speedBytesPerSecond: nil
                ))
                continue
            }

            let resumedBytes = if persistedState?.currentPart == currentPart {
                max(localBytes, persistedState?.currentPartReceivedBytes ?? 0)
            } else {
                localBytes
            }

            await emitPackageProgress(
                path: partURL.lastPathComponent,
                received: completedBytes + resumedBytes,
                total: resolvedTotalBytes(expectedArchiveSize ?? 0, expectedArchiveSize),
                currentPart: currentPart,
                totalParts: totalParts,
                currentPartReceived: resumedBytes,
                currentPartTotal: metadata.contentLength,
                speedBytesPerSecond: nil,
                onEvent: onEvent
            )

            let completedBytesBeforePart = completedBytes
            try await retryOnConnectionLoss(
                operationController: operationController
            ) {
                try await self.streamDownload(
                    game: game,
                    archiveFileName: fileName,
                    archiveFormat: .multipartZip,
                    remoteURL: partURL,
                    destination: destination,
                    totalExpectedBytes: expectedArchiveSize,
                    downloadedBytesBaseline: completedBytes,
                    currentPart: currentPart,
                    totalParts: totalParts,
                    remoteMetadata: metadata,
                    operationController: operationController
                ) { received, total, speed in
                    let overallTotal = expectedArchiveSize ?? (completedBytesBeforePart + total)
                    await onEvent(.downloadingPackage(
                        path: partURL.lastPathComponent,
                        received: completedBytesBeforePart + received,
                        total: overallTotal,
                        currentPart: currentPart,
                        totalParts: totalParts,
                        currentPartReceived: received,
                        currentPartTotal: total > 0 ? total : nil,
                        speedBytesPerSecond: speed
                    ))
                }
            }

            try? downloadStateStore.clear(for: game.id)
            let finalPartBytes = normalizedExistingSize(at: destination, expectedBytes: metadata.contentLength)
            await onEvent(.verifying(path: partURL.lastPathComponent))
            try verifyDownloadedPart(
                fileName: partURL.lastPathComponent,
                actualBytes: finalPartBytes,
                expectedBytes: metadata.contentLength
            )
            completedBytes += finalPartBytes

            await onEvent(.downloadingPackage(
                path: fileName,
                received: resolvedTotalBytes(completedBytes, expectedArchiveSize),
                total: resolvedTotalBytes(expectedArchiveSize ?? 0, expectedArchiveSize),
                currentPart: currentPart,
                totalParts: totalParts,
                currentPartReceived: finalPartBytes,
                currentPartTotal: metadata.contentLength ?? finalPartBytes,
                speedBytesPerSecond: nil
            ))
        }

        guard let firstPartURL else {
            throw PackageDownloadError.remoteURLMissing
        }
        return firstPartURL
    }

    private func streamDownload(
        game: GameDefinition,
        archiveFileName: String,
        archiveFormat: ArchiveFormat,
        remoteURL: URL,
        destination: URL,
        totalExpectedBytes: Int64?,
        downloadedBytesBaseline: Int64,
        currentPart: Int?,
        totalParts: Int?,
        remoteMetadata: RemoteFileMetadata,
        operationController: OperationController?,
        progress: @escaping @Sendable (Int64, Int64, Int64?) async -> Void
    ) async throws {
        var startOffset = normalizedExistingSize(at: destination, expectedBytes: remoteMetadata.contentLength)
        let effectiveMetadata = remoteMetadata

        if startOffset > 0, !remoteMetadata.supportsByteRanges {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            startOffset = 0
        }

        try prepareDestinationFile(at: destination)

        let delegate = RangeDownloadDelegate(
            destinationURL: destination,
            startOffset: startOffset,
            expectedBytes: effectiveMetadata.contentLength,
            progress: progress,
            checkpoint: { [downloadStateStore] currentPartBytes, expectedPartBytes in
                let state = PersistedDownloadState(
                    gameID: game.id,
                    archiveFileName: archiveFileName,
                    archiveFormat: archiveFormat,
                    totalExpectedBytes: totalExpectedBytes,
                    downloadedBytes: downloadedBytesBaseline + currentPartBytes,
                    currentPart: currentPart,
                    totalParts: totalParts,
                    currentPartURL: remoteURL,
                    currentPartFileName: remoteURL.lastPathComponent,
                    currentPartReceivedBytes: currentPartBytes,
                    currentPartExpectedBytes: expectedPartBytes,
                    supportsByteRanges: effectiveMetadata.supportsByteRanges,
                    etag: effectiveMetadata.etag,
                    lastModified: effectiveMetadata.lastModified,
                    savedAt: Date()
                )
                try? downloadStateStore.save(state)
            }
        )

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 60 * 60 * 8
        let downloadSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        await operationController?.setHandlers(
            pause: {
                delegate.pause()
                downloadSession.invalidateAndCancel()
            },
            resume: nil,
            stop: { [self] in
                delegate.stop()
                downloadSession.invalidateAndCancel()
                try? self.downloadStateStore.clear(for: game.id)
            }
        )

        do {
            try await delegate.start(
                session: downloadSession,
                request: makeRequest(for: remoteURL, startOffset: startOffset)
            )
            await operationController?.setHandlers(pause: nil, resume: nil, stop: nil)
        } catch PackageDownloadInterruption.paused {
            await operationController?.setHandlers(pause: nil, resume: nil, stop: nil)
            throw PackageDownloadInterruption.paused
        } catch {
            await operationController?.setHandlers(pause: nil, resume: nil, stop: nil)
            throw error
        }
    }

    private func emitPackageProgress(
        path: String,
        received: Int64,
        total: Int64,
        currentPart: Int?,
        totalParts: Int?,
        currentPartReceived: Int64?,
        currentPartTotal: Int64?,
        speedBytesPerSecond: Int64?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        await onEvent(.downloadingPackage(
            path: path,
            received: received,
            total: total,
            currentPart: currentPart,
            totalParts: totalParts,
            currentPartReceived: currentPartReceived,
            currentPartTotal: currentPartTotal,
            speedBytesPerSecond: speedBytesPerSecond
        ))
    }

    private func contentMetadata(for remoteURL: URL) async throws -> RemoteFileMetadata {
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<400 ~= http.statusCode else {
            throw PackageDownloadError.invalidResponse
        }

        let contentLength = http.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init)
        let acceptRanges = http.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased()
        return RemoteFileMetadata(
            contentLength: contentLength,
            supportsByteRanges: acceptRanges == "bytes",
            etag: http.value(forHTTPHeaderField: "ETag"),
            lastModified: http.value(forHTTPHeaderField: "Last-Modified")
        )
    }

    private func contentMetadataWithRetry(
        for remoteURL: URL,
        operationController: OperationController?
    ) async throws -> RemoteFileMetadata {
        try await retryOnConnectionLoss(operationController: operationController) {
            try await self.contentMetadata(for: remoteURL)
        }
    }

    private func retryOnConnectionLoss<T>(
        operationController: OperationController?,
        operation: () async throws -> T
    ) async throws -> T {
        while true {
            try await operationController?.checkpoint()

            do {
                return try await operation()
            } catch PackageDownloadInterruption.paused {
                throw PackageDownloadInterruption.paused
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

    private func normalizedExistingSize(at url: URL, expectedBytes: Int64?) -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        let actualSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        if let expectedBytes, actualSize > expectedBytes {
            try? fileManager.removeItem(at: url)
            return 0
        }

        return actualSize
    }

    private func prepareDestinationFile(at url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
    }

    private func makeRequest(for remoteURL: URL, startOffset: Int64) -> URLRequest {
        var request = URLRequest(url: remoteURL)
        if startOffset > 0 {
            request.setValue("bytes=\(startOffset)-", forHTTPHeaderField: "Range")
        }
        return request
    }

    private func verifyDownloadedPart(fileName: String, actualBytes: Int64, expectedBytes: Int64?) throws {
        guard let expectedBytes, expectedBytes > 0 else { return }
        guard actualBytes == expectedBytes else {
            throw PackageDownloadError.downloadedPartIntegrityMismatch(
                fileName: fileName,
                expectedBytes: expectedBytes,
                actualBytes: actualBytes
            )
        }
    }

    private func shouldResetPartialDownload(
        persistedState: PersistedDownloadState,
        remoteURL: URL,
        remoteMetadata: RemoteFileMetadata
    ) -> Bool {
        guard persistedState.currentPartURL == remoteURL else { return false }
        if let savedETag = persistedState.etag, let currentETag = remoteMetadata.etag, savedETag != currentETag {
            return true
        }
        if let savedLastModified = persistedState.lastModified,
           let currentLastModified = remoteMetadata.lastModified,
           savedLastModified != currentLastModified {
            return true
        }
        if persistedState.currentPartExpectedBytes != nil,
           remoteMetadata.contentLength != nil,
           persistedState.currentPartExpectedBytes != remoteMetadata.contentLength {
            return true
        }
        return false
    }

    private func resolvedTotalBytes(_ value: Int64, _ expectedArchiveSize: Int64?) -> Int64 {
        if let expectedArchiveSize, expectedArchiveSize > 0 {
            return expectedArchiveSize
        }
        return value
    }
}

private struct RemoteFileMetadata: Sendable {
    let contentLength: Int64?
    let supportsByteRanges: Bool
    let etag: String?
    let lastModified: String?
}

private final class RangeDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let startOffset: Int64
    private let expectedBytes: Int64?
    private let progressHandler: @Sendable (Int64, Int64, Int64?) async -> Void
    private let checkpointHandler: @Sendable (Int64, Int64?) -> Void

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var task: URLSessionDataTask?
    private var handle: FileHandle?
    private var currentBytes: Int64
    private var didResume = false
    private var isPauseRequested = false
    private var isStopRequested = false
    private var transferStartDate: Date?
    private var lastProgressDate: Date?
    private var lastProgressBytes: Int64?
    private var smoothedSpeedBytesPerSecond: Double?
    private var lastCheckpointDate = Date()
    private var bytesSinceCheckpoint: Int64 = 0

    init(
        destinationURL: URL,
        startOffset: Int64,
        expectedBytes: Int64?,
        progress: @escaping @Sendable (Int64, Int64, Int64?) async -> Void,
        checkpoint: @escaping @Sendable (Int64, Int64?) -> Void
    ) {
        self.destinationURL = destinationURL
        self.startOffset = startOffset
        self.expectedBytes = expectedBytes
        self.currentBytes = startOffset
        self.progressHandler = progress
        self.checkpointHandler = checkpoint
    }

    func start(session: URLSession, request: URLRequest) async throws {
        let handle = try FileHandle(forWritingTo: destinationURL)
        try handle.seekToEnd()
        self.handle = handle

        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            let task = session.dataTask(with: request)
            self.task = task
            lock.unlock()
            task.resume()
        }
    }

    func pause() {
        checkpointHandler(currentBytes, expectedBytes)
        lock.lock()
        isPauseRequested = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    func stop() {
        lock.lock()
        isStopRequested = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try handle?.write(contentsOf: data)
        } catch {
            resume(with: .failure(error))
            return
        }

        let now = Date()
        if transferStartDate == nil {
            transferStartDate = now
        }
        currentBytes += Int64(data.count)
        bytesSinceCheckpoint += Int64(data.count)

        let speedBytesPerSecond: Int64?
        if let lastProgressDate, let lastProgressBytes {
            let deltaTime = now.timeIntervalSince(lastProgressDate)
            let deltaBytes = currentBytes - lastProgressBytes
            if deltaTime > 0 {
                let instantaneousSpeed = Double(max(deltaBytes, 0)) / deltaTime
                let smoothedSpeed = blendedSpeedEstimate(
                    instantaneousSpeed: instantaneousSpeed,
                    now: now
                )
                speedBytesPerSecond = Int64(smoothedSpeed.rounded())
            } else {
                speedBytesPerSecond = nil
            }
        } else {
            speedBytesPerSecond = nil
        }
        lastProgressDate = now
        lastProgressBytes = currentBytes

        if bytesSinceCheckpoint >= 4 * 1024 * 1024 || now.timeIntervalSince(lastCheckpointDate) >= 2 {
            checkpointHandler(currentBytes, expectedBytes)
            bytesSinceCheckpoint = 0
            lastCheckpointDate = now
        }

        Task {
            await progressHandler(currentBytes, expectedBytes ?? currentBytes, speedBytesPerSecond)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
        guard let http = response as? HTTPURLResponse else {
            resume(with: .failure(PackageDownloadError.invalidResponse))
            return .cancel
        }

        if startOffset > 0 {
            guard http.statusCode == 206 else {
                resume(with: .failure(PackageDownloadError.invalidResponse))
                return .cancel
            }
        } else if !(200..<300).contains(http.statusCode) {
            resume(with: .failure(PackageDownloadError.invalidResponse))
            return .cancel
        }

        return .allow
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? handle?.synchronize()
        try? handle?.close()
        handle = nil

        if let error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                if isPauseRequested {
                    checkpointHandler(currentBytes, expectedBytes)
                    resume(with: .failure(PackageDownloadInterruption.paused))
                } else {
                    resume(with: .failure(CancellationError()))
                }
                return
            }
            resume(with: .failure(error))
            return
        }

        checkpointHandler(currentBytes, expectedBytes)
        resume(with: .success(()))
    }

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

    private func blendedSpeedEstimate(instantaneousSpeed: Double, now: Date) -> Double {
        let elapsed = max(now.timeIntervalSince(transferStartDate ?? now), 0.001)
        let transferredBytes = max(currentBytes - startOffset, 0)
        let overallAverageSpeed = Double(transferredBytes) / elapsed

        let deltaTime = max(now.timeIntervalSince(lastProgressDate ?? now), 0.001)
        let smoothingWindow: Double = 8
        let alpha = min(max(deltaTime / smoothingWindow, 0.08), 0.35)

        if let previousSmoothedSpeed = smoothedSpeedBytesPerSecond {
            smoothedSpeedBytesPerSecond = previousSmoothedSpeed + alpha * (instantaneousSpeed - previousSmoothedSpeed)
        } else {
            smoothedSpeedBytesPerSecond = overallAverageSpeed > 0 ? overallAverageSpeed : instantaneousSpeed
        }

        let smoothedSpeed = smoothedSpeedBytesPerSecond ?? instantaneousSpeed

        if elapsed < 6 {
            return overallAverageSpeed > 0 ? overallAverageSpeed : smoothedSpeed
        }

        return smoothedSpeed * 0.75 + overallAverageSpeed * 0.25
    }
}
