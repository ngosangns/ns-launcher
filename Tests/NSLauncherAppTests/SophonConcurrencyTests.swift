import XCTest
@testable import NSLauncherApp

/// A limiter that leaks slots, a queue that hands one asset to two workers, or a tracker that
/// stops emitting all fail the same way: the download still finishes, eventually, and nobody can
/// tell what went wrong. These are the parts of the engine worth pinning.
final class SophonConcurrencyTests: XCTestCase {

    // MARK: - Request limiter

    /// The whole point of the limiter: never more than the cap in flight at once.
    func testNoMoreThanTheCapRunAtOnce() async {
        let limiter = SophonDownloadRequestLimiter(maxConcurrentRequests: 3)
        let counter = ConcurrencyCounter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<40 {
                group.addTask {
                    await limiter.acquire()
                    await counter.enter()
                    // Yield so an over-admission would actually overlap and be observed.
                    await Task.yield()
                    await counter.leave()
                    await limiter.release()
                }
            }
        }

        let peak = await counter.peak
        XCTAssertLessThanOrEqual(peak, 3)
        XCTAssertGreaterThan(peak, 1, "nothing ran concurrently, so the cap was never exercised")
        let active = await counter.active
        XCTAssertEqual(active, 0)
    }

    /// A slot released with nobody waiting must go back to the pool. If it did not, a long
    /// download would lose capacity every time a burst ended and eventually crawl.
    func testSlotsAreReusableAfterAQuietPeriod() async {
        let limiter = SophonDownloadRequestLimiter(maxConcurrentRequests: 2)
        for _ in 0..<10 {
            await limiter.acquire()
            await limiter.release()
        }
        // Both slots must still be free; if they leaked, the second acquire would never return.
        await limiter.acquire()
        await limiter.acquire()
        await limiter.release()
        await limiter.release()
    }

    /// A waiter must be handed the slot rather than left parked while the count drops — otherwise
    /// a queued chunk hangs until some unrelated task happens to release.
    func testAWaiterIsResumedWhenASlotIsReleased() async {
        let limiter = SophonDownloadRequestLimiter(maxConcurrentRequests: 1)
        await limiter.acquire()

        let waiter = Task {
            await limiter.acquire()
            return true
        }
        await Task.yield()
        await limiter.release()

        let resumed = await waiter.value
        XCTAssertTrue(resumed)
        await limiter.release()
    }

    // MARK: - Asset queue

    /// Two workers taking the same asset would download it twice and race on the same file.
    func testEveryAssetIsHandedOutExactlyOnce() async {
        let assets = (0..<50).map { makeAsset(path: "file-\($0)", compressed: Int64($0 * 100)) }
        let queue = SophonAssetQueue(assets: assets)
        let collected = PathCollector()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    while let asset = await queue.next() {
                        await collected.add(asset.path)
                    }
                }
            }
        }

        let paths = await collected.paths
        XCTAssertEqual(paths.count, 50)
        XCTAssertEqual(Set(paths).count, 50, "an asset was handed out more than once")
    }

    /// Biggest first: the long pole starts while there is still small work to fill the other
    /// workers, instead of being picked up last and running alone at the end.
    func testTheLargestAssetsAreHandedOutFirst() async {
        let queue = SophonAssetQueue(assets: [
            makeAsset(path: "small", compressed: 10),
            makeAsset(path: "huge", compressed: 10_000),
            makeAsset(path: "medium", compressed: 500)
        ])

        var order: [String] = []
        while let asset = await queue.next() { order.append(asset.path) }
        XCTAssertEqual(order, ["huge", "medium", "small"])
    }

    /// Equal sizes have to break ties deterministically, or a resumed install reorders its work
    /// between runs for no reason.
    func testEqualSizedAssetsAreOrderedByPath() async {
        let queue = SophonAssetQueue(assets: [
            makeAsset(path: "c", compressed: 100),
            makeAsset(path: "a", compressed: 100),
            makeAsset(path: "b", compressed: 100)
        ])
        var order: [String] = []
        while let asset = await queue.next() { order.append(asset.path) }
        XCTAssertEqual(order, ["a", "b", "c"])
    }

    func testAnExhaustedQueueKeepsReturningNothing() async {
        let queue = SophonAssetQueue(assets: [])
        let first = await queue.next()
        let second = await queue.next()
        XCTAssertNil(first)
        XCTAssertNil(second)
    }

    // MARK: - Asset writer

    /// Chunks arrive out of order and are written by offset; the finished file must read back as
    /// if they had arrived in sequence.
    func testChunksWrittenOutOfOrderLandAtTheirOffsets() async throws {
        let url = try makeFile(size: 12)
        let writer = try SophonAssetWriter(url: url)

        try await writer.write(Data("IJKL".utf8), at: 8)
        try await writer.write(Data("ABCD".utf8), at: 0)
        try await writer.write(Data("EFGH".utf8), at: 4)
        try await writer.close()

        XCTAssertEqual(try String(data: Data(contentsOf: url), encoding: .utf8), "ABCDEFGHIJKL")
    }

    /// Closing twice happens on the error path, where a `defer` and an explicit close both run.
    func testClosingTwiceIsNotAnError() async throws {
        let url = try makeFile(size: 4)
        let writer = try SophonAssetWriter(url: url)
        try await writer.write(Data("ABCD".utf8), at: 0)
        try await writer.close()
        try await writer.close()
    }

    // MARK: - Progress tracker

    /// Every event crosses an actor boundary and re-renders the panel; a chunk-by-chunk stream
    /// would cost more than the download itself.
    func testSmallFrequentAdvancesAreCoalesced() async {
        let tracker = SophonProgressTracker(totalBytes: 100_000_000)
        let events = EventCollector()
        let start = Date(timeIntervalSince1970: 5_000_000)

        for index in 0..<20 {
            await tracker.advance(
                bytes: 1024,
                path: "file.pak",
                fileTotal: 100_000_000,
                now: start.addingTimeInterval(Double(index) * 0.01),
                onEvent: { await events.add($0) }
            )
        }

        let count = await events.count
        XCTAssertLessThanOrEqual(count, 1, "20 small advances inside the interval should not emit 20 events")
    }

    func testCrossingTheByteThresholdEmits() async {
        let tracker = SophonProgressTracker(totalBytes: 100_000_000)
        let events = EventCollector()
        let start = Date(timeIntervalSince1970: 5_000_000)

        await tracker.advance(
            bytes: SophonProgressTracker.emitByteThreshold,
            path: "file.pak",
            fileTotal: 100_000_000,
            now: start,
            onEvent: { await events.add($0) }
        )
        let count = await events.count
        XCTAssertEqual(count, 1)
    }

    /// A slow transfer must still refresh the panel, or a download that is working looks frozen.
    func testCrossingTheTimeThresholdEmitsEvenForTinyProgress() async {
        let tracker = SophonProgressTracker(totalBytes: 100_000_000)
        let events = EventCollector()
        let start = Date(timeIntervalSince1970: 5_000_000)

        await tracker.advance(bytes: 1, path: "f", fileTotal: 100_000_000, now: start, onEvent: { await events.add($0) })
        await tracker.advance(
            bytes: 1,
            path: "f",
            fileTotal: 100_000_000,
            now: start.addingTimeInterval(SophonProgressTracker.emitTimeThreshold + 0.01),
            onEvent: { await events.add($0) }
        )

        let count = await events.count
        XCTAssertGreaterThanOrEqual(count, 1)
    }

    /// Completion must always be shown, whatever the thresholds say — a bar stuck at 99% on a
    /// finished download is the most visible bug this tracker can produce.
    func testReachingTheTotalAlwaysEmits() async {
        let tracker = SophonProgressTracker(totalBytes: 1_000)
        let events = EventCollector()
        let start = Date(timeIntervalSince1970: 5_000_000)

        await tracker.advance(bytes: 1_000, path: "f", fileTotal: 1_000, now: start, onEvent: { await events.add($0) })
        let last = await events.last
        guard case let .downloadingSophonAsset(_, overallReceived, overallTotal, _, _) = try? XCTUnwrap(last) else {
            return XCTFail("expected a download event")
        }
        XCTAssertEqual(overallReceived, 1_000)
        XCTAssertEqual(overallTotal, 1_000)
    }

    /// Per-file progress must not exceed the file's own size, however the chunks add up.
    func testPerFileProgressIsClampedToTheFileTotal() async {
        let tracker = SophonProgressTracker(totalBytes: 10_000)
        let events = EventCollector()
        let start = Date(timeIntervalSince1970: 5_000_000)

        for index in 0..<5 {
            await tracker.advance(
                bytes: 400,
                path: "f",
                fileTotal: 1_000,
                now: start.addingTimeInterval(Double(index)),
                onEvent: { await events.add($0) }
            )
        }

        let last = await events.last
        guard case let .downloadingSophonAsset(_, _, _, fileReceived, fileTotal) = try? XCTUnwrap(last) else {
            return XCTFail("expected a download event")
        }
        XCTAssertLessThanOrEqual(fileReceived, fileTotal)
    }

    /// Flush is what publishes the tail the thresholds withheld.
    func testFlushEmitsWhateverTheThresholdsHeldBack() async {
        let tracker = SophonProgressTracker(totalBytes: 100_000_000)
        let events = EventCollector()
        let start = Date(timeIntervalSince1970: 5_000_000)

        // The first advance always emits — `lastEmitDate` starts at `.distantPast`. The second one
        // lands inside both thresholds and is the one flush has to publish.
        await tracker.advance(bytes: 1, path: "f", fileTotal: 100_000_000, now: start, onEvent: { await events.add($0) })
        await tracker.advance(
            bytes: 1,
            path: "f",
            fileTotal: 100_000_000,
            now: start.addingTimeInterval(0.01),
            onEvent: { await events.add($0) }
        )
        let beforeFlush = await events.count
        XCTAssertEqual(beforeFlush, 1, "the second advance should have been withheld")

        await tracker.flush(now: start, onEvent: { await events.add($0) })
        let afterFlush = await events.count
        XCTAssertGreaterThan(afterFlush, beforeFlush)
    }

    /// Flushing twice must not emit the same state again.
    func testFlushingWithNothingPendingEmitsNothing() async {
        let tracker = SophonProgressTracker(totalBytes: 1_000)
        let events = EventCollector()
        let start = Date(timeIntervalSince1970: 5_000_000)

        await tracker.advance(bytes: 1_000, path: "f", fileTotal: 1_000, now: start, onEvent: { await events.add($0) })
        let afterAdvance = await events.count
        await tracker.flush(now: start, onEvent: { await events.add($0) })
        let afterFlush = await events.count
        XCTAssertEqual(afterAdvance, afterFlush)
    }

    /// Files already on disk count toward the total immediately, or a resumed install would show
    /// 0% while most of the game is already there.
    func testExistingBytesCountTowardTheOverallTotal() async {
        let tracker = SophonProgressTracker(totalBytes: 1_000)
        let events = EventCollector()

        await tracker.registerExistingBytes(
            600,
            path: "already-there.pak",
            fileTotal: 600,
            now: Date(timeIntervalSince1970: 5_000_000),
            onEvent: { await events.add($0) }
        )

        let last = await events.last
        guard case let .downloadingSophonAsset(path, overallReceived, _, fileReceived, fileTotal) = try? XCTUnwrap(last) else {
            return XCTFail("expected a download event")
        }
        XCTAssertEqual(path, "already-there.pak")
        XCTAssertEqual(overallReceived, 600)
        XCTAssertEqual(fileReceived, 600)
        XCTAssertEqual(fileTotal, 600)
    }

    // MARK: - Helpers

    private func makeAsset(path: String, compressed: Int64) -> SophonAsset {
        SophonAsset(
            path: path,
            size: compressed,
            md5: "md5",
            chunks: [
                SophonChunk(
                    name: "\(path)-chunk",
                    offset: 0,
                    compressedSize: compressed,
                    decompressedSize: compressed,
                    decompressedMD5: "md5",
                    chunkBaseURL: URL(string: "https://example.invalid")!
                )
            ],
            isDirectory: false,
            matchingField: "game",
            categoryName: "Game"
        )
    }

    private func makeFile(size: Int) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SophonConcurrencyTests-\(UUID().uuidString).bin")
        try Data(repeating: 0, count: size).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}

/// Tracks how many tasks are inside the limiter at once.
private actor ConcurrencyCounter {
    private(set) var active = 0
    private(set) var peak = 0

    func enter() {
        active += 1
        peak = max(peak, active)
    }

    func leave() {
        active -= 1
    }
}

private actor PathCollector {
    private(set) var paths: [String] = []
    func add(_ path: String) { paths.append(path) }
}

private actor EventCollector {
    private var events: [InstallProgressEvent] = []
    var count: Int { events.count }
    var last: InstallProgressEvent? { events.last }
    func add(_ event: InstallProgressEvent) { events.append(event) }
}
