import XCTest
@testable import NSLauncherApp

/// The three artifact slots that carry a choice are chosen by search now, not by
/// a rule.
///
/// The rule was ATK%-or-scaling-stat sands, a goblet of the character's own
/// element, and a CRIT DMG circlet. It was defensible for a damage dealer and
/// wrong for anyone whose damage is a reaction: transformative reactions ignore
/// ATK, DMG bonus and CRIT entirely and scale on Elemental Mastery alone, so the
/// rule handed a Bloom carry a goblet and a circlet that contributed nothing to
/// the damage the model was crediting them with — and no solo pass could ever
/// find that out, because a character scored alone triggers no reaction at all.
final class AbyssMainStatSearchTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func makeOptimizer() throws -> AbyssOptimizer {
        try XCTUnwrap(AbyssOptimizer(library: library))
    }

    /// The payoff. A Dendro reaction team's carry should come back built for
    /// Elemental Mastery, which the old rule could not express in any slot.
    func testAReactionCarryIsBuiltForElementalMastery() async throws {
        let optimizer = try makeOptimizer()
        let roster = AbyssRoster(
            characters: ["nahida", "xingqiu", "kuki-shinobu", "diona"].map { .init(id: $0) },
            weapons: [])
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 1,
                                                               splitsHalves: false))
        let team = try XCTUnwrap(output.reports.first?.wholeFloorTeams?.first)

        let members = try team.memberIDs.map { try XCTUnwrap(library.charactersByID[$0]) }
        let context = AbyssTeamContext.build(members: members, library: library)
        XCTAssertFalse(context.transformativeReactions.isEmpty,
                       "this roster was chosen because it reacts")

        let carry = try XCTUnwrap(team.memberIDs.max {
            (team.assignment[$0]?.stats.elementalMastery ?? 0)
                < (team.assignment[$1]?.stats.elementalMastery ?? 0)
        })
        let option = try XCTUnwrap(team.assignment[carry])
        let emSlots = option.mainStats.slots.filter { $0 == .elementalMastery }.count
        XCTAssertGreaterThanOrEqual(emSlots, 2,
                                    "\(carry) triggers the team's reaction and was given \(emSlots) "
                                    + "Elemental Mastery slots")
        XCTAssertGreaterThan(option.stats.elementalMastery, 500,
                             "\(carry): the reaction scales on EM and there is barely any")
    }

    /// Gear selection alone cannot find that build, and the test says why rather
    /// than leaving it as a claim: a character scored on their own triggers no
    /// reaction, so Elemental Mastery is worth nothing to a solo score and no
    /// amount of searching there would ever pick it. The team pass is where it
    /// becomes visible.
    ///
    /// Xingqiu, not Nahida: this used to run on Nahida, and held only because
    /// the transcription of her skill dropped the "+ x% Elemental Mastery" half
    /// of Tri-Karma Purification. The game's own table has it, so a solo score
    /// *does* see EM on her now — through her multiplier, not a reaction. The
    /// premise needs a character whose kit scales on nothing but ATK.
    func testASoloScoreCannotSeeWhatMakesTheReactionCarryWork() throws {
        let scorer = AbyssScorer(library: library, tuning: try XCTUnwrap(library.tuning))
        let character = try XCTUnwrap(library.charactersByID["xingqiu"])
        let profile = try XCTUnwrap(library.profilesByCharacterID["xingqiu"])
        XCTAssertTrue(profile.hits.allSatisfy { $0.basis == .atk },
                      "xingqiu's kit now scales on something other than ATK; pick another character")
        let context = scorer.soloContext(for: character, profile: profile)

        var bare = AbyssStats()
        bare.baseATK = 1000
        var withEM = bare
        withEM.elementalMastery = 1000

        XCTAssertEqual(scorer.soloScore(context: context, stats: withEM),
                       scorer.soloScore(context: context, stats: bare), accuracy: 1e-9,
                       "1000 Elemental Mastery changed a solo score; this test's premise is gone")
    }

    /// A search, not a new rule: different characters come back with different
    /// answers in every slot.
    ///
    /// On a fixed roster that scales on three different stats, rather than
    /// the default pool: what the top five teams of a given cycle's floor 12
    /// happen to be is not this test's subject, and on the 2026-09 cycle they
    /// are five ATK-scaling teams whose sands are, correctly, all the same.
    func testDifferentCharactersGetDifferentMainStats() async throws {
        let optimizer = try makeOptimizer()
        let roster = AbyssRoster(
            characters: ["hu-tao", "nahida", "neuvillette", "bennett", "xingqiu", "kuki-shinobu", "diona", "furina"]
                .map { .init(id: $0) },
            weapons: [])
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                               poolSize: 40, refinesArtifacts: false,
                                                               splitsHalves: false))
        let plans = try XCTUnwrap(output.reports.first?.wholeFloorTeams).flatMap { team in
            team.memberIDs.compactMap { team.assignment[$0]?.mainStats }
        }
        XCTAssertFalse(plans.isEmpty)
        XCTAssertGreaterThan(Set(plans.map(\.sands)).count, 1, "every sands came out the same")
        XCTAssertGreaterThan(Set(plans.map(\.circlet)).count, 1, "every circlet came out the same")
    }

    /// The two slots that stay pinned, and the reason they are pinned: the score
    /// is damage, and it cannot see a heal landing or a burst being up. A free
    /// search would sell both for a few percent and call it an improvement.
    func testTheSlotsStandingInForWhatTheScoreCannotSeeAreKept() async throws {
        let optimizer = try makeOptimizer()
        let roster = AbyssRoster(
            characters: ["hu-tao", "xingqiu", "bennett", "diona"].map { .init(id: $0) },
            weapons: [])
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 1,
                                                               splitsHalves: false))
        let team = try XCTUnwrap(output.reports.first?.wholeFloorTeams?.first)

        var healers = 0
        for id in team.memberIDs {
            let option = try XCTUnwrap(team.assignment[id])
            guard option.role == .healer else { continue }
            healers += 1
            XCTAssertEqual(option.mainStats.circlet, .healingBonus,
                           "\(id) is the team's healer and was sold their Healing Bonus circlet")
        }
        XCTAssertGreaterThan(healers, 0, "this roster was chosen because it has a healer")
    }
}
