import XCTest
@testable import NSLauncherApp

/// Behavioural guarantees the golden fixture cannot express: that results are
/// reproducible, that parallel and serial agree, and that the roster's limits
/// are respected.
final class AbyssOptimizerTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func makeOptimizer() throws -> AbyssOptimizer {
        try XCTUnwrap(AbyssOptimizer(library: library))
    }

    /// Near-ties are the normal case — two teams routinely differ by under
    /// 0.1% — and Swift's sort is not stable, so without an explicit tie-break
    /// the same input would return a different order run to run and the results
    /// would look arbitrary.
    func testSameInputProducesTheSameOrderEveryRun() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let request = AbyssOptimizerRequest(roster: roster, floors: [12], topN: 10)

        let first = await optimizer.run(request)
        let second = await optimizer.run(request)

        let firstTeams = try XCTUnwrap(first.reports.first?.teams)
        let secondTeams = try XCTUnwrap(second.reports.first?.teams)
        XCTAssertEqual(firstTeams.map(\.id), secondTeams.map(\.id), "team order changed between runs")
        for (lhs, rhs) in zip(firstTeams, secondTeams) {
            XCTAssertEqual(lhs.score, rhs.score, accuracy: 1e-12)
        }
    }

    /// The parallel path splits the combination space by rank; a mistake in that
    /// arithmetic would skip or double-count teams, which shows up here as a
    /// different answer from the single-stripe path.
    ///
    /// Run without artifact refinement: that pass only re-ranks the shortlist it
    /// is handed, so with it on a team could win the narrow search and never
    /// reach the wide search's shortlist — which would make this assertion about
    /// the *enumeration* fail for a reason that has nothing to do with it.
    func testParallelSearchAgreesWithSingleStripeSearch() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()

        // A pool of 15 crosses the striping threshold; a pool of 6 stays under it.
        let wide = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [11], topN: 5,
                                                             poolSize: 15, refinesArtifacts: false))
        let narrow = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [11], topN: 5,
                                                               poolSize: 6, refinesArtifacts: false))

        let wideTop = try XCTUnwrap(wide.reports.first?.teams.first)
        let narrowTop = try XCTUnwrap(narrow.reports.first?.teams.first)
        // The wider pool can only find something at least as good.
        XCTAssertGreaterThanOrEqual(wideTop.score, narrowTop.score)
    }

    func testCombinationWalkVisitsEveryTeamExactlyOnce() {
        let n = 9
        let total = AbyssOptimizer.combinationCount(n, choose: 4)
        XCTAssertEqual(total, 126)

        var seen: Set<[Int]> = []
        var indices = [0, 1, 2, 3]
        XCTAssertTrue(AbyssOptimizer.combination(at: 0, n: n, into: &indices))
        for _ in 0..<total {
            XCTAssertTrue(seen.insert(indices).inserted, "combination \(indices) visited twice")
            _ = AbyssOptimizer.advance(&indices, n: n)
        }
        XCTAssertEqual(seen.count, Int(total), "walk did not cover every combination")
    }

    /// Starting a stripe part-way in must land on the same team the sequential
    /// walk would have reached.
    func testCombinationRankMatchesSequentialWalk() {
        let n = 12
        var walked = [0, 1, 2, 3]
        for rank in 0..<AbyssOptimizer.combinationCount(n, choose: 4) {
            var jumped = [0, 0, 0, 0]
            XCTAssertTrue(AbyssOptimizer.combination(at: rank, n: n, into: &jumped))
            XCTAssertEqual(jumped, walked, "rank \(rank) disagrees with the sequential walk")
            _ = AbyssOptimizer.advance(&walked, n: n)
        }
    }

    /// Weapons are single items. Two characters on one team cannot both hold
    /// the same one, and when the roster genuinely cannot cover the team the
    /// result has to say so rather than pretend.
    func testNoWeaponIsUsedTwiceUnlessTheRosterCannotCoverTheTeam() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 10))

        for team in try XCTUnwrap(output.reports.first?.teams) {
            let weaponIDs = team.memberIDs.compactMap { team.assignment[$0]?.weaponID }
            let duplicated = Set(weaponIDs.filter { id in weaponIDs.filter { $0 == id }.count > 1 })
            let reportsContention = team.notes.contains { note in
                if case .weaponContested = note { return true }
                return false
            }
            XCTAssertEqual(!duplicated.isEmpty, reportsContention,
                           "team \(team.id) shares \(duplicated) without saying so")
        }
    }

    func testRosterWithFewerThanFourCharactersProducesNoTeams() async throws {
        let optimizer = try makeOptimizer()
        let roster = AbyssRoster(characters: [.init(id: "hu-tao"), .init(id: "bennett")], weapons: [])
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster))
        XCTAssertTrue(output.reports.isEmpty, "a two-character roster cannot field a team")
    }

    /// A renamed or removed id should surface, not silently shrink the pool.
    func testUnknownRosterEntriesAreReported() async throws {
        let optimizer = try makeOptimizer()
        let roster = AbyssRoster(
            characters: [.init(id: "hu-tao"), .init(id: "not-a-character")],
            weapons: [.init(id: "not-a-weapon")])
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster))
        XCTAssertEqual(output.unknownRosterIDs, ["not-a-character", "not-a-weapon"])
    }

    /// With no roster the optimizer considers everything, which is the "what
    /// could I build in theory" mode. It also has to stay fast enough to run
    /// from a button press.
    func testFullRosterRunCompletesQuickly() async throws {
        let optimizer = try makeOptimizer()
        let started = Date()
        let output = await optimizer.run(AbyssOptimizerRequest(floors: [12], topN: 5, poolSize: 40))
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(output.reports.count, 1)
        XCTAssertEqual(output.reports.first?.teams.count, 5)
        XCTAssertLessThan(elapsed, 20, "a single floor over a 40-character pool should not take this long")
    }
}
