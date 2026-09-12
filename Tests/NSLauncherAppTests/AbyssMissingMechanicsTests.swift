import XCTest
@testable import NSLauncherApp

/// Three mechanics the model did not have, and the evidence that it does now.
///
/// All three were the same shape of hole: a channel that existed but nothing
/// ever fed it. `resMultiplier` had a negative branch no source could reach.
/// `damage-formula.json` carried a whole `lunarStellar` block nothing read. The
/// charged-attack parser had a vocabulary that could not see a charged attack
/// the data named after the skill.
final class AbyssMissingMechanicsTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }
    private func tuning() throws -> AbyssTuning { try XCTUnwrap(library.tuning) }
    private func team(_ ids: [String]) throws -> AbyssTeamContext {
        AbyssTeamContext.build(members: try ids.map { try XCTUnwrap(library.charactersByID[$0]) },
                               library: library)
    }

    // MARK: - Enemy resistance reduction

    /// An Anemo character on the team strips the resistance of everything the
    /// team can swirl. Before this, nothing in the model could move enemy
    /// resistance at all and the negative branch of `resMultiplier` was dead
    /// code.
    func testAnAnemoTeamStripsTheResistanceOfWhatItSwirls() throws {
        let withAnemo = try team(["venti", "hu-tao", "bennett", "diona"])
        let without = try team(["fischl", "hu-tao", "bennett", "diona"])

        XCTAssertGreaterThan(withAnemo.resistanceShred[.pyro] ?? 0, 0,
                             "Viridescent Venerer should be stripping Pyro resistance")
        XCTAssertEqual(without.resistanceShred[.pyro] ?? 0, 0)
        XCTAssertNil(withAnemo.resistanceShred[.anemo],
                     "Anemo is not swirled, so it is never the element stripped")

        // And it reaches the damage: below zero the resistance curve only
        // halves, which is why stripping beats stacking a DMG bonus.
        XCTAssertLessThan(withAnemo.resistance(0.10, to: .pyro), 0.10)
        XCTAssertGreaterThan(
            AbyssDamageMath.resMultiplier(withAnemo.resistance(0.10, to: .pyro)),
            AbyssDamageMath.resMultiplier(0.10))
    }

    /// A named character's shred applies to their own element only, and two
    /// sources on one element take the larger rather than the sum.
    func testShredIsPerElementAndDoesNotStack() throws {
        let faruzan = try team(["faruzan", "xiao", "bennett", "diona"])
        XCTAssertGreaterThan(faruzan.resistanceShred[.anemo] ?? 0, 0,
                             "Faruzan's burst strips Anemo resistance; only the DMG half was modelled")

        let shenhe = try team(["shenhe", "ganyu", "bennett", "diona"])
        XCTAssertGreaterThan(shenhe.resistanceShred[.cryo] ?? 0, 0)

        // Kazuha and Sucrose both imply Viridescent Venerer; one shred, not two.
        let one = try team(["kaedehara-kazuha", "hu-tao", "bennett", "diona"])
        let two = try team(["kaedehara-kazuha", "sucrose", "hu-tao", "bennett"])
        XCTAssertEqual(one.resistanceShred[.pyro] ?? 0, two.resistanceShred[.pyro] ?? 0,
                       accuracy: 1e-9, "two Anemo characters stacked the same shred twice")
    }

    /// The shred moved out of `setEffectApprox` when it became real, so the two
    /// do not both pay for it.
    func testTheShredIsNotAlsoCountedAsADamageBonus() throws {
        let approximations = Dictionary(
            try tuning().setEffectApprox.map { ($0.setId, $0.damageBonus) },
            uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(approximations["deepwood-memories"], 0,
                       "Deepwood is nothing but its shred; the %DMG stand-in should be gone")
        XCTAssertLessThan(approximations["viridescent-venerer"] ?? 1, 0.25,
                          "Viridescent Venerer's %DMG should have dropped by the shred's share")
    }

    // MARK: - Lunar and Stellar reactions

    func testTheLunarAndStellarBlockIsRead() throws {
        let constants = library.damageConstants
        XCTAssertEqual(constants.lunarStellarEM, .init(numerator: 6, offset: 2000))
        for reaction: AbyssReaction in [.lunarBloom, .lunarCharged, .lunarCrystallize,
                                        .stellarSwirl, .stellarConduct] {
            XCTAssertNotNil(constants.lunarStellarCoefficients[reaction],
                            "\(reaction.rawValue) is still unpriced")
        }
        XCTAssertFalse(library.diagnostics.damageFormulaUnread.contains { $0.contains("lunarStellar") },
                       "\(library.diagnostics.damageFormulaUnread)")

        // Stellar-Conduct is a range in the data, placed on its ramp by tuning.
        let ramp = try tuning().stellarConductRamp
        XCTAssertEqual(try XCTUnwrap(constants.lunarStellarCoefficients[.stellarConduct]),
                       1 + ramp * (2 - 1), accuracy: 1e-9)
    }

    /// A Stellar Jubilee team unlocks both the plain reaction and its upgrade,
    /// and the pricing picks whichever the floor pays more for — which is the
    /// point of offering both.
    func testAStellarTeamUnlocksBothAndTheFloorDecides() throws {
        let context = try team(["odette", "fischl", "bennett", "diona"])
        XCTAssertTrue(context.stellarJubilee)
        XCTAssertTrue(context.transformativeReactions.isSuperset(of: [.superconduct, .stellarConduct]))

        let scorer = AbyssScorer(library: library, tuning: try tuning())
        func floor(_ buffs: [AbyssFloorBuff]) -> AbyssFloorContext {
            AbyssFloorContext(floor: 12, half: nil, monsterLevel: 100, resistances: [:],
                              buffs: buffs, shieldElements: [])
        }
        func buff(_ bonus: Double, _ reaction: AbyssReaction) -> AbyssFloorBuff {
            AbyssFloorBuff(bonus: bonus, elements: [], reactions: [reaction],
                           normalAttackOnly: false, raw: "test")
        }
        XCTAssertEqual(scorer.transformative(for: context, floor: floor([buff(3, .stellarConduct)]))?
                            .reaction, .stellarConduct)
        XCTAssertEqual(scorer.transformative(for: context, floor: floor([buff(3, .superconduct)]))?
                            .reaction, .superconduct)
    }

    /// A character who raises Lunar/Stellar base damage is worth something to a
    /// team even when they do nothing else — but only to the reactions the data
    /// says they raise.
    func testAReactionBaseDamageBonusReachesOnlyTheReactionsItNames() throws {
        let scorer = AbyssScorer(library: library, tuning: try tuning())
        let floor = AbyssFloorContext(floor: 12, half: nil, monsterLevel: 100, resistances: [:],
                                      buffs: [], shieldElements: [])
        let withSource = try team(["odette", "fischl", "diona", "bennett"])
        // `"Stellar-Conduct, Stellar Swirl"` in the data, and nothing else.
        XCTAssertGreaterThan(withSource.reactionBaseDamageBonus[.stellarConduct] ?? 0, 0,
                             "Odette is listed in reactionBaseDmgBonusSources")
        XCTAssertNil(withSource.reactionBaseDamageBonus[.lunarBloom],
                     "Odette's column names no Lunar reaction")
        XCTAssertNotNil(scorer.transformative(for: withSource, floor: floor))
    }

    /// This rotation's Stellar-Conduct clauses used to reach nothing at all.
    func testTheRotationsStellarClausesArePricedNow() throws {
        let cycle = try XCTUnwrap(library.latestCycle)
        var diagnostics = AbyssParseDiagnostics()
        _ = AbyssFloorContext.build(cycle: cycle, floor: 12, half: 1,
                                    ownElementResistance: try tuning().enemyOwnElementResistance,
                                    diagnostics: &diagnostics)
        XCTAssertTrue(diagnostics.floorBuffsNotPriced.isEmpty,
                      "still unpriced: \(diagnostics.floorBuffsNotPriced)")
    }

    // MARK: - Charged attacks the vocabulary could not see

    func testCharacterNamedChargedAttacksAreCounted() throws {
        for id in ["ganyu", "tighnari", "neuvillette", "yelan", "lyney", "arataki-itto",
                   "sigewinne", "yoimiya"] {
            let profile = try XCTUnwrap(library.profilesByCharacterID[id])
            XCTAssertNotNil(profile.aggregate.first { $0.category == .charged },
                            "\(id) has no charged attack at all")
        }
        // Neuvillette's is the one that also had to find its basis in the label.
        let neuvillette = try XCTUnwrap(library.profilesByCharacterID["neuvillette"])
        XCTAssertEqual(neuvillette.aggregate.first { $0.category == .charged }?.basis, .hp)
    }

    /// Every entry in the table has to still match a row, or it is quietly doing
    /// nothing after a data update.
    func testEveryChargedLabelStillMatchesARow() throws {
        for entry in library.traitsByCharacterID.values {
            guard let charged = entry.chargedAttackLabels else { continue }
            let character = try XCTUnwrap(library.charactersByID[entry.characterId],
                                          "\(entry.characterId) is no longer in the data")
            for label in charged.labels {
                XCTAssertTrue(character.normalAttack.hits.contains {
                    $0.label.range(of: label, options: .caseInsensitive) != nil
                }, "\(entry.characterId): no row matches \"\(label)\" any more")
            }
        }
    }

    /// What is still falling through, kept visible rather than silent.
    func testTheRowsStillUnclassifiedAreKnownOnes() throws {
        let unclassified = library.diagnostics.normalAttackRowsUnclassified
        XCTAssertFalse(unclassified.contains { $0.hasPrefix("ganyu") },
                       "Ganyu's Frostflake Arrow is classified now")
        XCTAssertLessThanOrEqual(unclassified.count, 8,
                                 "more rows are falling through than before: \(unclassified.sorted())")
    }
}
