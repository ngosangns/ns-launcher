// AbyssStats.swift
//
// A character's assembled stat sheet: character base + weapon + artifacts +
// party buffs.
//
// The scorer copies this value roughly a million times per run, so the
// elemental DMG bonuses are a `SIMD8<Double>` rather than a dictionary — a
// `[GenshinElement: Double]` would heap-allocate on every copy and dominate the
// run. Eight lanes covers the seven elements with one spare.

import Foundation

struct AbyssStats: Sendable, Equatable, Codable {
    /// Character base ATK plus the weapon's base ATK. Percentage buffs scale
    /// this total, which is why weapon ATK belongs here and not in `flatATK`.
    var baseATK: Double = 0
    var baseHP: Double = 0
    var baseDEF: Double = 0

    var atkPercent: Double = 0
    var hpPercent: Double = 0
    var defPercent: Double = 0
    var flatATK: Double = 0
    var flatHP: Double = 0
    var flatDEF: Double = 0

    var elementalMastery: Double = 0
    /// 1.0 = 100%, the game's baseline.
    var energyRecharge: Double = 1
    var critRate: Double = 0.05
    var critDMG: Double = 0.50
    var healingBonus: Double = 0

    /// Per-element DMG bonus, indexed by `GenshinElement.simdIndex`.
    var elementalDMG: SIMD8<Double> = .zero
    var dmgAll: Double = 0
    var dmgNormal: Double = 0
    var dmgCharged: Double = 0
    var dmgSkill: Double = 0
    var dmgBurst: Double = 0

    /// Buffs this character grants the whole party. Collected separately
    /// because they are applied to every member, including the granter.
    var partyATKPercent: Double = 0
    var partyElementalMastery: Double = 0
    var partyDMG: Double = 0
    /// Flat ATK handed to the party. A separate channel from `partyATKPercent`
    /// because the buffs that dominate this slot — Bennett's Fantastic Voyage,
    /// Kujou Sara's Crowfeather — are a share of the *caster's* Base ATK given
    /// to everyone as a flat number. Folding them into a percentage would scale
    /// them by the receiver's own Base ATK instead, which is a different and
    /// wrong quantity.
    var partyFlatATK: Double = 0
    /// Per-element DMG bonus handed to the party, indexed like `elementalDMG`.
    /// Distinct from `partyDMG`, which reaches every element: a buff that only
    /// lifts Anemo must not lift the Pyro member's damage too.
    var partyElementalDMG: SIMD8<Double> = .zero

    var atk: Double { baseATK * (1 + atkPercent) + flatATK }
    var hp: Double { baseHP * (1 + hpPercent) + flatHP }
    var def: Double { baseDEF * (1 + defPercent) + flatDEF }

    func stat(for basis: ScalingBasis) -> Double {
        switch basis {
        case .atk: return atk
        case .hp: return hp
        case .def: return def
        case .em: return elementalMastery
        }
    }

    /// Expected-value crit multiplier used to compare builds: `1 + CR × CD`,
    /// with crit rate clamped to 100%.
    var critMultiplier: Double {
        1 + Swift.min(Swift.max(critRate, 0), 1) * critDMG
    }

    func elementalBonus(_ element: GenshinElement) -> Double {
        elementalDMG[element.simdIndex]
    }

    func categoryBonus(_ category: HitCategory) -> Double {
        switch category {
        case .normal: return dmgNormal
        case .charged: return dmgCharged
        case .skill: return dmgSkill
        case .burst: return dmgBurst
        }
    }

    mutating func add(_ value: Double, to field: AbyssStatField) {
        switch field {
        case .atkPercent: atkPercent += value
        case .hpPercent: hpPercent += value
        case .defPercent: defPercent += value
        case .flatATK: flatATK += value
        case .flatHP: flatHP += value
        case .flatDEF: flatDEF += value
        case .elementalMastery: elementalMastery += value
        case .energyRecharge: energyRecharge += value
        case .critRate: critRate += value
        case .critDMG: critDMG += value
        case .healingBonus: healingBonus += value
        case .dmgAll: dmgAll += value
        case .dmgNormal: dmgNormal += value
        case .dmgCharged: dmgCharged += value
        case .dmgSkill: dmgSkill += value
        case .dmgBurst: dmgBurst += value
        case .partyATKPercent: partyATKPercent += value
        case .partyElementalMastery: partyElementalMastery += value
        case .partyDMG: partyDMG += value
        case .partyFlatATK: partyFlatATK += value
        case .elemental(let element): elementalDMG[element.simdIndex] += value
        case .partyElementalDMG(let element): partyElementalDMG[element.simdIndex] += value
        }
    }

    /// Reads one slot back. The inverse of `add(_:to:)`, and total over the same
    /// cases — which is what lets the golden fixture write its stat sheet by
    /// walking `AbyssStatField.scalarCases` instead of twenty hand-written
    /// lines that could drift from the struct without anything noticing.
    func value(of field: AbyssStatField) -> Double {
        switch field {
        case .atkPercent: return atkPercent
        case .hpPercent: return hpPercent
        case .defPercent: return defPercent
        case .flatATK: return flatATK
        case .flatHP: return flatHP
        case .flatDEF: return flatDEF
        case .elementalMastery: return elementalMastery
        case .energyRecharge: return energyRecharge
        case .critRate: return critRate
        case .critDMG: return critDMG
        case .healingBonus: return healingBonus
        case .dmgAll: return dmgAll
        case .dmgNormal: return dmgNormal
        case .dmgCharged: return dmgCharged
        case .dmgSkill: return dmgSkill
        case .dmgBurst: return dmgBurst
        case .partyATKPercent: return partyATKPercent
        case .partyElementalMastery: return partyElementalMastery
        case .partyDMG: return partyDMG
        case .partyFlatATK: return partyFlatATK
        case .elemental(let element): return elementalDMG[element.simdIndex]
        case .partyElementalDMG(let element): return partyElementalDMG[element.simdIndex]
        }
    }
}
