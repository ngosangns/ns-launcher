// AbyssStats.swift
//
// A character's assembled stat sheet: character base + weapon + artifacts +
// party buffs. Ported from `Stats` in the Python's `build.py`.
//
// The scorer copies this value roughly a million times per run, so the
// elemental DMG bonuses are a `SIMD8<Double>` rather than a dictionary — a
// `[GenshinElement: Double]` would heap-allocate on every copy and dominate the
// run. Eight lanes covers the seven elements with one spare.

import Foundation

struct AbyssStats: Sendable, Equatable {
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
        case .elemental(let element): elementalDMG[element.simdIndex] += value
        }
    }
}
