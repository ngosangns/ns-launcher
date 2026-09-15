// AbyssBuffTimeline.swift
//
// What a triggered buff is worth over a rotation, Phase 5 of
// `docs/redesign.md`: in place of `conditionalUptime` (every qualified bonus at
// 60%) and `assumedStacks` (every stacking line at 2.5 stacks).
//
// A buff's worth is the stacks it holds *while the damage it boosts happens*,
// which is not the same as the share of the rotation it is up. Shimenawa's
// Reminiscence is up 10s of 20, but it is up for the attack string that follows
// the skill — the only damage it boosts. So the timeline answers per kind of
// hit (normal, charged, skill, burst), from the wearer's own rotation: how
// often they cast, how many hits a cast lands, how much of their damage is
// field time spent attacking. A party buff reaches damage the wearer does not
// deal, and is priced at its share of the rotation instead.
//
// Conditions that depend on who else is in the team — an aura on the enemy, a
// shield, a count of same-element members — cannot be decided while the
// sheet is assembled, because the sheet is assembled once per character and
// scored in hundreds of teams. They ride on the sheet as `AbyssGates` and are
// opened by the scorer against `AbyssTeamConditions`.

import Foundation
import simd

/// What the timeline reads about whoever holds the weapon or wears the set.
struct AbyssBuffWearer: Sendable, Equatable {
    var element: GenshinElement = .anemo
    var weaponType: String = ""
    var nation: String = ""
    var rotationSeconds: Double = 20
    var skillCasts: Double = 1
    var burstCasts: Double = 1
    /// Hits one cast lands, from `AbyssApplicationProfile`.
    var hitsPerSkill: Double = 1
    var hitsPerBurst: Double = 1
    /// Share of the wearer's own damage from normal attacks, charged attacks,
    /// skills and bursts, at their solo rotation.
    var weights = SIMD4<Double>(repeating: 0.25)
    /// Their normal and charged attacks deal Elemental DMG.
    var elementalAttacks = true
    var bondOfLife = false
    var nightsoul = false
    var heals = false
    var moonsign = false

    /// A character whose damage is attacks is on field for it; one whose damage
    /// is skills and bursts is mostly not. Read from the damage rather than
    /// written down per role.
    var fieldShare: Double { min(1, weights[0] + weights[1]) }
    var attackSeconds: Double { fieldShare * rotationSeconds }

    static let standIn = AbyssBuffWearer()
}

/// Team conditions a gate can wait on, one bit each. Counts carry the count.
enum AbyssTeamCondition: Int, CaseIterable, Sendable {
    // Enemy affected by an element: indexed by `GenshinElement.simdIndex`.
    case auraFirst = 0
    case shield = 8
    case healed
    case hpChange
    case reaction
    case moonsignAscendant
    case hexerei
    case crystallize
    // Counts of other members.
    case sameElement
    case otherElement
    case natlanOrOtherElement
    case liyue
    case liyueWithWearer
    case distinctElements
    case elementMembersFirst = 24

    var bit: UInt32 { 1 << UInt32(rawValue) }

    static func aura(_ element: GenshinElement) -> UInt32 { 1 << UInt32(auraFirst.rawValue + element.simdIndex) }

    static func members(_ element: GenshinElement) -> Int { elementMembersFirst.rawValue + element.simdIndex }
}

/// Per team member, what each `AbyssTeamCondition` is worth: 1 or 0 for a
/// condition, a count for a count. Built once per team and member.
///
/// Packed four bits a condition into two words rather than held in a
/// `SIMD32<Double>`: every value is a small integer, and in a debug build each
/// subscript of a generic SIMD type is a metadata lookup — which was most of a
/// search's time.
struct AbyssTeamConditions: Sendable, Equatable {
    private var low: UInt64 = 0
    private var high: UInt64 = 0

    static let zero = AbyssTeamConditions()

    subscript(index: Int) -> Double {
        get {
            let word = index < 16 ? low : high
            return Double((word >> UInt64((index & 15) * 4)) & 0xF)
        }
        set {
            let shift = UInt64((index & 15) * 4)
            let value = UInt64(min(15, max(0, newValue.rounded())))
            if index < 16 {
                low = (low & ~(0xF << shift)) | (value << shift)
            } else {
                high = (high & ~(0xF << shift)) | (value << shift)
            }
        }
    }
}

/// One buff on a sheet that waits on the team.
struct AbyssGate: Sendable, Equatable, Codable {
    var value = 0.0
    /// Index into `AbyssStatField.indexed`.
    var field: UInt8 = 0
    /// For a count: above zero, the count must reach it; below zero, the count
    /// is capped at its magnitude (the effect's stacks).
    var limit: Int8 = 0
    /// The gate opens when any of these holds (an aura of either element)…
    var any: UInt32 = 0
    /// …and every one of these does. A count bit multiplies instead.
    var all: UInt32 = 0

    /// How far the gate is open for a member with these conditions.
    func factor(_ conditions: AbyssTeamConditions) -> Double {
        var factor = 1.0
        if any != 0 {
            var open = 0.0
            var bits = any
            while bits != 0 {
                open = max(open, conditions[bits.trailingZeroBitCount])
                bits &= bits - 1
            }
            factor *= open
        }
        var bits = all
        while bits != 0 {
            var value = conditions[bits.trailingZeroBitCount]
            if limit > 0 { value = value >= Double(limit) ? 1 : 0 }
            if limit < 0 { value = min(value, Double(-limit)) }
            factor *= value
            bits &= bits - 1
        }
        return factor
    }
}

/// Buffs on a sheet that wait on the team. Eight fixed slots, so a sheet stays a
/// plain value — the scorer copies it a million times a run — and no generic
/// storage, for the reason `AbyssTeamConditions` gives.
struct AbyssGates: Sendable, Equatable, Codable {
    static let capacity = 8

    private var slot0 = AbyssGate(), slot1 = AbyssGate(), slot2 = AbyssGate(), slot3 = AbyssGate()
    private var slot4 = AbyssGate(), slot5 = AbyssGate(), slot6 = AbyssGate(), slot7 = AbyssGate()
    private(set) var count = 0
    /// Gates that did not fit, so a test can pin that none are dropped.
    private(set) var overflow = 0

    subscript(index: Int) -> AbyssGate {
        get {
            switch index {
            case 0: return slot0
            case 1: return slot1
            case 2: return slot2
            case 3: return slot3
            case 4: return slot4
            case 5: return slot5
            case 6: return slot6
            default: return slot7
            }
        }
        set {
            switch index {
            case 0: slot0 = newValue
            case 1: slot1 = newValue
            case 2: slot2 = newValue
            case 3: slot3 = newValue
            case 4: slot4 = newValue
            case 5: slot5 = newValue
            case 6: slot6 = newValue
            default: slot7 = newValue
            }
        }
    }

    mutating func append(_ gate: AbyssGate) {
        guard gate.value != 0 else { return }
        guard count < Self.capacity else {
            overflow += 1
            return
        }
        self[count] = gate
        count += 1
    }

    mutating func append(value: Double, field: AbyssStatField, any: UInt32, all: UInt32, limit: Int8) {
        append(AbyssGate(value: value, field: UInt8(AbyssStatField.index(of: field)), limit: limit,
                         any: any, all: all))
    }
}

enum AbyssBuffTimeline {
    static let categories: [HitCategory] = [.normal, .charged, .skill, .burst]

    /// A buff's standing on one wearer: average stacks per kind of hit, stacks
    /// averaged over the rotation, and what it waits on from the team.
    struct Reading: Sendable, Equatable {
        /// Average stacks during normal, charged, skill and burst damage.
        var stacks: SIMD4<Double>
        /// Average stacks over the rotation, for damage the wearer does not deal.
        var rotation: Double
        var any: UInt32 = 0
        var all: UInt32 = 0
        var limit: Int8 = 0

        static let off = Reading(stacks: .zero, rotation: 0)

        var isOff: Bool { rotation == 0 && stacks == .zero }
    }

    static func read(_ buff: AbyssBuff, wearer: AbyssBuffWearer) -> Reading {
        let full = Double(buff.stacks)
        var reading = Reading(stacks: SIMD4(repeating: full), rotation: full)
        // Whether a timing condition has already turned `duration` into a
        // share of the rotation. When none has, a buff that lasts `duration`
        // and can start once per `cooldown` is up at most that share of the
        // time: Sapwood Blade's leaf, 12s per 20s however often the team reacts.
        var timed = false
        for condition in buff.conditions {
            switch condition {
            // Timing: the wearer's own rotation.
            case .cast(let actions):
                timed = true
                reading.narrow(cast(actions, buff: buff, wearer: wearer))
            case .hit(let actions, let elemental):
                timed = true
                reading.narrow(hit(actions, elemental: elemental, buff: buff, wearer: wearer))
            case .every(let period):
                timed = true
                let share = buff.duration.map { min(1, $0 / period) } ?? 1
                reading.narrow(uniform(full * share))
            case .onField:
                let field = wearer.fieldShare
                reading.narrow(Reading(stacks: SIMD4(full, full, full * field, full * field), rotation: full * field))
            case .offField:
                let away = 1 - wearer.fieldShare
                reading.narrow(Reading(stacks: SIMD4(0, 0, full * away, full * away), rotation: full * away))
            case .swapIn:
                timed = true
                // One swap in per cooldown at best; without a cooldown, one per
                // member of a four-character rotation.
                let period = max(buff.cooldown ?? 0, wearer.rotationSeconds / 4)
                let share = buff.duration.map { min(1, $0 / max(period, 1e-9)) } ?? 1
                reading.narrow(uniform(full * share))

            // Facts about the wearer.
            case .bondOfLife where !wearer.bondOfLife, .nightsoul where !wearer.nightsoul,
                 .heals where !wearer.heals, .moonsign(1) where !wearer.moonsign:
                return .off
            case .bondOfLife, .nightsoul, .heals, .moonsign(1):
                break
            case .weaponType(let types):
                if !types.contains(wearer.weaponType) { return .off }
            // The benchmark and the game's defaults: one target, full HP, no
            // kills, and Energy is spent as soon as it is full.
            case .hpAbove, .enemiesBelow:
                break
            case .hpBelow, .enemiesAtLeast, .defeat, .energyFull, .energyEmpty, .unmodelled:
                return .off

            // The team.
            case .aura(let elements):
                reading.any |= elements.reduce(UInt32(0)) { $0 | AbyssTeamCondition.aura($1) }
            case .shield: reading.all |= AbyssTeamCondition.shield.bit
            case .healed: reading.all |= AbyssTeamCondition.healed.bit
            case .hpChange:
                // A Bond of Life changes the wearer's HP on its own.
                if !wearer.bondOfLife { reading.all |= AbyssTeamCondition.hpChange.bit }
            case .reaction: reading.all |= AbyssTeamCondition.reaction.bit
            case .crystallize: reading.all |= AbyssTeamCondition.crystallize.bit
            case .moonsign: reading.all |= AbyssTeamCondition.moonsignAscendant.bit
            case .hexerei: reading.all |= AbyssTeamCondition.hexerei.bit
            case .distinctElements(let atLeast):
                reading.all |= AbyssTeamCondition.distinctElements.bit
                reading.limit = Int8(clamping: atLeast)
            case .partyMembers(let match, let atLeast, let includeWearer):
                let condition: Int
                switch match {
                case .sameElement: condition = AbyssTeamCondition.sameElement.rawValue
                case .otherElement: condition = AbyssTeamCondition.otherElement.rawValue
                case .natlanOrOtherElement: condition = AbyssTeamCondition.natlanOrOtherElement.rawValue
                case .liyue:
                    condition = includeWearer ? AbyssTeamCondition.liyueWithWearer.rawValue
                        : AbyssTeamCondition.liyue.rawValue
                case .element(let element): condition = AbyssTeamCondition.members(element)
                }
                reading.all |= 1 << UInt32(condition)
                if let atLeast {
                    reading.limit = Int8(clamping: atLeast)
                } else {
                    // Per member: the count is the stacks, not the timeline.
                    reading.limit = -Int8(clamping: buff.stacks)
                    reading.stacks /= full
                    reading.rotation /= full
                }
            }
        }
        if !timed, let duration = buff.duration, let cooldown = buff.cooldown, cooldown > duration {
            reading.narrow(uniform(Double(buff.stacks) * duration / cooldown))
        }
        return reading
    }

    // MARK: - Timing

    private static func uniform(_ stacks: Double) -> Reading {
        Reading(stacks: SIMD4(repeating: stacks), rotation: stacks)
    }

    /// A buff started by casting: each cast adds a stack for `duration`.
    ///
    /// Damage of the casting action is inside its own buff; attacks follow the
    /// casts on field, so their share is of the attack time rather than of the
    /// rotation; the other cast's share is of the rotation.
    private static func cast(_ actions: AbyssBuff.Actions, buff: AbyssBuff, wearer: AbyssBuffWearer) -> Reading {
        let full = Double(buff.stacks)
        let period = wearer.rotationSeconds
        var casts = (actions.contains(.skill) ? wearer.skillCasts : 0)
            + (actions.contains(.burst) ? wearer.burstCasts : 0)
        if let cooldown = buff.cooldown, cooldown > 0 { casts = min(casts, period / cooldown) }
        guard casts > 0 else { return .off }
        guard let duration = buff.duration else { return uniform(full) }

        let overRotation = min(full, casts * duration / period)
        let overAttacks = min(full, casts * duration / max(wearer.attackSeconds, duration))
        var stacks = SIMD4<Double>(overAttacks, overAttacks, overRotation, overRotation)
        if actions.contains(.skill) { stacks[2] = max(1, overRotation) }
        if actions.contains(.burst) { stacks[3] = max(1, overRotation) }
        return Reading(stacks: stacks, rotation: overRotation)
    }

    /// A buff started by hits: each hit adds a stack.
    ///
    /// Attacks are one long run of hits over the attack time, so stacks are
    /// full through it and last `duration` past it. A skill or burst lands its
    /// hits in a burst per cast: the first hit finds no stack, the next one,
    /// and so on — which is why a hit-stacking buff is worth little to a
    /// one-hit skill and all of its stacks to a twelve-hit one.
    private static func hit(_ actions: AbyssBuff.Actions, elemental: Bool, buff: AbyssBuff,
                            wearer: AbyssBuffWearer) -> Reading {
        let full = Double(buff.stacks)
        let period = wearer.rotationSeconds
        let any = actions.isEmpty
        let attacksTrigger = (any || actions.contains(.normal) || actions.contains(.charged))
            && (!elemental || wearer.elementalAttacks) && wearer.fieldShare > 0
        let skillTriggers = (any || actions.contains(.skill)) && wearer.skillCasts > 0
        let burstTriggers = (any || actions.contains(.burst)) && wearer.burstCasts > 0
        guard attacksTrigger || skillTriggers || burstTriggers else { return .off }
        let duration = buff.duration ?? period

        func ramp(_ hits: Double) -> Double {
            // Mean over a cast's hits of the stacks the earlier hits built.
            guard hits > 1 else { return 0 }
            let count = Int(hits.rounded())
            var total = 0.0
            for index in 0..<count { total += min(full, Double(index)) }
            return total / Double(count)
        }

        var covered = 0.0
        if attacksTrigger { covered += wearer.attackSeconds + duration }
        if skillTriggers { covered += wearer.skillCasts * duration }
        if burstTriggers { covered += wearer.burstCasts * duration }
        let rotation = full * min(1, covered / period)
        let skillStacks = skillTriggers ? min(full, wearer.hitsPerSkill) : full
        let burstStacks = burstTriggers ? min(full, wearer.hitsPerBurst) : full
        let stacked = min(skillStacks, burstStacks, full)

        var stacks = SIMD4<Double>(repeating: rotation)
        if attacksTrigger {
            stacks[0] = full
            stacks[1] = full
        } else {
            let attackShare = min(1, (covered - (attacksTrigger ? wearer.attackSeconds : 0))
                / max(wearer.attackSeconds, duration))
            stacks[0] = stacked * attackShare
            stacks[1] = stacked * attackShare
        }
        if skillTriggers { stacks[2] = max(ramp(wearer.hitsPerSkill), rotation) }
        if burstTriggers { stacks[3] = max(ramp(wearer.hitsPerBurst), rotation) }
        return Reading(stacks: stacks, rotation: rotation)
    }
}

private extension AbyssBuffTimeline.Reading {
    /// Two timing conditions on one buff: both must hold, so the lesser.
    mutating func narrow(_ other: AbyssBuffTimeline.Reading) {
        stacks = simd_min(stacks, other.stacks)
        rotation = min(rotation, other.rotation)
    }
}

extension AbyssStatField {
    /// `allCases` once, so a gate can name a field by index.
    static let indexed: [AbyssStatField] = allCases

    static func index(of field: AbyssStatField) -> Int {
        indexed.firstIndex(of: field) ?? 0
    }
}
