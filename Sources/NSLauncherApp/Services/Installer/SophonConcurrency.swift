// SophonConcurrency.swift
//
// The four coordination primitives the Sophon download engine runs on: a request limiter, a
// per-asset writer, a work queue, and a progress tracker.
//
// They were private types inside the installer, which meant the parts most likely to hold a
// concurrency bug — a limiter that leaks slots, a queue that hands the same asset out twice, a
// tracker that stops emitting — had no way to be exercised on their own. None of them knows
// anything about Sophon beyond the asset type, so none of them needed to live there.
//
// The tracker takes `now` rather than reading the clock, for the same reason `TransferMetrics`
// does: its emit throttle is a time-based decision, and a test cannot wait out real seconds.

import Foundation

actor SophonDownloadRequestLimiter {
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

actor SophonAssetWriter {
    private var handle: FileHandle?

    init(url: URL) throws {
        self.handle = try FileHandle(forWritingTo: url)
    }

    func write(_ data: Data, at offset: Int64) throws {
        guard let handle else { return }
        try handle.seek(toOffset: UInt64(offset))
        try handle.write(contentsOf: data)
    }

    func close() throws {
        guard let handle else { return }
        try handle.close()
        self.handle = nil
    }
}

actor SophonAssetQueue {
    private let assets: [SophonAsset]
    private var index = 0

    init(assets: [SophonAsset]) {
        self.assets = assets.sorted { lhs, rhs in
            lhs.compressedBytes == rhs.compressedBytes
                ? lhs.path < rhs.path
                : lhs.compressedBytes > rhs.compressedBytes
        }
    }

    func next() -> SophonAsset? {
        guard index < assets.count else { return nil }
        let asset = assets[index]
        index += 1
        return asset
    }
}

actor SophonProgressTracker {
    private var receivedBytes: Int64 = 0
    private var emittedBytes: Int64 = 0
    private let totalBytes: Int64
    private var fileBytes: [String: Int64] = [:]
    private var lastPath: String?
    private var lastFileTotal: Int64 = 0
    private var lastEmitDate = Date.distantPast

    /// An event is emitted once either threshold is crossed. Every event crosses an actor boundary
    /// and re-renders the progress panel, so a chunk-by-chunk stream would cost more than the
    /// download; these bound the rate without letting the display go stale.
    static let emitByteThreshold: Int64 = 4 * 1024 * 1024
    static let emitTimeThreshold: TimeInterval = 0.25

    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }

    func registerExistingBytes(
        _ bytes: Int64,
        path: String,
        fileTotal: Int64,
        now: Date = Date(),
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        receivedBytes += bytes
        fileBytes[path] = fileTotal
        lastPath = path
        lastFileTotal = fileTotal
        emittedBytes = receivedBytes
        lastEmitDate = now
        await onEvent(.downloadingSophonAsset(
            path: path,
            overallReceived: receivedBytes,
            overallTotal: totalBytes,
            fileReceived: fileTotal,
            fileTotal: fileTotal
        ))
    }

    func advance(
        bytes: Int64,
        path: String,
        fileTotal: Int64,
        now: Date = Date(),
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        receivedBytes += bytes
        fileBytes[path, default: 0] = min((fileBytes[path] ?? 0) + bytes, fileTotal)
        lastPath = path
        lastFileTotal = fileTotal
        guard receivedBytes - emittedBytes >= Self.emitByteThreshold
            || now.timeIntervalSince(lastEmitDate) >= Self.emitTimeThreshold
            || receivedBytes >= totalBytes else {
            return
        }

        emittedBytes = receivedBytes
        lastEmitDate = now
        await onEvent(.downloadingSophonAsset(
            path: path,
            overallReceived: receivedBytes,
            overallTotal: totalBytes,
            fileReceived: fileBytes[path] ?? 0,
            fileTotal: fileTotal
        ))
    }

    func flush(now: Date = Date(), onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void) async {
        guard emittedBytes != receivedBytes, let lastPath else { return }
        emittedBytes = receivedBytes
        lastEmitDate = now
        await onEvent(.downloadingSophonAsset(
            path: lastPath,
            overallReceived: receivedBytes,
            overallTotal: totalBytes,
            fileReceived: fileBytes[lastPath] ?? 0,
            fileTotal: lastFileTotal
        ))
    }
}
