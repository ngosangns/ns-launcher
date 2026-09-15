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
                                   bondOfLifeIDs: library.bondOfLifeIDs,
                                   weaponBuffs: library.weaponBuffsByID, setBuffs: library.setBuffsByID)
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
    /// Set bonuses are structured buffs now and leave reaction damage out; the
    /// name routing still reads the character data, and still refuses.
    func testReactionDamageIsNotAHitBonus() throws {
        let tuning = try tuning()
        for name in ["Stellar Swirl DMG", "Party Stellar Glimmer DMG Bonus", "Lunar-Charged DMG Bonus",
                     "Overloaded DMG", "Swirl DMG"] {
            XCTAssertEqual(AbyssBuildAssembler.resolve(named: name, value: 0.4, tuning: tuning).count, 0,
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
        // Four pieces of Bloodstained wait on a defeated opponent, which a
        // single-target rotation never has.
        XCTAssertEqual(try wearing(["bloodstained-chivalry"], on: "diluc").dmgCharged, 0, accuracy: 1e-12)
    }

    /// "Party Incoming Healing" and "Party Shield Strength" say party and are
    /// not damage; they used to reach the party as +20% and +30% DMG.
    func testPartyHealingAndShieldAreNotPartyDamage() throws {
        let tuning = try tuning()
        for name in ["Party Incoming Healing", "Party Shield Strength"] {
            XCTAssertTrue(AbyssBuildAssembler.resolve(named: name, value: 0.3, tuning: tuning).isEmpty,
                          "\"\(name)\" was priced")
        }
        XCTAssertEqual(try wearing(["tenacity-of-the-millelith"], on: "zhongli").partyDMG, 0, accuracy: 1e-12)
        XCTAssertEqual(try wearing(["maiden-beloved"], on: "bennett").partyDMG, 0, accuracy: 1e-12)
        // What they do grant still arrives.
        XCTAssertGreaterThan(try wearing(["tenacity-of-the-millelith"], on: "zhongli").partyATKPercent, 0)
    }

    /// A bonus against afflicted enemies is not on the sheet until the team
    /// says the aura is there: it waits in a gate instead of arriving at a
    /// guessed 60%.
    func testABonusAgainstAnAuraWaitsOnTheTeam() throws {
        let thundersoother = try wearing(["thundersoother"], on: "bennett")
        XCTAssertEqual(thundersoother.dmgAll, 0, accuracy: 1e-12)
        XCTAssertEqual(thundersoother.gates.count, 1)
        XCTAssertEqual(thundersoother.gates[0].value, 0.35, accuracy: 1e-12)
        var electro = AbyssTeamConditions.zero
        electro[AbyssTeamCondition.auraFirst.rawValue + GenshinElement.electro.simdIndex] = 1
        XCTAssertEqual(thundersoother.gates[0].factor(electro), 1)
        XCTAssertEqual(thundersoother.gates[0].factor(.zero), 0)
    }

    // MARK: - Timelines

    /// Shimenawa's +50% lasts 10s after a skill: worth what that window covers
    /// of the attacks, and never counted twice.
    func testShimenawaIsWorthItsWindow() throws {
        let stats = try wearing(["shimenawas-reminiscence"], on: "hu-tao")
        XCTAssertGreaterThan(stats.dmgNormal, 0)
        XCTAssertLessThanOrEqual(stats.dmgNormal, 0.5 + 1e-12)
        XCTAssertEqual(stats.dmgNormal, stats.dmgCharged, accuracy: 1e-12)
        XCTAssertEqual(stats.dmgSkill, 0, accuracy: 1e-12)
        // The two-piece still applies in full.
        XCTAssertEqual(stats.atkPercent, 0.18, accuracy: 1e-12)
    }

    /// Obsidian Codex's +40% CRIT Rate reached every wearer; it needs
    /// Nightsoul's Blessing, which only Natlan characters have.
    func testNightsoulSetsNeedNightsoul() throws {
        let bennett = try wearing(["obsidian-codex"], on: "bennett")
        XCTAssertEqual(bennett.critRate, AbyssStats().critRate, accuracy: 1e-12,
                       "a non-Natlan wearer got Obsidian Codex's CRIT Rate")
        XCTAssertEqual(bennett.dmgNormal, 0, accuracy: 1e-12)
        XCTAssertGreaterThan(try wearing(["obsidian-codex"], on: "mavuika").dmgNormal, 0)
    }

    /// An effect that raises one element's DMG lands in that element's lane,
    /// where only that element's hits read it.
    func testAnElementBonusLandsInItsLane() throws {
        let bennett = try wearing(["crimson-witch-of-flames"], on: "bennett")
        XCTAssertGreaterThan(bennett.elementalDMG[GenshinElement.pyro.simdIndex], 0.15)
        XCTAssertEqual(bennett.dmgAll, 0, accuracy: 1e-12)
        XCTAssertEqual(try wearing(["husk-of-opulent-dreams"], on: "xingqiu").dmgAll, 0, accuracy: 1e-12)
    }

    /// Fragment of Harmonic Whimsy triggers on the wearer's Bond of Life, and
    /// was the best set for 27 characters who have none. The Bond of Life
    /// characters are the ones whose own talent text grants it.
    func testBondOfLifeSetsRequireBondOfLife() throws {
        XCTAssertEqual(library.bondOfLifeIDs, ["arlecchino", "clorinde", "sigewinne"])
        XCTAssertEqual(try wearing(["fragment-of-harmonic-whimsy"], on: "bennett").dmgAll, 0, accuracy: 1e-12)
        XCTAssertGreaterThan(try wearing(["fragment-of-harmonic-whimsy"], on: "arlecchino").dmgAll, 0)
        // Blizzard Strayer's CRIT Rate waits on a Cryo aura rather than on the
        // wearer being Cryo.
        XCTAssertEqual(try wearing(["blizzard-strayer"], on: "ganyu").critRate, AbyssStats().critRate,
                       accuracy: 1e-12)
        XCTAssertEqual(try wearing(["blizzard-strayer"], on: "ganyu").gates.count, 1)
    }

    /// VV and Thundering Fury are reaction sets and add nothing to their
    /// wearer's hits.
    func testReactionSetsAddNothingToAHit() throws {
        for id in ["viridescent-venerer", "thundering-fury"] {
            let stats = try wearing([id], on: "xingqiu")
            XCTAssertEqual(stats.dmgAll, 0, accuracy: 1e-12, "\(id) raised its wearer's hits")
            XCTAssertEqual(stats.gates.count, 0)
        }
    }

    // MARK: - The whole data

    /// The guard against the whole class: no set, worn by a character it does
    /// not specially favour, adds more than +40% to every hit. Before these
    /// fixes Scarlet Proof added +70% and Bloodstained + Pale Flame +50%.
    func testNoSetAddsAnImplausibleAllDamageBonus() throws {
        for set in library.artifactSets {
            let four = try wearing([set.id], on: "bennett")
            let pair = try wearing([set.id, set.id], on: "bennett")
            XCTAssertLessThanOrEqual(four.dmgAll + four.partyDMG, 0.4, "\(set.id): four pieces add too much")
            XCTAssertLessThanOrEqual(pair.dmgAll + pair.partyDMG, 0.25, "\(set.id): two pieces add too much")
        }
    }
}
