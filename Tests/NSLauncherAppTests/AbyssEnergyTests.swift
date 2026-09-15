import XCTest
@testable import NSLauncherApp

/// Energy, Phase 3 of `docs/redesign.md`: bursts are cast as often as energy
/// and cooldown allow, and Energy Recharge is worth what that buys.
///
/// Three groups: the data joins (every particle count resolves or is named),
/// the rules (a particle's value by element and by who is on field), and the
/// payoff — Energy Recharge moves a score until the burst is funded and then
/// stops, and a support's burst buff moves with it.
final class AbyssEnergyTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func scorer() throws -> AbyssScorer {
        AbyssScorer(library: library, tuning: try XCTUnwrap(library.tuning))
    }

    private func characters(_ ids: [String]) throws -> [AbyssCharacter] {
        try ids.map { try XCTUnwrap(library.charactersByID[$0], "\($0) is not in the data") }
    }

    // MARK: - The data

    /// Every character has an energy economy, and the ones standing in with the
    /// median are named: the seven Travelers (no structured talents, no wiki
    /// page of their own) and the three whose page carries no particle note
    /// and who are not in gcsim either. A new name here is a character the
    /// sync or a kit lost; one vanishing is a gap somebody closed.
    func testEveryCharacterHasAnEnergyProfileAndTheEstimatesAreKnown() {
        XCTAssertEqual(library.energyByCharacterID.count, library.characters.count)
        let known: Set<String> = [
            "linnea", "lohen", "zibai",
            "traveler-anemo", "traveler-cryo", "traveler-dendro", "traveler-electro",
            "traveler-geo", "traveler-hydro", "traveler-pyro",
        ]
        let estimated = library.diagnostics.particlesEstimated
        XCTAssertEqual(estimated, known,
                       "new: \(estimated.subtracting(known).sorted()) gone: \(known.subtracting(estimated).sorted())")
        XCTAssertGreaterThan(library.medianParticlesPerCast, 0)
    }

    /// The costs and cooldowns are the game's own, not a default.
    func testBurstCostsComeFromTheTalentTables() throws {
        XCTAssertEqual(library.energyByCharacterID["bennett"]?.burstCost, 60)
        XCTAssertEqual(library.energyByCharacterID["raiden-shogun"]?.burstCost, 90)
        XCTAssertEqual(library.energyByCharacterID["xiangling"]?.burstCost, 80)
        // The Travelers read theirs from the transcription.
        XCTAssertGreaterThan(library.energyByCharacterID["traveler-anemo"]?.burstCost ?? 0, 0)
    }

    /// Each kit field means something only against a particular kind of wiki
    /// note, and an entry used against the wrong kind is dead or silently
    /// double-counting: a literal where the page has a note, a hold variant
    /// where the note has one number, a per-event note with no event count.
    func testEveryKitEnergyFieldMatchesTheNoteItReads() throws {
        for kit in library.kitsByCharacterID.values {
            let readings = library.particles?.characters[kit.characterId]?.readings ?? []
            guard let energy = kit.energy else { continue }
            XCTAssertFalse(energy.note.isEmpty, "\(kit.characterId): energy has no note")
            if energy.particlesPerCast != nil {
                XCTAssertTrue(readings.isEmpty,
                              "\(kit.characterId): a literal particle count overrides a wiki note")
            }
            if energy.variant == .hold {
                XCTAssertNotNil(readings.first?.hold, "\(kit.characterId): plays hold but the note has no hold")
            }
            if readings.first?.perEvent != nil {
                XCTAssertNotNil(energy.eventsPerCast ?? energy.particlesPerCast,
                                "\(kit.characterId): a per-event note with no eventsPerCast")
            }
        }
        // And the other direction: no character reads a per-event note bare,
        // except the ones already named as estimates — Lohen and Zibai, whose
        // events ("any attack under Masterstroke") have no cadence in either
        // the table or gcsim to count them by.
        let estimated = library.diagnostics.particlesEstimated
        for (id, entry) in library.particles?.characters ?? [:]
        where entry.readings.first?.perEvent != nil && !estimated.contains(id) {
            XCTAssertNotNil(library.kitsByCharacterID[id]?.energy?.eventsPerCast,
                            "\(id): \"\(entry.readings.first?.perEvent?.event ?? "")\" needs eventsPerCast")
        }
    }

    // MARK: - The rules

    /// A particle of your own element is worth three of another's, and off
    /// field you receive `offFieldShare` of it. Checked on a team whose numbers
    /// can be worked out by hand from the profiles.
    func testParticleValueByElementAndField() throws {
        let scorer = try scorer()
        let rules = try XCTUnwrap(library.tuning).energy
        let members = try characters(["bennett", "xiangling"])
        let bennett = try XCTUnwrap(library.energyByCharacterID["bennett"])
        let xiangling = try XCTUnwrap(library.energyByCharacterID["xiangling"])
        XCTAssertEqual(bennett.collector, .caster)
        XCTAssertEqual(xiangling.collector, .field)

        let rotations = scorer.rotations(for: members)
        let enemy = rules.enemyClearParticlesPerRotation * rules.clearParticle
        // Bennett: his own presses land on him; Guoba's land on whoever is on field.
        let same = rules.sameElementParticle
        XCTAssertEqual(rotations[0].energyOffField,
                       bennett.particlesPerRotation * same
                           + (xiangling.particlesPerRotation * same + enemy) * rules.offFieldShare,
                       accuracy: 1e-9)
        XCTAssertEqual(rotations[0].energyOnField,
                       bennett.particlesPerRotation * same + xiangling.particlesPerRotation * same + enemy,
                       accuracy: 1e-9)
        // Xiangling: Bennett's presses reach her off field whoever is on it.
        XCTAssertEqual(rotations[1].energyOffField,
                       bennett.particlesPerRotation * same * rules.offFieldShare
                           + (xiangling.particlesPerRotation * same + enemy) * rules.offFieldShare,
                       accuracy: 1e-9)
    }

    /// Another element's particles are worth `otherElementParticle`.
    func testOffElementParticlesAreWorthLess() throws {
        let scorer = try scorer()
        let samePyro = scorer.rotations(for: try characters(["xiangling", "bennett"]))[0]
        let hydro = scorer.rotations(for: try characters(["xiangling", "xingqiu"]))[0]
        XCTAssertGreaterThan(samePyro.energyOffField, hydro.energyOffField,
                             "Bennett's Pyro particles should be worth more to Xiangling than Xingqiu's Hydro")
    }

    // MARK: - The payoff

    /// Energy Recharge buys bursts until the cooldown is the limit, and then
    /// buys nothing.
    func testEnergyRechargeBuysBurstsUntilTheCooldownCaps() throws {
        let rotation = try scorer().soloRotation(for: try characters(["raiden-shogun"])[0])
        let starved = rotation.burstCasts(energyRecharge: 1.0, onField: true)
        let fed = rotation.burstCasts(energyRecharge: 2.5, onField: true)
        XCTAssertLessThan(starved, fed)
        XCTAssertEqual(rotation.burstCasts(energyRecharge: 10, onField: true), rotation.burstCap, accuracy: 1e-12)
        XCTAssertEqual(rotation.burstCasts(energyRecharge: 20, onField: true), rotation.burstCap, accuracy: 1e-12)
    }

    /// The score sees it. Raiden's damage is her burst and her burst-window
    /// attack string, so Energy Recharge is a damage stat on her — the thing
    /// the old model could not express, and the reason the Energy Recharge
    /// sands used to be forced onto supports rather than searched.
    func testEnergyRechargeRaisesABurstCarrysScore() throws {
        let scorer = try scorer()
        let raiden = try characters(["raiden-shogun"])[0]
        let context = scorer.soloContext(for: raiden)
        var stats = AbyssStats()
        stats.baseATK = 1000
        stats.critRate = 0.6
        stats.critDMG = 1.2
        var fed = stats
        fed.energyRecharge = 2.5
        XCTAssertGreaterThan(scorer.soloScore(context: context, stats: fed),
                             scorer.soloScore(context: context, stats: stats) * 1.05)
    }

    /// A support's burst buff is worth what their energy buys: Bennett with no
    /// Energy Recharge to speak of hands his carry less ATK than Bennett with
    /// plenty — through the party channel, not his own damage.
    func testABurstBuffScalesWithTheBuffersEnergy() throws {
        let scorer = try scorer()
        let members = try characters(["hu-tao", "bennett"])
        let team = AbyssTeamContext.build(members: members, library: library)
        let context = scorer.teamDamageContext(members: members, floor: .neutral, team: team)
        var bennett = AbyssStats()
        bennett.baseATK = 800
        bennett.burstPartyFlatATK = 800
        bennett.energyRecharge = 0.5
        var fed = bennett
        fed.energyRecharge = 3
        let carry = AbyssStats()

        let starved = scorer.partyBuffs(stats: [carry, bennett], setIDs: [[], []], resonance: .none,
                                        members: context.members)
        let funded = scorer.partyBuffs(stats: [carry, fed], setIDs: [[], []], resonance: .none,
                                       members: context.members)
        XCTAssertLessThan(starved.flatATK, funded.flatATK)
        XCTAssertEqual(funded.flatATK, 800 * context.members[1].rotation.burstCap, accuracy: 1e-9)
    }

    /// Supports search their sands like everyone else now; only the healer's
    /// circlet is still pinned, because the score still cannot see a heal.
    func testSupportsAreNoLongerPinnedToEnergyRechargeSands() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs)
        for role in [AbyssRole.support, .shield] {
            let sands = assembler.mainStatCandidates(role: role, element: .pyro).sands
            XCTAssertTrue(sands.contains(.energyRecharge))
            XCTAssertTrue(sands.contains(.atkPercent), "\(role.rawValue) is still pinned to Energy Recharge")
        }
        XCTAssertEqual(assembler.mainStatCandidates(role: .healer, element: .pyro).circlet, [.healingBonus])
    }

    /// A stance character's attack string exists only in the stance: with no
    /// burst, Raiden's Musou Isshin strikes are worth nothing.
    func testAStanceGatesTheAttackString() throws {
        let rotation = try scorer().soloRotation(for: try characters(["raiden-shogun"])[0])
        XCTAssertEqual(rotation.window, .burst)
        XCTAssertEqual(rotation.attackWindow(burstCasts: 0), 0)
        XCTAssertEqual(rotation.attackWindow(burstCasts: 0.5), 0.5)
        XCTAssertEqual(rotation.attackWindow(burstCasts: 1), 1)
    }

    // MARK: - Field time

    /// Field time is spent on the best loop open to the character, and a loop
    /// that takes longer fits fewer times — the replacement for six strings
    /// and two charged attacks for everyone.
    func testFieldTimeBuysAttacksAtTheirOwnLength() throws {
        var rotation = AbyssScorer.Rotation.unconstrained
        rotation.comboSeconds = 2
        rotation.chargedSeconds = 1
        let split = AbyssScorer.DamageSplit(skill: 0, burst: 0, combo: 1000, charged: 900)
        // String plus charged, (1000 + 900) / 3, beats the string alone, 1000 / 2…
        XCTAssertEqual(rotation.attackRate(split), 1900.0 / 3, accuracy: 1e-9)
        // …and a bow's charged-only loop beats both.
        rotation.loops.charged = true
        XCTAssertEqual(rotation.attackRate(split), 900, accuracy: 1e-9)

        var slower = rotation
        slower.comboSeconds = 4
        slower.loops = .init(combo: true, mixed: false, charged: false)
        rotation.loops = .init(combo: true, mixed: false, charged: false)
        XCTAssertEqual(slower.attackRate(split), rotation.attackRate(split) / 2, accuracy: 1e-9)
    }

    /// The data behind it: frames resolve for most characters, Neuvillette
    /// spends his field time on Equitable Judgment, and every other member's
    /// casts come out of the driver's time.
    func testFieldTimeComesFromFramesAndCasts() throws {
        // Every character gcsim implements has an entry; of those, only the
        // fields the patterns did not recognise stand in with the median.
        let covered = Set(library.frames?.characters.keys.map { $0 } ?? [])
        XCTAssertGreaterThan(covered.count, 100)
        let estimatedAmongCovered = library.diagnostics.framesEstimated.filter { entry in
            covered.contains(String(entry.split(separator: ":")[0]))
        }
        XCTAssertLessThan(estimatedAmongCovered.count, 50,
                          "most timings should come from gcsim, not the median")
        let neuvillette = try XCTUnwrap(library.energyByCharacterID["neuvillette"])
        XCTAssertEqual(neuvillette.attackLoops, .init(combo: false, mixed: false, charged: true))
        let huTao = try XCTUnwrap(library.energyByCharacterID["hu-tao"])
        XCTAssertEqual(huTao.comboSeconds, Double(14 + 12 + 26 + 29 + 37 + 72) / 60, accuracy: 1e-9)

        let scorer = try scorer()
        let members = try characters(["hu-tao", "bennett", "xingqiu", "diona"])
        let team = AbyssTeamContext.build(members: members, library: library)
        let context = scorer.teamDamageContext(members: members, floor: .neutral, team: team)
        var sheet = AbyssStats()
        sheet.energyRecharge = 1.5
        let stats = Array(repeating: sheet, count: 4)
        let field = scorer.fieldSeconds(driver: 0, members: context.members, stats: stats)
        let tuning = try XCTUnwrap(library.tuning)
        XCTAssertLessThan(field, tuning.rotationSeconds)
        XCTAssertGreaterThan(field, tuning.rotationSeconds / 2, "the supports' casts ate most of the rotation")
    }

    /// The per-character bars add up to the score, whoever ends up on field.
    func testPerCharacterDamageAddsUpToTheTeamTotal() throws {
        let scorer = try scorer()
        let members = try characters(["raiden-shogun", "xiangling", "xingqiu", "bennett"])
        let team = AbyssTeamContext.build(members: members, library: library)
        let context = scorer.teamDamageContext(members: members, floor: .neutral, team: team)
        var sheet = AbyssStats()
        sheet.baseATK = 900
        sheet.critRate = 0.5
        sheet.critDMG = 1.0
        sheet.energyRecharge = 1.3
        let stats = Array(repeating: sheet, count: members.count)
        var splits = [AbyssScorer.DamageSplit](repeating: .zero, count: members.count)
        let damage = scorer.teamDamage(context: context, stats: stats, setIDs: members.map { _ in [] },
                                       splits: &splits)
        var sum = damage.reactionDamage
        for index in members.indices {
            let rotation = context.members[index].rotation
            sum += index == damage.onFieldIndex
                ? scorer.onFieldDamage(splits[index], rotation: rotation, energyRecharge: sheet.energyRecharge,
                                       fieldSeconds: scorer.fieldSeconds(driver: index, members: context.members,
                                                                         stats: stats))
                : scorer.offFieldDamage(splits[index], rotation: rotation, energyRecharge: sheet.energyRecharge)
        }
        XCTAssertEqual(sum, damage.total, accuracy: max(damage.total, 1) * 1e-9)
    }
}
