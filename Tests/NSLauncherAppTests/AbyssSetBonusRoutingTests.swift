import XCTest
@testable import NSLauncherApp

/// Where an artifact set's bonuses land, pinned one failure at a time.
///
/// Every test here is a bug found on 2026-09-16 by running floor 12 over the
/// whole character pool instead of the example roster: Scarlet Proof was the
/// best set for 95 of 125 characters, and once that was removed every
/// character wore Bloodstained Chivalry + Pale Flame. Neither was a judgment
/// about sets. Both were names routed to "+% DMG on every hit" that are not
/// that — and the golden fixture, recorded on a 15-character roster, never
/// showed it.
final class AbyssSetBonusRoutingTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func assembler() throws -> AbyssBuildAssembler {
        let tuning = try XCTUnwrap(library.tuning)
        return AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                   artifactSets: library.artifactSets, bondOfLifeIDs: library.bondOfLifeIDs)
    }

    private func tuning() throws -> AbyssTuning { try XCTUnwrap(library.tuning) }

    /// The sheet a set adds to a bare character, and nothing else.
    private func wearing(_ setIDs: [String], on characterID: String) throws -> AbyssStats {
        let assembler = try assembler()
        let character = try XCTUnwrap(library.charactersByID[characterID])
        let sets = try setIDs.map { try XCTUnwrap(library.artifactSetsByID[$0], "\($0) is not a set") }
        var stats = AbyssStats()
        var diagnostics = AbyssParseDiagnostics()
        assembler.applySets(sets, character: character, to: &stats, diagnostics: &diagnostics)
        return stats
    }

    // MARK: - Names that are not a hit's damage

    /// "Stellar Swirl DMG +40%" is reaction damage. It used to fall through to
    /// the catch-all for anything mentioning DMG and become +40% to every hit.
    func testReactionDamageIsNotAHitBonus() throws {
        let tuning = try tuning()
        for name in ["Stellar Swirl DMG", "Party Stellar Glimmer DMG Bonus", "Lunar-Charged DMG Bonus",
                     "Overloaded DMG", "Swirl DMG"] {
            XCTAssertEqual(AbyssBuildAssembler.resolve(named: name, value: 0.4, conditional: false, tuning: tuning).count, 0,
                           "\"\(name)\" reached a hit's damage")
            XCTAssertEqual(AbyssBuildAssembler.unpriced(named: name), "reaction")
        }
    }

    /// No hit in any profile is physical, so a Physical DMG bonus buys nothing.
    /// It used to be `dmgAll`, which made Bloodstained Chivalry + Pale Flame
    /// +50% to every hit of every character.
    func testPhysicalDamageBuysNothing() throws {
        let stats = try wearing(["bloodstained-chivalry", "pale-flame"], on: "bennett")
        XCTAssertEqual(stats.dmgAll, 0, accuracy: 1e-12)
        XCTAssertEqual(AbyssBuildAssembler.unpriced(named: "Physical DMG"), "physical")
    }

    /// "Party Incoming Healing" and "Party Shield Strength" say party and are
    /// not damage; they used to reach the party as +20% and +30% DMG.
    func testPartyHealingAndShieldAreNotPartyDamage() throws {
        let tuning = try tuning()
        for name in ["Party Incoming Healing", "Party Shield Strength"] {
            XCTAssertTrue(AbyssBuildAssembler.resolve(named: name, value: 0.3, conditional: false, tuning: tuning).isEmpty,
                          "\"\(name)\" was priced")
        }
        XCTAssertEqual(try wearing(["tenacity-of-the-millelith"], on: "zhongli").partyDMG, 0, accuracy: 1e-12)
        XCTAssertEqual(try wearing(["maiden-beloved"], on: "bennett").partyDMG, 0, accuracy: 1e-12)
        // What they do grant still arrives.
        XCTAssertGreaterThan(try wearing(["tenacity-of-the-millelith"], on: "zhongli").partyATKPercent, 0)
    }

    /// The catch-all is gone; the bonuses to every hit are named shapes, and a
    /// condition in the name makes them conditional.
    func testAnAllDamageBonusIsANamedShape() throws {
        let tuning = try tuning()
        let plain = AbyssBuildAssembler.resolve(named: "DMG Bonus", value: 0.2, conditional: false, tuning: tuning)
        XCTAssertEqual(plain.first?.field, .dmgAll)
        XCTAssertTrue(AbyssBuildAssembler.isConditional("DMG vs Electro-afflicted enemies"))
        XCTAssertTrue(AbyssBuildAssembler.isConditional("DMG (while Nightsoul's Blessing active, on-field)"))
        let thundersoother = try wearing(["thundersoother"], on: "bennett")
        XCTAssertEqual(thundersoother.dmgAll, 0.35 * tuning.conditionalUptime, accuracy: 1e-12,
                       "a bonus against afflicted enemies is conditional")
        XCTAssertTrue(AbyssBuildAssembler.resolve(named: "Normal Attack SPD", value: 0.1, conditional: false,
                                                  tuning: tuning).isEmpty)
    }

    // MARK: - Approximations

    /// A set with a hand-written approximation has it instead of its parsed
    /// four-piece bonuses. Shimenawa's Normal Attack DMG used to be 0.5 + 0.35.
    func testAnApproximationReplacesTheParsedFourPiece() throws {
        let tuning = try tuning()
        let shimenawa = try XCTUnwrap(tuning.setEffectApprox.first { $0.setId == "shimenawas-reminiscence" })
        let stats = try wearing(["shimenawas-reminiscence"], on: "hu-tao")
        XCTAssertEqual(stats.dmgNormal, shimenawa.damageBonus, accuracy: 1e-12)
        XCTAssertEqual(stats.dmgCharged, 0, accuracy: 1e-12)
        // The two-piece still applies in full.
        XCTAssertEqual(stats.atkPercent, 0.18, accuracy: 1e-12)
    }

    /// Obsidian Codex's +40% CRIT Rate reached every wearer, although the
    /// approximation that stands for it requires a Natlan character.
    func testARequirementGatesTheWholeFourPiece() throws {
        let bennett = try wearing(["obsidian-codex"], on: "bennett")
        XCTAssertEqual(bennett.critRate, AbyssStats().critRate, accuracy: 1e-12,
                       "a non-Natlan wearer got Obsidian Codex's CRIT Rate")
        let tuning = try tuning()
        XCTAssertEqual(bennett.dmgAll, 0.15 * tuning.conditionalUptime, accuracy: 1e-12,
                       "the four-piece added something beyond the two-piece for a non-Natlan wearer")
        XCTAssertGreaterThan(try wearing(["obsidian-codex"], on: "mavuika").dmgAll,
                             try wearing(["obsidian-codex"], on: "bennett").dmgAll)
    }

    /// An effect that raises one element's DMG requires a wearer of it.
    func testAnElementBonusRequiresThatElement() throws {
        XCTAssertGreaterThan(try wearing(["crimson-witch-of-flames"], on: "bennett").dmgAll, 0)
        XCTAssertEqual(try wearing(["crimson-witch-of-flames"], on: "xingqiu").dmgAll, 0, accuracy: 1e-12)
        XCTAssertEqual(try wearing(["husk-of-opulent-dreams"], on: "xingqiu").dmgAll, 0, accuracy: 1e-12)
    }

    /// Fragment of Harmonic Whimsy triggers on the wearer's Bond of Life, and
    /// was the best set for 27 characters who have none. The Bond of Life
    /// characters are the ones whose own talent text grants it.
    func testBondOfLifeSetsRequireBondOfLife() throws {
        XCTAssertEqual(library.bondOfLifeIDs, ["arlecchino", "clorinde", "sigewinne"])
        XCTAssertEqual(try wearing(["fragment-of-harmonic-whimsy"], on: "bennett").dmgAll, 0, accuracy: 1e-12)
        XCTAssertGreaterThan(try wearing(["fragment-of-harmonic-whimsy"], on: "arlecchino").dmgAll, 0)
        XCTAssertEqual(try wearing(["blizzard-strayer"], on: "bennett").dmgAll, 0, accuracy: 1e-12)
        XCTAssertGreaterThan(try wearing(["blizzard-strayer"], on: "ganyu").dmgAll, 0)
    }

    /// No approximation prices reaction damage as a hit's: VV and Thundering
    /// Fury are reaction sets and add nothing to their wearer's hits.
    func testReactionSetsAddNothingToAHit() throws {
        for id in ["viridescent-venerer", "thundering-fury"] {
            let stats = try wearing([id], on: "xingqiu")
            XCTAssertEqual(stats.dmgAll, 0, accuracy: 1e-12, "\(id) raised its wearer's hits")
        }
    }

    // MARK: - The whole data

    /// The guard against the whole class: no set, worn four-piece by a
    /// character it does not specially favour, adds more than +40% to every
    /// hit. Before these fixes Scarlet Proof added +70% and Bloodstained +
    /// Pale Flame +50%.
    func testNoSetAddsAnImplausibleAllDamageBonus() throws {
        let tuning = try tuning()
        for set in library.artifactSets {
            let four = try wearing([set.id], on: "bennett")
            let pair = try wearing([set.id, set.id], on: "bennett")
            XCTAssertLessThanOrEqual(four.dmgAll + four.partyDMG, 0.4, "\(set.id): four pieces add too much")
            XCTAssertLessThanOrEqual(pair.dmgAll + pair.partyDMG, 0.25, "\(set.id): two pieces add too much")
        }
        XCTAssertNil(tuning.setEffectApprox.first { $0.setId == "noblesse-oblige" },
                     "Noblesse's approximation only repeated its two-piece Burst DMG")
    }
}
