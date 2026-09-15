import XCTest
@testable import NSLauncherApp

/// What a score is measured in, and what the enemy takes off it.
///
/// Two things that were quietly wrong in the same place. The number the tab
/// printed was damage per rotation, which is a unit nobody thinks in and which
/// made the plan score — a harmonic mean, meaning "how long the floor takes" —
/// dimensionally meaningless. And on floor 12, the only floor the app actually
/// plans for, not one monster carries a resistance note, so every element sat at
/// the 10% baseline and bringing Cryo against a Cryo Abyss Mage cost nothing at
/// all.
final class AbyssScoreBasisTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func tuning() throws -> AbyssTuning { try XCTUnwrap(library.tuning) }

    private func scorer() throws -> AbyssScorer {
        AbyssScorer(library: library, tuning: try tuning())
    }

    // MARK: - Per second, not per rotation

    /// A gear option's solo score is the damage of one rotation divided by how
    /// long a rotation takes.
    func testSoloScoreIsPerSecond() throws {
        let scorer = try scorer()
        let tuning = try tuning()
        let character = try XCTUnwrap(library.charactersByID["hu-tao"])
        let context = scorer.soloContext(for: character)

        var stats = AbyssStats()
        stats.baseATK = 1000
        stats.critRate = 0.6
        stats.critDMG = 1.4

        let perRotation = scorer.onFieldDamage(
            scorer.damageSplit(context: context, stats: stats, partyBuffs: .none))
        let score = scorer.soloScore(context: context, stats: stats)

        XCTAssertGreaterThan(score, 0)
        XCTAssertEqual(score * tuning.rotationSeconds, perRotation,
                       accuracy: max(perRotation, 1) * 1e-9,
                       "solo score is not damage per second")
    }

    /// And so is everything a team result reports: the members' damage adds back
    /// up to exactly the rotation the scorer computed, once the seconds are put
    /// back. This pins the unit and the per-character accounting at once — a
    /// member's share is not a fraction of some other number.
    func testATeamsReportedDamageIsPerSecondAndAddsUp() throws {
        let scorer = try scorer()
        let tuning = try tuning()
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))
        let cycle = try XCTUnwrap(library.latestCycle)
        var diagnostics = AbyssParseDiagnostics()
        let floor = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, ownElementResistance: tuning.enemyOwnElementResistance,
            diagnostics: &diagnostics))

        let members = try ["hu-tao", "xingqiu", "bennett", "zhongli"].map {
            try XCTUnwrap(library.charactersByID[$0])
        }
        let options = Dictionary(uniqueKeysWithValues: members.map { character in
            (character.id, optimizer.gearOptions(for: character, weapons: library.weapons,
                                                 sets: library.fiveStarArtifactSets, roster: nil))
        })
        let result = try XCTUnwrap(scorer.score(members: members, options: options, floor: floor))

        let team = AbyssTeamContext.build(members: members, library: library)
        var splits = [AbyssScorer.DamageSplit](repeating: .zero, count: members.count)
        let damage = scorer.teamDamage(
            members: members,
            stats: members.map { result.assignment[$0.id]?.stats ?? AbyssStats() },
            setIDs: members.map { result.assignment[$0.id]?.setIDs ?? [] },
            floor: floor, team: team, splits: &splits)

        let reported = result.perCharacterDamage.values.reduce(0, +)
        XCTAssertGreaterThan(reported, 0)
        XCTAssertEqual(reported * tuning.rotationSeconds, damage.total,
                       accuracy: max(damage.total, 1) * 1e-9,
                       "the members' damage per second does not add back up to the rotation")
    }

    // MARK: - The enemy's own element

    /// The gap this closed first, before there was any real data to check it
    /// against: on floor 12 the wiki-transcribed data records no resistance
    /// note at all, so before either fix every element sat at the 10%
    /// baseline and bringing Cryo against a Cryo Abyss Mage cost a team
    /// nothing.
    func testFloorTwelveNoLongerPricesEveryElementAtTheBaseline() throws {
        let cycle = try XCTUnwrap(library.latestCycle)
        let floor = try XCTUnwrap(cycle.floors.first { $0.floor == 12 })
        let notes = floor.chambers
            .flatMap(\.waves).flatMap(\.monsters)
            .compactMap(\.resistanceNotes)
            .filter { !$0.contains("chưa xác nhận") }
        XCTAssertTrue(notes.isEmpty,
                      "floor 12 now carries resistance notes; this test's premise has changed")

        var diagnostics = AbyssParseDiagnostics()
        let context = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, half: 2,
            ownElementResistance: try tuning().enemyOwnElementResistance,
            diagnostics: &diagnostics))

        XCTAssertEqual(context.resistance(for: .geo), AbyssFloorContext.defaultResistance,
                       accuracy: 1e-9,
                       "an element no enemy in this half carries should stay at the baseline")
        XCTAssertGreaterThan(context.resistance(for: .cryo), context.resistance(for: .geo))
    }

    /// The gap the flat inference itself turned out to have, once real data
    /// existed to check it against: `scripts/sync-abyss-monster-resistance.py`
    /// wrote each floor-12 monster's real resistance table from the game's
    /// own files, and it does not agree with "every enemy resists +30pp what
    /// it attacks with" — some resist a lot more, some not at all. This half's
    /// own Cryo Abyss Mage is the clean case: `elements: ["Cryo"]`, and a real
    /// resistance table that shows no Cryo bonus whatsoever.
    func testTheFlatInferenceIsWrongForACharacterTheRealDataCorrects() throws {
        let cycle = try XCTUnwrap(library.latestCycle)
        let mage = try XCTUnwrap(cycle.floors.first { $0.floor == 12 }?.chambers
            .flatMap(\.waves).flatMap(\.monsters)
            .first { $0.name == "Cryo Abyss Mage" })
        XCTAssertNil(mage.resistanceNotes, "this monster's own note would win over the synced data too")
        let real = try XCTUnwrap(mage.resistances?["Cryo"],
                                 "Cryo Abyss Mage is expected to resolve against gi.yatta.moe; if the "
                                 + "rotation changed and dropped it, rewrite this test against whichever "
                                 + "monster the sync script now confirms carries no elevated resistance")
        XCTAssertEqual(real, AbyssFloorContext.defaultResistance, accuracy: 1e-9,
                       "this is the test's premise: a monster the flat inference would have boosted "
                       + "by 30pp, that the real data says gets nothing extra at all")

        var diagnostics = AbyssParseDiagnostics()
        let context = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, half: 2,
            ownElementResistance: try tuning().enemyOwnElementResistance,
            diagnostics: &diagnostics))
        // The half's Cryo figure is the mean over every half-2 monster that
        // names Cryo in `elements`, each answering with its synced table or —
        // for the one unmatched monster on this floor, if it were here — the
        // flat inference. Recomputed from the data rather than typed in, so
        // the assertion is the precedence rule itself and not a number that
        // goes stale with the next rotation.
        let cryoVoters = try XCTUnwrap(cycle.floors.first { $0.floor == 12 }?.chambers
            .flatMap { chamber in chamber.waves.filter { $0.wave == 2 } }
            .flatMap(\.monsters)
            .filter { $0.elements.contains("Cryo") })
        XCTAssertGreaterThan(cryoVoters.count, 1, "the average is only interesting with several voters")
        let expected = cryoVoters
            .map { $0.resistances?["Cryo"] ?? (try? tuning().enemyOwnElementResistance) ?? 0 }
            .reduce(0, +) / Double(cryoVoters.count)
        XCTAssertEqual(context.resistance(for: .cryo), expected, accuracy: 1e-9)
        XCTAssertLessThan(expected, try tuning().enemyOwnElementResistance,
                          "with three of this half's four Cryo monsters really at baseline, the mean "
                          + "has to land below the old flat answer")
    }

    /// The other direction of the same finding: a monster the flat inference
    /// *understated*. Icewind Suite's real resistance to both its elements is
    /// 60 points above baseline, twice the flat guess.
    func testTheFlatInferenceUnderstatesABossTheRealDataCorrects() throws {
        let cycle = try XCTUnwrap(library.latestCycle)
        let boss = try XCTUnwrap(cycle.floors.first { $0.floor == 12 }?.chambers
            .flatMap(\.waves).flatMap(\.monsters)
            .first { $0.name.hasPrefix("Icewind Suite") })
        XCTAssertNil(boss.resistanceNotes)
        for raw in ["Anemo", "Cryo"] {
            let real = try XCTUnwrap(boss.resistances?[raw], "\(raw): expected a synced value")
            XCTAssertEqual(real, AbyssFloorContext.defaultResistance + 0.60, accuracy: 1e-9,
                           "\(raw): this is the test's premise — the boss's real resistance is twice "
                           + "the flat inference's guess")
        }
    }

    /// Turning the flat-inference assumption off must still leave a *matched*
    /// monster's real resistance untouched: the two sources answer different
    /// questions (source 3 is a last resort for a monster source 2 has not
    /// been matched for yet), and the parameter that tunes one has nothing to
    /// say about the other.
    func testPricingAnEnemysOwnElementAtTheBaselineOnlyChangesTheUnmatchedFallback() throws {
        let cycle = try Self.cycle(monsters: """
            [{"name": "Matched", "count": "1", "size": "Vừa", "elements": ["Pyro"],
              "resistanceNotes": null, "weakpoint": false, "mechanics": null, "hpRatio": null,
              "resistances": {"Pyro": 0.7}},
             {"name": "Unmatched", "count": "1", "size": "Vừa", "elements": ["Hydro"],
              "resistanceNotes": null, "weakpoint": false, "mechanics": null, "hpRatio": null}]
            """)
        var diagnostics = AbyssParseDiagnostics()
        let baseline = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, ownElementResistance: AbyssFloorContext.defaultResistance,
            diagnostics: &diagnostics))
        let inferring = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, ownElementResistance: 0.3, diagnostics: &diagnostics))

        XCTAssertEqual(baseline.resistance(for: .pyro), 0.7, accuracy: 1e-9,
                       "the matched monster's real 70% should not move just because the fallback did")
        XCTAssertEqual(inferring.resistance(for: .pyro), 0.7, accuracy: 1e-9,
                       "nor should turning the fallback back up move a monster the fallback never speaks for")
        XCTAssertEqual(baseline.resistance(for: .hydro), AbyssFloorContext.defaultResistance, accuracy: 1e-9)
        XCTAssertEqual(inferring.resistance(for: .hydro), 0.3, accuracy: 1e-9,
                       "the unmatched monster is exactly what the fallback parameter is for")
    }

    /// Coverage of `scripts/sync-abyss-monster-resistance.py` over the bundled
    /// rotation, and the two names it could not resolve, named exactly.
    ///
    /// A named list rather than a bare count in either direction: a *new*
    /// unresolved monster showing up here (the set grew) means a rotation
    /// added something the script has never seen and nobody has looked at
    /// yet; one of *these two* disappearing (the set shrank) means the script
    /// resolved a monster this test still thinks is unresolved, and the
    /// reasoning in `scripts/sync-abyss-monster-resistance.py`'s
    /// `MONSTER_ALIASES` comment needs updating to match. Either way this
    /// should go red and be looked at, not silently keep passing.
    func testMonsterResistanceSyncCoverage() throws {
        let cycle = try XCTUnwrap(library.latestCycle)
        let monsters = cycle.floors.flatMap(\.chambers).flatMap(\.waves).flatMap(\.monsters)
        let names = Set(monsters.map(\.name))
        let unresolved = Set(monsters.filter { $0.resistances == nil }.map(\.name))

        XCTAssertEqual(unresolved, ["Battle-Hardened Chimeric Volkodlak Archer",
                                    "Veteran Tainted Water-Splitting Phantasm"],
                       "run scripts/sync-abyss-monster-resistance.py and read why this changed")
        XCTAssertGreaterThan(Double(names.count - unresolved.count) / Double(names.count), 0.9,
                             "sync coverage dropped below 90% of this rotation's distinct monsters")

        // Every resolved monster's table has to actually answer for every
        // element it is listed as attacking or shielding with, or
        // `AbyssFloorContext.build`'s lookup would silently fall through to
        // the flat inference for that one element while looking resolved.
        for monster in monsters where monster.resistances != nil {
            for element in monster.elements where GenshinElement(rawValue: element) != nil {
                XCTAssertNotNil(monster.resistances?[element],
                                "\(monster.name): resolved, but its own table has no entry for "
                                + "\(element), which its `elements` field names")
            }
        }
    }

    /// The synced `resistances` table is only consulted for elements the
    /// monster's own `elements` field already names — a real, elevated
    /// resistance to some other element does not silently enter the model
    /// through the side door. Scoped this way on purpose: see
    /// `AbyssFloorContext.build`'s comment on why "same voters, real values"
    /// rather than "every real number votes".
    func testASyncedResistanceOutsideTheMonstersOwnElementsIsIgnored() throws {
        let cycle = try Self.cycle(monsters: """
            [{"name": "A", "count": "1", "size": "Vừa", "elements": ["Pyro"],
              "resistanceNotes": null, "weakpoint": false, "mechanics": null, "hpRatio": null,
              "resistances": {"Pyro": 0.5, "Hydro": 0.9}}]
            """)
        var diagnostics = AbyssParseDiagnostics()
        let context = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, ownElementResistance: 0.3, diagnostics: &diagnostics))
        XCTAssertEqual(context.resistance(for: .pyro), 0.5, accuracy: 1e-9)
        XCTAssertEqual(context.resistance(for: .hydro), AbyssFloorContext.defaultResistance, accuracy: 1e-9,
                       "Hydro is not in this monster's own `elements`, so its real 90% must not surface")
    }

    /// A monster whose note already prices an element must not also be charged
    /// the inferred figure for it: the note is the better evidence, and averaging
    /// the two would bury it.
    func testATranscribedResistanceWinsOverTheInferredOne() throws {
        let cycle = try Self.cycle(monsters: """
            [{"name": "A", "count": "1", "size": "Vừa", "elements": ["Pyro", "Cryo"],
              "resistanceNotes": "kháng Pyro +80%", "weakpoint": false,
              "mechanics": null, "hpRatio": null}]
            """)
        var diagnostics = AbyssParseDiagnostics()
        let context = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, ownElementResistance: 0.3, diagnostics: &diagnostics))

        XCTAssertEqual(context.resistance(for: .pyro), 0.9, accuracy: 1e-9,
                       "the note said +80% over the baseline and should stand alone")
        XCTAssertEqual(context.resistance(for: .cryo), 0.3, accuracy: 1e-9,
                       "the note said nothing about Cryo, so the enemy's own element applies")
        XCTAssertEqual(context.resistance(for: .hydro), AbyssFloorContext.defaultResistance,
                       accuracy: 1e-9)
    }

    /// "Physical" appears in the same field and is not a playable element; it
    /// must not fall through into one.
    func testPhysicalIsNotTreatedAsAnElement() throws {
        let cycle = try Self.cycle(monsters: """
            [{"name": "A", "count": "1", "size": "Vừa", "elements": ["Physical"],
              "resistanceNotes": null, "weakpoint": false, "mechanics": null, "hpRatio": null}]
            """)
        var diagnostics = AbyssParseDiagnostics()
        let context = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12, ownElementResistance: 0.3, diagnostics: &diagnostics))
        XCTAssertTrue(context.resistances.isEmpty)
    }

    /// A one-monster floor 12, so a rule can be checked against a case written
    /// out in full instead of against whatever this rotation happens to hold.
    private static func cycle(monsters: String) throws -> AbyssCycle {
        let json = """
        {
          "periodStart": "2026-01-01", "periodEnd": "2026-01-15", "gameVersion": "0.0",
          "blessingOfTheAbyssalMoon": {
            "name": "None", "description": "", "timeStart": "", "timeEnd": ""
          },
          "floors": [{
            "floor": 12, "leyLineDisorder": "", "recommendation": "",
            "chambers": [{
              "chamber": 1, "monsterLevel": 100,
              "waves": [{"wave": 1, "monsters": \(monsters)}]
            }]
          }]
        }
        """
        return try JSONDecoder().decode(AbyssCycle.self, from: Data(json.utf8))
    }
}
