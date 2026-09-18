// AbyssEnemyHPTests.swift
//
// A floor scored by how long it takes to clear, Phase 6 of docs/redesign.md:
// the HP each fight holds, and what it does to the plan score.

import XCTest
@testable import NSLauncherApp

final class AbyssEnemyHPTests: XCTestCase {
    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func context(floor: Int, half: Int?) throws -> (AbyssFloorContext, AbyssParseDiagnostics) {
        var diagnostics = AbyssParseDiagnostics()
        let context = try XCTUnwrap(AbyssFloorContext.build(
            cycle: try XCTUnwrap(library.latestCycle), floor: floor, half: half,
            ownElementResistance: try XCTUnwrap(library.tuning).enemyOwnElementResistance,
            enemyHP: library.enemyHP, diagnostics: &diagnostics))
        return (context, diagnostics)
    }

    // MARK: - The data

    /// The table is the wiki's, and one row of it pinned against the game: HP
    /// type 2 at level 95 is the game's GROW_CURVE_HP_2 there (3,344.2771, from
    /// gi.yatta.moe) × 13.584.
    func testTheHPTableReadsTheWikisValues() throws {
        let table = try XCTUnwrap(library.enemyHP)
        XCTAssertEqual(table.hp(ratio: 1, type: "2", level: 95) ?? 0, 3344.2771 * 13.584, accuracy: 0.01)
        XCTAssertNil(table.hp(ratio: 1, type: "2", level: 0))
        XCTAssertNil(table.hp(ratio: 1, type: "no-such-type", level: 95))
    }

    /// The variant is read, not assumed: the Battle-Hardened Domovoy Sculptor
    /// on floor 12 (2026-09-16 rotation; the previous rotation's Battle-Hardened
    /// Chimeric Volkodlak Archer is gone) is really a Churin (Local Legend) at
    /// 25.168, its base page's own Normal-variant ratio nowhere near it.
    func testABattleHardenedMonsterScalesByItsOwnVariant() throws {
        let floor = try XCTUnwrap(library.latestCycle?.floors.first { $0.floor == 12 })
        let boss = try XCTUnwrap(floor.chambers.flatMap { $0.waves.flatMap(\.monsters) }
            .first { $0.name == "Battle-Hardened Domovoy Sculptor" })
        XCTAssertEqual(boss.hp?.page, "Churin (Local Legend)")
        XCTAssertEqual(boss.hp?.variant, "Battle-Hardened")
        XCTAssertEqual(boss.hp?.ratio ?? 0, 25.168, accuracy: 1e-9)
        XCTAssertEqual(floor.enemyHPMultiplier, 2.5)
    }

    // MARK: - A fight's HP

    /// Floor 12's halves do not hold the same HP — the assumption the harmonic
    /// mean made — and not by a little. (2026-09-16 rotation; the numbers
    /// changed with the rotation, the property they demonstrate did not.)
    func testFloor12sHalvesHoldDifferentHP() throws {
        let first = try XCTUnwrap(context(floor: 12, half: 1).0.enemyHP)
        let second = try XCTUnwrap(context(floor: 12, half: 2).0.enemyHP)
        XCTAssertEqual(first, 9_466_072.53336, accuracy: 10)
        XCTAssertEqual(second, 11_387_324.1793236, accuracy: 10)
        XCTAssertEqual(try XCTUnwrap(context(floor: 12, half: nil).0.enemyHP), first + second, accuracy: 1e-3)
    }

    /// A floor whose counts the wiki marks uncertain has no HP, and says so,
    /// rather than a guessed one. (2026-09-16 rotation: floor 11's own count
    /// is no longer uncertain — it's a floor that changed this rotation and
    /// fully resolved. Floors 9 and 10 didn't change this rotation at all, so
    /// the current cycle's wiki page carries no Domain Enemies section for
    /// them, which reads exactly like an uncertain count does: no HP, and
    /// `fightHPUnknown` says why.)
    func testAFightWithoutHPSaysSo() throws {
        let (floor9, diagnostics) = try context(floor: 9, half: 1)
        XCTAssertNil(floor9.enemyHP)
        XCTAssertTrue(diagnostics.fightHPUnknown.contains("floor 9 half 1"))
    }

    /// Time is spent where the HP is, so the level the DEF multiplier uses is
    /// weighted by it. (2026-09-16 rotation; the previous rotation's floor 12
    /// half 1 example moved to half 2 here — this rotation's half 1 landed on
    /// the same weighted and unweighted level by coincidence.)
    func testTheLevelIsWeightedByHP() throws {
        let weighted = try context(floor: 12, half: 2).0.monsterLevel
        var diagnostics = AbyssParseDiagnostics()
        let unweighted = try XCTUnwrap(AbyssFloorContext.build(
            cycle: try XCTUnwrap(library.latestCycle), floor: 12, half: 2,
            ownElementResistance: try XCTUnwrap(library.tuning).enemyOwnElementResistance,
            diagnostics: &diagnostics)).monsterLevel
        XCTAssertEqual(unweighted, 98, "without HP the three chambers weigh the same")
        XCTAssertEqual(weighted, 97)
    }

    // MARK: - The plan score

    /// With HP, a plan's score is the damage per second that clears both halves
    /// in the teams' combined time — so the best plan is the fastest one, and a
    /// half holding more HP weighs more.
    func testThePlanScoreIsTheFastestClear() {
        let score = AbyssFloorPlan.combine(100, 50, firstHP: 3000, secondHP: 1000)
        XCTAssertEqual(score, 4000 / (30.0 + 20), accuracy: 1e-9)
        // The same two teams the other way round: the strong team on the small half is slower.
        XCTAssertGreaterThan(score, AbyssFloorPlan.combine(50, 100, firstHP: 3000, secondHP: 1000))
        // Without HP it is the harmonic mean, as before.
        XCTAssertEqual(AbyssFloorPlan.combine(100, 50), AbyssFloorPlan.combine(100, 50, firstHP: 1, secondHP: 1),
                       accuracy: 1e-9)
    }

    func testAPlansClearTimeIsItsHPOverItsScores() throws {
        let team = { (score: Double) in
            AbyssTeamResult(memberIDs: ["a"], onFieldID: "a", score: score, perCharacterDamage: [:],
                            assignment: [:], notes: [], baseScore: score)
        }
        let plan = AbyssFloorPlan(firstHalf: team(100), secondHalf: team(50), score: 0,
                                  firstHalfHP: 3000, secondHalfHP: 1000)
        let clear = try XCTUnwrap(plan.clearSeconds)
        XCTAssertEqual(clear.first, 30, accuracy: 1e-9)
        XCTAssertEqual(clear.second, 20, accuracy: 1e-9)
        XCTAssertNil(AbyssFloorPlan(firstHalf: team(100), secondHalf: team(50), score: 0).clearSeconds)
    }

    /// The pairing bound still holds with weights: the plans it returns are the
    /// best under the weighted score, checked against every pair.
    func testPairingWithHPMatchesBruteForce() {
        func team(_ id: String, _ score: Double) -> AbyssTeamResult {
            AbyssTeamResult(memberIDs: [id, id + "2"], onFieldID: id, score: score, perCharacterDamage: [:],
                            assignment: [:], notes: [], baseScore: score)
        }
        let first = [team("a", 120), team("b", 90), team("c", 60)]
        let second = [team("a", 200), team("d", 80), team("e", 40)]
        let plans = AbyssOptimizer.pair(first: first, second: second, count: 1, firstHP: 5000, secondHP: 1000)
        var best = -Double.infinity
        for one in first {
            for two in second where Set(one.memberIDs).isDisjoint(with: two.memberIDs) {
                best = max(best, AbyssFloorPlan.combine(one.score, two.score, firstHP: 5000, secondHP: 1000))
            }
        }
        XCTAssertEqual(plans.first?.score ?? 0, best, accuracy: 1e-9)
        XCTAssertEqual(plans.first?.firstHalfHP, 5000)
    }
}
