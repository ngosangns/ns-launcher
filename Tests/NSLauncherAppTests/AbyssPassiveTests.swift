// AbyssPassiveTests.swift
//
// Weapon passives and set bonuses as structured buffs (`passives.json` against
// `passive-text.json`), and what `AbyssBuffTimeline` makes of them — Phase 5 of
// docs/redesign.md.

import XCTest
@testable import NSLauncherApp

final class AbyssPassiveTests: XCTestCase {
    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func buffs(_ weaponID: String) throws -> [AbyssBuff] {
        try XCTUnwrap(library.weaponBuffsByID[weaponID], "\(weaponID) has no buffs")
    }

    // MARK: - Resolution

    /// Every value is a number the game text writes, every duration and stack
    /// count too, and every weapon and set with text has an entry.
    func testEveryReferenceResolves() {
        XCTAssertEqual(library.diagnostics.passiveReferencesUnresolved.sorted(), [])
    }

    /// The prose summary the model used to read had The Catch at 12% Burst DMG
    /// and routed its Burst CRIT Rate into every hit. The game says 16%, rising
    /// to 32% at R5, and the CRIT Rate is the burst's alone.
    func testRefinementsAreReadFromTheGameTextsColumns() throws {
        let theCatch = try buffs("the-catch")
        let damage = try XCTUnwrap(theCatch.first { $0.stat == .dmg })
        XCTAssertEqual(damage.on, .burst)
        XCTAssertEqual(damage.value(refinement: 1), 0.16, accuracy: 1e-9)
        XCTAssertEqual(damage.value(refinement: 5), 0.32, accuracy: 1e-9)
        let crit = try XCTUnwrap(theCatch.first { $0.stat == .critRate })
        XCTAssertEqual(crit.on, .burst)
        XCTAssertEqual(crit.value(refinement: 5), 0.12, accuracy: 1e-9)
    }

    /// A tag holding a list is read as tiers, per refinement.
    func testTieredValuesAreReadPerRefinement() throws {
        let emblem = try XCTUnwrap(buffs("mistsplitter-reforged").first { !$0.tiers.isEmpty })
        XCTAssertEqual(emblem.tiers(refinement: 1), [0.08, 0.16, 0.28])
        XCTAssertEqual(emblem.tiers(refinement: 5).last ?? 0, 0.56, accuracy: 1e-9)
    }

    /// Weapons the old data had no lines for at all.
    func testWeaponsTheSummaryMissedArePriced() throws {
        XCTAssertFalse(try buffs("the-widsith").isEmpty)
        XCTAssertFalse(try buffs("the-stringless").isEmpty)
        XCTAssertFalse(try buffs("wandering-evenstar").isEmpty)
    }

    /// No sheet a search can build overflows the fixed gate and conversion
    /// slots: an overflow would drop a buff silently.
    func testNoWeaponOrSetOverflowsTheFixedSlots() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                            bondOfLifeIDs: library.bondOfLifeIDs,
                                            weaponBuffs: library.weaponBuffsByID, setBuffs: library.setBuffsByID)
        let wearer = AbyssBuffWearer.standIn
        for set in library.fiveStarArtifactSets {
            for (weaponID, weapon) in library.weaponBuffsByID {
                var stats = AbyssStats()
                assembler.apply(weapon, refinement: 5, wearer: wearer, to: &stats)
                assembler.apply(library.setBuffsByID[set.id]?.twoPiece ?? [], refinement: 1, wearer: wearer,
                                to: &stats)
                assembler.apply(library.setBuffsByID[set.id]?.fourPiece ?? [], refinement: 1, wearer: wearer,
                                to: &stats)
                XCTAssertEqual(stats.conversions.overflow, 0, "\(weaponID) + \(set.id)")
                stats.foldConversions()
                XCTAssertEqual(stats.gates.overflow, 0, "\(weaponID) + \(set.id)")
            }
        }
    }

    // MARK: - Timeline

    private func buff(_ conditions: [AbyssBuff.Condition], duration: Double? = nil, stacks: Int = 1,
                      cooldown: Double? = nil) -> AbyssBuff {
        AbyssBuff(stat: .dmg, values: [0.1], tiers: [], caps: [], source: nil, per: 1, on: [], scope: .wearer,
                  conditions: conditions, duration: duration, stacks: stacks, cooldown: cooldown, scale: 1,
                  group: nil)
    }

    private var attacker: AbyssBuffWearer {
        var wearer = AbyssBuffWearer.standIn
        wearer.weights = SIMD4(0.6, 0.2, 0.1, 0.1)
        wearer.skillCasts = 2
        wearer.burstCasts = 1
        wearer.hitsPerSkill = 1
        wearer.hitsPerBurst = 6
        return wearer
    }

    /// A buff for 6s after each of two skills covers the attack time that
    /// follows them, and the skill's own hits entirely.
    func testACastBuffCoversTheAttacksThatFollowIt() {
        let reading = AbyssBuffTimeline.read(buff([.cast(.skill)], duration: 6), wearer: attacker)
        // Attack time is 80% of 20s = 16s; two casts × 6s cover 12s of it.
        XCTAssertEqual(reading.stacks[0], 12.0 / 16, accuracy: 1e-9)
        XCTAssertEqual(reading.stacks[2], 1, accuracy: 1e-9)
        XCTAssertEqual(reading.rotation, 12.0 / 20, accuracy: 1e-9)
    }

    /// A stack per hit is worth nothing to a one-hit skill's own damage and
    /// most of its stacks to a six-hit burst.
    func testHitStacksRampOverACastsHits() {
        let reading = AbyssBuffTimeline.read(buff([.hit([.skill, .burst], elemental: false)], duration: 1,
                                                  stacks: 3), wearer: attacker)
        XCTAssertEqual(reading.stacks[3], (0.0 + 1 + 2 + 3 + 3 + 3) / 6, accuracy: 1e-9)
        XCTAssertLessThan(reading.stacks[2], 1)
    }

    /// A buff with a duration and a cooldown and no timing of its own is up
    /// for that share: Sapwood Blade's leaf, 12s per 20s.
    func testDurationOverCooldownCapsAnUntimedBuff() {
        let reading = AbyssBuffTimeline.read(buff([.reaction], duration: 12, cooldown: 20), wearer: attacker)
        XCTAssertEqual(reading.rotation, 0.6, accuracy: 1e-9)
        XCTAssertNotEqual(reading.all, 0, "a reaction waits on the team")
    }

    /// Facts about the wearer decide at once; a single-target rotation at full
    /// HP never defeats anything or drops below a threshold.
    func testWearerFactsAndRotationDefaults() {
        XCTAssertTrue(AbyssBuffTimeline.read(buff([.nightsoul]), wearer: attacker).isOff)
        var natlan = attacker
        natlan.nightsoul = true
        XCTAssertFalse(AbyssBuffTimeline.read(buff([.nightsoul]), wearer: natlan).isOff)
        XCTAssertTrue(AbyssBuffTimeline.read(buff([.defeat]), wearer: attacker).isOff)
        XCTAssertTrue(AbyssBuffTimeline.read(buff([.hpBelow]), wearer: attacker).isOff)
        XCTAssertFalse(AbyssBuffTimeline.read(buff([.hpAbove]), wearer: attacker).isOff)
        XCTAssertTrue(AbyssBuffTimeline.read(buff([.enemiesAtLeast(2)]), wearer: attacker).isOff)
    }

    // MARK: - Gates

    func testTeamConditionsPackCountsAndFlags() {
        var conditions = AbyssTeamConditions.zero
        conditions[AbyssTeamCondition.shield.rawValue] = 1
        conditions[AbyssTeamCondition.otherElement.rawValue] = 3
        conditions[AbyssTeamCondition.members(.dendro)] = 2
        XCTAssertEqual(conditions[AbyssTeamCondition.shield.rawValue], 1)
        XCTAssertEqual(conditions[AbyssTeamCondition.otherElement.rawValue], 3)
        XCTAssertEqual(conditions[AbyssTeamCondition.members(.dendro)], 2)
        XCTAssertEqual(conditions[AbyssTeamCondition.healed.rawValue], 0)
    }

    /// A gate on an aura opens for either element; a per-member gate counts,
    /// capped at the effect's stacks; an at-least gate is all or nothing.
    func testGateFactors() {
        var conditions = AbyssTeamConditions.zero
        conditions[AbyssTeamCondition.auraFirst.rawValue + GenshinElement.hydro.simdIndex] = 1
        conditions[AbyssTeamCondition.otherElement.rawValue] = 3

        let aura = AbyssGate(value: 1, any: AbyssTeamCondition.aura(.pyro) | AbyssTeamCondition.aura(.hydro))
        XCTAssertEqual(aura.factor(conditions), 1)
        XCTAssertEqual(AbyssGate(value: 1, any: AbyssTeamCondition.aura(.pyro)).factor(conditions), 0)

        let perMember = AbyssGate(value: 1, limit: -2, all: AbyssTeamCondition.otherElement.bit)
        XCTAssertEqual(perMember.factor(conditions), 2)
        XCTAssertEqual(AbyssGate(value: 1, limit: 3, all: AbyssTeamCondition.otherElement.bit).factor(conditions), 1)
        XCTAssertEqual(AbyssGate(value: 1, limit: 4, all: AbyssTeamCondition.otherElement.bit).factor(conditions), 0)
    }

    /// "Other party members" counts the team without the wearer.
    func testTeamConditionsCountTheOtherMembers() throws {
        let members = try ["xiangling", "bennett", "xingqiu", "sucrose"].map {
            try XCTUnwrap(library.charactersByID[$0])
        }
        let team = AbyssTeamContext.build(members: members, library: library)
        let conditions = team.conditions(for: members[0])
        XCTAssertEqual(conditions[AbyssTeamCondition.sameElement.rawValue], 1)
        XCTAssertEqual(conditions[AbyssTeamCondition.otherElement.rawValue], 2)
        XCTAssertEqual(conditions[AbyssTeamCondition.reaction.rawValue], 1)
        XCTAssertEqual(conditions[AbyssTeamCondition.distinctElements.rawValue], 3)
        XCTAssertEqual(conditions[AbyssTeamCondition.liyue.rawValue], 1, "Xingqiu is the other Liyue member")
    }

    /// The buff to "party members other than the wearer" reaches the party and
    /// is taken back out of the wearer's own sheet.
    func testAnOthersBuffSkipsTheWearer() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs)
        var stats = AbyssStats()
        let floatingDreams = try buffs("a-thousand-floating-dreams").filter { $0.scope == .others }
        XCTAssertEqual(floatingDreams.count, 1)
        assembler.apply(floatingDreams, refinement: 1, wearer: .standIn, to: &stats)
        XCTAssertEqual(stats.partyElementalMastery, 40, accuracy: 1e-9)
        XCTAssertEqual(stats.elementalMastery, -40, accuracy: 1e-9)
    }
}
