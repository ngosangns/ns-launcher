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
    /// The share of `partyFlatATK` / `partyElementalDMG` a *burst* grants —
    /// kept apart so the scorer can scale it by how often that burst is
    /// actually up. Bennett's Fantastic Voyage is worth what his energy buys.
    var burstPartyFlatATK: Double = 0
    var burstPartyElementalDMG: SIMD8<Double> = .zero

    /// Stats the character's kit or weapon turns into ATK, as rates: Hu Tao's
    /// Paramita Papilio and Staff of Homa hand over a share of Max HP, Noelle's
    /// Sweeping Time a share of DEF, Engulfing Lightning a share of the Energy
    /// Recharge above 100%. Kept as rates rather than folded into `flatATK` at
    /// assembly so that a substat or main stat that raises HP raises ATK too —
    /// which is what makes HP% worth searching for on Hu Tao.
    var atkFromHPRate: Double = 0
    var atkFromDEFRate: Double = 0
    var atkPercentPerExcessER: Double = 0

    /// CRIT that reaches one kind of hit only, indexed by
    /// `AbyssStats.categoryIndex`: normal, charged, skill, burst.
    var critRateByCategory: SIMD4<Double> = .zero
    var critDMGByCategory: SIMD4<Double> = .zero
    /// Either of the two is non-zero, kept so the scorer's hot loop can skip
    /// them without reading them.
    var hasCategoryCrit = false

    /// Weapon and set buffs that wait on the team — see `AbyssGates`.
    var gates = AbyssGates()

    /// Buffs that are a rate of another stat ("24% of Elemental Mastery as
    /// ATK"), held until the sheet is complete and folded in by
    /// `foldConversions()`. Kept apart from `atkFromHPRate` and its siblings,
    /// which stay lazy for the kits that use them.
    var conversions = AbyssConversions()

    /// What this sheet's four-piece set hands the party, so that a second
    /// wearer of the same set can take theirs back out — see
    /// `AbyssScorer.partyBuffs`.
    var setPartyATKPercent: Double = 0
    var setPartyFlatATK: Double = 0
    var setPartyElementalMastery: Double = 0
    var setPartyDMG: Double = 0
    var setPartyElementalDMG: SIMD8<Double> = .zero

    /// Branches rather than multiplies by zero: this is read per hit in the
    /// scorer's innermost loop, and almost every sheet converts nothing.
    var atk: Double {
        var atk = baseATK * (1 + atkPercent) + flatATK
        if atkFromHPRate != 0 { atk += hp * atkFromHPRate }
        if atkFromDEFRate != 0 { atk += def * atkFromDEFRate }
        if atkPercentPerExcessER != 0, energyRecharge > 1 {
            atk += baseATK * atkPercentPerExcessER * (energyRecharge - 1)
        }
        return atk
    }
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

    /// The same, for one kind of hit.
    func critMultiplier(_ category: HitCategory) -> Double {
        let index = Self.categoryIndex(category)
        return 1 + Swift.min(Swift.max(critRate + critRateByCategory[index], 0), 1)
            * (critDMG + critDMGByCategory[index])
    }

    static func categoryIndex(_ category: HitCategory) -> Int {
        switch category {
        case .normal: return 0
        case .charged: return 1
        case .skill: return 2
        case .burst: return 3
        }
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
        case .critRateFor(let category):
            critRateByCategory[Self.categoryIndex(category)] += value
            hasCategoryCrit = true
        case .critDMGFor(let category):
            critDMGByCategory[Self.categoryIndex(category)] += value
            hasCategoryCrit = true
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
        case .critRateFor(let category): return critRateByCategory[Self.categoryIndex(category)]
        case .critDMGFor(let category): return critDMGByCategory[Self.categoryIndex(category)]
        }
    }

    /// Folds `conversions` into the sheet at its current stats. Called once
    /// the sheet is complete — after main stats and sets — and idempotent: the
    /// slots are emptied as they are applied.
    mutating func foldConversions() {
        guard conversions.count > 0 else { return }
        for index in 0..<conversions.count {
            let conversion = conversions[index]
            let base: Double
            switch AbyssConversions.Source(rawValue: conversion.source) ?? .em {
            case .em: base = elementalMastery
            case .hp: base = hp
            case .def: base = def
            case .atk: base = atk
            case .er: base = energyRecharge
            case .erOver100: base = Swift.max(0, energyRecharge - 1)
            }
            var value = base * conversion.rate
            if conversion.cap > 0 { value = Swift.min(value, conversion.cap) }
            if conversion.any != 0 || conversion.all != 0 {
                gates.append(AbyssGate(value: value, field: conversion.field, limit: conversion.limit,
                                       any: conversion.any, all: conversion.all))
            } else {
                add(value, to: AbyssStatField.indexed[Int(conversion.field)])
            }
        }
        conversions = AbyssConversions()
    }
}

/// One rate buff waiting for a complete sheet — see `AbyssStats.conversions`.
struct AbyssConversion: Sendable, Equatable, Codable {
    /// Already divided by the effect's `per` and multiplied by its uptime.
    var rate = 0.0
    /// Zero for no cap.
    var cap = 0.0
    var source: UInt8 = 0
    var field: UInt8 = 0
    var limit: Int8 = 0
    var any: UInt32 = 0
    var all: UInt32 = 0
}

/// Rate buffs waiting for a complete sheet, four fixed slots — see
/// `AbyssGates` for why not an array or SIMD storage.
struct AbyssConversions: Sendable, Equatable, Codable {
    enum Source: UInt8 {
        case em, hp, def, atk, er, erOver100
    }

    static let capacity = 4

    private var slot0 = AbyssConversion(), slot1 = AbyssConversion()
    private var slot2 = AbyssConversion(), slot3 = AbyssConversion()
    private(set) var count = 0
    private(set) var overflow = 0

    subscript(index: Int) -> AbyssConversion {
        get {
            switch index {
            case 0: return slot0
            case 1: return slot1
            case 2: return slot2
            default: return slot3
            }
        }
        set {
            switch index {
            case 0: slot0 = newValue
            case 1: slot1 = newValue
            case 2: slot2 = newValue
            default: slot3 = newValue
            }
        }
    }

    mutating func append(_ conversion: AbyssConversion) {
        guard conversion.rate != 0 else { return }
        guard count < Self.capacity else {
            overflow += 1
            return
        }
        self[count] = conversion
        count += 1
    }

    mutating func append(rate: Double, cap: Double?, source: Source, field: AbyssStatField,
                         any: UInt32, all: UInt32, limit: Int8) {
        append(AbyssConversion(rate: rate, cap: cap ?? 0, source: source.rawValue,
                               field: UInt8(AbyssStatField.index(of: field)), limit: limit, any: any, all: all))
    }
}

extension AbyssConversions.Source {
    init(_ source: AbyssBuff.Source) {
        switch source {
        case .em: self = .em
        case .hp: self = .hp
        case .def: self = .def
        case .atk: self = .atk
        case .er: self = .er
        case .erOver100: self = .erOver100
        }
    }
}
