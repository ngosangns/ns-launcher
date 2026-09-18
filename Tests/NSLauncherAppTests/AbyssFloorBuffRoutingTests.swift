import XCTest
@testable import NSLauncherApp

/// Where a floor buff lands, and what it is allowed to touch.
///
/// A Ley Line Disorder that says "Sát thương Superconduct +200%" multiplies the
/// Superconduct reaction. The model used to add it to every hit the team made
/// instead, gated only on the team being *able* to Superconduct — which on this
/// rotation's floor 12 was worth +85% to a team's score for a reaction worth 5%
/// of its damage, and picked the entire first-half team on that basis. Worse,
/// the reaction the buff named was not even the one being priced: the pricing
/// ranked on the bare coefficient, so Overloaded (2.75) beat a Superconduct
/// (1.5) the floor was tripling.
final class AbyssFloorBuffRoutingTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func tuning() throws -> AbyssTuning { try XCTUnwrap(library.tuning) }

    private func scorer() throws -> AbyssScorer {
        AbyssScorer(library: library, tuning: try tuning())
    }

    private func floor(_ buffs: [AbyssFloorBuff]) -> AbyssFloorContext {
        AbyssFloorContext(floor: 12, half: nil, monsterLevel: 100, resistances: [:],
                          buffs: buffs, shieldElements: [])
    }

    private func buff(_ bonus: Double,
                      reactions: Set<AbyssReaction> = [],
                      elements: Set<GenshinElement> = [],
                      normalAttackOnly: Bool = false) -> AbyssFloorBuff {
        AbyssFloorBuff(bonus: bonus, elements: elements, reactions: reactions,
                       normalAttackOnly: normalAttackOnly, raw: "test")
    }

    private func team(_ ids: [String]) throws -> (AbyssTeamContext, [AbyssCharacter]) {
        let members = try ids.map { try XCTUnwrap(library.charactersByID[$0]) }
        return (AbyssTeamContext.build(members: members, library: library), members)
    }

    // MARK: - A reaction buff belongs to the reaction

    func testAReactionBuffDoesNotTouchDirectDamage() throws {
        let scorer = try scorer()
        let (context, members) = try team(["rosaria", "lisa", "amber", "xinyan"])
        XCTAssertTrue(context.transformativeReactions.contains(.superconduct),
                      "this team was chosen because it can Superconduct")

        var stats = AbyssStats()
        stats.baseATK = 2000
        let bare = scorer.damageContext(for: members[0], floor: floor([]), team: context)
        let buffed = scorer.damageContext(for: members[0],
                                          floor: floor([buff(2.0, reactions: [.superconduct])]),
                                          team: context)
        XCTAssertEqual(
            scorer.damageSplit(context: buffed, stats: stats, partyBuffs: .none).ability,
            scorer.damageSplit(context: bare, stats: stats, partyBuffs: .none).ability,
            accuracy: 1e-9,
            "+200% Superconduct moved a character's direct damage")
    }

    func testAReactionBuffMultipliesThatReactionsDamage() throws {
        let scorer = try scorer()
        let (context, _) = try team(["rosaria", "lisa", "amber", "xinyan"])

        let bare = try XCTUnwrap(scorer.transformative(for: context, floor: floor([])))
        let buffed = try XCTUnwrap(scorer.transformative(
            for: context, floor: floor([buff(2.0, reactions: [.superconduct])])))
        XCTAssertEqual(buffed.reaction, .superconduct)
        XCTAssertEqual(buffed.base,
                       (library.damageConstants.transformativeCoefficients[.superconduct] ?? 0)
                           / (library.damageConstants.transformativeCoefficients[bare.reaction] ?? 1)
                           * bare.base * 3,
                       accuracy: max(buffed.base, 1) * 1e-9,
                       "the reaction the floor names should be worth three times its coefficient")
    }

    /// The reason the buff has to reach the pricing and not just the damage:
    /// which reaction is "strongest" depends on what the floor pays for it.
    func testTheFloorDecidesWhichReactionIsStrongest() throws {
        let scorer = try scorer()
        let (context, _) = try team(["rosaria", "lisa", "amber", "xinyan"])
        let coefficients = library.damageConstants.transformativeCoefficients
        XCTAssertGreaterThan(coefficients[.overloaded] ?? 0, coefficients[.superconduct] ?? 0,
                             "this test is about the weaker reaction winning on the right floor")

        XCTAssertEqual(scorer.transformative(for: context, floor: floor([]))?.reaction, .overloaded)
        XCTAssertEqual(scorer.transformative(for: context,
                                             floor: floor([buff(2.0, reactions: [.superconduct])]))?
                            .reaction,
                       .superconduct,
                       "a floor tripling Superconduct still priced Overloaded")
    }

    /// A buff with no reaction is a plain damage bonus and keeps its old route.
    func testAnElementBuffStillReachesDirectDamage() throws {
        let scorer = try scorer()
        let (context, members) = try team(["rosaria", "lisa", "amber", "xinyan"])
        var stats = AbyssStats()
        stats.baseATK = 2000

        let bare = scorer.damageContext(for: members[0], floor: floor([]), team: context)
        let buffed = scorer.damageContext(for: members[0],
                                          floor: floor([buff(0.6, elements: [members[0].element])]),
                                          team: context)
        XCTAssertGreaterThan(
            scorer.damageSplit(context: buffed, stats: stats, partyBuffs: .none).ability,
            scorer.damageSplit(context: bare, stats: stats, partyBuffs: .none).ability)
    }

    /// Vaporize and Melt are not transformative, so their buffs have their own
    /// home: the amplifying multiplier, which has always taken a `reactionBonus`
    /// and never been given one.
    func testAnAmplifyingBuffReachesTheAmplifyingMultiplier() throws {
        let scorer = try scorer()
        let (context, members) = try team(["hu-tao", "xingqiu", "bennett", "diona"])
        XCTAssertTrue(context.enabledReactions.contains(.vaporize),
                      "this team was chosen because it can Vaporize")

        var stats = AbyssStats()
        stats.baseATK = 2000
        let bare = scorer.damageContext(for: members[0], floor: floor([]), team: context)
        let buffed = scorer.damageContext(for: members[0],
                                          floor: floor([buff(0.5, reactions: [.vaporize])]),
                                          team: context)
        // The multiplier travels on the split as a gain; how much of the split
        // it reaches is decided per team in `teamDamage` (Phase 4).
        XCTAssertGreaterThan(
            scorer.damageSplit(context: buffed, stats: stats, partyBuffs: .none).amplifyingGain,
            scorer.damageSplit(context: bare, stats: stats, partyBuffs: .none).amplifyingGain,
            "a Vaporize buff reached nothing")
    }

    /// A buff naming a reaction the damage model cannot price has to be
    /// reported rather than swallowed — and right now there is no such
    /// reaction, which is the stronger statement.
    ///
    /// This rotation's Stellar-Conduct clauses used to be exactly that case:
    /// they reached nothing, and before the routing was fixed they were silently
    /// worth +75% to every hit instead. Both halves are closed now, so the
    /// diagnostic is empty because the model is complete.
    func testEveryReactionAFloorCanNameIsPriceableSomewhere() throws {
        for reaction in AbyssReaction.allCases {
            let priceable = reaction.transformativeKey != nil || reaction.lunarStellarKey != nil
                || reaction == .vaporize || reaction == .melt
            XCTAssertTrue(priceable,
                          "\(reaction.rawValue) has no home: a floor buff naming it would be "
                          + "dropped, and `floorBuffsNotPriced` is the only thing that would say so")
        }

        let cycle = try XCTUnwrap(library.latestCycle)
        var diagnostics = AbyssParseDiagnostics()
        _ = AbyssFloorContext.build(cycle: cycle, floor: 12, half: 1,
                                    ownElementResistance: try tuning().enemyOwnElementResistance,
                                    diagnostics: &diagnostics)
        XCTAssertTrue(diagnostics.floorBuffsNotPriced.isEmpty,
                      "unpriced: \(diagnostics.floorBuffsNotPriced)")
    }
}
