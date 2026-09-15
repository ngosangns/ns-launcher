import XCTest
@testable import NSLauncherApp

/// Two classes of buff the model used to read past: Elemental Mastery on a
/// weapon passive, and the party-wide buffs a character's own talents grant.
///
/// Both were silent losses — no diagnostic, no unmapped-name report, just a
/// number that never arrived — which is why they are pinned here rather than
/// left to the golden fixture alone.
final class AbyssBuildAssemblerTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func makeAssembler() throws -> AbyssBuildAssembler {
        let tuning = try XCTUnwrap(library.tuning)
        return AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                   talentBuffs: library.talentBuffsByCharacterID,
                                   conversions: library.conversionsByCharacterID,
                                   weaponBuffs: library.weaponBuffsByID, setBuffs: library.setBuffsByID)
    }

    private func sheet(_ characterID: String, weapon weaponID: String?, refinement: Int = 1) throws -> AbyssStats {
        let assembler = try makeAssembler()
        let character = try XCTUnwrap(library.charactersByID[characterID])
        let profile = try XCTUnwrap(library.profilesByCharacterID[characterID])
        return assembler.statsWithoutSets(
            character: character, profile: profile,
            weapon: weaponID.flatMap { library.weaponsByID[$0] },
            role: .mainDPS, refinement: refinement, mainStats: .damage(for: character))
    }

    // MARK: - Stat conversions

    /// Hu Tao's Paramita Papilio turns Max HP into ATK. It reaches the sheet as
    /// a *rate*, so anything that raises her HP afterwards — a substat, a
    /// sands, a Homa refinement — raises her ATK through it, which is the only
    /// way a search can learn that HP% is a damage stat on her.
    func testAKitConversionMakesHPWorthATK() throws {
        let rate = try XCTUnwrap(library.conversionsByCharacterID["hu-tao"]?.first)
        XCTAssertEqual(rate.from, .hp)
        let sheet = try sheet("hu-tao", weapon: nil)
        XCTAssertEqual(sheet.atkFromHPRate, rate.rate, accuracy: 1e-12)

        var moreHP = sheet
        moreHP.hpPercent += 0.4
        XCTAssertEqual(moreHP.atk - sheet.atk, sheet.baseHP * 0.4 * rate.rate, accuracy: 1e-6,
                       "40% more HP should be worth exactly its share as ATK")

        // Nobody else's HP became ATK.
        let yelan = try self.sheet("yelan", weapon: nil)
        XCTAssertEqual(yelan.atkFromHPRate, 0)
    }

    /// Noelle's is DEF, and the file cannot say otherwise: the stat converted
    /// from is the suffix the game wrote on the row.
    func testNoelleConvertsDEFNotHP() throws {
        let sheet = try sheet("noelle", weapon: nil)
        XCTAssertGreaterThan(sheet.atkFromDEFRate, 0)
        XCTAssertEqual(sheet.atkFromHPRate, 0)
    }

    /// Staff of Homa's HP-to-ATK line used to be dropped: it says neither
    /// "buff" nor "bonus", so the stat-buff rule never matched it, and a Homa
    /// refinement was worth exactly its HP%. It is a rate now, folded in once
    /// the sheet is complete, so the HP it reads includes the artifacts'.
    func testHomaConvertsHPToATKAndRefinementRaisesIt() throws {
        var r1 = try sheet("hu-tao", weapon: "staff-of-homa", refinement: 1)
        var r5 = try sheet("hu-tao", weapon: "staff-of-homa", refinement: 5)
        var bare = try sheet("hu-tao", weapon: nil)
        XCTAssertGreaterThan(r1.conversions.count, 0, "Homa's conversion did not reach the sheet")
        r1.foldConversions()
        r5.foldConversions()
        bare.foldConversions()
        XCTAssertEqual(r1.conversions.count, 0, "folding must empty the slots")
        XCTAssertGreaterThan(r5.atk, r1.atk)
        // Worth its rate of the finished sheet's HP.
        XCTAssertEqual(r1.flatATK - bare.flatATK, r1.hp * 0.008, accuracy: 1e-6)
    }

    /// Engulfing Lightning's is the Energy Recharge above 100%, as ATK%.
    func testEngulfingLightningPaysForEnergyRechargeAboveBaseline() throws {
        var sheet = try sheet("raiden-shogun", weapon: "engulfing-lightning")
        var moreER = sheet
        moreER.energyRecharge += 0.5
        sheet.foldConversions()
        moreER.foldConversions()
        XCTAssertEqual(moreER.atkPercent - sheet.atkPercent, 0.5 * 0.28, accuracy: 1e-6)
        var atBaseline = try self.sheet("raiden-shogun", weapon: "engulfing-lightning")
        atBaseline.energyRecharge = 1
        var below = atBaseline
        below.energyRecharge = 0.8
        atBaseline.foldConversions()
        below.foldConversions()
        XCTAssertEqual(atBaseline.atkPercent, below.atkPercent, accuracy: 1e-9,
                       "below 100% there is nothing to convert")
    }

    // MARK: - Own buffs

    /// Xiao's burst raises his *own* normal-attack damage and nobody else's;
    /// it must land on his sheet and stay out of the party channels.
    func testAnOwnStatBuffStaysOnTheCastersSheet() throws {
        let sheet = try sheet("xiao", weapon: nil)
        XCTAssertGreaterThan(sheet.dmgNormal, 0.9, "Bane of All Evil's bonus did not reach Xiao's own sheet")
        XCTAssertEqual(sheet.partyDMG, 0, accuracy: 1e-9)
        XCTAssertEqual(sheet.partyATKPercent, 0, accuracy: 1e-9)
        XCTAssertEqual(sheet.partyFlatATK, 0, accuracy: 1e-9)
    }

    // MARK: - Weapon passives

    /// Elemental Mastery is a flat quantity in the tens or hundreds, and the
    /// old "a value above 3 is a hit's damage percentage" guard threw away every
    /// EM weapon passive. Sapwood Blade's EM comes from a leaf after a
    /// reaction, 12s per 20s: it waits on a team that reacts, at that share.
    func testWeaponElementalMasteryPassiveWaitsOnAReaction() throws {
        let bare = try sheet("kamisato-ayaka", weapon: nil)
        let armed = try sheet("kamisato-ayaka", weapon: "sapwood-blade")
        XCTAssertEqual(armed.elementalMastery, bare.elementalMastery, accuracy: 1e-9)
        XCTAssertEqual(armed.gates.count, 1)
        XCTAssertEqual(armed.gates[0].value, 60 * 12 / 20, accuracy: 1e-9)
        XCTAssertEqual(AbyssStatField.indexed[Int(armed.gates[0].field)], .elementalMastery)
    }

    /// The guard still has to do its job. Lines like "AoE DMG (% ATK)" carry a
    /// few hundred percent because they *are* a hit, and letting one into a
    /// bonus field would multiply a build's damage several hundredfold — so
    /// every weapon in the data is checked against a sanity ceiling.
    func testLargeNonElementalMasteryPassiveValuesAreStillRejected() throws {
        let assembler = try makeAssembler()
        let character = try XCTUnwrap(library.charactersByID["kamisato-ayaka"])
        let profile = try XCTUnwrap(library.profilesByCharacterID["kamisato-ayaka"])

        let offenders = library.weapons.filter { weapon in
            (weapon.passive?.effects ?? []).contains { effect in
                guard let value = effect.value(refinement: 1), abs(value) > 3 else { return false }
                let name = effect.stat.lowercased()
                return !name.contains("elemental mastery") && !name.hasPrefix("em ")
            }
        }
        XCTAssertFalse(offenders.isEmpty, "the data no longer has such a line; this test needs updating")

        for weapon in library.weapons where weapon.type == character.weaponType {
            let stats = assembler.statsWithoutSets(character: character, profile: profile,
                                                   weapon: weapon, role: .mainDPS,
                                                   mainStats: .damage(for: character))
            XCTAssertLessThan(stats.dmgAll, 3, "\(weapon.id): a damage instance leaked into dmgAll")
            XCTAssertLessThan(stats.atkPercent, 5, "\(weapon.id): a damage instance leaked into ATK%")
        }
    }

    // MARK: - Talent party buffs

    /// `character-kits.json`'s `buffs` point at rows in the talent tables by
    /// exact label. A rename would make a buff vanish silently, so every entry
    /// has to resolve at load.
    func testEveryTalentBuffEntryResolvesAgainstTheTalentTables() throws {
        let entries = library.kitsByCharacterID.values.filter { !($0.buffs ?? []).isEmpty }
        XCTAssertFalse(entries.isEmpty, "the table is empty; nothing is being modelled")
        XCTAssertEqual(library.diagnostics.talentBuffUnresolved, [],
                       "a partyBuffs entry no longer matches the character data")

        for entry in entries {
            let resolved = library.talentBuffsByCharacterID[entry.characterId] ?? []
            XCTAssertEqual(resolved.count, entry.buffs?.count,
                           "\(entry.characterId): not every buff resolved")
            for buff in resolved {
                XCTAssertGreaterThan(buff.value, 0, "\(entry.characterId): buff resolved to zero")
            }
        }
    }

    /// Bennett's Fantastic Voyage is a share of *his own* Base ATK handed to the
    /// party as flat ATK. It is the single largest buff in the game and the
    /// model credited him with none of it. It is a *burst* buff, so it lands in
    /// the burst channel the scorer scales by how often his burst is up.
    func testBennettGrantsFlatATKScaledByHisOwnBaseATK() throws {
        let entry = try XCTUnwrap(library.kitsByCharacterID["bennett"]?.buffs?.first)
        let table = try XCTUnwrap(library.talentParams?.characters["bennett"]?.elementalBurst)
        let ratio = try XCTUnwrap(AbyssTalentReader.row(labelled: try XCTUnwrap(entry.label), in: table, level: 10))
            .values.reduce(0, +)

        let bare = try sheet("bennett", weapon: nil)
        XCTAssertEqual(bare.burstPartyFlatATK, ratio * entry.uptime * bare.baseATK, accuracy: 1e-9)
        XCTAssertEqual(bare.partyFlatATK, 0, accuracy: 1e-9, "a burst buff reached the always-on channel")

        // A better weapon raises his Base ATK, so it raises the buff too.
        let armed = try sheet("bennett", weapon: "the-alley-flash")
        XCTAssertGreaterThan(armed.burstPartyFlatATK, bare.burstPartyFlatATK)

        // It is a party channel, not his own sheet: crediting it twice would
        // make him a damage dealer.
        XCTAssertEqual(bare.flatATK, try sheet("hu-tao", weapon: nil).flatATK, accuracy: 1e-9,
                       "the party buff leaked into the caster's own flat ATK")
    }

    /// Faruzan's is a DMG bonus for her own element only. Routing it through
    /// `partyDMG` would have lifted every member's damage whatever they cast.
    func testFaruzanBuffsOnlyHerOwnElement() throws {
        let sheet = try sheet("faruzan", weapon: nil)
        XCTAssertGreaterThan(sheet.burstPartyElementalDMG[GenshinElement.anemo.simdIndex], 0)
        XCTAssertEqual(sheet.partyDMG, 0, accuracy: 1e-9,
                       "an element-scoped buff reached the all-element channel")
        for element in GenshinElement.allCases where element != .anemo {
            XCTAssertEqual(sheet.burstPartyElementalDMG[element.simdIndex], 0, accuracy: 1e-9,
                           "\(element.rawValue) was buffed by an Anemo-only effect")
        }
    }

    /// The whole point: the buff has to arrive on the *other* members' damage.
    func testATeammateHitsHarderWithBennettInTheTeam() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let huTao = try XCTUnwrap(library.charactersByID["hu-tao"])
        let huTaoSheet = try sheet("hu-tao", weapon: "staff-of-homa")
        let bennettSheet = try sheet("bennett", weapon: nil)

        let context = scorer.soloContext(for: huTao)
        let alone = scorer.damageSplit(context: context, stats: huTaoSheet, partyBuffs: .none)
        let buffed = scorer.damageSplit(
            context: context, stats: huTaoSheet,
            partyBuffs: scorer.partyBuffs(stats: [huTaoSheet, bennettSheet], setIDs: [[], []],
                                          resonance: .none))

        XCTAssertGreaterThan(buffed.ability, alone.ability,
                             "Bennett's ATK buff did not reach his team mate")
    }

    // MARK: - Charged attacks

    /// `HitCategory.charged` used to be a slot nothing ever landed in: talents
    /// produce `.skill`/`.burst` and only numbered combo hits became `.normal`,
    /// so every "Charged Attack DMG" bonus in the data multiplied a zero.
    func testChargedAttacksReachTheDamageProfile() throws {
        let withCharged = library.characters.filter { character in
            library.profilesByCharacterID[character.id]?.hits.contains { $0.category == .charged } ?? false
        }
        XCTAssertGreaterThan(withCharged.count, 80,
                             "charged attacks are not reaching the profile for most characters")

        // And the time to make them is not zero: a charged attack takes field
        // time the frame data measures, for everyone who has one.
        XCTAssertGreaterThan(library.energyByCharacterID["hu-tao"]?.chargedSeconds ?? 0, 0)
    }

    /// A bow's "Aimed Shot" and "Aimed Shot sạc đầy" are two ways to fire the
    /// same arrow. Summing them would double every bow in the data, so the
    /// parser takes the strongest row rather than the total.
    func testChargedAttackTakesTheStrongestRowRatherThanTheirSum() throws {
        let yoimiya = try XCTUnwrap(library.charactersByID["yoimiya"])
        let rows = yoimiya.normalAttack.hits.filter { $0.label.lowercased().contains("aimed") }
        XCTAssertEqual(rows.count, 2, "this test needs a character with two aimed-shot rows")

        let parsed = rows.compactMap { AbyssTextParser.scalingValue($0.values["lv10"] ?? "")?.multiplier }
        XCTAssertEqual(parsed.count, 2)
        let charged = try XCTUnwrap(AbyssTextParser.chargedAttack(yoimiya))
        XCTAssertEqual(charged.0, parsed.max() ?? 0, accuracy: 1e-9)
        XCTAssertLessThan(charged.0, parsed.reduce(0, +), "the two rows were summed")
    }

    /// "Normal/Charged Attack DMG" raises both, and they are separate slots.
    /// Routing such a bonus to the normal half alone dropped the charged half
    /// of five artifact sets.
    func testABonusNamingBothNormalAndChargedReachesBoth() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let resolved = AbyssBuildAssembler.resolve(named: "Normal/Charged Attack DMG", value: 0.3, tuning: tuning)
        XCTAssertEqual(Set(resolved.map(\.field)), [.dmgNormal, .dmgCharged])
        for entry in resolved { XCTAssertEqual(entry.value, 0.3, accuracy: 1e-9) }

        // A bonus naming only one still lands in only one.
        XCTAssertEqual(AbyssBuildAssembler.resolve(named: "Charged Attack DMG", value: 0.5, tuning: tuning).map(\.field),
                       [.dmgCharged])
        XCTAssertEqual(AbyssBuildAssembler.resolve(named: "Normal Attack DMG", value: 0.5, tuning: tuning).map(\.field),
                       [.dmgNormal])
    }

    // MARK: - Set bonuses

    /// Every 5★ set's four-piece is priced from `passives.json`, except the
    /// ones whose whole effect the damage model deliberately leaves out.
    /// Before Phase 5 these sets were a hand-estimated %DMG each; a set joining
    /// this list is a set that stopped contributing.
    func testFourPiecesWithNothingPricedAreTheDeliberateOnes() throws {
        let silent = library.fiveStarArtifactSets.filter { set in
            (library.setBuffsByID[set.id]?.fourPiece ?? []).allSatisfy { buff in
                buff.conditions.contains(.unmodelled) || buff.conditions.contains(.defeat)
            }
        }
        XCTAssertEqual(Set(silent.map(\.id)), [
            // Reaction damage only.
            "flower-of-paradise-lost", "aubade-of-morningstar-and-moon", "thundering-fury",
            // Resistance shred, priced by `tuning.resistanceShred`.
            "viridescent-venerer", "deepwood-memories",
            // Healing, shields, flat damage additions, Physical DMG.
            "maiden-beloved", "ocean-hued-clam", "song-of-days-past", "echoes-of-an-offering",
            // Conditions a single-target rotation never meets.
            "bloodstained-chivalry", "unfinished-reverie", "celestial-gift", "disenchantment-in-deep-shadow",
        ], "the set of four-pieces priced at nothing changed")
    }

    /// A party-wide set buff has to reach the other members, and has to be
    /// counted once however many of them wear it.
    func testAPartySetBuffIsSharedButNotStacked() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = try makeAssembler()
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let noblesse = try XCTUnwrap(library.artifactSetsByID["noblesse-oblige"])
        let members = Array(library.characters.prefix(4))
        let context = AbyssTeamContext.build(members: members, library: library)

        var diagnostics = AbyssParseDiagnostics()
        let sheets = members.map { member -> AbyssStats in
            guard let profile = library.profilesByCharacterID[member.id] else { return AbyssStats() }
            return assembler.stats(character: member, profile: profile, weapon: nil, sets: [noblesse],
                                   role: .mainDPS, mainStats: .damage(for: member),
                                   diagnostics: &diagnostics)
        }

        let one = scorer.partyBuffs(stats: [sheets[0]], setIDs: [[noblesse.id]], team: context)
        let all = scorer.partyBuffs(stats: sheets, setIDs: members.map { _ in [noblesse.id] },
                                    team: context)
        XCTAssertGreaterThan(one.atkPercent, 0, "the party buff did not reach the party")
        XCTAssertEqual(all.atkPercent, one.atkPercent, accuracy: 1e-9,
                       "four members wearing the same set granted it four times")
    }
}
