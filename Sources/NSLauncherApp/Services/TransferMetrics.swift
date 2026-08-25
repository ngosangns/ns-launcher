// TransferMetrics.swift
//
// Speed, ETA and the throttles that keep them readable during a multi-gigabyte download.
//
// Every type here takes `now` rather than reading the clock. That is the whole reason they are out
// of `LauncherViewModel`: a rolling average over a 12-second window and a 1.5-second refresh gate
// cannot be tested against a clock they read themselves, and these numbers are shown to a user who
// has no way of telling a wrong ETA from a slow download.
//
// The throttles are deliberately not one shared generic. They gate on different things — elapsed
// time alone versus elapsed time plus an identity change that must bypass the gate — and collapsing
// them would mean a parameter that only one caller ever sets.

import Foundation

/// One transfer sample used for rolling speed and ETA calculations.
struct TransferSample: Equatable {
    let date: Date
    let receivedBytes: Int64
}

/// Rolling speed and ETA over a recent window.
///
/// A window rather than a total average: a download that stalls and recovers should show the
/// current rate, not one smeared across the whole session.
struct TransferRateEstimator {
    /// Samples closer together than this overwrite the previous one instead of being appended, so
    /// a chatty progress callback cannot fill the window with near-identical points.
    static let minimumSampleSpacing: TimeInterval = 0.5
    /// How far back the average reaches.
    static let rollingWindow: TimeInterval = 12
    /// How long the window must span before an ETA is trustworthy enough to show.
    static let warmupDuration: TimeInterval = 5
    /// Byte delta that forces a new sample regardless of spacing, so a fast burst is not averaged
    /// into the point before it.
    static let significantByteDelta: Int64 = 512 * 1024

    private var samples: [TransferSample] = []

    struct Estimate: Equatable {
        var speedBytesPerSecond: Int64?
        var etaSeconds: Double?
        var isWarmupComplete: Bool

        static let none = Estimate(speedBytesPerSecond: nil, etaSeconds: nil, isWarmupComplete: false)
    }

    /// Records progress and returns the current estimate.
    mutating func update(received: Int64, total: Int64, now: Date) -> Estimate {
        if let last = samples.last {
            let deltaTime = now.timeIntervalSince(last.date)
            let deltaBytes = received - last.receivedBytes
            // A negative delta means the transfer restarted; that is a new sample, not a correction.
            if deltaTime >= Self.minimumSampleSpacing || deltaBytes >= Self.significantByteDelta || deltaBytes < 0 {
                samples.append(TransferSample(date: now, receivedBytes: received))
            } else {
                samples[samples.count - 1] = TransferSample(date: now, receivedBytes: received)
            }
        } else {
            samples.append(TransferSample(date: now, receivedBytes: received))
        }

        samples.removeAll { now.timeIntervalSince($0.date) > Self.rollingWindow }

        guard let first = samples.first, let last = samples.last else { return .none }
        let elapsed = last.date.timeIntervalSince(first.date)
        let transferred = last.receivedBytes - first.receivedBytes
        guard elapsed >= 1, transferred > 0 else { return .none }

        let speed = Int64((Double(transferred) / elapsed).rounded())
        let eta: Double? = {
            guard speed > 0, total > received else { return nil }
            return Double(total - received) / Double(speed)
        }()
        return Estimate(speedBytesPerSecond: speed, etaSeconds: eta, isWarmupComplete: elapsed >= Self.warmupDuration)
    }

    mutating func reset() {
        samples = []
    }
}

/// Formats an ETA with coarse rounding so the label does not flicker every second.
enum ETAFormatter {
    /// Rounds to a granularity proportional to the duration: a 3-hour estimate that moves by 5
    /// seconds is noise, while a 30-second one that moves by a minute is wrong.
    static func text(seconds: Double) -> String? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        let rounded: Double
        switch seconds {
        case 0..<60:
            rounded = (seconds / 5).rounded() * 5
        case 60..<600:
            rounded = (seconds / 15).rounded() * 15
        case 600..<3600:
            rounded = (seconds / 30).rounded() * 30
        default:
            rounded = (seconds / 60).rounded() * 60
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = rounded >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter.string(from: rounded)
    }
}

/// Holds the speed and ETA labels steady between refreshes.
///
/// Losing a value is published immediately while gaining one waits for the gate: a stale speed
/// shown after a transfer stops is a lie, whereas a speed that appears half a second late is not.
struct TransferMetricsThrottle {
    static let refreshInterval: TimeInterval = 1.5

    private var lastUpdateAt: Date?
    private var displayedSpeedText: String?
    private var displayedEtaText: String?

    mutating func display(
        speedText: String?,
        etaText: String?,
        now: Date
    ) -> (speedText: String?, etaText: String?) {
        let shouldRefresh = lastUpdateAt.map { now.timeIntervalSince($0) >= Self.refreshInterval } ?? true

        if shouldRefresh || displayedSpeedText == nil || displayedEtaText == nil {
            displayedSpeedText = speedText
            displayedEtaText = etaText
            lastUpdateAt = now
        } else if speedText == nil {
            displayedSpeedText = nil
        }

        if etaText == nil {
            displayedEtaText = nil
        }

        return (displayedSpeedText, displayedEtaText)
    }

    mutating func reset() {
        lastUpdateAt = nil
        displayedSpeedText = nil
        displayedEtaText = nil
    }
}

/// Cached download text fields used to reduce UI refresh churn.
struct DownloadFieldSnapshot: Equatable {
    let path: String
    let partText: String?
    let detailText: String
    let currentPartDetailText: String?
    let totalKBText: String?
    let currentPartKBText: String?
}

/// Holds download text fields steady between refreshes.
///
/// Moving to a different file or part bypasses the gate. Those identify *what* is downloading, so
/// a stale one would label the new file's bytes with the old file's name.
struct DownloadFieldThrottle {
    static let refreshInterval: TimeInterval = 0.8

    private var lastUpdateAt: Date?
    private var displayed: DownloadFieldSnapshot?

    mutating func display(_ latest: DownloadFieldSnapshot, now: Date) -> DownloadFieldSnapshot {
        let shouldRefresh = {
            guard let displayed, let lastUpdateAt else { return true }
            if displayed.path != latest.path || displayed.partText != latest.partText { return true }
            return now.timeIntervalSince(lastUpdateAt) >= Self.refreshInterval
        }()

        if shouldRefresh {
            displayed = latest
            lastUpdateAt = now
        }
        return displayed ?? latest
    }

    mutating func reset() {
        lastUpdateAt = nil
        displayed = nil
    }
}
