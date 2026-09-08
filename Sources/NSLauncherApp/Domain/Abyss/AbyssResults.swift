// AbyssResults.swift
//
// Types the planner produces: parsed intermediates, a character's chosen gear,
// and a scored team. Kept free of SwiftUI so `Views/Abyss/AbyssPresentation.swift`
// can own the icon/colour mapping and `AppText` the wording.

import Foundation

/// One "+X% to <something>" clause pulled out of a Ley Line Disorder or
/// Blessing of the Abyssal Moon description.
///
/// A clause with no element, reaction or normal-attack qualifier is dropped by
/// the parser rather than applied to everything: those are almost always prose
/// that merely contains a number ("tối đa 1 lần mỗi 4 giây").
struct AbyssFloorBuff: Sendable, Equatable {
    /// 0.50 = +50% damage.
    let bonus: Double
    let elements: Set<GenshinElement>
    let reactions: Set<AbyssReaction>
    let normalAttackOnly: Bool
    /// The clause this came from, shown in the UI so a surprising score can be
    /// traced back to the sentence that caused it.
    let raw: String
}

/// What the text parsers could not turn into numbers.
///
/// Reported rather than silently dropped: the data is prose transcribed from a
/// wiki, so the honest answer to "is the model using all of it?" is a count,
/// and a growing list here is the signal that new data needs a parser rule.
struct AbyssParseDiagnostics: Sendable, Equatable {
    var scalingParsed = 0
    var scalingSkipped = 0
    var artifactBonusMapped = 0
    var artifactBonusUnmapped: Set<String> = []
    var resistanceNotesUnparsed: Set<String> = []
    var leyLineUnparsed: Set<String> = []

    mutating func merge(_ other: AbyssParseDiagnostics) {
        scalingParsed += other.scalingParsed
        scalingSkipped += other.scalingSkipped
        artifactBonusMapped += other.artifactBonusMapped
        artifactBonusUnmapped.formUnion(other.artifactBonusUnmapped)
        resistanceNotesUnparsed.formUnion(other.resistanceNotesUnparsed)
        leyLineUnparsed.formUnion(other.leyLineUnparsed)
    }
}

/// A character's damage-relevant multipliers, parsed once at load.
struct AbyssDamageProfile: Sendable, Equatable {
    struct Term: Sendable, Equatable {
        let multiplier: Double
        let basis: ScalingBasis
        let category: HitCategory
    }

    /// Every parsed hit, in source order. Compared against the golden fixture.
    let hits: [Term]
    /// `hits` collapsed to one term per (basis, category) pair. The scorer runs
    /// over this instead: it is the same number, in 3-5 terms instead of 10-20,
    /// and the scorer evaluates it a million times per run.
    let aggregate: [Term]
    /// The stat this character mostly scales off, deciding their substat spread.
    let basis: ScalingBasis
}

/// One way to equip a character: a weapon, one 4-piece set or two 2-piece sets.
struct AbyssGearOption: Sendable {
    let stats: AbyssStats
    let weaponID: String?
    let setIDs: [String]
    let role: AbyssRole
    /// Damage this character alone would do on a neutral floor. Used to rank
    /// gear, to trim the candidate pool, and to decide who wins a contested
    /// weapon.
    let soloScore: Double
}

/// Something worth telling the user about a team, kept structured so it can be
/// rendered in either language. The Python baked Vietnamese sentences into its
/// results; that cannot ship in a bilingual app.
enum AbyssTeamNote: Sendable, Equatable, Hashable {
    case noSustainPenalty
    case breaksShield([GenshinElement])
    case exploitsWeakness([GenshinElement])
    case moonsignAscendantGleam
    case hexereiSecretRite
    case resonance(name: String)
    /// The roster has fewer copies of a weapon than the team wants; someone is
    /// holding a weapon another member is also credited with.
    case weaponContested([String])
}

struct AbyssTeamResult: Sendable, Identifiable {
    var id: String { memberIDs.joined(separator: "+") + "@" + onFieldID }

    let memberIDs: [String]
    let onFieldID: String
    let score: Double
    let perCharacterDamage: [String: Double]
    let assignment: [String: AbyssGearOption]
    let notes: [AbyssTeamNote]
}

struct AbyssFloorReport: Sendable, Identifiable {
    var id: Int { floor }

    let floor: Int
    let monsterLevel: Int
    let buffs: [AbyssFloorBuff]
    let shieldElements: [GenshinElement]
    /// Elements the floor's enemies resist less than the 10% baseline.
    let weakElements: [GenshinElement]
    let teams: [AbyssTeamResult]
}

struct AbyssOptimizerRequest: Sendable {
    /// `nil` runs against every character and weapon in the data — the
    /// "what could I build in theory" mode.
    var roster: AbyssRoster?
    /// `nil` covers every floor in the cycle.
    var floors: [Int]?
    var topN: Int = 5
    /// Ceiling on how many characters get combined. C(n,4) grows fast enough
    /// that the whole roster would be wasteful, and characters that rank far
    /// down on solo damage do not appear in good teams.
    var poolSize: Int = 40

    init(roster: AbyssRoster? = nil, floors: [Int]? = nil, topN: Int = 5, poolSize: Int = 40) {
        self.roster = roster
        self.floors = floors
        self.topN = topN
        self.poolSize = poolSize
    }
}

struct AbyssOptimizerOutput: Sendable {
    let reports: [AbyssFloorReport]
    let consideredCharacterIDs: [String]
    /// Ids in the roster that no longer exist in the data — surfaced so a
    /// renamed character shows up as a warning instead of quietly shrinking
    /// the pool.
    let unknownRosterIDs: [String]
}
