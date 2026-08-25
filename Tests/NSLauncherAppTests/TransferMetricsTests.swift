import XCTest
@testable import NSLauncherApp

/// Speed and ETA are numbers a user cannot check. A wrong one is indistinguishable from a slow
/// download, so the window arithmetic and the refresh gates are pinned against a fixed clock.
final class TransferRateEstimatorTests: XCTestCase {
    private var estimator = TransferRateEstimator()
    private let start = Date(timeIntervalSince1970: 1_000_000)

    /// One sample cannot establish a rate. Reporting one would show a speed derived from a single
    /// point the instant a download starts.
    func testASingleSampleYieldsNoEstimate() {
        let estimate = estimator.update(received: 1024, total: 10_240, now: start)
        XCTAssertNil(estimate.speedBytesPerSecond)
        XCTAssertNil(estimate.etaSeconds)
        XCTAssertFalse(estimate.isWarmupComplete)
    }

    func testSpeedIsBytesOverTheWindowElapsed() {
        _ = estimator.update(received: 0, total: 10_000_000, now: start)
        let estimate = estimator.update(received: 4_000_000, total: 10_000_000, now: start.addingTimeInterval(4))
        XCTAssertEqual(estimate.speedBytesPerSecond, 1_000_000)
    }

    func testETAIsRemainingBytesOverSpeed() {
        _ = estimator.update(received: 0, total: 10_000_000, now: start)
        let estimate = estimator.update(received: 2_000_000, total: 10_000_000, now: start.addingTimeInterval(2))
        // 8,000,000 bytes left at 1,000,000 B/s.
        XCTAssertEqual(try XCTUnwrap(estimate.etaSeconds), 8, accuracy: 0.001)
    }

    /// Under a second of span, the rate is dominated by sampling jitter.
    func testNoEstimateUntilTheWindowSpansASecond() {
        _ = estimator.update(received: 0, total: 10_000_000, now: start)
        let estimate = estimator.update(received: 500_000, total: 10_000_000, now: start.addingTimeInterval(0.6))
        XCTAssertNil(estimate.speedBytesPerSecond)
    }

    /// The ETA is only trustworthy once the window is wide enough; the view model uses this flag
    /// to show a warming-up state instead of a number that would be wrong by hours.
    func testWarmupCompletesOnlyAfterTheWarmupDuration() {
        _ = estimator.update(received: 0, total: 100_000_000, now: start)
        let early = estimator.update(received: 3_000_000, total: 100_000_000, now: start.addingTimeInterval(3))
        XCTAssertFalse(early.isWarmupComplete)
        XCTAssertNotNil(early.speedBytesPerSecond)

        let late = estimator.update(
            received: 6_000_000,
            total: 100_000_000,
            now: start.addingTimeInterval(TransferRateEstimator.warmupDuration + 0.1)
        )
        XCTAssertTrue(late.isWarmupComplete)
    }

    /// Samples older than the window are dropped, so a stall then a recovery reports the current
    /// rate rather than one smeared across the whole session.
    func testSamplesOlderThanTheWindowAreForgotten() {
        _ = estimator.update(received: 0, total: 1_000_000_000, now: start)
        _ = estimator.update(received: 1_000_000, total: 1_000_000_000, now: start.addingTimeInterval(1))

        // Long after the window: only samples inside it count.
        let afterStall = start.addingTimeInterval(TransferRateEstimator.rollingWindow + 30)
        _ = estimator.update(received: 1_000_000, total: 1_000_000_000, now: afterStall)
        let estimate = estimator.update(
            received: 11_000_000,
            total: 1_000_000_000,
            now: afterStall.addingTimeInterval(2)
        )
        XCTAssertEqual(estimate.speedBytesPerSecond, 5_000_000)
    }

    /// A transfer that restarts reports fewer bytes than before. While the window still holds a
    /// pre-restart sample the span is negative, and the estimator reports nothing rather than a
    /// negative speed — then recovers once that sample ages out.
    func testARestartReportsNoSpeedUntilTheStaleSampleAgesOut() {
        _ = estimator.update(received: 5_000_000, total: 10_000_000, now: start)
        _ = estimator.update(received: 0, total: 10_000_000, now: start.addingTimeInterval(0.1))
        let duringRestart = estimator.update(received: 2_000_000, total: 10_000_000, now: start.addingTimeInterval(2))
        XCTAssertNil(duringRestart.speedBytesPerSecond)

        let afterWindow = start.addingTimeInterval(TransferRateEstimator.rollingWindow + 1)
        _ = estimator.update(received: 4_000_000, total: 10_000_000, now: afterWindow)
        let recovered = estimator.update(received: 6_000_000, total: 10_000_000, now: afterWindow.addingTimeInterval(2))
        XCTAssertEqual(recovered.speedBytesPerSecond, 1_000_000)
    }

    /// A finished transfer has no ETA — `total - received` is zero and dividing would show "0
    /// seconds remaining" forever on a completed download.
    func testACompletedTransferHasNoETA() {
        _ = estimator.update(received: 0, total: 1_000_000, now: start)
        let estimate = estimator.update(received: 1_000_000, total: 1_000_000, now: start.addingTimeInterval(2))
        XCTAssertNotNil(estimate.speedBytesPerSecond)
        XCTAssertNil(estimate.etaSeconds)
    }

    /// No progress across the window means no speed, rather than a zero that would divide into an
    /// infinite ETA.
    func testAStalledTransferReportsNoSpeed() {
        _ = estimator.update(received: 1_000_000, total: 10_000_000, now: start)
        let estimate = estimator.update(received: 1_000_000, total: 10_000_000, now: start.addingTimeInterval(5))
        XCTAssertNil(estimate.speedBytesPerSecond)
        XCTAssertNil(estimate.etaSeconds)
    }

    func testResetClearsTheWindow() {
        _ = estimator.update(received: 0, total: 10_000_000, now: start)
        _ = estimator.update(received: 5_000_000, total: 10_000_000, now: start.addingTimeInterval(5))
        estimator.reset()
        XCTAssertNil(estimator.update(received: 0, total: 10_000_000, now: start.addingTimeInterval(6)).speedBytesPerSecond)
    }
}

final class ETAFormatterTests: XCTestCase {
    /// Coarse rounding is the point: a label that changes every second is unreadable.
    func testRoundingGetsCoarserAsTheEstimateGrows() {
        // Same granularity in, same text out — proof the value was snapped, not formatted raw.
        XCTAssertEqual(ETAFormatter.text(seconds: 31), ETAFormatter.text(seconds: 32))
        XCTAssertEqual(ETAFormatter.text(seconds: 300), ETAFormatter.text(seconds: 305))
        XCTAssertEqual(ETAFormatter.text(seconds: 1_800), ETAFormatter.text(seconds: 1_810))
        XCTAssertEqual(ETAFormatter.text(seconds: 7_200), ETAFormatter.text(seconds: 7_215))
    }

    /// Rounding must not erase a real difference.
    func testDistinctDurationsStillReadDifferently() {
        XCTAssertNotEqual(ETAFormatter.text(seconds: 30), ETAFormatter.text(seconds: 90))
        XCTAssertNotEqual(ETAFormatter.text(seconds: 600), ETAFormatter.text(seconds: 3_600))
    }

    /// A non-positive or non-finite estimate has no honest text; the label is hidden instead.
    func testNonsensicalDurationsProduceNoText() {
        XCTAssertNil(ETAFormatter.text(seconds: 0))
        XCTAssertNil(ETAFormatter.text(seconds: -5))
        XCTAssertNil(ETAFormatter.text(seconds: .infinity))
        XCTAssertNil(ETAFormatter.text(seconds: .nan))
    }
}

final class TransferMetricsThrottleTests: XCTestCase {
    private var throttle = TransferMetricsThrottle()
    private let start = Date(timeIntervalSince1970: 2_000_000)

    func testTheFirstValuesAreShownImmediately() {
        let shown = throttle.display(speedText: "1 MB/s", etaText: "2 minutes", now: start)
        XCTAssertEqual(shown.speedText, "1 MB/s")
        XCTAssertEqual(shown.etaText, "2 minutes")
    }

    /// Between refreshes the label holds steady, which is what stops it flickering.
    func testUpdatesInsideTheIntervalAreHeld() {
        _ = throttle.display(speedText: "1 MB/s", etaText: "2 minutes", now: start)
        let shown = throttle.display(speedText: "9 MB/s", etaText: "1 minute", now: start.addingTimeInterval(0.5))
        XCTAssertEqual(shown.speedText, "1 MB/s")
        XCTAssertEqual(shown.etaText, "2 minutes")
    }

    func testUpdatesAfterTheIntervalGetThrough() {
        _ = throttle.display(speedText: "1 MB/s", etaText: "2 minutes", now: start)
        let shown = throttle.display(
            speedText: "9 MB/s",
            etaText: "1 minute",
            now: start.addingTimeInterval(TransferMetricsThrottle.refreshInterval)
        )
        XCTAssertEqual(shown.speedText, "9 MB/s")
    }

    /// Losing a value must not wait for the gate: a speed shown after the transfer stopped is a
    /// lie, while a speed appearing half a second late is merely late.
    func testLosingAValueClearsItImmediately() {
        _ = throttle.display(speedText: "1 MB/s", etaText: "2 minutes", now: start)
        let shown = throttle.display(speedText: nil, etaText: nil, now: start.addingTimeInterval(0.1))
        XCTAssertNil(shown.speedText)
        XCTAssertNil(shown.etaText)
    }

    func testResetForgetsTheHeldValues() {
        _ = throttle.display(speedText: "1 MB/s", etaText: "2 minutes", now: start)
        throttle.reset()
        let shown = throttle.display(speedText: "9 MB/s", etaText: "1 minute", now: start.addingTimeInterval(0.1))
        XCTAssertEqual(shown.speedText, "9 MB/s")
    }
}

final class DownloadFieldThrottleTests: XCTestCase {
    private var throttle = DownloadFieldThrottle()
    private let start = Date(timeIntervalSince1970: 3_000_000)

    private func snapshot(path: String, part: String? = nil, detail: String = "detail") -> DownloadFieldSnapshot {
        DownloadFieldSnapshot(
            path: path,
            partText: part,
            detailText: detail,
            currentPartDetailText: nil,
            totalKBText: nil,
            currentPartKBText: nil
        )
    }

    func testTheFirstSnapshotIsShownImmediately() {
        let shown = throttle.display(snapshot(path: "a.pak"), now: start)
        XCTAssertEqual(shown.path, "a.pak")
    }

    func testDetailChangesWithinTheIntervalAreHeld() {
        _ = throttle.display(snapshot(path: "a.pak", detail: "1 MB of 9 MB"), now: start)
        let shown = throttle.display(snapshot(path: "a.pak", detail: "2 MB of 9 MB"), now: start.addingTimeInterval(0.2))
        XCTAssertEqual(shown.detailText, "1 MB of 9 MB")
    }

    /// A new file bypasses the gate. Holding the old path would label the new file's bytes with
    /// the previous file's name — a wrong statement, not a stale one.
    func testANewPathBypassesTheInterval() {
        _ = throttle.display(snapshot(path: "a.pak"), now: start)
        let shown = throttle.display(snapshot(path: "b.pak"), now: start.addingTimeInterval(0.05))
        XCTAssertEqual(shown.path, "b.pak")
    }

    func testANewPartBypassesTheInterval() {
        _ = throttle.display(snapshot(path: "a.pak", part: "1 of 3"), now: start)
        let shown = throttle.display(snapshot(path: "a.pak", part: "2 of 3"), now: start.addingTimeInterval(0.05))
        XCTAssertEqual(shown.partText, "2 of 3")
    }

    func testUpdatesAfterTheIntervalGetThrough() {
        _ = throttle.display(snapshot(path: "a.pak", detail: "1 MB"), now: start)
        let shown = throttle.display(
            snapshot(path: "a.pak", detail: "5 MB"),
            now: start.addingTimeInterval(DownloadFieldThrottle.refreshInterval + 0.01)
        )
        XCTAssertEqual(shown.detailText, "5 MB")
    }

    func testResetForgetsTheHeldSnapshot() {
        _ = throttle.display(snapshot(path: "a.pak", detail: "1 MB"), now: start)
        throttle.reset()
        let shown = throttle.display(snapshot(path: "a.pak", detail: "5 MB"), now: start.addingTimeInterval(0.05))
        XCTAssertEqual(shown.detailText, "5 MB")
    }
}
