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
                                   artifactSets: library.artifactSets,
                                   talentPartyBuffs: library.talentPartyBuffsByCharacterID)
    }

    private func sheet(_ characterID: String, weapon weaponID: String?) throws -> AbyssStats {
        let assembler = try makeAssembler()
        let character = try XCTUnwrap(library.charactersByID[characterID])
        let profile = try XCTUnwrap(library.profilesByCharacterID[characterID])
        return assembler.statsWithoutSets(
            character: character, profile: profile,
            weapon: weaponID.flatMap { library.weaponsByID[$0] },
            role: .mainDPS)
    }

    // MARK: - Weapon passives

    /// Elemental Mastery is a flat quantity in the tens or hundreds, so the
    /// "a value above 3 is a hit's damage percentage, not a buff" guard threw
    /// away *every* EM weapon passive in the data. The artifact path has always
    /// carried an exception for it; the weapon path did not.
    func testWeaponElementalMasteryPassiveIsNotMistakenForADamagePercentage() throws {
        // Sapwood Blade's substat is Energy Recharge, so its whole EM
        // contribution is the passive — nothing else can account for it.
        let sapwood = try XCTUnwrap(library.weaponsByID["sapwood-blade"])
        let passive = try XCTUnwrap(sapwood.passive?.effects.first)
        let atR1 = try XCTUnwrap(passive.value(refinement: 1))
        XCTAssertGreaterThan(atR1, 3, "this test only means anything while the value trips the guard")

        let bare = try sheet("kamisato-ayaka", weapon: nil)
        let armed = try sheet("kamisato-ayaka", weapon: "sapwood-blade")
        XCTAssertEqual(armed.elementalMastery - bare.elementalMastery, atR1, accuracy: 1e-9,
                       "the EM passive did not reach the stat sheet")
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
                                                   weapon: weapon, role: .mainDPS)
            XCTAssertLessThan(stats.dmgAll, 3, "\(weapon.id): a damage instance leaked into dmgAll")
            XCTAssertLessThan(stats.atkPercent, 5, "\(weapon.id): a damage instance leaked into ATK%")
        }
    }

    // MARK: - Talent party buffs

    /// The table in `tuning.json` points at rows in the character data by exact
    /// label. A rename would make a buff vanish silently, so every entry has to
    /// resolve at load.
    func testEveryTalentPartyBuffEntryResolvesAgainstTheCharacterData() throws {
        let tuning = try XCTUnwrap(library.tuning)
        XCTAssertFalse(tuning.talentPartyBuff.isEmpty, "the table is empty; nothing is being modelled")
        XCTAssertEqual(library.diagnostics.talentPartyBuffUnresolved, [],
                       "a talentPartyBuff entry no longer matches the character data")

        for entry in tuning.talentPartyBuff {
            let resolved = library.talentPartyBuffsByCharacterID[entry.characterId] ?? []
            XCTAssertFalse(resolved.isEmpty, "\(entry.characterId) resolved to no buff")
            for buff in resolved {
                XCTAssertGreaterThan(buff.value, 0, "\(entry.characterId): buff resolved to zero")
            }
        }
    }

    /// Bennett's Fantastic Voyage is a share of *his own* Base ATK handed to the
    /// party as flat ATK. It is the single largest buff in the game and the
    /// model credited him with none of it.
    func testBennettGrantsFlatATKScaledByHisOwnBaseATK() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let entry = try XCTUnwrap(tuning.talentPartyBuff.first { $0.characterId == "bennett" })
        let bennett = try XCTUnwrap(library.charactersByID["bennett"])
        let ratio = try XCTUnwrap(AbyssTextParser.talentPercentage(
            in: bennett.elementalBurst, label: entry.label, index: entry.valueIndex ?? 0))

        let bare = try sheet("bennett", weapon: nil)
        XCTAssertEqual(bare.partyFlatATK, ratio * entry.uptime * bare.baseATK, accuracy: 1e-9)

        // A better weapon raises his Base ATK, so it raises the buff too.
        let armed = try sheet("bennett", weapon: "the-alley-flash")
        XCTAssertGreaterThan(armed.partyFlatATK, bare.partyFlatATK)

        // It is a party channel, not his own sheet: crediting it twice would
        // make him a damage dealer.
        XCTAssertEqual(bare.flatATK, try sheet("hu-tao", weapon: nil).flatATK, accuracy: 1e-9,
                       "the party buff leaked into the caster's own flat ATK")
    }

    /// Faruzan's is a DMG bonus for her own element only. Routing it through
    /// `partyDMG` would have lifted every member's damage whatever they cast.
    func testFaruzanBuffsOnlyHerOwnElement() throws {
        let sheet = try sheet("faruzan", weapon: nil)
        XCTAssertGreaterThan(sheet.partyElementalDMG[GenshinElement.anemo.simdIndex], 0)
        XCTAssertEqual(sheet.partyDMG, 0, accuracy: 1e-9,
                       "an element-scoped buff reached the all-element channel")
        for element in GenshinElement.allCases where element != .anemo {
            XCTAssertEqual(sheet.partyElementalDMG[element.simdIndex], 0, accuracy: 1e-9,
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

        // And the bonus fields that feed it are no longer inert.
        let tuning = try XCTUnwrap(library.tuning)
        XCTAssertGreaterThan(tuning.chargedAttacksPerRotation, 0)
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
        let resolved = AbyssBuildAssembler.resolve(named: "Normal/Charged Attack DMG", value: 0.3,
                                                   conditional: false, tuning: tuning)
        XCTAssertEqual(Set(resolved.map(\.field)), [.dmgNormal, .dmgCharged])
        for entry in resolved { XCTAssertEqual(entry.value, 0.3, accuracy: 1e-9) }

        // A bonus naming only one still lands in only one.
        XCTAssertEqual(AbyssBuildAssembler.resolve(named: "Charged Attack DMG", value: 0.5,
                                                   conditional: false, tuning: tuning).map(\.field),
                       [.dmgCharged])
        XCTAssertEqual(AbyssBuildAssembler.resolve(named: "Normal Attack DMG", value: 0.5,
                                                   conditional: false, tuning: tuning).map(\.field),
                       [.dmgNormal])
    }

    // MARK: - Set approximations

    /// The de-duplication table is keyed by set alone, so it cannot express an
    /// approximation whose value depends on who is wearing it. A party
    /// approximation with a requirement would be counted for a member who does
    /// not meet it.
    func testPartySetApproximationsCarryNoRequirement() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let party = tuning.setEffectApprox.filter { $0.party == true }
        XCTAssertFalse(party.isEmpty, "no party approximations; this test needs updating")
        for entry in party {
            XCTAssertNil(entry.requirement,
                         "\(entry.setId): a party approximation cannot depend on the wearer")
        }
    }

    /// Six 5★ sets used to contribute exactly nothing: no `bonuses` on their
    /// 4-piece and no entry in the approximation table. Four of them are now
    /// modelled; the two that only raise reaction damage are left out on
    /// purpose, because the model computes no reaction damage to raise.
    func testSetsThatUsedToContributeNothingNowDo() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let approximated = Set(tuning.setEffectApprox.map(\.setId))
        let silent = library.fiveStarArtifactSets.filter {
            $0.fourPiece.bonuses.isEmpty && !approximated.contains($0.id)
        }
        XCTAssertEqual(Set(silent.map(\.id)),
                       ["flower-of-paradise-lost", "aubade-of-morningstar-and-moon"],
                       "the set of deliberately unmodelled 4-piece effects changed")

        for setID in ["archaic-petra", "celestial-gift", "vermillion-hereafter",
                      "disenchantment-in-deep-shadow"] {
            XCTAssertTrue(approximated.contains(setID), "\(setID) is contributing nothing again")
        }
    }

    /// A party-wide approximation has to reach the other members, and has to be
    /// counted once however many of them wear it.
    func testAPartySetApproximationIsSharedButNotStacked() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = try makeAssembler()
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let petra = try XCTUnwrap(library.artifactSetsByID["archaic-petra"])
        let members = Array(library.characters.prefix(4))
        let context = AbyssTeamContext.build(members: members, library: library)

        var diagnostics = AbyssParseDiagnostics()
        let sheets = members.map { member -> AbyssStats in
            guard let profile = library.profilesByCharacterID[member.id] else { return AbyssStats() }
            return assembler.stats(character: member, profile: profile, weapon: nil, sets: [petra],
                                   role: .mainDPS, diagnostics: &diagnostics)
        }

        let one = scorer.partyBuffs(stats: [sheets[0]], setIDs: [[petra.id]], team: context)
        let all = scorer.partyBuffs(stats: sheets, setIDs: members.map { _ in [petra.id] },
                                    team: context)
        XCTAssertGreaterThan(one.dmg, 0, "the party approximation did not reach the party")
        XCTAssertEqual(all.dmg, one.dmg, accuracy: 1e-9,
                       "four members wearing the same set granted it four times")
    }
}
