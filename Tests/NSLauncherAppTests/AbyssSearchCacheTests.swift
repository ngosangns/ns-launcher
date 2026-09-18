import XCTest
@testable import NSLauncherApp

/// What decides whether a cached search still answers the question being
/// asked, and whether the cache can actually carry a real result there and
/// back.
///
/// Two failure modes this guards against, both silent: a digest that matches
/// when it should not would show the player a suggested lineup for a roster
/// they no longer have, and a `Codable` field the synthesis quietly drops
/// (easy to miss across a dozen nested types — `AbyssTeamResult` alone nests
/// `AbyssGearOption`, which nests `AbyssStats`, which carries a `SIMD8`) would
/// show them a lineup missing whatever that field held.
final class AbyssSearchCacheTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    // MARK: - The key

    private func roster(_ ids: [String]) -> AbyssRoster {
        AbyssRoster(characters: ids.map { .init(id: $0) })
    }

    func testTwoIdenticalRequestsDigestTheSame() {
        let a = AbyssSearchCacheKey(
            request: AbyssOptimizerRequest(roster: roster(["hu-tao", "xingqiu"])),
            cyclePeriodStart: "2026-01-01")
        let b = AbyssSearchCacheKey(
            request: AbyssOptimizerRequest(roster: roster(["hu-tao", "xingqiu"])),
            cyclePeriodStart: "2026-01-01")
        XCTAssertEqual(a.digest, b.digest)
    }

    /// Every field the digest is built from has to move it, or a change in
    /// that field would silently reuse a cache entry that no longer answers
    /// for it.
    func testEveryFieldThatMattersMovesTheDigest() {
        let base = AbyssOptimizerRequest(roster: roster(["hu-tao", "xingqiu"]),
                                         topN: 5, poolSize: 40,
                                         refinesArtifacts: true, splitsHalves: true)
        let baseline = AbyssSearchCacheKey(request: base, cyclePeriodStart: "2026-01-01").digest

        func digest(_ mutate: (inout AbyssOptimizerRequest) -> Void,
                   cyclePeriodStart: String? = "2026-01-01") -> String {
            var request = base
            mutate(&request)
            return AbyssSearchCacheKey(request: request, cyclePeriodStart: cyclePeriodStart).digest
        }

        XCTAssertNotEqual(baseline, digest { $0.roster = self.roster(["hu-tao"]) },
                          "a roster edit reused a stale cache entry")
        XCTAssertNotEqual(baseline, digest { $0.usesFullCharacterPool = true })
        XCTAssertNotEqual(baseline, digest { $0.usesFullWeaponPool = true })
        XCTAssertNotEqual(baseline, digest { $0.usesMeasuredStats = true })
        XCTAssertNotEqual(baseline, digest { $0.floors = [11] })
        XCTAssertNotEqual(baseline, digest { $0.topN = 3 })
        XCTAssertNotEqual(baseline, digest { $0.poolSize = 20 })
        XCTAssertNotEqual(baseline, digest { $0.refinesArtifacts = false })
        XCTAssertNotEqual(baseline, digest { $0.splitsHalves = false })
        XCTAssertNotEqual(baseline, digest { $0.showcase = [AbyssShowcaseBuild(
            characterID: "hu-tao", level: 90, constellation: 0, weaponID: "staff-of-homa",
            weaponLevel: 90, weaponRefinement: 1, setPieces: [:], stats: AbyssMeasuredStats())] })
        XCTAssertNotEqual(baseline, digest({ _ in }, cyclePeriodStart: "2026-01-16"),
                          "a new rotation reused the previous one's cache entry")
        XCTAssertNotEqual(baseline, digest({ _ in }, cyclePeriodStart: nil))
        XCTAssertNotEqual(baseline,
                          AbyssSearchCacheKey(request: base, cyclePeriodStart: "2026-01-01",
                                              dataDigest: "some-other-bytes").digest,
                          "the same rotation over different data reused the old answer — the exact "
                          + "case Phase 0 produced: floor-12 resistances rewritten, periodStart unchanged")
    }

    /// The library's digest is a function of the files it read, and only of
    /// them: the same bundled data hashes the same on every load.
    func testTheLibraryDigestIsStableAndCoversTheData() {
        XCTAssertEqual(library.dataDigest.count, 64, "SHA-256 hex")
        XCTAssertEqual(AbyssDataLibrary(cycleOverrideDirectory: nil).dataDigest, library.dataDigest)
    }

    /// A roster's character order does not change what a search returns —
    /// `AbyssOptimizer` filters the library's own list by owned id and looks
    /// constellations up by id — so two rosters holding the same people in a
    /// different order are the same question and must digest the same.
    func testRosterOrderDoesNotMoveTheDigest() {
        let a = AbyssSearchCacheKey(request: AbyssOptimizerRequest(roster: roster(["hu-tao", "xingqiu"])),
                                    cyclePeriodStart: "2026-01-01").digest
        let b = AbyssSearchCacheKey(request: AbyssOptimizerRequest(roster: roster(["xingqiu", "hu-tao"])),
                                    cyclePeriodStart: "2026-01-01").digest
        XCTAssertEqual(a, b, "a reordered roster caused a needless cache miss")
    }

    // MARK: - The store

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("abyss-search-cache-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func sampleCache(key: String = "abc", computedAt: Date = Date()) -> AbyssSearchCache {
        AbyssSearchCache(key: key, computedAt: computedAt,
                        output: AbyssOptimizerOutput(reports: [], consideredCharacterIDs: ["hu-tao"],
                                                     unknownRosterIDs: []))
    }

    func testMissingFileIsNoCacheNotAnError() {
        let store = AbyssSearchCacheStore(baseDirectory: directory)
        XCTAssertNil(store.load())
    }

    func testRoundTripsAFreshEntry() throws {
        let store = AbyssSearchCacheStore(baseDirectory: directory)
        let cache = sampleCache()
        try store.save(cache)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.key, cache.key)
        XCTAssertEqual(loaded.output.consideredCharacterIDs, cache.output.consideredCharacterIDs)
    }

    /// The whole point of the store: a search from six days ago still answers.
    func testAnEntryUnderAWeekOldIsStillValid() throws {
        let store = AbyssSearchCacheStore(baseDirectory: directory)
        try store.save(sampleCache(computedAt: Date().addingTimeInterval(-6 * 24 * 60 * 60)))
        XCTAssertNotNil(store.load())
    }

    func testAnEntryOverAWeekOldIsGone() throws {
        let store = AbyssSearchCacheStore(baseDirectory: directory)
        try store.save(sampleCache(computedAt: Date().addingTimeInterval(-8 * 24 * 60 * 60)))
        XCTAssertNil(store.load(), "an 8-day-old entry should have expired")
    }

    func testCorruptFileIsNoCacheNotAnError() throws {
        let store = AbyssSearchCacheStore(baseDirectory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: directory.appendingPathComponent("abyss-search-cache.json"))
        XCTAssertNil(store.load(), "a cached search is a convenience — a bad file should degrade, not throw")
    }

    func testSavingOverwritesTheSingleSlot() throws {
        let store = AbyssSearchCacheStore(baseDirectory: directory)
        try store.save(sampleCache(key: "first"))
        try store.save(sampleCache(key: "second"))
        XCTAssertEqual(store.load()?.key, "second",
                       "this is a cache of the current suggested lineup, not a history of past ones")
    }

    func testClearRemovesTheFile() throws {
        let store = AbyssSearchCacheStore(baseDirectory: directory)
        try store.save(sampleCache())
        try store.clear()
        XCTAssertNil(store.load())
        try store.clear() // idempotent
    }

    // MARK: - A real result survives the round trip

    /// Not a fabricated `AbyssOptimizerOutput` but the product of an actual
    /// run, so every nested type — gear, main stats, notes, halves, plans —
    /// is exercised at once. Equality after encode/decode is the strongest
    /// statement available that `Codable` synthesis dropped nothing.
    func testARealSearchResultSurvivesEncodingAndDecoding() async throws {
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(
            roster: roster, floors: [12], topN: 3, poolSize: 15,
            refinesArtifacts: true, splitsHalves: true))
        XCTAssertFalse(output.reports.isEmpty, "the run has to produce something for this test to mean anything")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AbyssOptimizerOutput.self, from: try encoder.encode(output))

        XCTAssertEqual(decoded.reports.count, output.reports.count)
        XCTAssertEqual(decoded.consideredCharacterIDs, output.consideredCharacterIDs)
        XCTAssertEqual(decoded.unknownRosterIDs, output.unknownRosterIDs)

        for (before, after) in zip(output.reports, decoded.reports) {
            XCTAssertEqual(before.floor, after.floor)
            XCTAssertEqual(before.buffs, after.buffs)
            XCTAssertEqual(before.shieldElements, after.shieldElements)
            XCTAssertEqual(before.weakElements, after.weakElements)
            XCTAssertEqual(before.halves?.map(\.half), after.halves?.map(\.half))

            let beforeTeams = before.allTeams
            let afterTeams = after.allTeams
            XCTAssertEqual(beforeTeams.count, afterTeams.count)
            for (beforeTeam, afterTeam) in zip(beforeTeams, afterTeams) {
                XCTAssertEqual(beforeTeam.memberIDs, afterTeam.memberIDs)
                XCTAssertEqual(beforeTeam.onFieldID, afterTeam.onFieldID)
                XCTAssertEqual(beforeTeam.score, afterTeam.score, accuracy: 1e-9)
                XCTAssertEqual(beforeTeam.perCharacterDamage, afterTeam.perCharacterDamage)
                XCTAssertEqual(beforeTeam.notes, afterTeam.notes)
                XCTAssertEqual(beforeTeam.artifactAdvice, afterTeam.artifactAdvice)
                for id in beforeTeam.memberIDs {
                    let beforeGear = beforeTeam.assignment[id]
                    let afterGear = afterTeam.assignment[id]
                    XCTAssertEqual(beforeGear?.stats, afterGear?.stats, "\(id): stat sheet did not round-trip")
                    XCTAssertEqual(beforeGear?.weaponID, afterGear?.weaponID)
                    XCTAssertEqual(beforeGear?.setIDs, afterGear?.setIDs)
                    XCTAssertEqual(beforeGear?.mainStats, afterGear?.mainStats)
                    XCTAssertEqual(beforeGear?.role, afterGear?.role)
                    XCTAssertEqual(beforeGear?.statSource, afterGear?.statSource)
                }
            }
        }
    }
}
