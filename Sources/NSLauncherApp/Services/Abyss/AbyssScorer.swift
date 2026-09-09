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

    /// The party-wide stats the model tracks.
    struct PartyBuff: Sendable {
        var atkPercent = 0.0
        /// Flat ATK, kept apart from `atkPercent` — see `AbyssStats.partyFlatATK`.
        var flatATK = 0.0
        var elementalMastery = 0.0
        var dmg = 0.0
        /// Per-element, indexed by `GenshinElement.simdIndex`.
        var elementalDMG: SIMD8<Double> = .zero

        static let none = PartyBuff()

        var isZero: Bool {
            atkPercent == 0 && flatATK == 0 && elementalMastery == 0 && dmg == 0
                && elementalDMG == .zero
        }

        static func += (lhs: inout PartyBuff, rhs: PartyBuff) {
            lhs.atkPercent += rhs.atkPercent
            lhs.flatATK += rhs.flatATK
            lhs.elementalMastery += rhs.elementalMastery
            lhs.dmg += rhs.dmg
            lhs.elementalDMG += rhs.elementalDMG
        }

        static func -= (lhs: inout PartyBuff, rhs: PartyBuff) {
            lhs.atkPercent -= rhs.atkPercent
            lhs.flatATK -= rhs.flatATK
            lhs.elementalMastery -= rhs.elementalMastery
            lhs.dmg -= rhs.dmg
            lhs.elementalDMG -= rhs.elementalDMG
        }
    }

    init(library: AbyssDataLibrary, tuning: AbyssTuning) {
        self.library = library
        self.tuning = tuning

        func contribution(_ bonuses: [AbyssArtifactSet.Bonus]) -> PartyBuff {
            var buff = PartyBuff()
            for bonus in bonuses {
                let resolved = AbyssBuildAssembler.resolve(
                    named: bonus.stat, value: bonus.value,
                    conditional: bonus.stat.contains("("), tuning: tuning)
                for entry in resolved {
                    switch entry.field {
                    case .partyATKPercent: buff.atkPercent += entry.value
                    case .partyElementalMastery: buff.elementalMastery += entry.value
                    case .partyDMG: buff.dmg += entry.value
                    default: continue
                    }
                }
            }
            return buff
        }

        var table: [String: (twoPiece: PartyBuff, fourPiece: PartyBuff)] = [:]
        for set in library.artifactSets {
            let two = contribution(set.twoPiece.bonuses)
            var four = two
            four += contribution(set.fourPiece.bonuses)
            // A hand-written approximation that reaches the party is a party
            // buff like any other and does not stack with itself. Only the
            // four-piece variant carries it: `applySets` applies an
            // approximation only when all four pieces are the same set.
            //
            // This table is keyed by set alone, so it cannot express an
            // approximation whose value depends on who is wearing it — which is
            // why a party approximation may not carry a `requirement`, pinned by
            // `AbyssBuildAssemblerTests`.
            if let approximation = tuning.setEffectApprox.first(where: { $0.setId == set.id }),
               approximation.party == true {
                four.dmg += approximation.damageBonus
            }
            guard !two.isZero || !four.isZero else { continue }
            table[set.id] = (two, four)
        }
        setPartyBuffs = table
    }

    // MARK: - Per-character damage

    /// Damage split into the part that happens whether or not the character is
    /// on field, and the two on-field-only parts.
    ///
    /// Normal and charged attacks are separate because they happen a different
    /// number of times in a rotation — `normalCombosPerRotation` against
    /// `chargedAttacksPerRotation` — so one multiplier could not cover both.
    struct DamageSplit: Sendable {
        let ability: Double
        let combo: Double
        let charged: Double

        static let zero = DamageSplit(ability: 0, combo: 0, charged: 0)
    }

    /// Everything in one character's damage that their stat sheet cannot change:
    /// their parsed profile, the floor's defence and resistance multipliers, the
    /// amplifying reaction their team unlocks, and the floor buffs that reach
    /// them. A function of (character, floor, team) and nothing else.
    ///
    /// Split out because the artifact advisor holds all three fixed and varies
    /// only the stat sheet — a thousand times per character. Rebuilding this per
    /// sheet meant two `Set` allocations, a dictionary walk and a pass over the
    /// floor's buffs for each one, and that, not the arithmetic, was where a run
    /// spent its time.
    struct DamageContext: Sendable {
        let aggregate: [AbyssDamageProfile.Term]
        let element: GenshinElement
        /// `defMultiplier × resMultiplier`. Crit and amplification are left out
        /// on purpose: both depend on the stat sheet.
        let defenceAndResistance: Double
        /// 1.0 when the team unlocks no amplifying reaction for this element.
        let amplifyingCoefficient: Double
        let floorBonusNormal: Double
        let floorBonusOther: Double

        /// For a character with no parsed profile. An empty `aggregate` makes
        /// the damage loop produce zero, which is what the profile lookup used
        /// to return by an early exit.
        static let none = DamageContext(aggregate: [], element: .anemo, defenceAndResistance: 0,
                                        amplifyingCoefficient: 1, floorBonusNormal: 0,
                                        floorBonusOther: 0)
    }

    func damageContext(for character: AbyssCharacter,
                       profile explicitProfile: AbyssDamageProfile? = nil,
                       floor: AbyssFloorContext,
                       team: AbyssTeamContext) -> DamageContext {
        guard let profile = explicitProfile ?? library.profilesByCharacterID[character.id] else {
            return .none
        }
        let element = character.element
        let reactions = team.enabledReactions

        let defMultiplier = AbyssDamageMath.defMultiplier(
            characterLevel: AbyssDamageMath.characterLevel,
            monsterLevel: floor.monsterLevel)
        let resMultiplier = AbyssDamageMath.resMultiplier(floor.resistance(for: element))

        return DamageContext(
            aggregate: profile.aggregate,
            element: element,
            defenceAndResistance: defMultiplier * resMultiplier,
            // Reactions are gated by internal cooldown and by who applies which
            // element first, so only a fraction of hits actually amplify — see
            // `tuning.amplifyingUptime`, applied per sheet below.
            amplifyingCoefficient: AbyssDamageMath.amplifyingCoefficient(
                for: element, teamElements: team.elementSet,
                constants: library.damageConstants),
            // The floor bonus only varies by whether the hit is a normal attack,
            // so it is resolved twice rather than per hit.
            floorBonusNormal: floorBonus(floor, element: element, reactions: reactions,
                                         isNormalAttack: true),
            floorBonusOther: floorBonus(floor, element: element, reactions: reactions,
                                        isNormalAttack: false))
    }

    func damageSplit(context: DamageContext,
                     stats: AbyssStats,
                     partyBuffs: PartyBuff) -> DamageSplit {
        var effective = stats
        effective.atkPercent += partyBuffs.atkPercent
        effective.flatATK += partyBuffs.flatATK
        effective.elementalMastery += partyBuffs.elementalMastery
        effective.dmgAll += partyBuffs.dmg
        effective.elementalDMG += partyBuffs.elementalDMG

        let amplifyingFactor: Double
        if context.amplifyingCoefficient > 1 {
            let multiplier = AbyssDamageMath.amplifyingMultiplier(
                coefficient: context.amplifyingCoefficient,
                elementalMastery: effective.elementalMastery,
                constants: library.damageConstants)
            amplifyingFactor = 1 + tuning.amplifyingUptime * (multiplier - 1)
        } else {
            amplifyingFactor = 1
        }

        let common = context.defenceAndResistance * effective.critMultiplier * amplifyingFactor
        let elementalBonus = effective.dmgAll + effective.elementalBonus(context.element)

        var ability = 0.0
        var combo = 0.0
        var charged = 0.0
        for term in context.aggregate {
            // A floor buff scoped to normal attacks does not reach charged ones:
            // the game treats them as different actions, and the buff text says
            // "Thường công (Normal Attack)".
            let isNormal = term.category == .normal
            let bonus = elementalBonus
                + effective.categoryBonus(term.category)
                + (isNormal ? context.floorBonusNormal : context.floorBonusOther)
            let damage = term.multiplier * effective.stat(for: term.basis) * (1 + bonus) * common
            switch term.category {
            case .normal: combo += damage
            case .charged: charged += damage
            default: ability += damage
            }
        }

        return DamageSplit(ability: ability, combo: combo, charged: charged)
    }

    /// For callers that score one sheet once and have no context to reuse.
    func damageSplit(for character: AbyssCharacter,
                     stats: AbyssStats,
                     floor: AbyssFloorContext,
                     team: AbyssTeamContext,
                     partyBuffs: PartyBuff) -> DamageSplit {
        damageSplit(context: damageContext(for: character, floor: floor, team: team),
                    stats: stats, partyBuffs: partyBuffs)
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

    /// The context `soloScore` measures against: this character alone, on a
    /// neutral floor, with no team around them. Built once per character by gear
    /// selection, which then scores a thousand stat sheets against it.
    func soloContext(for character: AbyssCharacter,
                     profile: AbyssDamageProfile? = nil) -> DamageContext {
        damageContext(for: character, profile: profile, floor: .neutral, team: AbyssTeamContext(
            elements: [character.element], resonances: [], moonsignLevel: 0,
            hexerei: false, hasHeal: false, hasShield: false, stellarJubilee: false))
    }

    func soloScore(context: DamageContext, stats: AbyssStats) -> Double {
        let split = damageSplit(context: context, stats: stats, partyBuffs: .none)
        return onFieldDamage(split)
    }

    /// What a split is worth to a character who is standing on field: everything
    /// their abilities do, plus the attacks they only get to make there.
    func onFieldDamage(_ split: DamageSplit) -> Double {
        split.ability
            + split.combo * tuning.normalCombosPerRotation
            + split.charged * tuning.chargedAttacksPerRotation
    }

    /// Damage a character does alone on a neutral floor. Used to rank gear, trim
    /// the candidate pool, and settle who keeps a contested weapon.
    func soloScore(for character: AbyssCharacter, stats: AbyssStats) -> Double {
        soloScore(context: soloContext(for: character), stats: stats)
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
               floor: AbyssFloorContext,
               profiles: [String: AbyssDamageProfile] = [:]) -> AbyssTeamResult? {
        guard !members.isEmpty else { return nil }

        let team = AbyssTeamContext.build(members: members, library: library)
        let assignment = assignGear(members: members, options: options)
        guard assignment.count == members.count else { return nil }

        return evaluate(members: members, assignment: assignment, floor: floor, team: team,
                        profiles: profiles)
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
                  team: AbyssTeamContext,
                  profiles: [String: AbyssDamageProfile] = [:]) -> AbyssTeamResult? {
        guard !members.isEmpty, assignment.count == members.count else { return nil }

        let stats = members.map { assignment[$0.id]?.stats ?? AbyssStats() }
        let setIDs = members.map { assignment[$0.id]?.setIDs ?? [] }
        var splits = [DamageSplit](repeating: .zero, count: members.count)
        let context = teamDamageContext(members: members, floor: floor, team: team,
                                        profiles: profiles)
        let damage = teamDamage(context: context, stats: stats, setIDs: setIDs, splits: &splits)
        let onField = members[damage.onFieldIndex]

        var perCharacter: [String: Double] = [:]
        perCharacter.reserveCapacity(splits.count)
        for (index, split) in splits.enumerated() {
            perCharacter[members[index].id] = index == damage.onFieldIndex
                ? onFieldDamage(split)
                : split.ability * tuning.offFieldUptime
        }
        // Reaction damage is credited to whoever sets it off, so the per-member
        // bars in the tab show a high-EM support carrying a Bloom team rather
        // than looking idle next to damage they are in fact causing.
        if damage.reactionTriggerIndex >= 0 {
            perCharacter[members[damage.reactionTriggerIndex].id, default: 0] += damage.reactionDamage
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
    /// The whole team's share of that: one `DamageContext` per member plus the
    /// resonance buff, all of which depend on who is in the team and which floor
    /// it is, and none of which an artifact swap can change.
    struct TeamDamageContext: Sendable {
        let members: [DamageContext]
        let resonance: PartyBuff
        /// The best transformative reaction this team can set off on this floor,
        /// or nil when it can set off none.
        let transformative: Transformative?
    }

    /// A transformative reaction priced for one team on one floor.
    ///
    /// Everything except the triggering character's Elemental Mastery, because
    /// that is the only part an artifact swap can move — which is what lets the
    /// artifact advisor reuse this a thousand times per member.
    struct Transformative: Sendable {
        let reaction: AbyssReaction
        /// coefficient × levelMultiplier × resMultiplier.
        let base: Double
    }

    /// The strongest transformative reaction a team unlocks, priced against the
    /// floor's resistances.
    ///
    /// One reaction, not the sum of all of them. A Dendro/Hydro/Electro/Pyro
    /// team technically unlocks Bloom, Hyperbloom, Burgeon, Burning, Overloaded
    /// and Electro-Charged at once, but a rotation only has so many elemental
    /// applications to spend and they compete for the same aura. Counting the
    /// best one is the conservative reading; counting them all would make
    /// four-element soup the answer to every floor.
    func transformative(for team: AbyssTeamContext, floor: AbyssFloorContext) -> Transformative? {
        var best: Transformative?
        // Sorted, because Hyperbloom and Burgeon share a coefficient and a
        // resistance: the damage is the same either way, but the reaction that
        // gets named should not depend on how a Set happened to hash.
        for reaction in team.transformativeReactions.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let coefficient = library.damageConstants.transformativeCoefficients[reaction] else {
                continue
            }
            // Swirl takes the resistance of whatever element was swirled, so the
            // team picks whichever of its own elements the floor resists least.
            let resistance: Double
            if let element = reaction.damageElement {
                resistance = floor.resistance(for: element)
            } else {
                resistance = team.elementSet
                    .subtracting([.anemo, .geo])
                    .map { floor.resistance(for: $0) }
                    .min() ?? AbyssFloorContext.defaultResistance
            }
            let base = coefficient
                * library.damageConstants.transformativeLevelMultiplier
                * AbyssDamageMath.resMultiplier(resistance)
            if base > (best?.base ?? 0) {
                best = Transformative(reaction: reaction, base: base)
            }
        }
        return best
    }

    func teamDamageContext(members: [AbyssCharacter],
                           floor: AbyssFloorContext,
                           team: AbyssTeamContext,
                           profiles: [String: AbyssDamageProfile] = [:]) -> TeamDamageContext {
        TeamDamageContext(
            members: members.map {
                damageContext(for: $0, profile: profiles[$0.id], floor: floor, team: team)
            },
            resonance: resonanceBuff(for: team),
            transformative: transformative(for: team, floor: floor))
    }

    /// What a team does in one rotation, and who should stand on field.
    struct TeamDamage: Sendable {
        let total: Double
        let onFieldIndex: Int
        /// Reaction damage, and the member credited with triggering it. Zero and
        /// -1 when the team sets off no transformative reaction.
        let reactionDamage: Double
        let reactionTriggerIndex: Int
    }

    func teamDamage(context: TeamDamageContext,
                    stats: [AbyssStats],
                    setIDs: [[String]],
                    splits: inout [DamageSplit]) -> TeamDamage {
        let party = partyBuffs(stats: stats, setIDs: setIDs, resonance: context.resonance)

        var abilityTotal = 0.0
        for (index, memberContext) in context.members.enumerated() {
            let split = damageSplit(context: memberContext, stats: stats[index], partyBuffs: party)
            splits[index] = split
            abilityTotal += split.ability
        }

        let onFieldGain = { (split: DamageSplit) -> Double in
            (1 - tuning.offFieldUptime) * split.ability
                + tuning.normalCombosPerRotation * split.combo
                + tuning.chargedAttacksPerRotation * split.charged
        }

        // First maximum wins, matching the reference implementation's strict
        // `>` comparison over members in order.
        var bestIndex = 0
        var bestGain = onFieldGain(splits[0])
        for index in 1..<splits.count where onFieldGain(splits[index]) > bestGain {
            bestGain = onFieldGain(splits[index])
            bestIndex = index
        }

        // Transformative damage belongs to the team, not to a hit: it ignores
        // ATK, DMG bonus, CRIT and enemy DEF entirely and depends only on the
        // Elemental Mastery of whoever sets it off. The team always sets it off
        // with its best EM, which is why a support who deals no damage of their
        // own can be the largest contributor on a Bloom team.
        var reactionDamage = 0.0
        var triggerIndex = -1
        if let transformative = context.transformative {
            var bestEM = -Double.infinity
            for (index, sheet) in stats.enumerated() {
                let elementalMastery = sheet.elementalMastery + party.elementalMastery
                if elementalMastery > bestEM {
                    bestEM = elementalMastery
                    triggerIndex = index
                }
            }
            let bonus = library.damageConstants.transformativeEM.bonus(max(bestEM, 0))
            reactionDamage = tuning.transformativeReactionsPerRotation
                * transformative.base * (1 + bonus)
        }

        return TeamDamage(total: abilityTotal * tuning.offFieldUptime + bestGain + reactionDamage,
                          onFieldIndex: bestIndex,
                          reactionDamage: reactionDamage,
                          reactionTriggerIndex: triggerIndex)
    }

    /// For callers scoring one team once, with no context to reuse.
    func teamDamage(members: [AbyssCharacter],
                    stats: [AbyssStats],
                    setIDs: [[String]],
                    floor: AbyssFloorContext,
                    team: AbyssTeamContext,
                    splits: inout [DamageSplit]) -> TeamDamage {
        teamDamage(context: teamDamageContext(members: members, floor: floor, team: team),
                   stats: stats, setIDs: setIDs, splits: &splits)
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
        partyBuffs(stats: stats, setIDs: setIDs, resonance: resonanceBuff(for: team))
    }

    /// What a fixed team grants no matter what anyone wears. Hoisted out of the
    /// hot path because `resonanceStats` lowercases a string per bonus, which is
    /// not something to do a million times a run.
    func resonanceBuff(for team: AbyssTeamContext) -> PartyBuff {
        let resonance = team.resonanceStats(conditionalUptime: tuning.conditionalUptime)
        return PartyBuff(atkPercent: resonance.atkPercent,
                         elementalMastery: resonance.elementalMastery,
                         dmg: resonance.dmg)
    }

    func partyBuffs(stats: [AbyssStats],
                    setIDs: [[String]],
                    resonance: PartyBuff) -> PartyBuff {
        var party = resonance

        var countedSets: Set<String> = []
        for (index, sheet) in stats.enumerated() {
            party.atkPercent += sheet.partyATKPercent
            party.flatATK += sheet.partyFlatATK
            party.elementalMastery += sheet.partyElementalMastery
            party.dmg += sheet.partyDMG
            party.elementalDMG += sheet.partyElementalDMG

            // Everything the sheet got from its sets is already in the totals
            // above; take back the copies beyond the first.
            let worn = index < setIDs.count ? setIDs[index] : []
            for setID in worn {
                guard let entry = setPartyBuffs[setID] else { continue }
                let granted = worn.count == 1 ? entry.fourPiece : entry.twoPiece
                if !countedSets.insert(setID).inserted { party -= granted }
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
