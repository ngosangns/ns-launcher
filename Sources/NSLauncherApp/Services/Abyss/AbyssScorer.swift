// AbyssScorer.swift
//
// Scores one team against one floor.
//
// This runs on the order of a million times per optimisation, so two things are
// done the fast way rather than the obvious way, while producing the same
// numbers to the last digit — the golden fixture is what says so:
//
//   1. The per-character damage is split into skill, burst, combo and charged
//      parts once, instead of recomputing all four characters for each of the
//      four possible on-field slots. Off-field damage is `skills · skill +
//      bursts(off field) · burst`, so the total for a given on-field pick X is
//          Σ off-field damage + (bursts_X(on) − bursts_X(off)) · burst_X
//              + window_X · (combos · combo_X + charged · charged_X)
//      and the best X is whichever maximises the last two terms. Exact, not an
//      approximation, and a 4× saving. How many skills and bursts a rotation
//      holds is `Rotation` — energy, Phase 3 of `docs/redesign.md`.
//   2. Damage runs over `profile.aggregate` (one term per basis/category) rather
//      than every individual hit; they are algebraically identical because every
//      hit in a group shares the same stat and the same bonus.

import Foundation

struct AbyssScorer: Sendable {
    let library: AbyssDataLibrary
    let tuning: AbyssTuning

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
    }

    // MARK: - Per-character damage

    /// Damage split into the part that happens whether or not the character is
    /// on field, and the two on-field-only parts.
    ///
    /// Normal and charged attacks are separate because they happen a different
    /// number of times in a rotation — decided by how long each takes — so one
    /// multiplier could not cover both.
    struct DamageSplit: Sendable {
        /// One skill cast's damage.
        let skill: Double
        /// One burst cast's damage.
        let burst: Double
        let combo: Double
        let charged: Double
        /// The amplifying multiplier minus one at this sheet's Elemental
        /// Mastery, for the hits that land on the right aura. Zero when the
        /// character's element amplifies nothing in this team.
        var amplifyingGain: Double = 0
        /// Damage one element application adds through Aggravate or Spread at
        /// this sheet's Mastery, bonuses and crit. Zero without a Quicken aura.
        var catalyzePerApplication: Double = 0

        /// One cast of each, for callers that compare damage rather than
        /// count it.
        var ability: Double { skill + burst }

        static let zero = DamageSplit(skill: 0, burst: 0, combo: 0, charged: 0)

        /// The split with this member's reactions in it, at the uptimes one
        /// on-field pick gives: each part's applying share amplifies, and each
        /// application adds its catalyze damage.
        func reacted(_ applications: AbyssApplicationProfile, amplifying: Double, catalyze: Double) -> DamageSplit {
            let gain = amplifyingGain * amplifying
            let perApplication = catalyzePerApplication * catalyze
            return DamageSplit(
                skill: skill * (1 + gain * applications.skill.applyingShare)
                    + perApplication * applications.skill.applications,
                burst: burst * (1 + gain * applications.burst.applyingShare)
                    + perApplication * applications.burst.applications,
                combo: combo * (1 + gain * applications.combo.applyingShare)
                    + perApplication * applications.combo.applications,
                charged: charged * (1 + gain * applications.charged.applyingShare)
                    + perApplication * applications.charged.applications)
        }
    }

    /// One member's rotation, minus anything their gear decides: how often
    /// the skill is cast, what the burst costs and how often a rotation could
    /// hold it, and the energy that reaches this member in one rotation
    /// *before* Energy Recharge — once for off field, once for on it.
    ///
    /// Energy Recharge is left out because it is on the stat sheet, and the
    /// sheet is what the searches vary. Everything else here is fixed by who is
    /// in the team: particles are generated by skills, and every member
    /// receives every particle — at full value if on field when it lands, at
    /// `offFieldShare` otherwise, more for their own element.
    struct Rotation: Sendable {
        let skillCasts: Double
        let burstCost: Double
        let burstCap: Double
        let window: AbyssEnergyProfile.Window
        let energyOffField: Double
        let energyOnField: Double
        /// Seconds per cast until the character can swap out, and what a swap
        /// adds to an off-field cast.
        var skillSeconds: Double = 0
        var burstSeconds: Double = 0
        var swapSeconds: Double = 0
        /// Seconds per normal-attack string and per charged attack, and which
        /// loops field time can be spent on.
        var comboSeconds: Double = 0
        var chargedSeconds: Double = 0
        var loops = AbyssEnergyProfile.AttackLoops(combo: true, mixed: true, charged: false)
        /// Cast time the rest of the party takes out of this character's
        /// field time when nobody real is there — gear selection's stand-in.
        var standInOthersSeconds: Double = 0

        /// For a character with no energy profile: one of each, and no time on
        /// field to attack in.
        static let unconstrained = Rotation(skillCasts: 1, burstCost: 0, burstCap: 1, window: .none,
                                            energyOffField: 0, energyOnField: 0)

        /// Seconds this member's casts take out of a rotation. Off field, each
        /// cast also pays for the swap in.
        func castSeconds(bursts: Double, onField: Bool) -> Double {
            skillCasts * skillSeconds + bursts * burstSeconds
                + (onField ? 0 : (skillCasts + bursts) * swapSeconds)
        }

        /// Damage per second of field time: the best loop open to the
        /// character. A string and a string-plus-charged are open to everyone;
        /// charged attacks alone to bows and to kits that say so.
        func attackRate(_ split: DamageSplit) -> Double {
            var best = 0.0
            if loops.combo, comboSeconds > 0 { best = max(best, split.combo / comboSeconds) }
            if loops.mixed, comboSeconds + chargedSeconds > 0 {
                best = max(best, (split.combo + split.charged) / (comboSeconds + chargedSeconds))
            }
            if loops.charged, chargedSeconds > 0 { best = max(best, split.charged / chargedSeconds) }
            return best
        }

        /// Damage per second of field time from normal and from charged
        /// attacks, on the loop `attackRate` picks.
        func attackShares(_ split: DamageSplit) -> (combo: Double, charged: Double) {
            var best = (rate: 0.0, combo: 0.0, charged: 0.0)
            if loops.combo, comboSeconds > 0, split.combo / comboSeconds > best.rate {
                best = (split.combo / comboSeconds, split.combo / comboSeconds, 0)
            }
            if loops.mixed, comboSeconds + chargedSeconds > 0 {
                let seconds = comboSeconds + chargedSeconds
                if (split.combo + split.charged) / seconds > best.rate {
                    best = ((split.combo + split.charged) / seconds, split.combo / seconds, split.charged / seconds)
                }
            }
            if loops.charged, chargedSeconds > 0, split.charged / chargedSeconds > best.rate {
                best = (split.charged / chargedSeconds, 0, split.charged / chargedSeconds)
            }
            return (best.combo, best.charged)
        }

        /// Bursts one rotation holds: capped by the cooldown, and by energy.
        func burstCasts(energyRecharge: Double, onField: Bool) -> Double {
            guard burstCost > 0 else { return burstCap }
            let energy = (onField ? energyOnField : energyOffField) * energyRecharge
            return min(burstCap, energy / burstCost)
        }

        /// Share of the attack string that happens: all of it, unless it is a
        /// stance that exists only while the burst (or skill) is up.
        func attackWindow(burstCasts: Double) -> Double {
            switch window {
            case .none: return 1
            case .burst: return min(1, burstCasts)
            case .skill: return min(1, skillCasts)
            }
        }
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
        /// What the floor pays on top of that coefficient, from a Ley Line
        /// Disorder or Blessing that names Vaporize or Melt.
        let amplifyingReactionBonus: Double
        let floorBonusNormal: Double
        let floorBonusOther: Double
        /// How often each part of the split happens — see `Rotation`.
        let rotation: Rotation
        /// How often this character applies their element — see
        /// `AbyssApplicationProfile`.
        var applications: AbyssApplicationProfile = .none
        /// The aura this character's element amplifies off, and how much of it
        /// one application of theirs uses up: 2 for the strong direction
        /// (Hydro on Pyro, Pyro on Cryo), 0.5 for the weak one — the game's
        /// gauge consumption.
        var amplifyingAura: GenshinElement?
        var amplifyingConsumption: Double = 0
        /// Aggravate's or Spread's coefficient when the team holds a Quicken
        /// aura and this character is Electro or Dendro; zero otherwise.
        var catalyzeCoefficient: Double = 0
        /// The enemy's resistance multiplier alone, for hits that ignore DEF
        /// (Lunar direct damage), and what the team and the floor add to each
        /// Lunar reaction's base damage and bonus.
        var resistanceMultiplier: Double = 1
        var lunarBaseBonus: [AbyssReaction: Double] = [:]
        var lunarFloorBonus: [AbyssReaction: Double] = [:]
        /// The reactions this character's team actually triggers for the pair
        /// of elements each names — `AbyssTeamContext.enabledReactions`. A
        /// talent row that *is* Lunar or Stellar damage only fires when its
        /// own reaction is in here: Flins's Lunar-Charged burst deals nothing
        /// on a team without a Moonsign character, whatever the talent table
        /// says.
        var enabledReactions: Set<AbyssReaction> = []
        /// What the team holds that a gated weapon or set buff waits on — see
        /// `AbyssGates`.
        var conditions: AbyssTeamConditions = .zero

        /// For a character with no parsed profile. An empty `aggregate` makes
        /// the damage loop produce zero, which is what the profile lookup used
        /// to return by an early exit.
        static let none = DamageContext(aggregate: [], element: .anemo, defenceAndResistance: 0,
                                        amplifyingCoefficient: 1, amplifyingReactionBonus: 0,
                                        floorBonusNormal: 0, floorBonusOther: 0,
                                        rotation: .unconstrained)
    }

    // MARK: - Rotations

    /// Rotations for a whole team, member by member, in `members` order.
    ///
    /// A particle's collector decides who receives it at full value: the
    /// caster for an instant skill (they are still on field when it lands),
    /// whoever is on field for a summon. Neither depends on anyone's gear, and
    /// only the second depends on who is on field — which is why each member
    /// carries exactly two energy figures.
    func rotations(for members: [AbyssCharacter]) -> [Rotation] {
        let rules = tuning.energy
        let profiles = members.map { library.energyByCharacterID[$0.id] }
        let enemy = rules.enemyClearParticlesPerRotation * rules.clearParticle
        return members.indices.map { index in
            guard let own = profiles[index] else { return .unconstrained }
            var caster = 0.0
            var field = 0.0
            for (source, profile) in profiles.enumerated() {
                guard let profile else { continue }
                let value = profile.particlesPerRotation
                    * (profile.element == own.element ? rules.sameElementParticle : rules.otherElementParticle)
                switch profile.collector {
                case .caster: caster += value * (source == index ? 1 : rules.offFieldShare)
                case .field: field += value
                }
            }
            var rotation = Rotation(skillCasts: own.skillCastsPerRotation, burstCost: own.burstCost,
                                    burstCap: own.burstCastsCap, window: own.window,
                                    energyOffField: caster + (field + enemy) * rules.offFieldShare,
                                    energyOnField: caster + field + enemy)
            timing(&rotation, from: own)
            return rotation
        }
    }

    private func timing(_ rotation: inout Rotation, from profile: AbyssEnergyProfile) {
        rotation.skillSeconds = profile.skillSeconds
        rotation.burstSeconds = profile.burstSeconds
        rotation.swapSeconds = tuning.swapSeconds
        rotation.comboSeconds = profile.comboSeconds
        rotation.chargedSeconds = profile.chargedSeconds
        rotation.loops = profile.attackLoops
    }

    /// A character's rotation with nobody around them, for gear selection.
    ///
    /// Alone, a character would receive only their own particles and every
    /// burst in the game would look starved. So the three missing teammates
    /// are stood in for with the median particle count of every character the
    /// data resolves, of another element, landing off field — a figure
    /// computed from the data, not written down for the purpose.
    func soloRotation(for character: AbyssCharacter) -> Rotation {
        guard let own = library.energyByCharacterID[character.id] else { return .unconstrained }
        let rules = tuning.energy
        let energy = own.particlesPerRotation * rules.sameElementParticle
            + 3 * library.medianParticlesPerCast * rules.otherElementParticle * rules.offFieldShare
            + rules.enemyClearParticlesPerRotation * rules.clearParticle
        var rotation = Rotation(skillCasts: own.skillCastsPerRotation, burstCost: own.burstCost,
                                burstCap: own.burstCastsCap, window: own.window,
                                energyOffField: energy, energyOnField: energy)
        timing(&rotation, from: own)
        // The same three stand-ins take field time too: a skill and a burst
        // each at the median cast length, each paying for a swap.
        rotation.standInOthersSeconds = 3 * (library.medianSkillSeconds + library.medianBurstSeconds
                                             + 2 * tuning.swapSeconds)
        return rotation
    }

    func damageContext(for character: AbyssCharacter,
                       profile explicitProfile: AbyssDamageProfile? = nil,
                       floor: AbyssFloorContext,
                       team: AbyssTeamContext,
                       rotation: Rotation = .unconstrained) -> DamageContext {
        guard let profile = explicitProfile ?? library.profilesByCharacterID[character.id] else {
            return .none
        }
        let element = character.element

        // A floor buff naming Vaporize or Melt multiplies the amplifying
        // reaction, not every hit — the same distinction the transformative
        // buffs get below. `amplifyingMultiplier` has always taken a
        // `reactionBonus`; nothing ever passed one.
        let amplifying = team.enabledReactions.intersection([.vaporize, .melt])
        let amplifyingBonus = amplifying.isEmpty ? 0 : floor.buffs
            .filter { !$0.reactions.isDisjoint(with: amplifying) }
            .reduce(0) { $0 + $1.bonus }

        let defMultiplier = AbyssDamageMath.defMultiplier(
            characterLevel: AbyssDamageMath.characterLevel,
            monsterLevel: floor.monsterLevel)
        // What the team strips off the enemy first. Below zero the resistance
        // curve only halves, so this keeps paying where a DMG bonus saturates —
        // which is most of what an Anemo support is for.
        let resMultiplier = AbyssDamageMath.resMultiplier(
            team.resistance(floor.resistance(for: element), to: element))

        let amplifyingCoefficient = AbyssDamageMath.amplifyingCoefficient(
            for: element, teamElements: team.elementSet, constants: library.damageConstants)
        var context = DamageContext(
            aggregate: profile.aggregate,
            element: element,
            defenceAndResistance: defMultiplier * resMultiplier,
            // Only the hits that apply this element onto the right aura
            // amplify; how many that is depends on the team and on who is on
            // field, and is applied in `teamDamage` — see `ReactionVariant`.
            amplifyingCoefficient: amplifyingCoefficient,
            amplifyingReactionBonus: amplifyingBonus,
            // The floor bonus only varies by whether the hit is a normal attack,
            // so it is resolved twice rather than per hit.
            floorBonusNormal: floorBonus(floor, element: element, isNormalAttack: true),
            floorBonusOther: floorBonus(floor, element: element, isNormalAttack: false),
            rotation: rotation)
        context.applications = library.applicationsByCharacterID[character.id] ?? .none
        context.resistanceMultiplier = resMultiplier
        context.conditions = team.conditions(for: character)
        if profile.aggregate.contains(where: { $0.reaction != nil }) {
            context.lunarBaseBonus = team.reactionBaseDamageBonus
            context.enabledReactions = team.enabledReactions
            for reaction in AbyssDamageProfile.Term.namedReactions {
                context.lunarFloorBonus[reaction] = floor.buffs
                    .filter { $0.reactions.contains(reaction) }
                    .reduce(0) { $0 + $1.bonus }
            }
        }
        if amplifyingCoefficient > 1 {
            var best: (pair: AbyssDamageMath.Pair, coefficient: Double)?
            for (pair, coefficient) in library.damageConstants.amplifyingCoefficients
            where pair.trigger == element && team.elementSet.contains(pair.existing) {
                if coefficient > (best?.coefficient ?? 0) { best = (pair, coefficient) }
            }
            context.amplifyingAura = best?.pair.existing
            context.amplifyingConsumption = (best?.coefficient ?? 0) >= 2 ? 2 : 0.5
        }
        if team.elementSet.isSuperset(of: [.dendro, .electro]) {
            switch element {
            case .electro: context.catalyzeCoefficient = library.damageConstants.aggravateCoefficient
            case .dendro: context.catalyzeCoefficient = library.damageConstants.spreadCoefficient
            default: break
            }
        }
        return context
    }

    /// A wearer's stat sheet with the party's buffs folded in and their own
    /// gated buffs opened against `context.conditions` — everywhere a hit
    /// needs the sheet a character actually fights with, on field or off.
    func effectiveStats(context: DamageContext, stats: AbyssStats, partyBuffs: PartyBuff) -> AbyssStats {
        var effective = stats
        effective.atkPercent += partyBuffs.atkPercent
        effective.flatATK += partyBuffs.flatATK
        effective.elementalMastery += partyBuffs.elementalMastery
        effective.dmgAll += partyBuffs.dmg
        effective.elementalDMG += partyBuffs.elementalDMG
        // The wearer's own buffs that wait on the team; party ones were opened
        // above.
        if stats.gates.count > 0 {
            for index in 0..<stats.gates.count {
                let gate = stats.gates[index]
                let field = AbyssStatField.indexed[Int(gate.field)]
                guard !field.isPartyScoped else { continue }
                effective.add(gate.value * gate.factor(context.conditions), to: field)
            }
        }
        return effective
    }

    func damageSplit(context: DamageContext,
                     stats: AbyssStats,
                     partyBuffs: PartyBuff) -> DamageSplit {
        let effective = effectiveStats(context: context, stats: stats, partyBuffs: partyBuffs)
        let categoryCrit = effective.hasCategoryCrit

        var amplifyingGain = 0.0
        if context.amplifyingCoefficient > 1 {
            amplifyingGain = AbyssDamageMath.amplifyingMultiplier(
                coefficient: context.amplifyingCoefficient,
                elementalMastery: effective.elementalMastery,
                reactionBonus: context.amplifyingReactionBonus,
                constants: library.damageConstants) - 1
        }

        let common = context.defenceAndResistance * effective.critMultiplier
        let elementalBonus = effective.dmgAll + effective.elementalBonus(context.element)

        var skill = 0.0
        var burst = 0.0
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
            let crit = categoryCrit
                ? context.defenceAndResistance * effective.critMultiplier(term.category) : common
            var damage = term.multiplier * effective.stat(for: term.basis) * (1 + bonus) * crit
            if let reaction = term.reaction {
                // A talent row that *is* Lunar or Stellar damage only deals it
                // when the team's own elements actually trigger that reaction
                // — Flins's Lunar-Charged burst is a normal-looking hit on a
                // team without a Moonsign character, not a smaller Lunar one.
                if context.enabledReactions.contains(reaction) {
                    // Lunar/Stellar direct damage: the reaction's coefficient on
                    // the talent multiplier, raised by the team's base-damage
                    // bonus and the Lunar/Stellar EM curve; no DMG bonus and no
                    // enemy DEF, but CRIT.
                    let constants = library.damageConstants
                    damage = term.multiplier * effective.stat(for: term.basis)
                        * (constants.lunarStellarCoefficients[reaction] ?? 1)
                        * (1 + (context.lunarBaseBonus[reaction] ?? 0))
                        * (1 + constants.lunarStellarEM.bonus(effective.elementalMastery)
                            + (context.lunarFloorBonus[reaction] ?? 0))
                        * context.resistanceMultiplier * (categoryCrit ? effective.critMultiplier(term.category)
                            : effective.critMultiplier)
                } else {
                    damage = 0
                }
            }
            switch term.action {
            case .combo: combo += damage
            case .charged: charged += damage
            case .skill: skill += damage
            case .burst: burst += damage
            }
        }

        var split = DamageSplit(skill: skill, burst: burst, combo: combo, charged: charged)
        split.amplifyingGain = amplifyingGain
        if context.catalyzeCoefficient > 0 {
            // Added to the base damage of the hit that applies, so it takes that
            // hit's DMG bonus, crit, defence and resistance like the rest of it.
            let constants = library.damageConstants
            split.catalyzePerApplication = context.catalyzeCoefficient
                * constants.transformativeLevelMultiplier
                * (1 + constants.catalyzeEM.bonus(effective.elementalMastery))
                * (1 + elementalBonus + context.floorBonusOther)
                * common
        }
        return split
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

    /// Total floor buff that applies to this element/hit type.
    ///
    /// Buffs that name a reaction are *not* here. "Sát thương Superconduct
    /// +200%" is a multiplier on the Superconduct reaction, and this function
    /// used to add it to every hit the team made instead — which on this
    /// rotation's floor 12 was worth +85% to a team's score for a reaction
    /// worth 5% of its damage, and picked the whole first-half team on that
    /// basis. `AbyssScorer.transformative` prices them now, against the
    /// reaction they actually name.
    private func floorBonus(_ floor: AbyssFloorContext,
                            element: GenshinElement,
                            isNormalAttack: Bool) -> Double {
        var bonus = 0.0
        for buff in floor.buffs where buff.reactions.isEmpty {
            if !buff.elements.isEmpty, !buff.elements.contains(element) { continue }
            if buff.normalAttackOnly, !isNormalAttack { continue }
            // A number with neither an element nor a hit type is prose.
            if buff.elements.isEmpty, !buff.normalAttackOnly { continue }
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
            hexerei: false, hasHeal: false, hasShield: false, stellarJubilee: false),
            rotation: soloRotation(for: character))
    }

    /// A character's rotation as the buff timeline reads it: casts and hits
    /// from their solo rotation, and where their damage comes from on a bare
    /// sheet — which is what decides whether a buff to attacks or to skills is
    /// the one that matters to them.
    func buffWearer(for character: AbyssCharacter) -> AbyssBuffWearer {
        var wearer = AbyssBuffWearer()
        wearer.element = character.element
        wearer.weaponType = character.weaponType.rawValue
        wearer.nation = character.nationInGame
        wearer.nightsoul = character.nationInGame == "Natlan"
        wearer.bondOfLife = library.bondOfLifeIDs.contains(character.id)
        wearer.moonsign = library.moonsignIDs.contains(character.id)
        wearer.heals = library.sustainByCharacterID[character.id]?.canHeal ?? false
        wearer.rotationSeconds = tuning.rotationSeconds

        let context = soloContext(for: character)
        let rotation = context.rotation
        wearer.skillCasts = rotation.skillCasts
        wearer.burstCasts = rotation.burstCap
        let applications = library.applicationsByCharacterID[character.id] ?? .none
        wearer.hitsPerSkill = max(1, applications.skill.hits)
        wearer.hitsPerBurst = max(1, applications.burst.hits)
        wearer.elementalAttacks = applications.combo.hits > 0 || applications.charged.hits > 0

        let base = character.baseStats.lv90
        var sheet = AbyssStats(baseATK: base.atk ?? 0, baseHP: base.hp ?? 0, baseDEF: base.def ?? 0)
        sheet.elementalMastery = 100
        let split = damageSplit(context: context, stats: sheet, partyBuffs: .none)
        let fieldSeconds = max(0, tuning.rotationSeconds - rotation.standInOthersSeconds
            - rotation.castSeconds(bursts: rotation.burstCap, onField: true))
        let attackSeconds = rotation.attackWindow(burstCasts: rotation.burstCap) * fieldSeconds
        let attacks = rotation.attackShares(split)
        let raw = SIMD4<Double>(attacks.combo * attackSeconds, attacks.charged * attackSeconds,
                                rotation.skillCasts * split.skill, rotation.burstCap * split.burst)
        let total = raw.sum()
        if total > 0 { wearer.weights = raw / total }
        return wearer
    }

    func soloScore(context: DamageContext, stats: AbyssStats) -> Double {
        let split = damageSplit(context: context, stats: stats, partyBuffs: .none)
        let rotation = context.rotation
        let bursts = rotation.burstCasts(energyRecharge: stats.energyRecharge, onField: true)
        let fieldSeconds = tuning.rotationSeconds - rotation.standInOthersSeconds
            - rotation.castSeconds(bursts: bursts, onField: true)
        return perSecond(onFieldDamage(split, rotation: rotation, energyRecharge: stats.energyRecharge,
                                       fieldSeconds: fieldSeconds))
    }

    /// Damage per rotation into damage per second.
    ///
    /// Every number this type hands *out* — a team's score, a character's share
    /// of it, a gear option's solo score — is per second. Inside, damage is
    /// accumulated per rotation, because that is the unit the multipliers are
    /// written in: the attacks field time allows, the bursts energy allows, a reaction
    /// as often as the team's element applications set it off.
    ///
    /// A rotation is assumed to take `tuning.rotationSeconds` for every team, so
    /// this does not reorder anything — it is the same ranking in units that
    /// mean something. Teams do *not* all take the same time in the real game;
    /// making that difference count would need per-character cast and cooldown
    /// data the model does not have, and until it does, a shorter rotation is a
    /// strength this ranking cannot see.
    private func perSecond(_ damagePerRotation: Double) -> Double {
        guard tuning.rotationSeconds > 0 else { return damagePerRotation }
        return damagePerRotation / tuning.rotationSeconds
    }

    /// What a split is worth to a character who is standing on field: every
    /// skill and burst the rotation holds for them, plus `fieldSeconds` of
    /// their best attack loop — inside their stance window, if they have one.
    ///
    /// `fieldSeconds` is what the rotation leaves after everyone's casts. It
    /// replaces six normal-attack strings and two charged attacks for every
    /// character alike, which over-rated long strings and under-rated charged
    /// carries against gcsim (docs/redesign.md §7.6).
    func onFieldDamage(_ split: DamageSplit, rotation: Rotation, energyRecharge: Double,
                       fieldSeconds: Double) -> Double {
        let bursts = rotation.burstCasts(energyRecharge: energyRecharge, onField: true)
        return rotation.skillCasts * split.skill + bursts * split.burst
            + rotation.attackWindow(burstCasts: bursts) * max(0, fieldSeconds) * rotation.attackRate(split)
    }

    /// Field time the driver at `index` gets: the rotation, less every other
    /// member's off-field casts and the driver's own on-field ones.
    func fieldSeconds(driver index: Int, members: [DamageContext], stats: [AbyssStats]) -> Double {
        var seconds = tuning.rotationSeconds
        for (other, context) in members.enumerated() {
            let rotation = context.rotation
            let energyRecharge = stats[other].energyRecharge
            let onField = other == index
            seconds -= rotation.castSeconds(
                bursts: rotation.burstCasts(energyRecharge: energyRecharge, onField: onField), onField: onField)
        }
        return seconds
    }

    /// What a split is worth to a character who is not: their skills, and the
    /// bursts their off-field energy buys.
    func offFieldDamage(_ split: DamageSplit, rotation: Rotation, energyRecharge: Double) -> Double {
        rotation.skillCasts * split.skill
            + rotation.burstCasts(energyRecharge: energyRecharge, onField: false) * split.burst
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
        let variant = damage.onFieldIndex < context.variants.count ? context.variants[damage.onFieldIndex] : nil
        for (index, raw) in splits.enumerated() {
            let memberContext = context.members[index]
            let rotation = memberContext.rotation
            let energyRecharge = stats[index].energyRecharge
            let split = variant.map {
                raw.reacted(memberContext.applications, amplifying: $0.amplifying[index], catalyze: $0.catalyze[index])
            } ?? raw
            perCharacter[members[index].id] = perSecond(index == damage.onFieldIndex
                ? onFieldDamage(split, rotation: rotation, energyRecharge: energyRecharge,
                                fieldSeconds: fieldSeconds(driver: index, members: context.members, stats: stats))
                : offFieldDamage(split, rotation: rotation, energyRecharge: energyRecharge))
        }
        // Reaction damage is credited to whoever sets it off, so the per-member
        // bars in the tab show a high-EM support carrying a Bloom team rather
        // than looking idle next to damage they are in fact causing.
        if damage.reactionTriggerIndex >= 0 {
            perCharacter[members[damage.reactionTriggerIndex].id, default: 0]
                += perSecond(damage.reactionDamage)
        }

        let modifiers = teamModifiers(team: team, floor: floor)
        let score = perSecond(damage.total * modifiers.multiplier)
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
        /// by base damage, or nil when it can set off none.
        let transformative: Transformative?
        /// What reactions come to with each member on field, in `members` order.
        var variants: [ReactionVariant] = []
        /// Lunar-Charged and Lunar-Crystallize, priced for this team and floor
        /// — empty when the team triggers neither. See
        /// `AbyssScorer.indirectLunarStellarDamage`.
        var indirectLunarPricing: [IndirectLunarPricing] = []
    }

    /// The reactions a team sets off in one rotation with one particular
    /// member on field.
    ///
    /// Who stands on field changes whose attacks apply an element, and so how
    /// much aura there is to amplify off, how often Quicken is up and how many
    /// transformative reactions go off. All of it is counted from element
    /// applications (`AbyssApplicationProfile`) at each member's rotation —
    /// skills per cooldown, bursts at their cap, the on-field member's
    /// attacks for the field time left — which is gear-independent on
    /// purpose: counting at every sheet's own Energy Recharge would rebuild
    /// this for every artifact the search tries, for a second-order effect.
    struct ReactionVariant: Sendable {
        /// Per member: share of their applying hits that find the aura.
        var amplifying: [Double]
        /// Per member: share of their applications that find Quicken.
        var catalyze: [Double]
        /// The transformative reaction worth most at these counts, and how
        /// many times it goes off.
        var transformative: Transformative?
        var transformativeCount: Double = 0
        /// Per member: how many times they apply their element, with this
        /// driver on field — the same figure `transformativeCount` is counted
        /// from, kept per member for `indirectLunarStellarDamage`, which needs
        /// to know *who* contributed, not just how many applications happened.
        var applications: [Double] = []
    }

    /// A transformative reaction priced for one team on one floor.
    ///
    /// Everything except the triggering character's Elemental Mastery, because
    /// that is the only part an artifact swap can move — which is what lets the
    /// artifact advisor reuse this a thousand times per member.
    struct Transformative: Sendable {
        let reaction: AbyssReaction
        /// coefficient × levelMultiplier × resMultiplier × floor and team bonuses.
        let base: Double
        /// Which Elemental Mastery curve pays this reaction. The Lunar and
        /// Stellar family has its own, much flatter than the transformative one
        /// (`6·EM/(EM+2000)` against `16·EM/(EM+2000)`), so the same EM is worth
        /// far less to them and stacking it for a Stellar-Conduct team is a
        /// different decision from stacking it for a Hyperbloom one.
        let emCurve: AbyssDamageFormula.EMCurve
    }

    /// The pair of elements an indirectly-priced Lunar reaction needs, and
    /// everything about pricing it that does not depend on who is on field or
    /// which member contributes — see `indirectLunarStellarDamage`.
    struct IndirectLunarPricing: Sendable {
        let reaction: AbyssReaction
        let pair: (GenshinElement, GenshinElement)
        /// coefficient × levelMultiplier × (1 + team base-damage bonus).
        let prefix: Double
        /// What the floor adds to this reaction's base damage, from a Ley Line
        /// Disorder or Blessing that names it.
        let floorBonus: Double
        /// Each element's resistance multiplier, for the two elements
        /// `pair` names — a contributor is priced against their own element,
        /// the same convention the direct Lunar formula uses.
        let resistanceByElement: [GenshinElement: Double]
    }

    /// Lunar-Charged and Lunar-Crystallize, and the two elements each needs —
    /// see `indirectLunarStellarDamage`. Lunar-Bloom is absent: the data
    /// records it as direct-only, never triggered by bare elemental overlap.
    static let indirectLunarReactions: [(AbyssReaction, GenshinElement, GenshinElement)] = [
        (.lunarCharged, .hydro, .electro),
        (.lunarCrystallize, .geo, .hydro),
    ]

    /// Pricing for every indirect Lunar reaction this team can trigger on this
    /// floor — empty for a team with no Moonsign character, since
    /// `AbyssTeamContext.enabledReactions` never substitutes one in without it.
    func indirectLunarPricing(for team: AbyssTeamContext, floor: AbyssFloorContext) -> [IndirectLunarPricing] {
        Self.indirectLunarReactions.compactMap { reaction, first, second -> IndirectLunarPricing? in
            guard team.enabledReactions.contains(reaction),
                  let coefficient = library.damageConstants.lunarStellarCoefficients[reaction] else { return nil }
            let floorBonus = floor.buffs.filter { $0.reactions.contains(reaction) }.reduce(0) { $0 + $1.bonus }
            let baseBonus = team.reactionBaseDamageBonus[reaction] ?? 0
            var resistance: [GenshinElement: Double] = [:]
            for element in [first, second] {
                resistance[element] = AbyssDamageMath.resMultiplier(team.resistance(floor.resistance(for: element),
                                                                                     to: element))
            }
            return IndirectLunarPricing(
                reaction: reaction, pair: (first, second),
                prefix: coefficient * library.damageConstants.transformativeLevelMultiplier * (1 + baseBonus),
                floorBonus: floorBonus, resistanceByElement: resistance)
        }
    }

    /// Lunar-Charged and Lunar-Crystallize also happen *indirectly*, on top of
    /// whatever a character's own kit deals with the same name directly:
    /// every pair of Hydro/Electro (or Geo/Hydro) applications the team lands
    /// procs one, and `damage-formula.json`'s `lunarStellar.indirect` prices
    /// that proc per contributor rather than at the team's single best
    /// Elemental Mastery the way a classic transformative reaction is —
    /// Columbina's team still gets credit for Lunar-Charged when she is
    /// nobody's idea of the highest-EM member on it.
    ///
    /// Ranked by each contributor's own damage (their own Elemental Mastery,
    /// their own CRIT, their own element's resistance), the strongest pays
    /// 0.6 of the proc, the next 0.3, and the rest 0.05 each; a team with
    /// fewer than four contributors keeps those weights for the ranks it has
    /// rather than spreading them out, exactly as the data records it. A
    /// contributor is anyone of the reaction's two elements who lands at
    /// least one application with this member on field.
    func indirectLunarStellarDamage(pricing: [IndirectLunarPricing],
                                    members: [DamageContext],
                                    stats: [AbyssStats],
                                    party: PartyBuff,
                                    applications: [Double]) -> Double {
        guard !pricing.isEmpty else { return 0 }
        var byElement = SIMD8<Double>(repeating: 0)
        for (index, member) in members.enumerated() { byElement[member.element.simdIndex] += applications[index] }

        var total = 0.0
        for entry in pricing {
            let count = Self.reactionCount(entry.reaction, lanes: byElement)
            guard count > 0 else { continue }
            var contributions: [Double] = []
            for (index, member) in members.enumerated()
            where applications[index] > 0 && (member.element == entry.pair.0 || member.element == entry.pair.1) {
                let effective = effectiveStats(context: member, stats: stats[index], partyBuffs: party)
                let resistance = entry.resistanceByElement[member.element] ?? 1
                contributions.append(entry.prefix
                    * (1 + library.damageConstants.lunarStellarEM.bonus(max(effective.elementalMastery, 0))
                        + entry.floorBonus)
                    * resistance * effective.critMultiplier)
            }
            guard !contributions.isEmpty else { continue }
            contributions.sort(by: >)
            let weights: [Double] = [0.6, 0.3, 0.05, 0.05]
            let reactionBase = zip(contributions.prefix(4), weights).reduce(0) { $0 + $1.0 * $1.1 }
            total += count * reactionBase
        }
        return total
    }

    /// The strongest transformative reaction a team unlocks, priced against the
    /// floor's resistances *and* the floor's buffs.
    ///
    /// One reaction, not the sum of all of them. A Dendro/Hydro/Electro/Pyro
    /// team technically unlocks Bloom, Hyperbloom, Burgeon, Burning, Overloaded
    /// and Electro-Charged at once, but a rotation only has so many elemental
    /// applications to spend and they compete for the same aura. Counting the
    /// best one is the conservative reading; counting them all would make
    /// four-element soup the answer to every floor.
    ///
    /// "Strongest" has to include what the floor pays for it, which is the whole
    /// point of a Ley Line Disorder that names a reaction. Ranking on the bare
    /// coefficient priced Overloaded (2.75) over Superconduct (1.5) on a floor
    /// that triples Superconduct — so the team was chosen for a reaction the
    /// floor rewards and then paid for a different one.
    func transformative(for team: AbyssTeamContext, floor: AbyssFloorContext) -> Transformative? {
        transformativeCandidates(for: team, floor: floor).max { $0.base < $1.base }
    }

    /// Every transformative reaction the team can set off, priced per trigger.
    func transformativeCandidates(for team: AbyssTeamContext, floor: AbyssFloorContext) -> [Transformative] {
        var candidates: [Transformative] = []
        // Sorted, because Hyperbloom and Burgeon share a coefficient and a
        // resistance: the damage is the same either way, but the reaction that
        // gets named should not depend on how a Set happened to hash.
        // Lunar and Stellar reactions are priced from their own block, with
        // their own EM curve; everything else from the transformative one.
        for reaction in team.transformativeReactions.sorted(by: { $0.rawValue < $1.rawValue }) {
            let constants = library.damageConstants
            let lunar = constants.lunarStellarCoefficients[reaction]
            guard let coefficient = lunar ?? constants.transformativeCoefficients[reaction] else {
                continue
            }
            let emCurve = lunar == nil ? constants.transformativeEM : constants.lunarStellarEM
            // A Lunar/Stellar reaction is worth more when someone on the team
            // raises *that* reaction's base damage just by being there.
            let teamBonus = team.reactionBaseDamageBonus[reaction] ?? 0
            // Swirl takes the resistance of whatever element was swirled, so the
            // team picks whichever of its own elements the floor resists least.
            let resistance: Double
            if let element = reaction.damageElement {
                resistance = team.resistance(floor.resistance(for: element), to: element)
            } else {
                resistance = team.elementSet
                    .subtracting([.anemo, .geo])
                    .map { team.resistance(floor.resistance(for: $0), to: $0) }
                    .min() ?? AbyssFloorContext.defaultResistance
            }
            // Every floor buff that names this reaction, and only this one.
            let floorBonus = floor.buffs
                .filter { $0.reactions.contains(reaction) }
                .reduce(0) { $0 + $1.bonus }
            let base = coefficient
                * library.damageConstants.transformativeLevelMultiplier
                * AbyssDamageMath.resMultiplier(resistance)
                * (1 + floorBonus)
                * (1 + teamBonus)
            candidates.append(Transformative(reaction: reaction, base: base, emCurve: emCurve))
        }
        return candidates
    }

    /// How many times a transformative reaction goes off, from the applications
    /// of the elements it needs. Each reaction takes one application of each
    /// side; Swirl takes Anemo against every element it can swirl; Hyperbloom
    /// and Burgeon detonate the Bloom cores Dendro and Hydro make.
    static func reactionCount(_ reaction: AbyssReaction, applications: [GenshinElement: Double]) -> Double {
        var lanes = SIMD8<Double>(repeating: 0)
        for (element, value) in applications { lanes[element.simdIndex] += value }
        return reactionCount(reaction, lanes: lanes)
    }

    /// The same count over applications indexed by `GenshinElement.simdIndex` —
    /// the form the scorer uses, since it runs once per team per on-field pick.
    static func reactionCount(_ reaction: AbyssReaction, lanes: SIMD8<Double>) -> Double {
        func a(_ element: GenshinElement) -> Double { lanes[element.simdIndex] }
        switch reaction {
        case .overloaded: return min(a(.pyro), a(.electro))
        case .superconduct, .stellarConduct: return min(a(.cryo), a(.electro))
        case .electroCharged, .lunarCharged: return min(a(.hydro), a(.electro))
        case .burning: return min(a(.dendro), a(.pyro))
        case .bloom, .lunarBloom: return min(a(.dendro), a(.hydro))
        case .hyperbloom: return min(min(a(.dendro), a(.hydro)), a(.electro))
        case .burgeon: return min(min(a(.dendro), a(.hydro)), a(.pyro))
        case .swirl: return min(a(.anemo), a(.pyro) + a(.hydro) + a(.electro) + a(.cryo))
        case .stellarSwirl: return min(a(.anemo), a(.cryo))
        case .lunarCrystallize: return min(a(.geo), a(.hydro))
        case .vaporize, .melt, .shatter: return 0
        }
    }

    /// The reaction variants of a team, one per member on field.
    func reactionVariants(members: [DamageContext], candidates: [Transformative]) -> [ReactionVariant] {
        let count = members.count
        // Each member's applications and gauge units with member `driver` on field.
        func totals(driver: Int) -> (applications: [Double], units: [Double]) {
            var castSeconds = 0.0
            for (index, member) in members.enumerated() {
                let rotation = member.rotation
                castSeconds += rotation.castSeconds(bursts: rotation.burstCap, onField: index == driver)
            }
            var applications = [Double](repeating: 0, count: count)
            var units = [Double](repeating: 0, count: count)
            for (index, member) in members.enumerated() {
                let rotation = member.rotation
                let profile = member.applications
                var a = rotation.skillCasts * profile.skill.applications + rotation.burstCap * profile.burst.applications
                var u = rotation.skillCasts * profile.skill.units + rotation.burstCap * profile.burst.units
                if index == driver {
                    let field = max(0, tuning.rotationSeconds - castSeconds)
                    var strings = 0.0, chargedAttacks = 0.0
                    if rotation.loops.combo, !rotation.loops.mixed, !rotation.loops.charged, rotation.comboSeconds > 0 {
                        strings = field / rotation.comboSeconds
                    } else if rotation.loops.charged, !rotation.loops.combo, rotation.chargedSeconds > 0 {
                        chargedAttacks = field / rotation.chargedSeconds
                    } else if rotation.comboSeconds + rotation.chargedSeconds > 0 {
                        strings = field / (rotation.comboSeconds + rotation.chargedSeconds)
                        chargedAttacks = strings
                    }
                    a += strings * profile.combo.applications + chargedAttacks * profile.charged.applications
                    u += strings * profile.combo.units + chargedAttacks * profile.charged.units
                }
                applications[index] = a
                units[index] = u
            }
            return (applications, units)
        }

        return (0..<count).map { driver in
            let (applications, units) = totals(driver: driver)
            var byElement = SIMD8<Double>(repeating: 0)
            var unitsByElement = SIMD8<Double>(repeating: 0)
            for (index, member) in members.enumerated() {
                byElement[member.element.simdIndex] += applications[index]
                unitsByElement[member.element.simdIndex] += units[index]
            }
            var variant = ReactionVariant(amplifying: [Double](repeating: 0, count: count),
                                          catalyze: [Double](repeating: 0, count: count))
            let quicken = min(byElement[GenshinElement.dendro.simdIndex], byElement[GenshinElement.electro.simdIndex])
            for (index, member) in members.enumerated() where applications[index] > 0 {
                if let aura = member.amplifyingAura, member.amplifyingConsumption > 0 {
                    // Aura units the other side lays down, against the units this
                    // member's applications use up.
                    let gauge = units[index] / applications[index]
                    let supported = unitsByElement[aura.simdIndex] / (member.amplifyingConsumption * gauge)
                    variant.amplifying[index] = min(1, supported / applications[index])
                }
                if member.catalyzeCoefficient > 0 {
                    variant.catalyze[index] = min(1, 2 * quicken / applications[index])
                }
            }
            var best: (Transformative, Double)?
            for candidate in candidates {
                let reactions = Self.reactionCount(candidate.reaction, lanes: byElement)
                if reactions * candidate.base > (best.map { $0.0.base * $0.1 } ?? 0) {
                    best = (candidate, reactions)
                }
            }
            variant.transformative = best?.0
            variant.transformativeCount = best?.1 ?? 0
            variant.applications = applications
            return variant
        }
    }

    func teamDamageContext(members: [AbyssCharacter],
                           floor: AbyssFloorContext,
                           team: AbyssTeamContext,
                           profiles: [String: AbyssDamageProfile] = [:]) -> TeamDamageContext {
        let rotations = rotations(for: members)
        let contexts = members.indices.map {
            damageContext(for: members[$0], profile: profiles[members[$0].id], floor: floor,
                          team: team, rotation: rotations[$0])
        }
        let candidates = transformativeCandidates(for: team, floor: floor)
        var context = TeamDamageContext(
            members: contexts,
            resonance: resonanceBuff(for: team),
            transformative: candidates.max { $0.base < $1.base })
        context.variants = reactionVariants(members: contexts, candidates: candidates)
        context.indirectLunarPricing = indirectLunarPricing(for: team, floor: floor)
        return context
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
        let party = partyBuffs(stats: stats, setIDs: setIDs, resonance: context.resonance,
                               members: context.members)

        for (index, memberContext) in context.members.enumerated() {
            splits[index] = damageSplit(context: memberContext, stats: stats[index], partyBuffs: party)
        }

        // Every member's off-field cast time once, so each candidate's field
        // time is a subtraction rather than a loop.
        var offFieldCasts = 0.0
        for (index, memberContext) in context.members.enumerated() {
            let rotation = memberContext.rotation
            offFieldCasts += rotation.castSeconds(
                bursts: rotation.burstCasts(energyRecharge: stats[index].energyRecharge, onField: false),
                onField: false)
        }

        // Transformative damage belongs to the team, not to a hit: it ignores
        // ATK, DMG bonus, CRIT and enemy DEF entirely and depends only on the
        // Elemental Mastery of whoever sets it off. The team always sets it off
        // with its best EM, which is why a support who deals no damage of their
        // own can be the largest contributor on a Bloom team.
        var bestEM = -Double.infinity
        var triggerIndex = -1
        for (index, sheet) in stats.enumerated() {
            let elementalMastery = sheet.elementalMastery + party.elementalMastery
            if elementalMastery > bestEM {
                bestEM = elementalMastery
                triggerIndex = index
            }
        }

        // Each candidate on field: every member's damage at the reactions that
        // pick sets off, plus the transformative reactions it counts. The
        // candidates differ in whose attacks apply an element, so the whole
        // team is summed per candidate — still no damage recomputed, only
        // arithmetic over the splits above.
        var best: (total: Double, index: Int, reaction: Double)?
        for driver in context.members.indices {
            let variant = driver < context.variants.count ? context.variants[driver] : nil
            var total = 0.0
            for (index, memberContext) in context.members.enumerated() {
                let rotation = memberContext.rotation
                let energyRecharge = stats[index].energyRecharge
                let split = variant.map {
                    splits[index].reacted(memberContext.applications, amplifying: $0.amplifying[index],
                                          catalyze: $0.catalyze[index])
                } ?? splits[index]
                if index == driver {
                    let ownOff = rotation.castSeconds(
                        bursts: rotation.burstCasts(energyRecharge: energyRecharge, onField: false), onField: false)
                    let ownOn = rotation.castSeconds(
                        bursts: rotation.burstCasts(energyRecharge: energyRecharge, onField: true), onField: true)
                    total += onFieldDamage(split, rotation: rotation, energyRecharge: energyRecharge,
                                           fieldSeconds: tuning.rotationSeconds - (offFieldCasts - ownOff) - ownOn)
                } else {
                    total += offFieldDamage(split, rotation: rotation, energyRecharge: energyRecharge)
                }
            }
            var reaction = 0.0
            if let variant, let transformative = variant.transformative, triggerIndex >= 0 {
                reaction = variant.transformativeCount * transformative.base
                    * (1 + transformative.emCurve.bonus(max(bestEM, 0)))
            }
            if let variant {
                reaction += indirectLunarStellarDamage(pricing: context.indirectLunarPricing,
                                                        members: context.members, stats: stats, party: party,
                                                        applications: variant.applications)
            }
            total += reaction
            // First maximum wins: strict `>` over members in order, so a tie
            // resolves to the earlier member and the pick is the same every run.
            if best == nil || total > best!.total { best = (total, driver, reaction) }
        }

        return TeamDamage(total: best?.total ?? 0,
                          onFieldIndex: best?.index ?? 0,
                          reactionDamage: best?.reaction ?? 0,
                          reactionTriggerIndex: (best?.reaction ?? 0) > 0 ? triggerIndex : -1)
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
        let resonance = team.resonanceStats()
        return PartyBuff(atkPercent: resonance.atkPercent,
                         elementalMastery: resonance.elementalMastery,
                         dmg: resonance.dmg)
    }

    /// - Parameter members: when given, a buff a member's *burst* grants is
    ///   scaled by the bursts that member's off-field energy buys — Bennett's
    ///   Fantastic Voyage is worth what his Energy Recharge pays for. The
    ///   off-field figure is used even for a buffer who ends up on field: the
    ///   on-field pick depends on the damage, which depends on these buffs, and
    ///   a buffer is almost never the one on field. Without `members` a burst
    ///   buff counts in full.
    func partyBuffs(stats: [AbyssStats],
                    setIDs: [[String]],
                    resonance: PartyBuff,
                    members: [DamageContext]? = nil) -> PartyBuff {
        var party = resonance

        var countedSets: Set<String> = []
        for (index, sheet) in stats.enumerated() {
            let burstShare = members.map { index < $0.count
                ? $0[index].rotation.burstCasts(energyRecharge: sheet.energyRecharge, onField: false)
                : 1 } ?? 1
            party.atkPercent += sheet.partyATKPercent
            party.flatATK += sheet.partyFlatATK + sheet.burstPartyFlatATK * burstShare
            party.elementalMastery += sheet.partyElementalMastery
            party.dmg += sheet.partyDMG
            party.elementalDMG += sheet.partyElementalDMG + sheet.burstPartyElementalDMG * burstShare

            // Party buffs that wait on the team open against the wearer's
            // conditions; without the team, they stay shut.
            if let members, index < members.count, sheet.gates.count > 0 {
                for slot in 0..<sheet.gates.count {
                    let gate = sheet.gates[slot]
                    let value = gate.value * gate.factor(members[index].conditions)
                    switch AbyssStatField.indexed[Int(gate.field)] {
                    case .partyATKPercent: party.atkPercent += value
                    case .partyFlatATK: party.flatATK += value
                    case .partyElementalMastery: party.elementalMastery += value
                    case .partyDMG: party.dmg += value
                    case .partyElementalDMG(let element): party.elementalDMG[element.simdIndex] += value
                    default: break
                    }
                }
            }

            // A four-piece set's party buff is in the totals above once per
            // wearer; take back every copy beyond the first.
            let worn = index < setIDs.count ? setIDs[index] : []
            if worn.count == 1, let setID = worn.first, !countedSets.insert(setID).inserted {
                party.atkPercent -= sheet.setPartyATKPercent
                party.flatATK -= sheet.setPartyFlatATK
                party.elementalMastery -= sheet.setPartyElementalMastery
                party.dmg -= sheet.setPartyDMG
                party.elementalDMG -= sheet.setPartyElementalDMG
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
