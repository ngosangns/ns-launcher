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

    init(tuning: AbyssTuning, moonsignIDs: Set<String>) {
        self.tuning = tuning
        self.moonsignIDs = moonsignIDs
    }

    /// Builds the level-90 stat sheet for one character/weapon/artifact combination.
    func stats(character: AbyssCharacter,
               profile: AbyssDamageProfile,
               weapon: AbyssWeapon?,
               sets: [AbyssArtifactSet],
               role: AbyssRole,
               refinement: Int = 1,
               diagnostics: inout AbyssParseDiagnostics) -> AbyssStats {
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

        if sets.count == 1, let set = sets.first {
            // Four pieces of one set: both bonuses apply.
            applyArtifactBonuses(set.twoPiece.bonuses, to: &stats, diagnostics: &diagnostics)
            applyArtifactBonuses(set.fourPiece.bonuses, to: &stats, diagnostics: &diagnostics)
            applySetApproximation(for: set, character: character, to: &stats)
        } else {
            // Two pieces each of two sets: only the 2-piece bonuses.
            for set in sets {
                applyArtifactBonuses(set.twoPiece.bonuses, to: &stats, diagnostics: &diagnostics)
            }
        }

        return stats
    }

    // MARK: - Stat name mapping

    /// Routes a stat named in the data into the matching field.
    /// Returns false when the name is not understood, so the caller can report
    /// it rather than silently dropping the bonus.
    func apply(named name: String, value rawValue: Double, to stats: inout AbyssStats,
               conditional: Bool = false) -> Bool {
        var value = rawValue
        if conditional { value *= tuning.conditionalUptime }
        let key = name.lowercased()

        // Flat stats. The data writes "Max HP: 1000" and "DEF: 100" for flat
        // bonuses and fractions below 1 for percentages, so magnitude tells them
        // apart; every percentage in the data is < 3. Elemental Mastery is flat
        // by nature and is handled by the rules below instead.
        if abs(value) > 3 && !key.contains("elemental mastery") {
            if key.contains("hp") { stats.flatHP += value; return true }
            if key.contains("atk") { stats.flatATK += value; return true }
            if key.contains("def") { stats.flatDEF += value; return true }
        }

        // "<Element> DMG Bonus"
        for element in GenshinElement.allCases
        where key.hasPrefix(element.rawValue.lowercased()) && key.contains("dmg") {
            stats.add(value, to: .elemental(element))
            return true
        }

        // Party-wide buffs are tracked separately: they apply to all four
        // members, including the character granting them.
        if key.contains("party") || key.contains("toàn đội") || key.contains("cả đội") {
            if key.contains("atk") {
                stats.partyATKPercent += value
            } else if key.contains("elemental mastery") || key.hasSuffix(" em") {
                stats.partyElementalMastery += value
            } else {
                stats.partyDMG += value
            }
            return true
        }

        // Ordered longest-first: "elemental skill and burst dmg" must be tested
        // before "elemental skill dmg", which must come before "elemental".
        let rules: [(needle: String, field: AbyssStatField)] = [
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
        for rule in rules where key.contains(rule.needle) {
            stats.add(value, to: rule.field)
            return true
        }

        // Bare names: artifact sets write "ATK"/"HP"/"DEF" for percentages.
        switch key {
        case "atk", "self atk": stats.atkPercent += value; return true
        case "hp": stats.hpPercent += value; return true
        case "def": stats.defPercent += value; return true
        default: break
        }

        // Anything else that mentions damage counts as a general bonus.
        if key.contains("dmg") {
            stats.dmgAll += value
            return true
        }
        return false
    }

    private func applyArtifactBonuses(_ bonuses: [AbyssArtifactSet.Bonus],
                                      to stats: inout AbyssStats,
                                      diagnostics: inout AbyssParseDiagnostics) {
        for bonus in bonuses {
            // A qualifier in parentheses ("CRIT Rate (when HP below 70%)")
            // means the bonus is conditional and rarely at full uptime.
            let conditional = bonus.stat.contains("(")
            if apply(named: bonus.stat, value: bonus.value, to: &stats, conditional: conditional) {
                diagnostics.artifactBonusMapped += 1
            } else {
                diagnostics.artifactBonusUnmapped.insert(bonus.stat)
            }
        }
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

    private func applyWeaponPassive(_ weapon: AbyssWeapon, refinement: Int, to stats: inout AbyssStats) {
        guard let passive = weapon.passive else { return }

        for effect in passive.effects {
            guard var value = effect.value(refinement: refinement) else { continue }
            let name = effect.stat

            // Only lines that actually name a stat buff.
            guard Self.matches(Self.isStatBuff, name), !Self.matches(Self.notAStatBuff, name) else { continue }
            // A value above 3 is a hit's damage percentage, not a buff.
            guard abs(value) <= 3 else { continue }

            if Self.matches(Self.perStack, name) { value *= tuning.assumedStacks }
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

    private func applyArtifactMainStats(role: AbyssRole,
                                        basis: ScalingBasis,
                                        element: GenshinElement,
                                        to stats: inout AbyssStats) {
        // Flower and Plume are fixed.
        stats.flatHP += tuning.mainStat("flat_hp")
        stats.flatATK += tuning.mainStat("flat_atk")

        // Sands: supports need energy, healers need HP, damage dealers follow
        // whichever stat their kit scales off.
        switch role {
        case .support, .shield:
            stats.energyRecharge += tuning.mainStat("er")
        case .healer:
            stats.hpPercent += tuning.mainStat("hp_pct")
        case .mainDPS, .subDPS:
            switch basis {
            case .def: stats.defPercent += tuning.mainStat("def_pct")
            case .hp: stats.hpPercent += tuning.mainStat("hp_pct")
            case .em: stats.elementalMastery += tuning.mainStat("em")
            case .atk: stats.atkPercent += tuning.mainStat("atk_pct")
            }
        }

        // Goblet: always the character's own element.
        stats.add(tuning.mainStat("elemental_dmg"), to: .elemental(element))

        // Circlet.
        if role == .healer {
            stats.healingBonus += tuning.mainStat("healing_bonus")
        } else {
            stats.critDMG += tuning.mainStat("crit_dmg")
        }
    }

    /// Spends the assumed substat roll budget according to the role's priorities.
    private func applySubstats(role: AbyssRole, basis: ScalingBasis, to stats: inout AbyssStats) {
        var priority = tuning.substatPriority[role.rawValue]
            ?? tuning.substatPriority[AbyssRole.subDPS.rawValue]
            ?? [:]

        // A DEF- or HP-scaling character wants those rolls where an ATK-scaling
        // one would want ATK%.
        if let swaps = tuning.scalingBasisSwap[basis.rawValue] {
            for (source, destination) in swaps {
                guard let share = priority.removeValue(forKey: source) else { continue }
                priority[destination, default: 0] += share
            }
        }

        for (statKey, share) in priority {
            let value = tuning.substatRollBudget * share * tuning.rollValue(statKey)
            guard let field = Self.substatField(statKey) else { continue }
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
