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
                    conditional: AbyssBuildAssembler.isConditional(bonus.stat), tuning: tuning)
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
            let approximation = tuning.setEffectApprox.first(where: { $0.setId == set.id })
            var four = two
            // Same rule as `AbyssBuildAssembler.applySets`: an approximation
            // replaces the parsed four-piece bonuses.
            if approximation == nil { four += contribution(set.fourPiece.bonuses) }
            // A hand-written approximation that reaches the party is a party
            // buff like any other and does not stack with itself. Only the
            // four-piece variant carries it: `applySets` applies an
            // approximation only when all four pieces are the same set.
            //
            // This table is keyed by set alone, so it cannot express an
            // approximation whose value depends on who is wearing it — which is
            // why a party approximation may not carry a `requirement`, pinned by
            // `AbyssBuildAssemblerTests`.
            if let approximation, approximation.party == true {
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
    /// number of times in a rotation — decided by how long each takes — so one
    /// multiplier could not cover both.
    struct DamageSplit: Sendable {
        /// One skill cast's damage.
        let skill: Double
        /// One burst cast's damage.
        let burst: Double
        let combo: Double
        let charged: Double

        /// One cast of each, for callers that compare damage rather than
        /// count it.
        var ability: Double { skill + burst }

        static let zero = DamageSplit(skill: 0, burst: 0, combo: 0, charged: 0)
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
            amplifyingReactionBonus: amplifyingBonus,
            // The floor bonus only varies by whether the hit is a normal attack,
            // so it is resolved twice rather than per hit.
            floorBonusNormal: floorBonus(floor, element: element, isNormalAttack: true),
            floorBonusOther: floorBonus(floor, element: element, isNormalAttack: false),
            rotation: rotation)
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
                reactionBonus: context.amplifyingReactionBonus,
                constants: library.damageConstants)
            amplifyingFactor = 1 + tuning.amplifyingUptime * (multiplier - 1)
        } else {
            amplifyingFactor = 1
        }

        let common = context.defenceAndResistance * effective.critMultiplier * amplifyingFactor
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
            let damage = term.multiplier * effective.stat(for: term.basis) * (1 + bonus) * common
            switch term.action {
            case .combo: combo += damage
            case .charged: charged += damage
            case .skill: skill += damage
            case .burst: burst += damage
            }
        }

        return DamageSplit(skill: skill, burst: burst, combo: combo, charged: charged)
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
    /// `transformativeReactionsPerRotation` times.
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
        for (index, split) in splits.enumerated() {
            let rotation = context.members[index].rotation
            let energyRecharge = stats[index].energyRecharge
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
        /// coefficient × levelMultiplier × resMultiplier × floor and team bonuses.
        let base: Double
        /// Which Elemental Mastery curve pays this reaction. The Lunar and
        /// Stellar family has its own, much flatter than the transformative one
        /// (`6·EM/(EM+2000)` against `16·EM/(EM+2000)`), so the same EM is worth
        /// far less to them and stacking it for a Stellar-Conduct team is a
        /// different decision from stacking it for a Hyperbloom one.
        let emCurve: AbyssDamageFormula.EMCurve
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
        var best: Transformative?
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
            if base > (best?.base ?? 0) {
                best = Transformative(reaction: reaction, base: base, emCurve: emCurve)
            }
        }
        return best
    }

    func teamDamageContext(members: [AbyssCharacter],
                           floor: AbyssFloorContext,
                           team: AbyssTeamContext,
                           profiles: [String: AbyssDamageProfile] = [:]) -> TeamDamageContext {
        let rotations = rotations(for: members)
        return TeamDamageContext(
            members: members.indices.map {
                damageContext(for: members[$0], profile: profiles[members[$0].id], floor: floor,
                              team: team, rotation: rotations[$0])
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
        let party = partyBuffs(stats: stats, setIDs: setIDs, resonance: context.resonance,
                               members: context.members)

        var offFieldTotal = 0.0
        for (index, memberContext) in context.members.enumerated() {
            let split = damageSplit(context: memberContext, stats: stats[index], partyBuffs: party)
            splits[index] = split
            offFieldTotal += offFieldDamage(split, rotation: memberContext.rotation,
                                            energyRecharge: stats[index].energyRecharge)
        }

        // What standing on field adds over not: the attack string, and the
        // extra bursts full-value particles buy.
        // Every member's off-field cast time once, so each candidate's field
        // time is a subtraction rather than a loop.
        var offFieldCasts = 0.0
        for (index, memberContext) in context.members.enumerated() {
            let rotation = memberContext.rotation
            offFieldCasts += rotation.castSeconds(
                bursts: rotation.burstCasts(energyRecharge: stats[index].energyRecharge, onField: false),
                onField: false)
        }
        func onFieldGain(_ index: Int) -> Double {
            let rotation = context.members[index].rotation
            let energyRecharge = stats[index].energyRecharge
            let ownOff = rotation.castSeconds(
                bursts: rotation.burstCasts(energyRecharge: energyRecharge, onField: false), onField: false)
            let ownOn = rotation.castSeconds(
                bursts: rotation.burstCasts(energyRecharge: energyRecharge, onField: true), onField: true)
            let field = tuning.rotationSeconds - (offFieldCasts - ownOff) - ownOn
            return onFieldDamage(splits[index], rotation: rotation, energyRecharge: energyRecharge,
                                 fieldSeconds: field)
                - offFieldDamage(splits[index], rotation: rotation, energyRecharge: energyRecharge)
        }

        // First maximum wins: strict `>` over members in order, so a tie
        // resolves to the earlier member and the pick is the same every run.
        var bestIndex = 0
        var bestGain = onFieldGain(0)
        for index in 1..<splits.count {
            let gain = onFieldGain(index)
            if gain > bestGain {
                bestGain = gain
                bestIndex = index
            }
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
            let bonus = transformative.emCurve.bonus(max(bestEM, 0))
            reactionDamage = tuning.transformativeReactionsPerRotation
                * transformative.base * (1 + bonus)
        }

        return TeamDamage(total: offFieldTotal + bestGain + reactionDamage,
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
