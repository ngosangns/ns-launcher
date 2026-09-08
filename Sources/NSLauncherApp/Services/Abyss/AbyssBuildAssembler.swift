// AbyssBuildAssembler.swift
//
// Assembles a character's stat sheet: character base at level 90, weapon at 90,
// and a 5★ level-20 artifact set chosen for their role. Ported from `build.py`.
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
// plausible, permanently wrong numbers. The rules below are kept in the Python's
// order because the order is load-bearing — "elemental skill dmg" has to be
// tested before "elemental" would match something else.

import Foundation

struct AbyssBuildAssembler: Sendable {
    let tuning: AbyssTuning
    let moonsignIDs: Set<String>

    /// Where each artifact set's bonuses land, resolved once per set id.
    ///
    /// `resolve(named:)` lowercases and substring-matches its way through
    /// nineteen rules, which is cheap once and ruinous when the artifact advisor
    /// dresses the same character in the same sixty sets a few thousand times.
    /// This is a memo of a pure function, not a second implementation: a set
    /// that is not in the table is resolved by exactly the same code.
    private let resolvedSets: [String: ResolvedSet]

    private struct ResolvedSet: Sendable {
        let twoPiece: [ResolvedBonus]
        let fourPiece: [ResolvedBonus]
    }

    /// One artifact bonus after name resolution. `field` is nil when the name
    /// was not understood, which the diagnostics report rather than swallow.
    private struct ResolvedBonus: Sendable {
        let field: AbyssStatField?
        let value: Double
        let name: String
        /// The bonus is qualified ("CRIT Rate (when HP below 70%)") and so is
        /// only active some of the time. Recorded because the game's own
        /// character screen shows the unconditional bonuses and not these, which
        /// is what lets a measured stat sheet be taken back apart.
        let isConditional: Bool
    }

    init(tuning: AbyssTuning, moonsignIDs: Set<String>, artifactSets: [AbyssArtifactSet] = []) {
        self.tuning = tuning
        self.moonsignIDs = moonsignIDs

        var resolved: [String: ResolvedSet] = [:]
        resolved.reserveCapacity(artifactSets.count)
        for set in artifactSets {
            resolved[set.id] = ResolvedSet(
                twoPiece: Self.resolveBonuses(set.twoPiece.bonuses, tuning: tuning),
                fourPiece: Self.resolveBonuses(set.fourPiece.bonuses, tuning: tuning))
        }
        resolvedSets = resolved
    }

    /// Builds the level-90 stat sheet for one character/weapon/artifact combination.
    func stats(character: AbyssCharacter,
               profile: AbyssDamageProfile,
               weapon: AbyssWeapon?,
               sets: [AbyssArtifactSet],
               role: AbyssRole,
               refinement: Int = 1,
               diagnostics: inout AbyssParseDiagnostics) -> AbyssStats {
        var stats = statsWithoutSets(character: character, profile: profile, weapon: weapon,
                                     role: role, refinement: refinement)
        applySets(sets, character: character, to: &stats, diagnostics: &diagnostics)
        return stats
    }

    /// Everything that does not depend on which artifact *sets* are worn:
    /// character base, weapon, artifact main stats and substats.
    ///
    /// Separate from `applySets` because the artifact advisor tries dozens of
    /// set combinations for one character and weapon, and this half is both the
    /// expensive one — the weapon passive is matched with regexes — and the one
    /// that does not change between them.
    func statsWithoutSets(character: AbyssCharacter,
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
            applyWeaponPassive(weapon, refinement: refinement, to: &stats)
        }

        applyArtifactMainStats(role: role, basis: profile.basis, element: character.element, to: &stats)
        applySubstats(role: role, basis: profile.basis, to: &stats)

        return stats
    }

    /// Adds the set bonuses on top of a sheet from `statsWithoutSets`.
    func applySets(_ sets: [AbyssArtifactSet],
                   character: AbyssCharacter,
                   to stats: inout AbyssStats,
                   diagnostics: inout AbyssParseDiagnostics) {
        if sets.count == 1, let set = sets.first {
            // Four pieces of one set: both bonuses apply.
            let entry = resolved(set)
            applyArtifactBonuses(entry.twoPiece, to: &stats, diagnostics: &diagnostics)
            applyArtifactBonuses(entry.fourPiece, to: &stats, diagnostics: &diagnostics)
            applySetApproximation(for: set, character: character, to: &stats)
        } else {
            // Two pieces each of two sets: only the 2-piece bonuses.
            for set in sets {
                applyArtifactBonuses(resolved(set).twoPiece, to: &stats, diagnostics: &diagnostics)
            }
        }
    }

    // MARK: - Stat name mapping

    /// Routes a stat named in the data into the matching field.
    /// Returns false when the name is not understood, so the caller can report
    /// it rather than silently dropping the bonus.
    @discardableResult
    func apply(named name: String, value rawValue: Double, to stats: inout AbyssStats,
               conditional: Bool = false) -> Bool {
        guard let resolved = Self.resolve(named: name, value: rawValue, conditional: conditional,
                                          tuning: tuning) else { return false }
        stats.add(resolved.value, to: resolved.field)
        return true
    }

    /// The field a named stat belongs in, and the value to put there.
    ///
    /// Split from `apply` so the result can be cached: the routing depends only
    /// on the name, and the same names are resolved over and over.
    static func resolve(named name: String, value rawValue: Double, conditional: Bool,
                        tuning: AbyssTuning) -> (field: AbyssStatField, value: Double)? {
        var value = rawValue
        if conditional { value *= tuning.conditionalUptime }
        let key = name.lowercased()

        // Flat stats. The data writes "Max HP: 1000" and "DEF: 100" for flat
        // bonuses and fractions below 1 for percentages, so magnitude tells them
        // apart; every percentage in the data is < 3. Elemental Mastery is flat
        // by nature and is handled by the rules below instead.
        if abs(value) > 3 && !key.contains("elemental mastery") {
            if key.contains("hp") { return (.flatHP, value) }
            if key.contains("atk") { return (.flatATK, value) }
            if key.contains("def") { return (.flatDEF, value) }
        }

        // "<Element> DMG Bonus"
        for (index, name) in Self.lowercasedElementNames.enumerated()
        where key.hasPrefix(name) && key.contains("dmg") {
            return (.elemental(GenshinElement.allCases[index]), value)
        }

        // Party-wide buffs are tracked separately: they apply to all four
        // members, including the character granting them.
        if key.contains("party") || key.contains("toàn đội") || key.contains("cả đội") {
            if key.contains("atk") {
                return (.partyATKPercent, value)
            } else if key.contains("elemental mastery") || key.hasSuffix(" em") {
                return (.partyElementalMastery, value)
            } else {
                return (.partyDMG, value)
            }
        }

        for rule in Self.nameRules where key.contains(rule.needle) {
            return (rule.field, value)
        }

        // Bare names: artifact sets write "ATK"/"HP"/"DEF" for percentages.
        switch key {
        case "atk", "self atk": return (.atkPercent, value)
        case "hp": return (.hpPercent, value)
        case "def": return (.defPercent, value)
        default: break
        }

        // Anything else that mentions damage counts as a general bonus.
        if key.contains("dmg") { return (.dmgAll, value) }
        return nil
    }

    /// `GenshinElement.allCases` names, lowercased once.
    private static let lowercasedElementNames = GenshinElement.allCases.map { $0.rawValue.lowercased() }

    /// Ordered longest-first: "elemental skill and burst dmg" must be tested
    /// before "elemental skill dmg", which must come before "elemental".
    private static let nameRules: [(needle: String, field: AbyssStatField)] = [
            ("crit rate", .critRate),
            ("crit dmg", .critDMG),
            ("elemental mastery", .elementalMastery),
            ("energy recharge", .energyRecharge),
            ("healing bonus", .healingBonus),
            ("healing effectiveness", .healingBonus),
            ("normal/charged/plunging attack dmg", .dmgNormal),
            ("normal/charged attack dmg", .dmgNormal),
            ("normal attack dmg", .dmgNormal),
            ("charged attack dmg", .dmgCharged),
            ("plunging attack dmg", .dmgNormal),
            ("elemental skill and burst dmg", .dmgSkill),
            ("elemental skill dmg", .dmgSkill),
            ("elemental burst dmg", .dmgBurst),
            ("physical dmg", .dmgAll),
            ("max hp", .hpPercent),
            ("atk%", .atkPercent),
            ("hp%", .hpPercent),
            ("def%", .defPercent),
    ]

    /// Resolves a set's bonuses once, keeping the names of the ones that did not
    /// map so the diagnostics can still report them on every use.
    private static func resolveBonuses(_ bonuses: [AbyssArtifactSet.Bonus],
                                       tuning: AbyssTuning) -> [ResolvedBonus] {
        bonuses.map { bonus in
            // A qualifier in parentheses ("CRIT Rate (when HP below 70%)")
            // means the bonus is conditional and rarely at full uptime.
            let conditional = bonus.stat.contains("(")
            let resolved = resolve(named: bonus.stat, value: bonus.value,
                                   conditional: conditional, tuning: tuning)
            return ResolvedBonus(field: resolved?.field, value: resolved?.value ?? 0,
                                 name: bonus.stat, isConditional: conditional)
        }
    }

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

        func collect(_ bonuses: [ResolvedBonus]) {
            for bonus in bonuses where !bonus.isConditional {
                guard let field = bonus.field else { continue }
                contribution.append((field, bonus.value))
            }
        }

        if sets.count == 1, let set = sets.first {
            let entry = resolved(set)
            collect(entry.twoPiece)
            collect(entry.fourPiece)
        } else {
            for set in sets { collect(resolved(set).twoPiece) }
        }
        return contribution
    }

    /// The stat sheet for a character the player actually owns, read from their
    /// showcase, with the artifact set effects removed.
    ///
    /// What comes back is their real base stats, real weapon, and the real main
    /// stats and substats they rolled — everything except which *set* those
    /// artifacts belong to. Feeding it to `applySets` then answers "what if
    /// these same artifacts were a different set", which is the only honest way
    /// to compare a build they have against one they could have.
    ///
    /// Conditional and stacking weapon passives are added here because the
    /// character screen does not show them; the unconditional ones are already
    /// in the measured numbers and must not be added twice.
    func showcaseStats(build: AbyssShowcaseBuild,
                       weapon: AbyssWeapon?,
                       wornSets: [AbyssArtifactSet]) -> AbyssStats {
        var stats = build.stats.stats
        for entry in unconditionalSetContribution(wornSets) {
            stats.add(-entry.value, to: entry.field)
        }
        if let weapon {
            applyWeaponPassive(weapon, refinement: build.weaponRefinement, to: &stats,
                               conditionalOnly: true)
        }
        return stats
    }

    private func applyArtifactBonuses(_ bonuses: [ResolvedBonus],
                                      to stats: inout AbyssStats,
                                      diagnostics: inout AbyssParseDiagnostics) {
        for bonus in bonuses {
            guard let field = bonus.field else {
                diagnostics.artifactBonusUnmapped.insert(bonus.name)
                continue
            }
            stats.add(bonus.value, to: field)
            diagnostics.artifactBonusMapped += 1
        }
    }

    /// The table entry for a set, resolving it on the spot if the assembler was
    /// built without the set list.
    private func resolved(_ set: AbyssArtifactSet) -> ResolvedSet {
        resolvedSets[set.id] ?? ResolvedSet(
            twoPiece: Self.resolveBonuses(set.twoPiece.bonuses, tuning: tuning),
            fourPiece: Self.resolveBonuses(set.fourPiece.bonuses, tuning: tuning))
    }

    // MARK: - Weapon passives

    /// Effect names that describe an extra hit rather than a stat buff, e.g.
    /// "AoE DMG (% ATK)". Counting those as a damage bonus would be wrong twice
    /// over — they are damage instances, and they are far larger than any buff.
    private static let notAStatBuff = try? NSRegularExpression(
        pattern: "\\(\\s*%|cooldown|chance|restore|\\bspd\\b|particle|energy|reset|duration",
        options: [.caseInsensitive])
    private static let isStatBuff = try? NSRegularExpression(pattern: "buff|bonus", options: [.caseInsensitive])
    private static let perStack = try? NSRegularExpression(pattern: "per stack|per seal|per .*stack",
                                                           options: [.caseInsensitive])
    private static let partyScoped = try? NSRegularExpression(pattern: "team|party|toàn đội",
                                                              options: [.caseInsensitive])

    /// Ordered like the Python's rule list: the first pattern that matches wins.
    private static let weaponEffectRules: [(pattern: NSRegularExpression?, field: AbyssStatField)] = [
        (try? NSRegularExpression(pattern: "crit\\s*rate", options: [.caseInsensitive]), .critRate),
        (try? NSRegularExpression(pattern: "crit\\s*dmg", options: [.caseInsensitive]), .critDMG),
        (try? NSRegularExpression(pattern: "elemental\\s*mastery|^em\\b", options: [.caseInsensitive]), .elementalMastery),
        (try? NSRegularExpression(pattern: "energy\\s*recharge", options: [.caseInsensitive]), .energyRecharge),
        (try? NSRegularExpression(pattern: "normal", options: [.caseInsensitive]), .dmgNormal),
        (try? NSRegularExpression(pattern: "charged", options: [.caseInsensitive]), .dmgCharged),
        (try? NSRegularExpression(pattern: "skill", options: [.caseInsensitive]), .dmgSkill),
        (try? NSRegularExpression(pattern: "burst", options: [.caseInsensitive]), .dmgBurst),
        (try? NSRegularExpression(pattern: "\\batk\\b", options: [.caseInsensitive]), .atkPercent),
        (try? NSRegularExpression(pattern: "\\bhp\\b", options: [.caseInsensitive]), .hpPercent),
        (try? NSRegularExpression(pattern: "\\bdef\\b", options: [.caseInsensitive]), .defPercent),
        (try? NSRegularExpression(pattern: "dmg", options: [.caseInsensitive]), .dmgAll),
    ]

    /// - Parameter conditionalOnly: skip passives the game's character screen
    ///   already shows, for use on top of a measured stat sheet. A passive
    ///   counts as hidden when it is qualified or stacks — at rest, neither is
    ///   in the numbers the game displays.
    private func applyWeaponPassive(_ weapon: AbyssWeapon, refinement: Int, to stats: inout AbyssStats,
                                    conditionalOnly: Bool = false) {
        guard let passive = weapon.passive else { return }

        for effect in passive.effects {
            guard var value = effect.value(refinement: refinement) else { continue }
            let name = effect.stat

            // Only lines that actually name a stat buff.
            guard Self.matches(Self.isStatBuff, name), !Self.matches(Self.notAStatBuff, name) else { continue }
            // A value above 3 is a hit's damage percentage, not a buff.
            guard abs(value) <= 3 else { continue }

            let stacks = Self.matches(Self.perStack, name)
            if conditionalOnly, !stacks, !name.contains("(") { continue }

            if stacks { value *= tuning.assumedStacks }
            if name.contains("(") { value *= tuning.conditionalUptime }

            let isParty = Self.matches(Self.partyScoped, name)
            for rule in Self.weaponEffectRules where Self.matches(rule.pattern, name) {
                if isParty, rule.field == .atkPercent {
                    stats.partyATKPercent += value
                } else {
                    stats.add(value, to: rule.field)
                }
                break
            }
        }
    }

    private static func matches(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        guard let regex else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: - Artifacts

    /// Which main stat goes in each of the three slots the model varies. Flower
    /// and Plume are fixed HP/ATK and are not part of any decision.
    ///
    /// Returned as data rather than applied directly so the Abyss tab can *show*
    /// the build it is recommending. The recommendation and the scored stat
    /// sheet come from this one function, so the advice cannot describe a build
    /// other than the one that produced the number next to it.
    func mainStatPlan(role: AbyssRole,
                      basis: ScalingBasis,
                      element: GenshinElement) -> (sands: AbyssMainStat, goblet: AbyssMainStat, circlet: AbyssMainStat) {
        // Sands: supports need energy, healers need HP, damage dealers follow
        // whichever stat their kit scales off.
        let sands: AbyssMainStat
        switch role {
        case .support, .shield:
            sands = .energyRecharge
        case .healer:
            sands = .hpPercent
        case .mainDPS, .subDPS:
            switch basis {
            case .def: sands = .defPercent
            case .hp: sands = .hpPercent
            case .em: sands = .elementalMastery
            case .atk: sands = .atkPercent
            }
        }

        // Goblet is always the character's own element; the circlet is CRIT DMG
        // for everyone who is not there to heal.
        return (sands, .elementalDMG(element), role == .healer ? .healingBonus : .critDMG)
    }

    private func applyArtifactMainStats(role: AbyssRole,
                                        basis: ScalingBasis,
                                        element: GenshinElement,
                                        to stats: inout AbyssStats) {
        // Flower and Plume are fixed.
        stats.flatHP += tuning.mainStat("flat_hp")
        stats.flatATK += tuning.mainStat("flat_atk")

        let plan = mainStatPlan(role: role, basis: basis, element: element)
        for slot in [plan.sands, plan.goblet, plan.circlet] {
            stats.add(tuning.mainStat(Self.tuningKey(for: slot)), to: slot.statField)
        }
    }

    /// Tuning key holding a main stat's level-20 value.
    private static func tuningKey(for stat: AbyssMainStat) -> String {
        switch stat {
        case .atkPercent: return "atk_pct"
        case .hpPercent: return "hp_pct"
        case .defPercent: return "def_pct"
        case .elementalMastery: return "em"
        case .energyRecharge: return "er"
        case .critRate: return "crit_rate"
        case .critDMG: return "crit_dmg"
        case .healingBonus: return "healing_bonus"
        case .elementalDMG: return "elemental_dmg"
        }
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
        switch key {
        case "crit_rate": return .critRate
        case "crit_dmg": return .critDMG
        case "atk_pct": return .atkPercent
        case "hp_pct": return .hpPercent
        case "def_pct": return .defPercent
        case "em": return .elementalMastery
        case "er": return .energyRecharge
        case "flat_atk": return .flatATK
        case "flat_hp": return .flatHP
        case "flat_def": return .flatDEF
        default: return nil
        }
    }

    /// Credits the hand-estimated effect of a 4-piece set whose real behaviour
    /// was too conditional to read off the data. See `tuning.json`.
    private func applySetApproximation(for set: AbyssArtifactSet,
                                       character: AbyssCharacter,
                                       to stats: inout AbyssStats) {
        guard let approximation = tuning.setEffectApprox.first(where: { $0.setId == set.id }),
              meetsRequirement(approximation.requirement, character: character) else { return }
        stats.add(approximation.damageBonus, to: approximation.scope.statField)
    }

    private func meetsRequirement(_ requirement: AbyssTuning.SetEffectApproximation.Requirement?,
                                  character: AbyssCharacter) -> Bool {
        switch requirement {
        case nil:
            return true
        case .natlan:
            return character.nationInGame == "Natlan"
        case .moonsign:
            return moonsignIDs.contains(character.id)
        case .stellar:
            return [.cryo, .electro, .anemo].contains(character.element)
        }
    }
}
