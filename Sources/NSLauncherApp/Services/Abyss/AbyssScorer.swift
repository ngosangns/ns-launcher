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

    /// Party-wide buffs each artifact set grants, worn as two pieces and as
    /// four. Needed because these do not stack with themselves — see
    /// `partyBuffs`.
    private let setPartyBuffs: [String: (twoPiece: PartyBuff, fourPiece: PartyBuff)]

    /// The three party-wide stats the model tracks.
    struct PartyBuff: Sendable {
        var atkPercent = 0.0
        var elementalMastery = 0.0
        var dmg = 0.0

        var isZero: Bool { atkPercent == 0 && elementalMastery == 0 && dmg == 0 }

        static func += (lhs: inout PartyBuff, rhs: PartyBuff) {
            lhs.atkPercent += rhs.atkPercent
            lhs.elementalMastery += rhs.elementalMastery
            lhs.dmg += rhs.dmg
        }
    }

    init(library: AbyssDataLibrary, tuning: AbyssTuning) {
        self.library = library
        self.tuning = tuning

        func contribution(_ bonuses: [AbyssArtifactSet.Bonus]) -> PartyBuff {
            var buff = PartyBuff()
            for bonus in bonuses {
                guard let resolved = AbyssBuildAssembler.resolve(
                        named: bonus.stat, value: bonus.value,
                        conditional: bonus.stat.contains("("), tuning: tuning) else { continue }
                switch resolved.field {
                case .partyATKPercent: buff.atkPercent += resolved.value
                case .partyElementalMastery: buff.elementalMastery += resolved.value
                case .partyDMG: buff.dmg += resolved.value
                default: continue
                }
            }
            return buff
        }

        var table: [String: (twoPiece: PartyBuff, fourPiece: PartyBuff)] = [:]
        for set in library.artifactSets {
            let two = contribution(set.twoPiece.bonuses)
            var four = two
            four += contribution(set.fourPiece.bonuses)
            guard !two.isZero || !four.isZero else { continue }
            table[set.id] = (two, four)
        }
        setPartyBuffs = table
    }

    // MARK: - Per-character damage

    /// Damage split into the part that happens whether or not the character is
    /// on field, and the normal-attack part that only happens when they are.
    struct DamageSplit: Sendable {
        let ability: Double
        let combo: Double

        static let zero = DamageSplit(ability: 0, combo: 0)
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
        // Imported characters choose first: what they hold is a fact, not a
        // preference, and they have no second option to fall back to. After
        // that, by solo score, ties broken by position so the result does not
        // depend on Swift's (unstable) sort.
        let order = members.enumerated()
            .sorted { lhs, rhs in
                let lhsOption = options[lhs.element.id]?.first
                let rhsOption = options[rhs.element.id]?.first
                let lhsMeasured = lhsOption?.statSource == .measured
                let rhsMeasured = rhsOption?.statSource == .measured
                if lhsMeasured != rhsMeasured { return lhsMeasured }
                let lhsScore = lhsOption?.soloScore ?? 0
                let rhsScore = rhsOption?.soloScore ?? 0
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

        return evaluate(members: members, assignment: assignment, floor: floor, team: team)
    }

    /// Scores a team whose gear is already decided.
    ///
    /// Split out of `score` so `AbyssArtifactAdvisor` can ask "what would this
    /// same team score wearing these other artifacts?" and get an answer from
    /// the same code that produced the ranking, rather than a second opinion
    /// that could drift from it.
    func evaluate(members: [AbyssCharacter],
                  assignment: [String: AbyssGearOption],
                  floor: AbyssFloorContext,
                  team: AbyssTeamContext) -> AbyssTeamResult? {
        guard !members.isEmpty, assignment.count == members.count else { return nil }

        let stats = members.map { assignment[$0.id]?.stats ?? AbyssStats() }
        let setIDs = members.map { assignment[$0.id]?.setIDs ?? [] }
        var splits = [DamageSplit](repeating: .zero, count: members.count)
        let damage = teamDamage(members: members, stats: stats, setIDs: setIDs, floor: floor,
                                team: team, splits: &splits)
        let onField = members[damage.onFieldIndex]

        var perCharacter: [String: Double] = [:]
        perCharacter.reserveCapacity(splits.count)
        for (index, split) in splits.enumerated() {
            perCharacter[members[index].id] = index == damage.onFieldIndex
                ? split.ability + split.combo * tuning.normalCombosPerRotation
                : split.ability * tuning.offFieldUptime
        }

        let modifiers = teamModifiers(team: team, floor: floor)
        let score = damage.total * modifiers.multiplier
        var notes = modifiers.notes

        let usedWeapons = members.compactMap { assignment[$0.id]?.weaponID }
        let contested = Set(usedWeapons.filter { id in usedWeapons.filter { $0 == id }.count > 1 })
        if !contested.isEmpty {
            notes.append(.weaponContested(contested.sorted()))
        }

        let sources = Set(members.map { assignment[$0.id]?.statSource ?? .modelled })
        if sources.count > 1 { notes.append(.mixedStatSources) }

        return AbyssTeamResult(
            memberIDs: members.map(\.id),
            onFieldID: onField.id,
            score: score,
            perCharacterDamage: perCharacter,
            assignment: assignment,
            notes: notes,
            baseScore: score)
    }

    /// The team's damage before the team-level multipliers, plus who should
    /// stand on field.
    ///
    /// The hot path, and deliberately allocation-free: the artifact advisor
    /// calls it dozens of times per character, and the dictionary building that
    /// `evaluate` does around it costs more than the arithmetic. `splits` is
    /// supplied by the caller so the buffer can be reused across calls; it is
    /// filled in `members` order.
    func teamDamage(members: [AbyssCharacter],
                    stats: [AbyssStats],
                    setIDs: [[String]],
                    floor: AbyssFloorContext,
                    team: AbyssTeamContext,
                    splits: inout [DamageSplit]) -> (total: Double, onFieldIndex: Int) {
        let party = partyBuffs(stats: stats, setIDs: setIDs, team: team)

        var abilityTotal = 0.0
        for (index, character) in members.enumerated() {
            let split = damageSplit(for: character, stats: stats[index], floor: floor, team: team,
                                    partyBuffs: (party.atkPercent, party.elementalMastery, party.dmg))
            splits[index] = split
            abilityTotal += split.ability
        }

        let onFieldGain = { (split: DamageSplit) -> Double in
            (1 - tuning.offFieldUptime) * split.ability + tuning.normalCombosPerRotation * split.combo
        }

        // First maximum wins, matching the reference implementation's strict
        // `>` comparison over members in order.
        var bestIndex = 0
        var bestGain = onFieldGain(splits[0])
        for index in 1..<splits.count where onFieldGain(splits[index]) > bestGain {
            bestGain = onFieldGain(splits[index])
            bestIndex = index
        }

        return (abilityTotal * tuning.offFieldUptime + bestGain, bestIndex)
    }

    /// Party-wide buffs reaching every member: the elemental resonances, plus
    /// what each member grants the party.
    ///
    /// An artifact set's party buff is counted **once**, however many members
    /// wear it. In game these do not stack with themselves, and the difference
    /// is not academic: with a plain sum, a search that optimises the team score
    /// discovers that putting Tenacity of the Millelith on three characters
    /// "grants" +60% party ATK and recommends exactly that. The rest of the
    /// model — weapon passives, talents — still sums, so a buff shared by two
    /// different weapons is still double-counted; that is a smaller and much
    /// rarer overlap, and fixing it needs source tracking this type does not
    /// carry.
    func partyBuffs(stats: [AbyssStats],
                    setIDs: [[String]],
                    team: AbyssTeamContext) -> PartyBuff {
        let resonance = team.resonanceStats(conditionalUptime: tuning.conditionalUptime)
        var party = PartyBuff(atkPercent: resonance.atkPercent,
                              elementalMastery: resonance.elementalMastery,
                              dmg: resonance.dmg)

        var countedSets: Set<String> = []
        for (index, sheet) in stats.enumerated() {
            party.atkPercent += sheet.partyATKPercent
            party.elementalMastery += sheet.partyElementalMastery
            party.dmg += sheet.partyDMG

            // Everything the sheet got from its sets is already in the totals
            // above; take back the copies beyond the first.
            let worn = index < setIDs.count ? setIDs[index] : []
            for setID in worn {
                guard let entry = setPartyBuffs[setID] else { continue }
                let granted = worn.count == 1 ? entry.fourPiece : entry.twoPiece
                if !countedSets.insert(setID).inserted {
                    party.atkPercent -= granted.atkPercent
                    party.elementalMastery -= granted.elementalMastery
                    party.dmg -= granted.dmg
                }
            }
        }
        return party
    }

    /// The multipliers and notes that depend on the team and the floor but not
    /// on anyone's gear. Constant while the advisor swaps artifacts around,
    /// which is why it is separated from the damage.
    func teamModifiers(team: AbyssTeamContext,
                       floor: AbyssFloorContext) -> (multiplier: Double, notes: [AbyssTeamNote]) {
        var multiplier = 1.0
        var notes: [AbyssTeamNote] = []

        if !(team.hasHeal || team.hasShield) {
            multiplier *= tuning.noSustainPenalty
            notes.append(.noSustainPenalty)
        }
        if !floor.shieldElements.isEmpty,
           !floor.shieldBreakingElements.isDisjoint(with: team.elementSet) {
            multiplier *= tuning.shieldBreakBonus
            notes.append(.breaksShield(floor.shieldElements))
        }
        let exploited = team.elementSet
            .filter { floor.resistance(for: $0) < AbyssFloorContext.defaultResistance }
            .sorted { $0.rawValue < $1.rawValue }
        if !exploited.isEmpty {
            multiplier *= tuning.weaknessExploitBonus
            notes.append(.exploitsWeakness(exploited))
        }
        if team.moonsignLevel >= 2 { notes.append(.moonsignAscendantGleam) }
        if team.hexerei { notes.append(.hexereiSecretRite) }
        notes.append(contentsOf: team.resonances.map { .resonance(name: $0.name) })

        return (multiplier, notes)
    }
}

extension AbyssFloorContext {
    /// Standard yardstick for comparing characters to each other rather than to
    /// a particular floor: level 95 enemies, baseline resistance, no buffs.
    static let neutral = AbyssFloorContext(
        floor: 0, monsterLevel: 95, resistances: [:], buffs: [], shieldElements: [])
}
