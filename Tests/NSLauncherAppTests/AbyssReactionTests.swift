import XCTest
@testable import NSLauncherApp

/// Constellations raising talent levels, and transformative reaction damage.
///
/// Both were whole mechanics the model did not have. The constellation a player
/// typed into the roster was stored and ignored; and a reaction that in game is
/// most of a Bloom team's damage contributed exactly nothing, which made every
/// Dendro team look like a bad version of a Pyro one.
final class AbyssReactionTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    // MARK: - Constellations

    /// C3 and C5 each raise one talent by three levels, and the data carries the
    /// level 13 column for the characters transcribed that far.
    func testConstellationsRaiseTheTalentLevelAProfileIsReadAt() throws {
        // Kuki Shinobu has both a lv13 column and the plain "Tăng cấp kỹ năng
        // thêm 3" phrasing, so she exercises the keyword branch.
        let id = "kuki-shinobu"
        let base = try XCTUnwrap(library.profile(for: id, constellation: 0))
        let atC6 = try XCTUnwrap(library.profile(for: id, constellation: 6))

        XCTAssertEqual(library.talentLevels(for: id, constellation: 0), .base)
        XCTAssertEqual(library.talentLevels(for: id, constellation: 6),
                       AbyssTalentLevels(skill: "lv13", burst: "lv13"))

        let baseTotal = base.hits.reduce(0) { $0 + $1.multiplier }
        let c6Total = atC6.hits.reduce(0) { $0 + $1.multiplier }
        XCTAssertGreaterThan(c6Total, baseTotal, "C6 did not raise any talent multiplier")
    }

    /// C3 raises one talent and C5 the other, so a C3 character must gain on
    /// exactly one of them.
    func testC3RaisesOneTalentAndC5TheOther() throws {
        let character = try XCTUnwrap(library.charactersByID["kamisato-ayaka"])
        let boosts = try XCTUnwrap(library.talentBoostsByCharacterID[character.id])
        XCTAssertEqual(boosts[3], .burst, "Ayaka's C3 raises Soumetsu, her burst")
        XCTAssertEqual(boosts[5], .skill, "Ayaka's C5 raises Hyouka, her skill")

        XCTAssertEqual(library.talentLevels(for: character.id, constellation: 3),
                       AbyssTalentLevels(skill: "lv10", burst: "lv13"))
        XCTAssertEqual(library.talentLevels(for: character.id, constellation: 4),
                       AbyssTalentLevels(skill: "lv10", burst: "lv13"))
        XCTAssertEqual(library.talentLevels(for: character.id, constellation: 5),
                       AbyssTalentLevels(skill: "lv13", burst: "lv13"))
    }

    /// Characters whose two talents share a prefix are where a first-match rule
    /// picks the wrong one, so the resolver counts matching words instead.
    func testTalentsSharingAPrefixResolveToTheRightOne() throws {
        for (id, level, expected) in [("skirk", 3, AbyssTalentSlot.burst),
                                      ("skirk", 5, .skill),
                                      ("candace", 3, .burst),
                                      ("candace", 5, .skill)] {
            guard let character = library.charactersByID[id] else { continue }
            let boosts = library.talentBoostsByCharacterID[id] ?? [:]
            XCTAssertEqual(boosts[level], expected,
                           "\(id) C\(level): resolved to the wrong talent "
                           + "(skill \"\(character.elementalSkill.name ?? "")\", "
                           + "burst \"\(character.elementalBurst.name ?? "")\")")
        }
    }

    /// A character whose data has no level 13 column must be unaffected rather
    /// than fall through to some other level.
    func testAConstellationWithoutLevelThirteenDataChangesNothing() throws {
        let id = "hu-tao"
        let withoutData = library.charactersByID[id]?.elementalSkill.scaling
            .allSatisfy { $0.values["lv13"] == nil } ?? false
        XCTAssertTrue(withoutData, "hu-tao now has lv13 data; this test needs a different character")

        let base = try XCTUnwrap(library.profile(for: id, constellation: 0))
        let atC6 = try XCTUnwrap(library.profile(for: id, constellation: 6))
        XCTAssertEqual(base.hits.map(\.multiplier), atC6.hits.map(\.multiplier))
    }

    /// The roster's constellation has to actually reach the search.
    func testTheRostersConstellationReachesTheScore() async throws {
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))
        let members: [AbyssRoster.OwnedCharacter] = ["kuki-shinobu", "raiden-shogun",
                                                     "kamisato-ayaka", "bennett"].map { .init(id: $0) }
        var atC0 = AbyssRoster(characters: members, weapons: [])
        var atC6 = AbyssRoster(characters: members.map { .init(id: $0.id, constellation: 6) },
                               weapons: [])
        atC0.weapons = []
        atC6.weapons = []

        let low = await optimizer.run(AbyssOptimizerRequest(roster: atC0, floors: [12], topN: 1,
                                                            refinesArtifacts: false))
        let high = await optimizer.run(AbyssOptimizerRequest(roster: atC6, floors: [12], topN: 1,
                                                             refinesArtifacts: false))
        let lowScore = try XCTUnwrap(low.reports.first?.teams.first?.score)
        let highScore = try XCTUnwrap(high.reports.first?.teams.first?.score)
        XCTAssertGreaterThan(highScore, lowScore,
                             "a C6 roster scored no better than the same characters at C0")
    }

    // MARK: - Transformative reactions

    private func context(_ ids: [String]) throws -> (AbyssTeamContext, [AbyssCharacter]) {
        let members = try ids.map { try XCTUnwrap(library.charactersByID[$0]) }
        return (AbyssTeamContext.build(members: members, library: library), members)
    }

    /// Hyperbloom and Burgeon need a Bloom core to detonate, so they want three
    /// elements rather than two.
    func testTwoStepReactionsNeedTheBloomCore() throws {
        let (dendroHydro, _) = try context(["nahida", "xingqiu", "bennett", "diona"])
        XCTAssertTrue(dendroHydro.transformativeReactions.contains(.bloom))
        XCTAssertFalse(dendroHydro.transformativeReactions.contains(.hyperbloom),
                       "Bloom without Electro is not a Hyperbloom")

        let (withElectro, _) = try context(["nahida", "xingqiu", "raiden-shogun", "diona"])
        XCTAssertTrue(withElectro.transformativeReactions.contains(.hyperbloom))
    }

    /// The Lunar upgrade renames the reaction for floor-buff purposes; it must
    /// not make the reaction disappear from the damage model.
    func testLunarTeamsStillTriggerTheUnderlyingReaction() throws {
        let (team, _) = try context(["nahida", "xingqiu", "raiden-shogun", "diona"])
        XCTAssertTrue(team.transformativeReactions.contains(.bloom),
                      "the transformative set must not be gated on the Lunar rename")
    }

    /// Only the strongest reaction is priced. Counting all of them at once would
    /// make four-element soup the answer to every floor.
    func testOnlyTheStrongestReactionIsPriced() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let (team, _) = try context(["nahida", "xingqiu", "raiden-shogun", "bennett"])
        XCTAssertGreaterThan(team.transformativeReactions.count, 2,
                             "this team should unlock several reactions at once")

        let priced = try XCTUnwrap(scorer.transformative(for: team, floor: .neutral))
        let coefficient = try XCTUnwrap(
            library.damageConstants.transformativeCoefficients[priced.reaction])
        let best = team.transformativeReactions
            .compactMap { library.damageConstants.transformativeCoefficients[$0] }
            .max()
        XCTAssertEqual(coefficient, best, "a weaker reaction was priced over a stronger one")
    }

    /// A team with no shared elements triggers nothing and must be priced at
    /// nothing rather than at some default.
    func testATeamWithNoReactionIsPricedAtNothing() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let (team, _) = try context(["hu-tao", "bennett", "xiangling", "yoimiya"])
        XCTAssertTrue(team.transformativeReactions.isEmpty, "an all-Pyro team reacts with nothing")
        XCTAssertNil(scorer.transformative(for: team, floor: .neutral))
    }

    /// Reaction damage depends on the triggering character's Elemental Mastery
    /// and on nothing else about them — not ATK, not CRIT, not the enemy's DEF.
    func testReactionDamageScalesWithElementalMasteryAndIsCreditedToItsTrigger() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let (team, members) = try context(["nahida", "xingqiu", "raiden-shogun", "diona"])
        let context = scorer.teamDamageContext(members: members, floor: .neutral, team: team)
        XCTAssertNotNil(context.transformative)

        var sheets = members.map { _ in AbyssStats() }
        var splits = [AbyssScorer.DamageSplit](repeating: .zero, count: members.count)
        let setIDs = members.map { _ in [String]() }

        let bare = scorer.teamDamage(context: context, stats: sheets, setIDs: setIDs,
                                     splits: &splits)
        XCTAssertGreaterThan(bare.reactionDamage, 0, "the team triggers a reaction but was paid none")
        XCTAssertEqual(bare.total, bare.reactionDamage, accuracy: 1e-9,
                       "with empty stat sheets the reaction is the only damage")

        // More Elemental Mastery on one member, and the reaction follows them.
        sheets[2].elementalMastery = 1000
        let boosted = scorer.teamDamage(context: context, stats: sheets, setIDs: setIDs,
                                        splits: &splits)
        XCTAssertGreaterThan(boosted.reactionDamage, bare.reactionDamage)
        XCTAssertEqual(boosted.reactionTriggerIndex, 2,
                       "the reaction should be credited to the highest-EM member")

        // ATK is irrelevant to it: a huge ATK sheet moves the team total but not
        // the reaction.
        sheets[0].baseATK = 100_000
        let fat = scorer.teamDamage(context: context, stats: sheets, setIDs: setIDs, splits: &splits)
        XCTAssertEqual(fat.reactionDamage, boosted.reactionDamage, accuracy: 1e-9,
                       "reaction damage must not depend on ATK")
    }

    /// The whole point: a Dendro reaction team should stop being scored as if
    /// the reaction did not exist.
    func testAReactionTeamScoresAboveItsOwnDirectDamage() async throws {
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))
        let roster = AbyssRoster(
            characters: ["nahida", "xingqiu", "raiden-shogun", "diona"].map { .init(id: $0) },
            weapons: [])
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 1,
                                                               refinesArtifacts: false))
        let team = try XCTUnwrap(output.reports.first?.teams.first)

        let tuning = try XCTUnwrap(library.tuning)
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let members = try team.memberIDs.map { try XCTUnwrap(library.charactersByID[$0]) }
        let context = AbyssTeamContext.build(members: members, library: library)
        XCTAssertNotNil(scorer.transformative(for: context, floor: .neutral),
                        "this roster was chosen because it reacts")
        XCTAssertGreaterThan(team.score, 0)
    }
}
