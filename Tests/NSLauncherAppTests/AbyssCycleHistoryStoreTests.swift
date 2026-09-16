import XCTest
@testable import NSLauncherApp

/// The local log the results tab reads "last cycle's plan" from: it has to
/// survive a round trip, merge rather than duplicate a re-run of the same
/// cycle, stay capped, and degrade quietly on a bad file — the same
/// "convenience, not a record" contract `AbyssSearchCacheStore` keeps.
final class AbyssCycleHistoryStoreTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("abyss-cycle-history-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func entry(cycle: String, floor: Int = 12, computedAt: Date = Date(),
                       score: Double = 100, seconds: Double? = 30,
                       members: [String] = ["hu-tao", "xingqiu", "yelan", "zhongli"]) -> AbyssCycleHistoryEntry {
        AbyssCycleHistoryEntry(cyclePeriodStart: cycle, computedAt: computedAt, floor: floor,
                               bestScore: score, bestClearTimeSeconds: seconds, teamMemberIDs: members)
    }

    func testMissingFileIsAnEmptyLogNotAnError() {
        let store = AbyssCycleHistoryStore(baseDirectory: directory)
        XCTAssertTrue(store.load().entries.isEmpty)
    }

    func testRoundTripsAFreshEntry() throws {
        let store = AbyssCycleHistoryStore(baseDirectory: directory)
        try store.append(entry(cycle: "2026-01-01"))
        let loaded = store.load()
        XCTAssertEqual(loaded.entries.count, 1)
        XCTAssertEqual(loaded.entries.first?.cyclePeriodStart, "2026-01-01")
        XCTAssertEqual(loaded.entries.first?.teamMemberIDs, ["hu-tao", "xingqiu", "yelan", "zhongli"])
    }

    /// A re-run of the same cycle and floor replaces its own entry rather
    /// than piling up duplicates — this is a log of cycles, not of runs.
    func testReRunningTheSameCycleAndFloorReplacesTheEntryInPlace() throws {
        let store = AbyssCycleHistoryStore(baseDirectory: directory)
        try store.append(entry(cycle: "2026-01-01", score: 100))
        try store.append(entry(cycle: "2026-01-01", score: 120))
        let loaded = store.load()
        XCTAssertEqual(loaded.entries.count, 1)
        XCTAssertEqual(loaded.entries.first?.bestScore, 120)
    }

    /// Different floors in the same cycle are different entries.
    func testTheSameCycleCanHoldMultipleFloors() throws {
        let store = AbyssCycleHistoryStore(baseDirectory: directory)
        try store.append(entry(cycle: "2026-01-01", floor: 11))
        try store.append(entry(cycle: "2026-01-01", floor: 12))
        XCTAssertEqual(store.load().entries.count, 2)
    }

    func testEntriesBeyondTheCapArePrunedOldestFirst() throws {
        let store = AbyssCycleHistoryStore(baseDirectory: directory)
        let base = Date()
        for day in 0..<(AbyssCycleHistoryStore.maxEntries + 3) {
            try store.append(entry(cycle: "cycle-\(day)",
                                   computedAt: base.addingTimeInterval(Double(day) * 86400)))
        }
        let loaded = store.load()
        XCTAssertEqual(loaded.entries.count, AbyssCycleHistoryStore.maxEntries)
        // The newest entries survive; the oldest ("cycle-0", "cycle-1"...) do not.
        XCTAssertFalse(loaded.entries.contains { $0.cyclePeriodStart == "cycle-0" })
        XCTAssertTrue(loaded.entries.contains { $0.cyclePeriodStart == "cycle-\(AbyssCycleHistoryStore.maxEntries + 2)" })
    }

    func testCorruptFileIsAnEmptyLogNotAnError() throws {
        let store = AbyssCycleHistoryStore(baseDirectory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: directory.appendingPathComponent("abyss-cycle-history.json"))
        XCTAssertTrue(store.load().entries.isEmpty)
    }

    func testClearRemovesTheFile() throws {
        let store = AbyssCycleHistoryStore(baseDirectory: directory)
        try store.append(entry(cycle: "2026-01-01"))
        try store.clear()
        XCTAssertTrue(store.load().entries.isEmpty)
        try store.clear() // idempotent
    }

    // MARK: - `mostRecent(forFloor:excludingCycle:)`

    /// The whole point of the lookup: it names a cycle other than the one
    /// currently being planned, so a same-cycle re-run never reads back as
    /// "last cycle".
    func testMostRecentExcludesTheCurrentCycle() {
        let history = AbyssCycleHistory(entries: [
            entry(cycle: "2026-01-01", computedAt: Date().addingTimeInterval(-2 * 86400)),
            entry(cycle: "2026-01-16", computedAt: Date()),
        ])
        XCTAssertEqual(history.mostRecent(forFloor: 12, excludingCycle: "2026-01-16")?.cyclePeriodStart,
                       "2026-01-01")
        // No current cycle to exclude: every logged entry is eligible, so the
        // newest one still wins.
        XCTAssertEqual(history.mostRecent(forFloor: 12, excludingCycle: nil)?.cyclePeriodStart, "2026-01-16")
    }

    func testMostRecentPicksTheLatestOfSeveralPastCycles() {
        let older = entry(cycle: "2025-12-01", computedAt: Date().addingTimeInterval(-30 * 86400))
        let newer = entry(cycle: "2026-01-01", computedAt: Date().addingTimeInterval(-2 * 86400))
        let history = AbyssCycleHistory(entries: [older, newer])
        XCTAssertEqual(history.mostRecent(forFloor: 12, excludingCycle: "2026-01-16")?.cyclePeriodStart,
                       "2026-01-01")
    }

    func testMostRecentIgnoresOtherFloors() {
        let history = AbyssCycleHistory(entries: [entry(cycle: "2026-01-01", floor: 11)])
        XCTAssertNil(history.mostRecent(forFloor: 12, excludingCycle: "2026-01-16"))
    }
}
