// AbyssScorer.swift
//
// Scores one team against one floor. Ported from `character_damage`,
// `assign_gear` and `score_team` in `scoring.py`.
//
// This runs on the order of a million times per optimisation, so two things are
// done differently from the reference implementation while producing the same
// numbers:
//
//   1. The per-character damage is split into an `ability` part and a `combo`
//      part once, instead of recomputing all four characters for each of the
//      four possible on-field slots. Since off-field damage is just `ability ×
//      uptime`, the total for a given on-field pick X is
//          uptime · Σ ability + (1 − uptime) · ability_X + combos · combo_X
//      so the best X is whichever maximises the last two terms. Exact, not an
//      approximation, and a 4× saving.
//   2. Damage runs over `profile.aggregate` (one term per basis/category) rather
//      than every individual hit; they are algebraically identical because every
//      hit in a group shares the same stat and the same bonus.

import Foundation

struct AbyssScorer: Sendable {
    let library: AbyssDataLibrary
    let tuning: AbyssTuning

    init(library: AbyssDataLibrary, tuning: AbyssTuning) {
        self.library = library
        self.tuning = tuning
    }

    // MARK: - Per-character damage

    /// Damage split into the part that happens whether or not the character is
    /// on field, and the normal-attack part that only happens when they are.
    struct DamageSplit: Sendable {
        let ability: Double
        let combo: Double
    }

    func damageSplit(for character: AbyssCharacter,
                     stats: AbyssStats,
                     floor: AbyssFloorContext,
                     team: AbyssTeamContext,
                     partyBuffs: (atkPercent: Double, elementalMastery: Double, dmg: Double)) -> DamageSplit {
        guard let profile = library.profilesByCharacterID[character.id] else {
            return DamageSplit(ability: 0, combo: 0)
        }
        let element = character.element

        var effective = stats
        effective.atkPercent += partyBuffs.atkPercent
        effective.elementalMastery += partyBuffs.elementalMastery
        effective.dmgAll += partyBuffs.dmg

        let resMultiplier = AbyssDamageMath.resMultiplier(floor.resistance(for: element))
        let defMultiplier = AbyssDamageMath.defMultiplier(
            characterLevel: AbyssDamageMath.characterLevel,
            monsterLevel: floor.monsterLevel)
        let critMultiplier = effective.critMultiplier

        // Reactions are gated by internal cooldown and by who applies which
        // element first, so only a fraction of hits actually amplify.
        let coefficient = AbyssDamageMath.amplifyingCoefficient(for: element, teamElements: team.elementSet)
        let amplifyingFactor: Double
        if coefficient > 1 {
            let multiplier = AbyssDamageMath.amplifyingMultiplier(
                coefficient: coefficient, elementalMastery: effective.elementalMastery)
            amplifyingFactor = 1 + tuning.amplifyingUptime * (multiplier - 1)
        } else {
            amplifyingFactor = 1
        }

        let reactions = team.enabledReactions
        let common = defMultiplier * resMultiplier * critMultiplier * amplifyingFactor
        let elementalBonus = effective.dmgAll + effective.elementalBonus(element)

        // The floor bonus only varies by whether the hit is a normal attack, so
        // it is resolved twice rather than per hit.
        let floorBonusNormal = floorBonus(floor, element: element, reactions: reactions, isNormalAttack: true)
        let floorBonusOther = floorBonus(floor, element: element, reactions: reactions, isNormalAttack: false)

        var ability = 0.0
        var combo = 0.0
        for term in profile.aggregate {
            let isNormal = term.category == .normal
            let bonus = elementalBonus
                + effective.categoryBonus(term.category)
                + (isNormal ? floorBonusNormal : floorBonusOther)
            let damage = term.multiplier * effective.stat(for: term.basis) * (1 + bonus) * common
            if isNormal { combo += damage } else { ability += damage }
        }

        return DamageSplit(ability: ability, combo: combo)
    }

    /// Total floor buff that applies to this element/reaction/hit type.
    private func floorBonus(_ floor: AbyssFloorContext,
                            element: GenshinElement,
                            reactions: Set<AbyssReaction>,
                            isNormalAttack: Bool) -> Double {
        var bonus = 0.0
        for buff in floor.buffs {
            if !buff.reactions.isEmpty, buff.reactions.isDisjoint(with: reactions) { continue }
            if !buff.elements.isEmpty, !buff.elements.contains(element) { continue }
            if buff.normalAttackOnly, !isNormalAttack { continue }
            if buff.reactions.isEmpty, buff.elements.isEmpty, !buff.normalAttackOnly { continue }
            bonus += buff.bonus
        }
        return bonus
    }

    /// Damage a character does alone on a neutral floor. Used to rank gear, trim
    /// the candidate pool, and settle who keeps a contested weapon.
    func soloScore(for character: AbyssCharacter, stats: AbyssStats) -> Double {
        let team = AbyssTeamContext(
            elements: [character.element], resonances: [], moonsignLevel: 0,
            hexerei: false, hasHeal: false, hasShield: false, stellarJubilee: false)
        let split = damageSplit(for: character, stats: stats, floor: .neutral, team: team,
                                partyBuffs: (0, 0, 0))
        return split.ability + split.combo * tuning.normalCombosPerRotation
    }

    // MARK: - Gear assignment

    /// Hands each member a weapon, with no weapon used twice.
    ///
    /// Weapons are single items: two characters on the same team cannot both
    /// hold one. The strongest candidate picks first and the rest fall back to
    /// their next-best option; if someone runs out, they keep their first choice
    /// and the caller reports the contested weapon rather than silently
    /// pretending the roster has two.
    func assignGear(members: [AbyssCharacter],
                    options: [String: [AbyssGearOption]]) -> [String: AbyssGearOption] {
        // Sorted by solo score, ties broken by position so the result does not
        // depend on Swift's (unstable) sort.
        let order = members.enumerated()
            .sorted { lhs, rhs in
                let lhsScore = options[lhs.element.id]?.first?.soloScore ?? 0
                let rhsScore = options[rhs.element.id]?.first?.soloScore ?? 0
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        var taken: Set<String> = []
        var chosen: [String: AbyssGearOption] = [:]
        chosen.reserveCapacity(members.count)

        for character in order {
            guard let candidates = options[character.id], !candidates.isEmpty else { continue }
            let pick = candidates.first { option in
                guard let weaponID = option.weaponID else { return true }
                return !taken.contains(weaponID)
            }
            let option = pick ?? candidates[0]
            chosen[character.id] = option
            if let weaponID = option.weaponID { taken.insert(weaponID) }
        }
        return chosen
    }

    // MARK: - Team scoring

    func score(members: [AbyssCharacter],
               options: [String: [AbyssGearOption]],
               floor: AbyssFloorContext) -> AbyssTeamResult? {
        guard !members.isEmpty else { return nil }

        let team = AbyssTeamContext.build(members: members, library: library)
        let assignment = assignGear(members: members, options: options)
        guard assignment.count == members.count else { return nil }

        var party = team.resonanceStats(conditionalUptime: tuning.conditionalUptime)
        for character in members {
            guard let stats = assignment[character.id]?.stats else { continue }
            party.atkPercent += stats.partyATKPercent
            party.elementalMastery += stats.partyElementalMastery
            party.dmg += stats.partyDMG
        }

        let splits = members.map { character -> (character: AbyssCharacter, split: DamageSplit) in
            let stats = assignment[character.id]?.stats ?? AbyssStats()
            return (character, damageSplit(for: character, stats: stats, floor: floor, team: team,
                                           partyBuffs: party))
        }

        let offFieldTotal = splits.reduce(0) { $0 + $1.split.ability } * tuning.offFieldUptime
        let onFieldGain = { (split: DamageSplit) -> Double in
            (1 - tuning.offFieldUptime) * split.ability + tuning.normalCombosPerRotation * split.combo
        }

        // First maximum wins, matching the reference implementation's strict
        // `>` comparison over members in order.
        var bestIndex = 0
        var bestGain = onFieldGain(splits[0].split)
        for index in 1..<splits.count where onFieldGain(splits[index].split) > bestGain {
            bestGain = onFieldGain(splits[index].split)
            bestIndex = index
        }
        let onField = splits[bestIndex].character

        var perCharacter: [String: Double] = [:]
        perCharacter.reserveCapacity(splits.count)
        for (index, entry) in splits.enumerated() {
            perCharacter[entry.character.id] = index == bestIndex
                ? entry.split.ability + entry.split.combo * tuning.normalCombosPerRotation
                : entry.split.ability * tuning.offFieldUptime
        }

        var score = offFieldTotal + bestGain
        var notes: [AbyssTeamNote] = []

        if !(team.hasHeal || team.hasShield) {
            score *= tuning.noSustainPenalty
            notes.append(.noSustainPenalty)
        }
        if !floor.shieldElements.isEmpty,
           !floor.shieldBreakingElements.isDisjoint(with: team.elementSet) {
            score *= tuning.shieldBreakBonus
            notes.append(.breaksShield(floor.shieldElements))
        }
        let exploited = team.elementSet
            .filter { floor.resistance(for: $0) < AbyssFloorContext.defaultResistance }
            .sorted { $0.rawValue < $1.rawValue }
        if !exploited.isEmpty {
            score *= tuning.weaknessExploitBonus
            notes.append(.exploitsWeakness(exploited))
        }
        if team.moonsignLevel >= 2 { notes.append(.moonsignAscendantGleam) }
        if team.hexerei { notes.append(.hexereiSecretRite) }
        notes.append(contentsOf: team.resonances.map { .resonance(name: $0.name) })

        let usedWeapons = members.compactMap { assignment[$0.id]?.weaponID }
        let contested = Set(usedWeapons.filter { id in usedWeapons.filter { $0 == id }.count > 1 })
        if !contested.isEmpty {
            notes.append(.weaponContested(contested.sorted()))
        }

        return AbyssTeamResult(
            memberIDs: members.map(\.id),
            onFieldID: onField.id,
            score: score,
            perCharacterDamage: perCharacter,
            assignment: assignment,
            notes: notes)
    }
}

extension AbyssFloorContext {
    /// Standard yardstick for comparing characters to each other rather than to
    /// a particular floor: level 95 enemies, baseline resistance, no buffs.
    static let neutral = AbyssFloorContext(
        floor: 0, monsterLevel: 95, resistances: [:], buffs: [], shieldElements: [])
}
