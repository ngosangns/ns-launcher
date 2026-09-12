import XCTest
@testable import NSLauncherApp

/// Planning a floor as the two fights it actually is.
///
/// Every Abyss chamber is cleared twice, by two teams that cannot share a
/// character, and this rotation's floor 12 does not even give the two halves the
/// same Ley Line Disorder: the first half pays +200% for Superconduct and the
/// second +75% for Pyro normal attacks. Read as one sentence — which is how the
/// model read it — every team collected both, so a Cryo/Electro team was scored
/// as though it also had the Pyro bonus and a Pyro team as though it had +200%
/// Superconduct. Neither team exists.
final class AbyssFloorHalvesTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func makeOptimizer() throws -> AbyssOptimizer {
        try XCTUnwrap(AbyssOptimizer(library: library))
    }

    private func cycle() throws -> AbyssCycle {
        try XCTUnwrap(library.latestCycle)
    }

    private func context(floor: Int, half: Int?) throws -> AbyssFloorContext {
        var diagnostics = AbyssParseDiagnostics()
        return try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle(), floor: floor, half: half,
            ownElementResistance: try XCTUnwrap(library.tuning).enemyOwnElementResistance,
            diagnostics: &diagnostics))
    }

    // MARK: - Reading the disorder

    func testADisorderThatNamesItsHalvesIsSplitAtTheMarkers() throws {
        let text = "Nửa 1 (nửa trước): Sát thương Superconduct +200%, sát thương Stellar-Conduct "
            + "+75%. Nửa 2 (nửa sau): Sát thương Thường công (Normal Attack) hệ Pyro +75%."
        let halves = AbyssTextParser.leyLineHalves(text)

        XCTAssertEqual(Set(halves.keys), [1, 2])
        let first = try XCTUnwrap(halves[1])
        let second = try XCTUnwrap(halves[2])
        XCTAssertTrue(first.contains("Superconduct"))
        XCTAssertTrue(first.contains("Stellar-Conduct"))
        XCTAssertFalse(first.contains("Thường công"), "the second half's clause leaked into the first")
        XCTAssertTrue(second.contains("Thường công"))
        XCTAssertFalse(second.contains("Superconduct"), "the first half's clause leaked into the second")
    }

    /// A clause written before the first marker is about the floor, so both
    /// halves keep it.
    func testTextBeforeTheFirstMarkerBelongsToBothHalves() throws {
        let halves = AbyssTextParser.leyLineHalves(
            "Toàn đội +30% sát thương Cryo. Nửa 1: +50% Superconduct. Nửa 2: +50% Overloaded.")
        XCTAssertEqual(halves[1]?.contains("Cryo"), true)
        XCTAssertEqual(halves[2]?.contains("Cryo"), true)
        XCTAssertEqual(halves[1]?.contains("Overloaded"), false)
        XCTAssertEqual(halves[2]?.contains("Superconduct"), false)
    }

    /// Floor 11 says its bonus applies "cùng lúc cho cả tầng, không tách theo
    /// nửa" — a mention of halves, not a split. Reading it as one would leave
    /// the second half with nothing.
    func testAPassingMentionOfHalvesIsNotASplit() throws {
        XCTAssertTrue(AbyssTextParser.leyLineHalves(
            "Toàn đội +60% sát thương Cryo và +60% sát thương Pyro "
            + "(áp dụng cùng lúc cho cả tầng, không tách theo nửa).").isEmpty)
        XCTAssertTrue(AbyssTextParser.leyLineHalves(
            "Sát thương Stellar Swirl gây bởi mọi nhân vật +50%.").isEmpty)
        XCTAssertTrue(AbyssTextParser.leyLineHalves(nil).isEmpty)
    }

    // MARK: - The floor as two fights

    func testEachHalfOfFloorTwelveGetsOnlyItsOwnLeyLineBonus() throws {
        let first = try context(floor: 12, half: 1)
        let second = try context(floor: 12, half: 2)

        func reactions(_ context: AbyssFloorContext) -> Set<AbyssReaction> {
            Set(context.buffs.filter { $0.source == .leyLine }.flatMap(\.reactions))
        }
        XCTAssertTrue(reactions(first).contains(.superconduct))
        XCTAssertFalse(reactions(second).contains(.superconduct),
                       "the second half was paid the first half's Superconduct bonus")
        XCTAssertTrue(second.buffs.contains { $0.source == .leyLine && $0.normalAttackOnly },
                      "the second half lost its Pyro normal-attack bonus")
        XCTAssertFalse(first.buffs.contains { $0.source == .leyLine && $0.normalAttackOnly },
                       "the first half was paid the second half's normal-attack bonus")
    }

    /// The cycle-wide Blessing is not a Ley Line clause and belongs to both.
    func testTheBlessingReachesBothHalves() throws {
        for half in [1, 2] {
            let context = try context(floor: 12, half: half)
            XCTAssertTrue(context.buffs.contains { $0.source == .blessing },
                          "half \(half) lost the Blessing of the Abyssal Moon")
        }
    }

    /// The two halves are not the same fight. Floor 12's second half is where
    /// the Iniquitous Baptist and the Cryo Abyss Mage put up elemental shields;
    /// the first half's machines have none.
    func testTheTwoHalvesMeetDifferentEnemies() throws {
        let first = try context(floor: 12, half: 1)
        let second = try context(floor: 12, half: 2)
        XCTAssertNotEqual(first.shieldElements, second.shieldElements)
        XCTAssertTrue(second.shieldElements.contains(.cryo))
        XCTAssertEqual(first.monsterLevel, second.monsterLevel,
                       "monster level is a property of the chamber, not of the half")
        XCTAssertEqual(first.half, 1)
        XCTAssertNil(try context(floor: 12, half: nil).half)
    }

    /// A floor whose chambers are two waves each is two fights; that is how the
    /// data records the halves.
    func testEveryFloorInTheCycleIsFoughtAsTwoHalves() throws {
        for floor in try cycle().floors {
            XCTAssertTrue(AbyssFloorContext.splitsIntoHalves(floor),
                          "floor \(floor.floor) is not recorded as two halves")
        }
    }

    // MARK: - Pairing

    func testAPlanFieldsTwoTeamsThatShareNobody() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                               refinesArtifacts: false))
        let report = try XCTUnwrap(output.reports.first)

        XCTAssertTrue(report.teams.isEmpty,
                      "a floor planned as two halves has no single team for the whole of it")
        XCTAssertEqual(report.plans.count, 5)
        XCTAssertEqual(report.halves.map(\.half), [1, 2])

        for (rank, plan) in report.plans.enumerated() {
            XCTAssertTrue(Set(plan.firstHalf.memberIDs).isDisjoint(with: Set(plan.secondHalf.memberIDs)),
                          "plan \(rank + 1) puts the same character in both halves")
            XCTAssertEqual(plan.score,
                           AbyssFloorPlan.combine(plan.firstHalf.score, plan.secondHalf.score),
                           accuracy: max(plan.score, 1) * 1e-9)
        }

        let scores = report.plans.map(\.score)
        XCTAssertEqual(scores, scores.sorted(by: >), "plans are not ranked best first")
    }

    /// A weapon is one item and both halves are fought in the same run, so the
    /// two teams cannot both hold it. The first version of the pairing checked
    /// characters only, and every one of the five plans it produced put the same
    /// Wolf's Gravestone in both halves.
    func testAPlanDoesNotPutTheSameWeaponInBothHalves() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                               refinesArtifacts: false))
        let plans = try XCTUnwrap(output.reports.first?.plans)
        XCTAssertFalse(plans.isEmpty)

        for (rank, plan) in plans.enumerated() {
            func weapons(_ team: AbyssTeamResult) -> Set<String> {
                Set(team.memberIDs.compactMap { team.assignment[$0]?.weaponID })
            }
            let shared = weapons(plan.firstHalf).intersection(weapons(plan.secondHalf))
            XCTAssertTrue(shared.isEmpty,
                          "plan \(rank + 1) hands \(shared.sorted()) to both halves at once")
        }
    }

    /// Five plans that reshuffle the same two teams would be one answer printed
    /// five times.
    func testEveryPlanOffersADifferentTeamForEachHalf() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                               refinesArtifacts: false))
        let plans = try XCTUnwrap(output.reports.first?.plans)

        XCTAssertEqual(Set(plans.map(\.firstHalf.id)).count, plans.count)
        XCTAssertEqual(Set(plans.map(\.secondHalf.id)).count, plans.count)
    }

    /// The point of pairing rather than ranking each half alone: the best plan
    /// is allowed to be worse in one half than that half could manage on its
    /// own, and it must never be the pair that happens to be illegal.
    func testTheBestPlanBeatsTakingEachHalfsOwnFavourite() throws {
        // Two rankings whose favourites want the same people. Taking each half's
        // own best gives an illegal pair; the answer is the best legal one.
        func team(_ ids: [String], _ score: Double) -> AbyssTeamResult {
            AbyssTeamResult(memberIDs: ids, onFieldID: ids[0], score: score,
                            perCharacterDamage: [:], assignment: [:], notes: [])
        }
        let first = [team(["a", "b", "c", "d"], 100), team(["a", "b", "c", "e"], 90),
                     team(["f", "g", "h", "i"], 50)]
        let second = [team(["a", "b", "c", "d"], 100), team(["d", "f", "g", "h"], 80),
                      team(["e", "f", "g", "h"], 70)]

        let plans = AbyssOptimizer.pair(first: first, second: second, count: 3)
        let best = try XCTUnwrap(plans.first)
        XCTAssertEqual(best.firstHalf.memberIDs, ["a", "b", "c", "e"])
        XCTAssertEqual(best.secondHalf.memberIDs, ["d", "f", "g", "h"])

        // 90 with 80 beats 100 with 70, and both beat anything built on the
        // 50-point team — which is the whole reason the pair is scored together.
        XCTAssertGreaterThan(AbyssFloorPlan.combine(90, 80), AbyssFloorPlan.combine(100, 70))
        XCTAssertGreaterThan(best.score, AbyssFloorPlan.combine(100, 50))
    }

    /// A roster that cannot field eight distinct characters has no plan, and
    /// saying so beats inventing one that reuses people.
    func testARosterTooSmallForTwoTeamsYieldsNoPlan() throws {
        func team(_ ids: [String], _ score: Double) -> AbyssTeamResult {
            AbyssTeamResult(memberIDs: ids, onFieldID: ids[0], score: score,
                            perCharacterDamage: [:], assignment: [:], notes: [])
        }
        let only = [team(["a", "b", "c", "d"], 100)]
        XCTAssertTrue(AbyssOptimizer.pair(first: only, second: only, count: 5).isEmpty)
    }

    /// Turning the split off is what the golden fixture runs against, so it has
    /// to keep giving one ranking for the floor read whole.
    func testTheSplitCanBeTurnedOff() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 3,
                                                               refinesArtifacts: false,
                                                               splitsHalves: false))
        let report = try XCTUnwrap(output.reports.first)
        XCTAssertEqual(report.teams.count, 3)
        XCTAssertTrue(report.plans.isEmpty)
        XCTAssertTrue(report.halves.isEmpty)
    }

    /// Both halves have to be cleared inside one timer, so the half a team is
    /// slow at is the one that decides the plan — not the half it crushes.
    func testAPlanIsRankedOnItsWeakerHalfRatherThanItsTotal() {
        XCTAssertGreaterThan(AbyssFloorPlan.combine(100, 100), AbyssFloorPlan.combine(190, 10),
                             "a plan with one hopeless half beat a balanced one")
        XCTAssertEqual(AbyssFloorPlan.combine(100, 100), 100, accuracy: 1e-9)
        XCTAssertEqual(AbyssFloorPlan.combine(100, 0), 0)
    }
}
