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

    /// The gap this closes: on floor 12 the data records no resistance at all,
    /// so before this every element was priced at the 10% baseline.
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

        // The second half is where the Cryo Abyss Mage and the Icewind Suite
        // are; nothing there is Geo.
        XCTAssertEqual(context.resistance(for: .cryo), try tuning().enemyOwnElementResistance,
                       accuracy: 1e-9)
        XCTAssertEqual(context.resistance(for: .geo), AbyssFloorContext.defaultResistance,
                       accuracy: 1e-9,
                       "an element no enemy carries should stay at the baseline")
        XCTAssertGreaterThan(context.resistance(for: .cryo), context.resistance(for: .geo))
    }

    /// Turning the assumption off has to leave the model exactly where it was.
    func testPricingAnEnemysOwnElementAtTheBaselineChangesNothing() throws {
        let cycle = try XCTUnwrap(library.latestCycle)
        var diagnostics = AbyssParseDiagnostics()
        let context = try XCTUnwrap(AbyssFloorContext.build(
            cycle: cycle, floor: 12,
            ownElementResistance: AbyssFloorContext.defaultResistance,
            diagnostics: &diagnostics))
        for element in GenshinElement.allCases {
            XCTAssertEqual(context.resistance(for: element), AbyssFloorContext.defaultResistance,
                           accuracy: 1e-9, "\(element.rawValue) moved with the rule switched off")
        }
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
