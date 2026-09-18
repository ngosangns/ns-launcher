// AbyssBuildAssembler.swift
//
// Assembles a character's stat sheet: character base at level 90, weapon at 90,
// and a 5★ level-20 artifact set chosen for their role.
//
// Artifacts are modelled, not read: the app has no idea what the player has
// actually rolled, so every character is given the same standardised build from
// `tuning.json` (main stats by role, substats from a roll budget). Absolute
// numbers are therefore approximate — but they are approximate *the same way*
// for every candidate, which is what a ranking needs.
//
// The delicate part is `apply(named:)`. The data names its stats in prose
// ("Normal/Charged Attack DMG", "Max HP", "Party ATK"), and every one has to
// land in the right field. A misrouted name does not crash; it produces
// plausible, permanently wrong numbers. The order of the rules below is
// load-bearing — "elemental skill dmg" has to be tested before "elemental"
// would match something else — so leave it alone unless that is the change.

import Foundation

struct AbyssBuildAssembler: Sendable {
    let tuning: AbyssTuning
    let moonsignIDs: Set<String>
    let bondOfLifeIDs: Set<String>
    /// Buffs from each character's own talents — party-wide or their own —
    /// already resolved by `AbyssDataLibrary`. Empty is a valid state — a
    /// caller that only assembles gear does not need them.
    let talentBuffs: [String: [AbyssTalentBuff]]
    /// Stats each character's kit turns into ATK, resolved by the library.
    let conversions: [String: [AbyssStatConversion]]
    /// Weapon passives and set bonuses as structured buffs — see
    /// `AbyssPassives.swift`. Empty prices no passive at all.
    let weaponBuffs: [String: [AbyssBuff]]
    let setBuffs: [String: (twoPiece: [AbyssBuff], fourPiece: [AbyssBuff])]
    /// Each character's rotation as the buff timeline reads it, built by
    /// `AbyssOptimizer` from the scorer's solo rotation. A character with none
    /// is read with `AbyssBuffWearer.standIn`'s timing and their own facts.
    let wearers: [String: AbyssBuffWearer]
    /// Each set's two- and four-piece bonuses already read against each
    /// character with a known rotation: the timeline is the same every time a
    /// set is tried on the same character, and gear search tries sets on a
    /// character thousands of times.
    private let setDeltas: [String: [String: (twoPiece: AbyssSheetDelta, fourPiece: AbyssSheetDelta)]]

    init(tuning: AbyssTuning, moonsignIDs: Set<String>,
         talentBuffs: [String: [AbyssTalentBuff]] = [:],
         conversions: [String: [AbyssStatConversion]] = [:],
         bondOfLifeIDs: Set<String> = [],
         weaponBuffs: [String: [AbyssBuff]] = [:],
         setBuffs: [String: (twoPiece: [AbyssBuff], fourPiece: [AbyssBuff])] = [:],
         wearers: [String: AbyssBuffWearer] = [:]) {
        self.tuning = tuning
        self.moonsignIDs = moonsignIDs
        self.bondOfLifeIDs = bondOfLifeIDs
        self.talentBuffs = talentBuffs
        self.conversions = conversions
        self.weaponBuffs = weaponBuffs
        self.setBuffs = setBuffs
        self.wearers = wearers

        var deltas: [String: [String: (twoPiece: AbyssSheetDelta, fourPiece: AbyssSheetDelta)]] = [:]
        for (id, wearer) in wearers {
            var perSet: [String: (twoPiece: AbyssSheetDelta, fourPiece: AbyssSheetDelta)] = [:]
            for (setID, buffs) in setBuffs {
                perSet[setID] = (
                    AbyssSheetDelta.of { Self.apply(buffs.twoPiece, refinement: 1, wearer: wearer, to: &$0) },
                    AbyssSheetDelta.of {
                        Self.apply(buffs.fourPiece, refinement: 1, wearer: wearer, to: &$0, recordsSetParty: true)
                    })
            }
            deltas[id] = perSet
        }
        setDeltas = deltas
    }

    /// The same assembler reading buffs against these rotations.
    func with(wearers: [String: AbyssBuffWearer]) -> AbyssBuildAssembler {
        AbyssBuildAssembler(tuning: tuning, moonsignIDs: moonsignIDs, talentBuffs: talentBuffs,
                            conversions: conversions, bondOfLifeIDs: bondOfLifeIDs, weaponBuffs: weaponBuffs,
                            setBuffs: setBuffs, wearers: wearers)
    }

    /// Builds the level-90 stat sheet for one character/weapon/artifact combination.
    func stats(character: AbyssCharacter,
               profile: AbyssDamageProfile,
               weapon: AbyssWeapon?,
               sets: [AbyssArtifactSet],
               role: AbyssRole,
               refinement: Int = 1,
               mainStats: AbyssMainStatPlan,
               diagnostics: inout AbyssParseDiagnostics) -> AbyssStats {
        var stats = statsWithoutSets(character: character, profile: profile, weapon: weapon,
                                     role: role, refinement: refinement, mainStats: mainStats)
        applySets(sets, character: character, to: &stats, diagnostics: &diagnostics)
        return stats
    }

    /// The sheet before any of the three main stats that carry a choice:
    /// character base, weapon, substats, talent party buffs, and the two
    /// artifact slots whose main stat is fixed in game.
    ///
    /// Split out because those three are searched: this half costs a regex sweep
    /// over the weapon passive and is the same for every candidate plan, so the
    /// search builds it once and adds three numbers per candidate.
    func statsWithoutArtifactMainStats(character: AbyssCharacter,
                                       profile: AbyssDamageProfile,
                                       weapon: AbyssWeapon?,
                                       role: AbyssRole,
                                       refinement: Int = 1) -> AbyssStats {
        let lv90 = character.baseStats.lv90
        var stats = AbyssStats(
            baseATK: lv90.atk ?? 0,
            baseHP: lv90.hp ?? 0,
            baseDEF: lv90.def ?? 0)

        // Ascension stat (the fifth stat a character gains levelling to 90).
        if let type = lv90.ascensionStatType, let value = lv90.ascensionStatValue {
            _ = apply(named: type, value: value, to: &stats)
        }

        if let weapon {
            stats.baseATK += weapon.atkLv90 ?? 0
            if let subStatType = weapon.subStat.type, let subStatValue = weapon.subStat.valueLv90 {
                _ = apply(named: subStatType, value: subStatValue, to: &stats)
            }
            applyWeaponPassive(weapon, refinement: refinement, character: character, to: &stats)
        }

        // Flower and Plume are fixed HP and ATK; there is nothing to decide
        // about them, so they belong on this side of the split.
        for slot in AbyssMainStatPlan.fixedSlots {
            stats.add(tuning.mainStat(slot.tuningKey), to: slot)
        }
        applySubstats(role: role, basis: profile.basis, to: &stats)
        applyTalentBuffs(for: character, to: &stats)
        applyConversions(for: character, to: &stats)

        return stats
    }

    /// That sheet with a main stat in each of the three slots that carry one.
    func applying(_ plan: AbyssMainStatPlan, to base: AbyssStats) -> AbyssStats {
        var stats = base
        for slot in plan.slots {
            stats.add(tuning.mainStat(Self.tuningKey(for: slot)), to: slot.statField)
        }
        return stats
    }

    /// Both halves at once, for callers that already know the plan.
    func statsWithoutSets(character: AbyssCharacter,
                          profile: AbyssDamageProfile,
                          weapon: AbyssWeapon?,
                          role: AbyssRole,
                          refinement: Int = 1,
                          mainStats: AbyssMainStatPlan) -> AbyssStats {
        applying(mainStats, to: statsWithoutArtifactMainStats(
            character: character, profile: profile, weapon: weapon, role: role,
            refinement: refinement))
    }

    /// Buffs this character's own talents grant.
    ///
    /// Applied after the weapon, because `flatATKFromBaseATK` is a share of the
    /// caster's Base ATK and Base ATK is character plus weapon — Bennett with a
    /// stronger polearm really does buff the party harder.
    ///
    /// Party buffs land in the `party*` fields, which the scorer hands to all
    /// four members, and change nothing on the caster's own sheet directly;
    /// that is what stops the buff being counted once for the caster and again
    /// for the party. An `ownStat` buff is the other way round: the caster's
    /// sheet and nobody else's.
    func applyTalentBuffs(for character: AbyssCharacter, to stats: inout AbyssStats) {
        for buff in talentBuffs[character.id] ?? [] {
            switch buff.kind {
            case .flatATKFromBaseATK where buff.fromBurst:
                stats.burstPartyFlatATK += buff.value * stats.baseATK
            case .flatATKFromBaseATK:
                stats.partyFlatATK += buff.value * stats.baseATK
            case .elementalDMG where buff.fromBurst:
                stats.burstPartyElementalDMG[character.element.simdIndex] += buff.value
            case .elementalDMG:
                stats.partyElementalDMG[character.element.simdIndex] += buff.value
            case .ownStat(let field):
                stats.add(buff.value, to: field)
            }
        }
    }

    /// The stat conversions this character's kit carries, as rates on the
    /// sheet — see `AbyssStats.atkFromHPRate`. Order does not matter: a rate
    /// adds, and `atk` multiplies it out from whatever HP the sheet ends with.
    func applyConversions(for character: AbyssCharacter, to stats: inout AbyssStats) {
        for conversion in conversions[character.id] ?? [] {
            switch conversion.from {
            case .hp: stats.atkFromHPRate += conversion.rate
            case .def: stats.atkFromDEFRate += conversion.rate
            case .atk, .em: break
            }
        }
    }

    /// Adds the set bonuses on top of a sheet from `statsWithoutSets`, then
    /// folds the rate buffs in: this is the last step of every sheet, so the
    /// stats a rate reads are final here.
    func applySets(_ sets: [AbyssArtifactSet],
                   character: AbyssCharacter,
                   to stats: inout AbyssStats,
                   diagnostics: inout AbyssParseDiagnostics) {
        if let known = setDeltas[character.id] {
            if sets.count == 1, let set = sets.first {
                known[set.id]?.twoPiece.apply(to: &stats)
                known[set.id]?.fourPiece.apply(to: &stats)
            } else {
                for set in sets { known[set.id]?.twoPiece.apply(to: &stats) }
            }
            stats.foldConversions()
            return
        }
        let wearer = wearer(for: character)
        if sets.count == 1, let set = sets.first {
            // Four pieces of one set: both bonuses apply.
            let buffs = setBuffs[set.id]
            apply(buffs?.twoPiece ?? [], refinement: 1, wearer: wearer, to: &stats)
            apply(buffs?.fourPiece ?? [], refinement: 1, wearer: wearer, to: &stats, recordsSetParty: true)
        } else {
            // Two pieces each of two sets: only the 2-piece bonuses.
            for set in sets {
                apply(setBuffs[set.id]?.twoPiece ?? [], refinement: 1, wearer: wearer, to: &stats)
            }
        }
        stats.foldConversions()
    }

    // MARK: - Stat name mapping

    /// Routes a stat named in the data into the matching field.
    /// Returns false when the name is not understood, so the caller can report
    /// it rather than silently dropping the bonus.
    @discardableResult
    func apply(named name: String, value rawValue: Double, to stats: inout AbyssStats) -> Bool {
        let resolved = Self.resolve(named: name, value: rawValue, tuning: tuning)
        guard !resolved.isEmpty else { return false }
        for entry in resolved { stats.add(entry.value, to: entry.field) }
        return true
    }

    /// The field(s) a named stat belongs in, and the value to put in each.
    ///
    /// Usually one, occasionally two: "Normal/Charged Attack DMG" really does
    /// raise both, and they are separate slots because the game treats a normal
    /// and a charged attack as different actions. Returning one field meant the
    /// charged half of five artifact sets was quietly dropped.
    ///
    /// Split from `apply` so the routing can be tested on its own. Since Phase 5
    /// it reads only the character data's own names — ascension stats and
    /// weapon substats; weapon passives and set bonuses are structured buffs.
    static func resolve(named name: String, value: Double,
                        tuning: AbyssTuning) -> [(field: AbyssStatField, value: Double)] {
        let key = name.lowercased()

        // Recognised, and deliberately worth nothing to a hit's damage — see
        // `unpriced(named:)`. Checked first: "Party Stellar Glimmer DMG Bonus"
        // says party and DMG, and used to reach every member's damage as +50%.
        if unpriced(named: name) != nil { return [] }

        // Flat stats. The data writes "Max HP: 1000" and "DEF: 100" for flat
        // bonuses and fractions below 1 for percentages, so magnitude tells them
        // apart; every percentage in the data is < 3. Elemental Mastery is flat
        // by nature and is handled by the rules below instead.
        if abs(value) > 3 && !key.contains("elemental mastery") {
            if key.contains("hp") { return [(.flatHP, value)] }
            if key.contains("atk") { return [(.flatATK, value)] }
            if key.contains("def") { return [(.flatDEF, value)] }
        }

        // "<Element> DMG Bonus"
        for (index, name) in Self.lowercasedElementNames.enumerated()
        where key.hasPrefix(name) && key.contains("dmg") {
            return [(.elemental(GenshinElement.allCases[index]), value)]
        }

        // Party-wide buffs are tracked separately: they apply to all four
        // members, including the character granting them.
        if key.contains("party") || key.contains("toàn đội") || key.contains("cả đội") {
            if key.contains("atk") {
                return [(.partyATKPercent, value)]
            } else if key.contains("elemental mastery") || key.hasSuffix(" em") {
                return [(.partyElementalMastery, value)]
            } else if key.contains("dmg") {
                return [(.partyDMG, value)]
            }
            // "Party Incoming Healing", "Party Shield Strength" used to land
            // here as +20% / +30% DMG for the whole party.
            return []
        }

        for rule in Self.nameRules where key.contains(rule.needle) {
            return rule.fields.map { (field: $0, value: value) }
        }

        // Bare names: artifact sets write "ATK"/"HP"/"DEF" for percentages.
        switch key {
        case "atk", "self atk": return [(.atkPercent, value)]
        case "hp": return [(.hpPercent, value)]
        case "def": return [(.defPercent, value)]
        default: break
        }

        // A bonus to every hit, however the data words the condition on it:
        // "DMG", "DMG Bonus", "DMG (while Nightsoul's Blessing active)", "DMG
        // vs Pyro-afflicted enemies". This used to be "anything that mentions
        // damage", which is how "Stellar Swirl DMG" became +40% to every hit
        // of every Scarlet Proof wearer and made it the best set for 95 of
        // 125 characters. A name outside these shapes is reported instead.
        if key == "dmg" || key == "dmg bonus" || key.hasPrefix("dmg (") || key.hasPrefix("dmg vs ") {
            return [(.dmgAll, value)]
        }
        return []
    }

    /// Why a recognised bonus is priced at nothing, or nil when it is priced.
    ///
    /// Three kinds, each a real effect the damage model has no slot for:
    /// reaction damage (priced per reaction by the scorer, not by adding it to
    /// every hit), Physical DMG (no hit in any profile is physical — see
    /// `tuning.notes.artifactMainStats`), and effects that are not damage at
    /// all. Kept apart from "not understood" so the unmapped report stays a
    /// list of gaps rather than a list of decisions.
    static func unpriced(named name: String) -> String? {
        let key = name.lowercased()
        if reactionName.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) != nil {
            return "reaction"
        }
        if key.contains("physical dmg") || key.contains("physical res") { return "physical" }
        if key.contains("healing") && !key.contains("healing bonus") && !key.contains("healing effectiveness") {
            return "not damage"
        }
        if key.contains("shield strength") { return "not damage" }
        return nil
    }

    /// Reaction names as the data writes them, including the umbrella terms
    /// ("Stellar Glimmer", "Lunar Reaction").
    private static let reactionName = try! NSRegularExpression(
        pattern: "\\b(swirl|superconduct|overloaded|electro-charged|bloom|hyperbloom|burgeon|burning|"
            + "crystallize|vaporize|melt|quicken|aggravate|spread|shatter|stellar|lunar|reaction)\\b")

    /// `GenshinElement.allCases` names, lowercased once.
    private static let lowercasedElementNames = GenshinElement.allCases.map { $0.rawValue.lowercased() }

    /// Ordered longest-first: "elemental skill and burst dmg" must be tested
    /// before "elemental skill dmg", which must come before "elemental".
    private static let nameRules: [(needle: String, fields: [AbyssStatField])] = [
            ("crit rate", [.critRate]),
            ("crit dmg", [.critDMG]),
            ("elemental mastery", [.elementalMastery]),
            ("energy recharge", [.energyRecharge]),
            ("healing bonus", [.healingBonus]),
            ("healing effectiveness", [.healingBonus]),
            // A bonus that names both really does raise both. Plunging attacks
            // are not in any damage profile, so the plunging variant adds
            // nothing beyond what its normal/charged halves already do.
            ("normal/charged/plunging attack dmg", [.dmgNormal, .dmgCharged]),
            ("normal/charged attack dmg", [.dmgNormal, .dmgCharged]),
            ("normal attack dmg", [.dmgNormal]),
            ("charged attack dmg", [.dmgCharged]),
            ("plunging attack dmg", [.dmgNormal]),
            ("elemental skill and burst dmg", [.dmgSkill]),
            ("elemental skill dmg", [.dmgSkill]),
            ("elemental burst dmg", [.dmgBurst]),
            ("max hp", [.hpPercent]),
            ("atk%", [.atkPercent]),
            ("hp%", [.hpPercent]),
            ("def%", [.defPercent]),
    ]

    /// What these sets contribute that the game's own character screen already
    /// shows: the bonuses that are always on.
    ///
    /// This is the inverse of `applySets` for the always-on half, and it exists
    /// so a *measured* stat sheet — read from a player's showcase, with their
    /// real artifacts already baked in — can have its set effects taken back out
    /// and a different set's put in. Without that, comparing "the set you are
    /// wearing" against "a set you could wear" would be comparing a measured
    /// number against a modelled one.
    func unconditionalSetContribution(_ sets: [AbyssArtifactSet]) -> [(field: AbyssStatField, value: Double)] {
        var contribution: [(field: AbyssStatField, value: Double)] = []

        func collect(_ buffs: [AbyssBuff]) {
            // Always on, the wearer's own, and not a rate of another stat: the
            // rest is either not on the screen or not a fixed number.
            for buff in buffs where buff.isAlwaysOn && buff.scope == .wearer && buff.source == nil {
                let value = buff.value(refinement: 1) * Double(buff.stacks)
                for field in Self.ownFields(buff, element: nil) { contribution.append((field, value)) }
            }
        }

        if sets.count == 1, let set = sets.first {
            collect(setBuffs[set.id]?.twoPiece ?? [])
            collect(setBuffs[set.id]?.fourPiece ?? [])
        } else {
            for set in sets { collect(setBuffs[set.id]?.twoPiece ?? []) }
        }
        return contribution
    }

    /// The stat sheet for a character the player actually owns, read from their
    /// showcase, normalised to level 90 and with the artifact set effects
    /// removed.
    ///
    /// What comes back is their real main stats and substats, their real weapon
    /// at its real refinement — everything except which *set* those artifacts
    /// belong to. Feeding it to `applySets` then answers "what if these same
    /// artifacts were a different set", which is the only honest way to compare
    /// a build they have against one they could have.
    ///
    /// **Levels are not read from the account.** The character's base HP/ATK/DEF
    /// and the weapon's base ATK are replaced with their level-90 values, the
    /// same numbers the modelled path uses and the same level
    /// `AbyssDamageMath.characterLevel` assumes when it computes the DEF
    /// multiplier. A roster half-way through levelling would otherwise be ranked
    /// on how far along it is rather than on what the build can do, and an
    /// imported character at 80 would score below a modelled one at 90 purely
    /// for being imported.
    ///
    /// Levelling shows up in two other places this cannot reach: the character's
    /// ascension stat and the weapon's substat both land in the percentage
    /// fields, mixed in with the artifact rolls, and the data carries only their
    /// level-90 values with nothing to subtract the account's own from. Those
    /// stay as measured, so a character well below 90 is still scored a little
    /// low.
    ///
    /// Conditional and stacking weapon passives are added here because the
    /// character screen does not show them; the unconditional ones are already
    /// in the measured numbers and must not be added twice.
    func showcaseStats(build: AbyssShowcaseBuild,
                       character: AbyssCharacter?,
                       weapon: AbyssWeapon?,
                       wornSets: [AbyssArtifactSet]) -> AbyssStats {
        var stats = build.stats.stats

        if let lv90 = character?.baseStats.lv90 {
            // Enka reports base ATK with the weapon's own base already added in
            // (base HP and DEF come from the character alone), so the level-90
            // replacement has to be assembled the same way.
            if let atk = lv90.atk { stats.baseATK = atk + (weapon?.atkLv90 ?? 0) }
            if let hp = lv90.hp { stats.baseHP = hp }
            if let def = lv90.def { stats.baseDEF = def }
        }

        for entry in unconditionalSetContribution(wornSets) {
            // Party-scoped bonuses are never in the measured numbers — the game
            // screen shows what this character keeps, not what they hand the
            // other three — so there is nothing to take back out. Subtracting
            // them anyway left the sheet granting a *negative* party buff, and
            // the artifact advisor, which dresses this character in some other
            // set afterwards, carried that negative straight into the team
            // score: an imported Noblesse Oblige wearer moved to another set
            // used to hand the party −20% ATK.
            guard !entry.field.isPartyScoped else { continue }
            stats.add(-entry.value, to: entry.field)
        }
        if let weapon {
            applyWeaponPassive(weapon, refinement: build.weaponRefinement, character: character, to: &stats,
                               conditionalOnly: true)
        }
        // Party buffs are never in the measured numbers: the game's character
        // screen shows what the character has, not what they hand the other
        // three.
        if let character { applyTalentBuffs(for: character, to: &stats) }
        return stats
    }

    // MARK: - Weapon passives and set bonuses

    /// - Parameter conditionalOnly: skip what the game's character screen
    ///   already shows, for use on top of a measured stat sheet: the wearer's
    ///   own always-on buffs. Triggered and party buffs are not on that screen.
    private func applyWeaponPassive(_ weapon: AbyssWeapon, refinement: Int, character: AbyssCharacter?,
                                    to stats: inout AbyssStats, conditionalOnly: Bool = false) {
        var buffs = weaponBuffs[weapon.id] ?? []
        if conditionalOnly { buffs.removeAll { $0.isAlwaysOn && $0.scope == .wearer } }
        let wearer = character.map(wearer(for:)) ?? .standIn
        apply(buffs, refinement: refinement, wearer: wearer, to: &stats)
    }

    /// The rotation the timeline reads for a character: the optimizer's, or
    /// the stand-in's timing with the character's own facts.
    func wearer(for character: AbyssCharacter) -> AbyssBuffWearer {
        if let known = wearers[character.id] { return known }
        var wearer = AbyssBuffWearer.standIn
        wearer.element = character.element
        wearer.weaponType = character.weaponType.rawValue
        wearer.nation = character.nationInGame
        wearer.nightsoul = character.nationInGame == "Natlan"
        wearer.bondOfLife = bondOfLifeIDs.contains(character.id)
        wearer.moonsign = moonsignIDs.contains(character.id)
        return wearer
    }

    /// Adds buffs to a sheet at their standing on this wearer.
    ///
    /// Effects sharing a `group` are one effect at a time (The Widsith plays
    /// one of three songs), so each counts for its share of the group.
    ///
    /// - Parameter recordsSetParty: these are a four-piece set's, whose party
    ///   buffs do not stack with a second wearer of the same set — recorded on
    ///   the sheet for `AbyssScorer.partyBuffs` to take back out.
    func apply(_ buffs: [AbyssBuff], refinement: Int, wearer: AbyssBuffWearer, to stats: inout AbyssStats,
               recordsSetParty: Bool = false) {
        Self.apply(buffs, refinement: refinement, wearer: wearer, to: &stats, recordsSetParty: recordsSetParty)
    }

    static func apply(_ buffs: [AbyssBuff], refinement: Int, wearer: AbyssBuffWearer, to stats: inout AbyssStats,
                      recordsSetParty: Bool = false) {
        var groups: [String: Int] = [:]
        for buff in buffs { if let group = buff.group { groups[group, default: 0] += 1 } }
        for buff in buffs {
            let share = buff.group.map { 1 / Double(groups[$0] ?? 1) } ?? 1
            apply(buff, refinement: refinement, wearer: wearer, share: share, to: &stats,
                  recordsSetParty: recordsSetParty)
        }
    }

    private static func apply(_ buff: AbyssBuff, refinement: Int, wearer: AbyssBuffWearer, share: Double,
                              to stats: inout AbyssStats, recordsSetParty: Bool) {
        let reading = AbyssBuffTimeline.read(buff, wearer: wearer)
        guard !reading.isOff else { return }
        let gated = reading.any != 0 || reading.all != 0
        let perMember = reading.limit < 0

        /// The buff's value at an average stack count.
        func amount(_ stacks: Double) -> Double {
            let tiers = buff.tiers(refinement: refinement)
            guard !tiers.isEmpty else { return buff.value(refinement: refinement) * stacks * share }
            // Counted per member, a tier table is read as its slope.
            if perMember { return (tiers.last ?? 0) / Double(tiers.count) * stacks * share }
            let clamped = min(max(stacks, 0), Double(tiers.count))
            let lower = Int(clamped.rounded(.down))
            let low = lower == 0 ? 0 : tiers[lower - 1]
            let high = lower >= tiers.count ? low : tiers[lower]
            return (low + (high - low) * (clamped - Double(lower))) * share
        }

        func add(_ value: Double, _ field: AbyssStatField) {
            if gated {
                stats.gates.append(value: value, field: field, any: reading.any, all: reading.all,
                                   limit: reading.limit)
            } else {
                stats.add(value, to: field)
            }
        }

        let categories = AbyssBuffTimeline.categories
        let reached = buff.on.isEmpty ? categories : categories.filter { buff.on.reaches($0) }
        let total = reached.reduce(0) { $0 + wearer.weights[AbyssStats.categoryIndex($1)] }
        /// Stacks averaged over the wearer's own damage of the kinds it reaches.
        let ownStacks: Double = {
            guard total > 0 else {
                return reached.map { reading.stacks[AbyssStats.categoryIndex($0)] }.max() ?? 0
            }
            return reached.reduce(0) {
                $0 + wearer.weights[AbyssStats.categoryIndex($1)] * reading.stacks[AbyssStats.categoryIndex($1)]
            } / total
        }()

        switch buff.scope {
        case .wearer:
            if let source = buff.source {
                guard let field = ownFields(buff, element: wearer.element).first else { return }
                let rate = amount(ownStacks) / buff.per
                stats.conversions.append(rate: rate, cap: buff.cap(refinement: refinement),
                                         source: AbyssConversions.Source(source), field: field,
                                         any: reading.any, all: reading.all, limit: reading.limit)
                return
            }
            switch buff.stat {
            case .dmg where buff.on.isEmpty && !gated:
                // Per kind of hit: a triggered bonus is worth different stacks
                // to a skill than to the attacks after it.
                let stacks = reading.stacks
                if stacks[0] == stacks[1], stacks[1] == stacks[2], stacks[2] == stacks[3] {
                    add(amount(stacks[0]), .dmgAll)
                } else {
                    for category in categories {
                        add(amount(stacks[AbyssStats.categoryIndex(category)]), .dmg(for: category))
                    }
                }
            case .dmg, .critRate, .critDMG:
                if buff.on.isEmpty {
                    guard let field = ownFields(buff, element: wearer.element).first else { return }
                    add(amount(ownStacks), field)
                } else {
                    for category in reached {
                        let stacks = reading.stacks[AbyssStats.categoryIndex(category)]
                        switch buff.stat {
                        case .critRate: add(amount(stacks), .critRateFor(category))
                        case .critDMG: add(amount(stacks), .critDMGFor(category))
                        default: add(amount(stacks), .dmg(for: category))
                        }
                    }
                }
            default:
                for field in ownFields(buff, element: wearer.element) { add(amount(ownStacks), field) }
            }

        case .party, .active, .others:
            guard let field = partyField(buff, element: wearer.element) else { return }
            let value = amount(reading.rotation)
            if let source = buff.source {
                stats.conversions.append(rate: value / buff.per, cap: buff.cap(refinement: refinement),
                                         source: AbyssConversions.Source(source), field: field,
                                         any: reading.any, all: reading.all, limit: reading.limit)
            } else {
                add(value, field)
                if recordsSetParty, !gated { recordSetParty(value, field, on: &stats) }
            }
            // "Party members other than the wearer": the wearer's copy of the
            // party buff is taken back out of their own sheet.
            if buff.scope == .others, let own = ownFields(buff, element: wearer.element).first {
                if let source = buff.source {
                    stats.conversions.append(rate: -value / buff.per, cap: nil,
                                             source: AbyssConversions.Source(source), field: own,
                                             any: reading.any, all: reading.all, limit: reading.limit)
                } else {
                    add(-value, own)
                }
            }
        }
    }

    /// Where a buff lands on the wearer's own sheet. Empty for a bonus to
    /// plunging attacks only, which no damage profile has.
    static func ownFields(_ buff: AbyssBuff, element: GenshinElement?) -> [AbyssStatField] {
        switch buff.stat {
        case .atkPercent: return [.atkPercent]
        case .hpPercent: return [.hpPercent]
        case .defPercent: return [.defPercent]
        case .flatATK: return [.flatATK]
        case .elementalMastery: return [.elementalMastery]
        case .energyRecharge: return [.energyRecharge]
        case .critRate: return [.critRate]
        case .critDMG: return [.critDMG]
        case .dmg:
            if buff.on.isEmpty { return [.dmgAll] }
            return AbyssBuffTimeline.categories.filter { buff.on.reaches($0) }.map { AbyssStatField.dmg(for: $0) }
        case .ownElementDMG: return element.map { [.elemental($0)] } ?? []
        case .elementDMG(let element): return [.elemental(element)]
        }
    }

    /// Where a buff lands when it reaches the party, or nil for a stat the
    /// party channels do not carry (CRIT, Energy Recharge, HP, and a bonus to
    /// only some kinds of hit).
    private static func partyField(_ buff: AbyssBuff, element: GenshinElement) -> AbyssStatField? {
        switch buff.stat {
        case .atkPercent: return .partyATKPercent
        case .flatATK: return .partyFlatATK
        case .elementalMastery: return .partyElementalMastery
        case .dmg where buff.on.isEmpty: return .partyDMG
        case .ownElementDMG: return .partyElementalDMG(element)
        case .elementDMG(let other): return .partyElementalDMG(other)
        default: return nil
        }
    }

    private static func recordSetParty(_ value: Double, _ field: AbyssStatField, on stats: inout AbyssStats) {
        switch field {
        case .partyATKPercent: stats.setPartyATKPercent += value
        case .partyFlatATK: stats.setPartyFlatATK += value
        case .partyElementalMastery: stats.setPartyElementalMastery += value
        case .partyDMG: stats.setPartyDMG += value
        case .partyElementalDMG(let element): stats.setPartyElementalDMG[element.simdIndex] += value
        default: break
        }
    }

    // MARK: - Artifacts

    /// What each slot is allowed to hold, for a search to pick from.
    ///
    /// Two of the lists are cut down, and both cuts are worth stating.
    ///
    /// The goblet offers one element rather than seven. A DMG bonus for an
    /// element only ever multiplies that element's damage, and a character deals
    /// their own; a Cryo goblet on a Pyro character contributes exactly zero
    /// here, so the other six are not candidates, they are wasted evaluations.
    ///
    /// The other cut is a constraint standing in for something the objective
    /// cannot see. The score is damage, and it has no term for "the heal
    /// landed" — so Healing Bonus is worth nothing to it, and a free search
    /// would strip it from every healer and call it an improvement. So a
    /// healer keeps the Healing Bonus circlet, and the search picks the rest.
    ///
    /// There used to be a second such line: a support or shielder kept the
    /// Energy Recharge sands, because the score could not see "the burst was
    /// up" either. Phase 3 made it see that — a burst is cast as often as
    /// energy allows, and a support's party buff from it scales the same way —
    /// so the sands is searched like every other slot now.
    func mainStatCandidates(role: AbyssRole,
                            element: GenshinElement) -> (sands: [AbyssMainStat],
                                                         goblet: [AbyssMainStat],
                                                         circlet: [AbyssMainStat]) {
        let scaling: [AbyssMainStat] = [.atkPercent, .hpPercent, .defPercent, .elementalMastery]
        let sands: [AbyssMainStat] = scaling + [.energyRecharge]
        let circlet: [AbyssMainStat] = role == .healer
            ? [.healingBonus]
            : scaling + [.critRate, .critDMG]
        return (sands, [.elementalDMG(element)] + scaling, circlet)
    }

    /// Tuning key holding a main stat's level-20 value. One hop, because the
    /// slot already knows its own name outside Swift — see
    /// `AbyssStatField.tuningKey`.
    private static func tuningKey(for stat: AbyssMainStat) -> String {
        stat.statField.tuningKey
    }

    /// How the assumed substat roll budget is split, richest share first.
    ///
    /// Ordered, unlike the dictionary it comes from: the UI shows this list, and
    /// summing the rolls in a fixed order also removes a hidden source of
    /// run-to-run drift — Swift seeds `Dictionary` hashing per process, so the
    /// old code added the same rolls in a different order on every launch and
    /// the last bits of every score moved with it.
    func substatPlan(role: AbyssRole, basis: ScalingBasis) -> [(key: String, share: Double)] {
        var priority = tuning.substatPriority[role.rawValue]
            ?? tuning.substatPriority[AbyssRole.subDPS.rawValue]
            ?? [:]

        // A DEF- or HP-scaling character wants those rolls where an ATK-scaling
        // one would want ATK%.
        if let swaps = tuning.scalingBasisSwap[basis.rawValue] {
            for (source, destination) in swaps.sorted(by: { $0.key < $1.key }) {
                guard let share = priority.removeValue(forKey: source) else { continue }
                priority[destination, default: 0] += share
            }
        }

        return priority
            .map { (key: $0.key, share: $0.value) }
            .sorted { lhs, rhs in
                if lhs.share != rhs.share { return lhs.share > rhs.share }
                return lhs.key < rhs.key
            }
    }

    /// Spends the assumed substat roll budget according to the role's priorities.
    private func applySubstats(role: AbyssRole, basis: ScalingBasis, to stats: inout AbyssStats) {
        for entry in substatPlan(role: role, basis: basis) {
            let value = tuning.substatRollBudget * entry.share * tuning.rollValue(entry.key)
            guard let field = Self.substatField(entry.key) else { continue }
            stats.add(value, to: field)
        }
    }

    private static func substatField(_ key: String) -> AbyssStatField? {
        AbyssStatField(tuningKey: key)
    }
}

/// What a group of buffs adds to a sheet, recorded once so it can be added
/// again without reading the timeline again. Every buff only ever adds to a
/// field, appends a gate or appends a conversion, so the difference from an
/// empty sheet is the whole effect.
struct AbyssSheetDelta: Sendable {
    private var fields: [(field: AbyssStatField, value: Double)] = []
    private var gates: [AbyssGate] = []
    private var conversions: [AbyssConversion] = []
    private var setParty: (atk: Double, flatATK: Double, em: Double, dmg: Double, elemental: SIMD8<Double>)?

    static func of(_ build: (inout AbyssStats) -> Void) -> AbyssSheetDelta {
        let empty = AbyssStats()
        var sheet = empty
        build(&sheet)
        var delta = AbyssSheetDelta()
        for field in AbyssStatField.indexed {
            let value = sheet.value(of: field) - empty.value(of: field)
            if value != 0 { delta.fields.append((field, value)) }
        }
        for index in 0..<sheet.gates.count { delta.gates.append(sheet.gates[index]) }
        for index in 0..<sheet.conversions.count { delta.conversions.append(sheet.conversions[index]) }
        if sheet.setPartyATKPercent != 0 || sheet.setPartyFlatATK != 0 || sheet.setPartyElementalMastery != 0
            || sheet.setPartyDMG != 0 || sheet.setPartyElementalDMG != .zero {
            delta.setParty = (sheet.setPartyATKPercent, sheet.setPartyFlatATK, sheet.setPartyElementalMastery,
                              sheet.setPartyDMG, sheet.setPartyElementalDMG)
        }
        return delta
    }

    func apply(to stats: inout AbyssStats) {
        for entry in fields { stats.add(entry.value, to: entry.field) }
        for gate in gates { stats.gates.append(gate) }
        for conversion in conversions { stats.conversions.append(conversion) }
        if let setParty {
            stats.setPartyATKPercent += setParty.atk
            stats.setPartyFlatATK += setParty.flatATK
            stats.setPartyElementalMastery += setParty.em
            stats.setPartyDMG += setParty.dmg
            stats.setPartyElementalDMG += setParty.elemental
        }
    }
}
