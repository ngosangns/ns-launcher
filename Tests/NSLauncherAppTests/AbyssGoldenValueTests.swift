import XCTest
@testable import NSLauncherApp

/// Holds the Swift engine to the numbers the Python reference produces.
///
/// Split by stage so a failure says *where* the port diverged: parsing, stat
/// assembly, floor context, or team scoring. A single "scores differ" test
/// would leave that to bisection.
final class AbyssGoldenValueTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    // MARK: - Parsing

    func testDamageProfilesMatchReferenceImplementation() throws {
        let golden = try AbyssGoldenFixture.load()
        var compared = 0

        for (characterID, expected) in golden.characters {
            let profile = try XCTUnwrap(library.profilesByCharacterID[characterID],
                                        "no profile for \(characterID)")

            XCTAssertEqual(profile.basis.rawValue, expected.scalingBasis,
                           "\(characterID): scaling basis differs")
            XCTAssertEqual(profile.hits.count, expected.profile.count,
                           "\(characterID): parsed a different number of hits")

            for (index, expectedTerm) in expected.profile.enumerated() where index < profile.hits.count {
                let term = profile.hits[index]
                XCTAssertEqual(term.multiplier, expectedTerm.multiplier, accuracy: 1e-9,
                               "\(characterID) hit \(index): multiplier differs")
                XCTAssertEqual(term.basis.rawValue, expectedTerm.basis,
                               "\(characterID) hit \(index): basis differs")
                XCTAssertEqual(term.category.rawValue, expectedTerm.category,
                               "\(characterID) hit \(index): category differs")
            }
            compared += 1
        }

        XCTAssertEqual(compared, 125, "the fixture should cover every character")
    }

    // MARK: - Stat assembly

    /// The one that catches a misrouted stat name. Every field is compared, not
    /// just the totals, because a bonus landing in `dmgNormal` instead of
    /// `dmgSkill` leaves the total unchanged while quietly changing every score.
    func testAssembledStatsMatchReferenceImplementation() throws {
        let golden = try AbyssGoldenFixture.load()
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))

        for (characterID, expected) in golden.characters {
            let character = try XCTUnwrap(library.charactersByID[characterID])
            let options = optimizer.gearOptions(for: character,
                                                weapons: library.weapons,
                                                sets: library.fiveStarArtifactSets,
                                                roster: nil)
            let best = try XCTUnwrap(options.first, "\(characterID): no gear option produced")

            XCTAssertEqual(best.role.rawValue, expected.role, "\(characterID): role differs")
            XCTAssertEqual(best.weaponID, expected.topGear.weaponId, "\(characterID): chose a different weapon")
            XCTAssertEqual(best.setIDs, expected.topGear.setIds, "\(characterID): chose different artifact sets")
            XCTAssertEqual(best.soloScore, expected.topGear.soloScore,
                           accuracy: max(abs(expected.topGear.soloScore), 1) * 1e-9,
                           "\(characterID): solo score differs")

            let stats = best.stats
            let want = expected.topGear.stats
            let fields: [(String, Double, Double)] = [
                ("baseATK", stats.baseATK, want.base_atk),
                ("baseHP", stats.baseHP, want.base_hp),
                ("baseDEF", stats.baseDEF, want.base_def),
                ("atkPercent", stats.atkPercent, want.atk_pct),
                ("hpPercent", stats.hpPercent, want.hp_pct),
                ("defPercent", stats.defPercent, want.def_pct),
                ("flatATK", stats.flatATK, want.flat_atk),
                ("flatHP", stats.flatHP, want.flat_hp),
                ("flatDEF", stats.flatDEF, want.flat_def),
                ("elementalMastery", stats.elementalMastery, want.em),
                ("energyRecharge", stats.energyRecharge, want.er),
                ("critRate", stats.critRate, want.crit_rate),
                ("critDMG", stats.critDMG, want.crit_dmg),
                ("healingBonus", stats.healingBonus, want.healing_bonus),
                ("dmgAll", stats.dmgAll, want.dmg_all),
                ("dmgNormal", stats.dmgNormal, want.dmg_normal),
                ("dmgCharged", stats.dmgCharged, want.dmg_charged),
                ("dmgSkill", stats.dmgSkill, want.dmg_skill),
                ("dmgBurst", stats.dmgBurst, want.dmg_burst),
                ("partyATKPercent", stats.partyATKPercent, want.party_atk_pct),
                ("partyElementalMastery", stats.partyElementalMastery, want.party_em),
                ("partyDMG", stats.partyDMG, want.party_dmg),
            ]
            for (name, got, wanted) in fields {
                XCTAssertEqual(got, wanted, accuracy: max(abs(wanted), 1) * 1e-9,
                               "\(characterID): \(name) differs")
            }

            for (rawElement, value) in want.dmg_elemental {
                let element = try XCTUnwrap(GenshinElement(rawValue: rawElement))
                XCTAssertEqual(stats.elementalBonus(element), value, accuracy: max(abs(value), 1) * 1e-9,
                               "\(characterID): \(rawElement) DMG bonus differs")
            }
        }
    }

    // MARK: - Team scoring

    /// End-to-end: the same roster, the same floors, the same top-10 teams in
    /// the same order with the same scores.
    func testTopTeamsMatchReferenceImplementation() async throws {
        let golden = try AbyssGoldenFixture.load()
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))
        let roster = try AbyssGoldenFixture.exampleRoster()

        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, topN: 10, poolSize: 40))
        XCTAssertFalse(output.reports.isEmpty, "optimizer produced no floors")

        for report in output.reports {
            let expectedTeams = try XCTUnwrap(golden.teams[String(report.floor)],
                                              "fixture has no teams for floor \(report.floor)")
            XCTAssertEqual(report.teams.count, expectedTeams.count,
                           "floor \(report.floor): different number of teams returned")

            for (rank, expected) in expectedTeams.enumerated() where rank < report.teams.count {
                let team = report.teams[rank]
                XCTAssertEqual(team.memberIDs.sorted(), expected.memberIds.sorted(),
                               "floor \(report.floor) rank \(rank + 1): different members")
                XCTAssertEqual(team.onFieldID, expected.onFieldId,
                               "floor \(report.floor) rank \(rank + 1): different on-field pick")
                XCTAssertEqual(team.score, expected.score, accuracy: max(abs(expected.score), 1) * 1e-9,
                               "floor \(report.floor) rank \(rank + 1): score differs")

                for (characterID, damage) in expected.perCharacter {
                    XCTAssertEqual(team.perCharacterDamage[characterID] ?? .nan, damage,
                                   accuracy: max(abs(damage), 1) * 1e-9,
                                   "floor \(report.floor) rank \(rank + 1): \(characterID) damage differs")
                }
            }
        }
    }

    // MARK: - Floor context

    func testFloorContextsMatchReferenceImplementation() throws {
        let golden = try AbyssGoldenFixture.load()
        let cycle = try XCTUnwrap(library.latestCycle)
        var diagnostics = AbyssParseDiagnostics()

        for (rawFloor, expected) in golden.floors {
            let floorNumber = try XCTUnwrap(Int(rawFloor))
            let context = try XCTUnwrap(
                AbyssFloorContext.build(cycle: cycle, floor: floorNumber, diagnostics: &diagnostics),
                "no context for floor \(floorNumber)")

            XCTAssertEqual(context.monsterLevel, expected.monsterLevel,
                           "floor \(floorNumber): monster level differs")
            XCTAssertEqual(context.shieldElements.map(\.rawValue).sorted(), expected.shieldElements.sorted(),
                           "floor \(floorNumber): shield elements differ")

            XCTAssertEqual(context.resistances.count, expected.res.count,
                           "floor \(floorNumber): different number of resistance entries")
            for (rawElement, value) in expected.res {
                let element = try XCTUnwrap(GenshinElement(rawValue: rawElement))
                XCTAssertEqual(context.resistances[element] ?? .nan, value, accuracy: 1e-9,
                               "floor \(floorNumber): \(rawElement) resistance differs")
            }

            XCTAssertEqual(context.buffs.count, expected.buffs.count,
                           "floor \(floorNumber): different number of parsed buffs")
            for (index, expectedBuff) in expected.buffs.enumerated() where index < context.buffs.count {
                let buff = context.buffs[index]
                XCTAssertEqual(buff.bonus, expectedBuff.bonus, accuracy: 1e-9,
                               "floor \(floorNumber) buff \(index): bonus differs")
                XCTAssertEqual(buff.normalAttackOnly, expectedBuff.normalAttackOnly,
                               "floor \(floorNumber) buff \(index): normal-attack scope differs")
                XCTAssertEqual(buff.elements.map(\.rawValue).sorted(), expectedBuff.elements.sorted(),
                               "floor \(floorNumber) buff \(index): elements differ")
                XCTAssertEqual(buff.reactions.map(\.rawValue).sorted(), expectedBuff.reactions.sorted(),
                               "floor \(floorNumber) buff \(index): reactions differ")
            }
        }
    }
}
