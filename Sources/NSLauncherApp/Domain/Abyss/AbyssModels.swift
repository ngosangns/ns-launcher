// AbyssModels.swift
//
// Value types shared by the Abyss team planner. Ported from
// `toi-uu-doi-hinh/optimizer/` — that Python remains the reference for the
// model's behaviour, and `Tests/.../Fixtures/abyss-golden.json` holds its
// numbers so this port can be held to them.
//
// Python leaned on dynamic typing in three places that become explicit types
// here: string stat names looked up with `getattr`/`setattr` (`AbyssStatField`),
// a `dmg_{category}` name built by interpolation (`HitCategory`), and dict
// iteration order deciding a tie-break (`ScalingBasis.tieBreakOrder`).

import Foundation

/// The seven playable elements. Physical is deliberately *not* a case: no
/// character has it as their element, and modelling it here would force an
/// impossible case into every `switch`. Enemy physical resistance is expressed
/// by `ResistanceTarget` instead.
enum GenshinElement: String, CaseIterable, Codable, Sendable, Hashable {
    case anemo = "Anemo"
    case geo = "Geo"
    case electro = "Electro"
    case dendro = "Dendro"
    case hydro = "Hydro"
    case pyro = "Pyro"
    case cryo = "Cryo"

    /// Slot in `AbyssStats.elementalDMG`'s `SIMD8`. Stable because it follows
    /// `allCases`, which follows declaration order.
    var simdIndex: Int {
        switch self {
        case .anemo: return 0
        case .geo: return 1
        case .electro: return 2
        case .dendro: return 3
        case .hydro: return 4
        case .pyro: return 5
        case .cryo: return 6
        }
    }
}

/// What an enemy resistance note refers to. Notes name Physical alongside the
/// elements ("kháng vật lý"), so parsing needs a wider type than `GenshinElement`.
enum ResistanceTarget: Hashable, Sendable {
    case element(GenshinElement)
    case physical
}

enum WeaponType: String, CaseIterable, Codable, Sendable {
    case sword = "Sword"
    case claymore = "Claymore"
    case polearm = "Polearm"
    case bow = "Bow"
    case catalyst = "Catalyst"
}

/// Which stat a talent multiplier scales off.
enum ScalingBasis: String, Codable, Sendable, CaseIterable {
    case atk = "ATK"
    case hp = "HP"
    case def = "DEF"
    case em = "EM"

    /// Order used to break ties when deciding a character's dominant basis.
    ///
    /// The Python takes `max()` over a dict built in the order ATK, DEF, HP, EM
    /// and Python's `max` keeps the *first* maximum, so a tie between non-ATK
    /// bases resolves to DEF, then HP, then EM. Swift's `Dictionary` has no
    /// order, so the rule has to be written down or characters with balanced
    /// DEF/HP scaling would silently pick a different basis — and with it a
    /// different substat spread and a different score.
    static let tieBreakOrder: [ScalingBasis] = [.def, .hp, .em]
}

/// Damage category a hit belongs to, replacing Python's `f"dmg_{category}"`.
enum HitCategory: String, Codable, Sendable, CaseIterable {
    case normal
    case charged
    case skill
    case burst
}

enum AbyssRole: String, Codable, Sendable, CaseIterable {
    case mainDPS = "main-dps"
    case subDPS = "sub-dps"
    case support
    case shield
    case healer
}

/// Reactions the planner reasons about by name. Only the ones that appear in
/// floor buff text or change a team's damage are modelled.
enum AbyssReaction: String, Codable, Sendable, Hashable, CaseIterable {
    case vaporize = "Vaporize"
    case melt = "Melt"
    case superconduct = "Superconduct"
    case stellarConduct = "Stellar-Conduct"
    case stellarSwirl = "Stellar Swirl"
    case electroCharged = "Electro-Charged"
    case lunarCharged = "Lunar-Charged"
    case lunarBloom = "Lunar-Bloom"
    case lunarCrystallize = "Lunar-Crystallize"
    case overloaded = "Overloaded"
    case bloom = "Bloom"
}

/// A named stat slot in `AbyssStats`.
///
/// Python resolved these at runtime from the text in the data (`setattr(stats,
/// attr, ...)`), which cannot be expressed in Swift and should not be: making
/// the slots an enum turns "this artifact bonus went into the wrong field" from
/// a silent wrong answer into a compile-time exhaustive `switch`.
enum AbyssStatField: Sendable, Hashable {
    case atkPercent, hpPercent, defPercent
    case flatATK, flatHP, flatDEF
    case elementalMastery, energyRecharge
    case critRate, critDMG, healingBonus
    case dmgAll, dmgNormal, dmgCharged, dmgSkill, dmgBurst
    case partyATKPercent, partyElementalMastery, partyDMG
    case elemental(GenshinElement)

    static func dmg(for category: HitCategory) -> AbyssStatField {
        switch category {
        case .normal: return .dmgNormal
        case .charged: return .dmgCharged
        case .skill: return .dmgSkill
        case .burst: return .dmgBurst
        }
    }
}
