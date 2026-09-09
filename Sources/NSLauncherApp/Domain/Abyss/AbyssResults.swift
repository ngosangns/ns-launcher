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
    /// Which of the Abyss's two buff layers a clause came from. Carried so the
    /// UI can say which, rather than presenting a cycle-wide blessing and a
    /// floor's own disorder as the same thing.
    enum Source: Sendable, Equatable {
        /// The floor's own Ley Line Disorder.
        case leyLine
        /// The Blessing of the Abyssal Moon, which applies to every floor for
        /// the whole cycle.
        case blessing
    }

    /// 0.50 = +50% damage.
    let bonus: Double
    let elements: Set<GenshinElement>
    let reactions: Set<AbyssReaction>
    let normalAttackOnly: Bool
    /// The clause this came from, shown in the UI so a surprising score can be
    /// traced back to the sentence that caused it.
    let raw: String
    var source: Source = .leyLine
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
    /// Entries in `tuning.json`'s `talentPartyBuff` whose character or scaling
    /// label no longer exists. That table points at rows in the character data
    /// by name; without this, a renamed row would make a buff quietly vanish
    /// instead of failing loudly.
    var talentPartyBuffUnresolved: Set<String> = []
    /// Parts of `damage-formula.json` the loader could not read, so the planner
    /// fell back to the values the port was written with.
    var damageFormulaUnread: Set<String> = []

    mutating func merge(_ other: AbyssParseDiagnostics) {
        scalingParsed += other.scalingParsed
        scalingSkipped += other.scalingSkipped
        artifactBonusMapped += other.artifactBonusMapped
        artifactBonusUnmapped.formUnion(other.artifactBonusUnmapped)
        resistanceNotesUnparsed.formUnion(other.resistanceNotesUnparsed)
        leyLineUnparsed.formUnion(other.leyLineUnparsed)
        talentPartyBuffUnresolved.formUnion(other.talentPartyBuffUnresolved)
        damageFormulaUnread.formUnion(other.damageFormulaUnread)
    }
}

/// One party-wide buff a character's talents grant, with its number already
/// read out of the character data and scaled by the assumed uptime.
///
/// Resolved once at load, like `AbyssDamageProfile`, so the label matching that
/// links `tuning.json` to the character data happens in one place and reports
/// itself when it fails.
struct AbyssTalentPartyBuff: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        /// Multiply by the caster's Base ATK to get flat ATK for the party.
        case flatATKFromBaseATK
        /// A DMG bonus for the caster's own element, party-wide.
        case elementalDMG
    }

    let kind: Kind
    /// Already multiplied by the entry's uptime.
    let value: Double
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
    /// Whether these numbers came from the player's own account or from the
    /// standardised build. Carried this far so the UI can say which, instead of
    /// presenting a measurement and an assumption as the same kind of claim.
    var statSource: AbyssStatSource = .modelled

    /// Same option with different artifacts. Used by `AbyssArtifactAdvisor`,
    /// which keeps the weapon (contention was already settled) and only moves
    /// the sets.
    func replacingSets(_ setIDs: [String], stats: AbyssStats) -> AbyssGearOption {
        AbyssGearOption(stats: stats, weaponID: weaponID, setIDs: setIDs, role: role,
                        soloScore: soloScore, statSource: statSource)
    }
}

/// An artifact main stat, as the model actually applies it.
///
/// This is not a display string: `AbyssBuildAssembler` builds its stat sheet
/// from the same plan the UI renders, so the advice cannot describe a build
/// different from the one that was scored.
enum AbyssMainStat: Sendable, Equatable, Hashable {
    case atkPercent
    case hpPercent
    case defPercent
    case elementalMastery
    case energyRecharge
    case critRate
    case critDMG
    case healingBonus
    case elementalDMG(GenshinElement)

    var statField: AbyssStatField {
        switch self {
        case .atkPercent: return .atkPercent
        case .hpPercent: return .hpPercent
        case .defPercent: return .defPercent
        case .elementalMastery: return .elementalMastery
        case .energyRecharge: return .energyRecharge
        case .critRate: return .critRate
        case .critDMG: return .critDMG
        case .healingBonus: return .healingBonus
        case .elementalDMG(let element): return .elemental(element)
        }
    }
}

/// Which artifacts to put on one character for one team on one floor.
///
/// The optimiser's first pass ranks gear on neutral ground — no floor, no team
/// — because it has to compare every character against every other before it
/// knows which four end up together. That is the right yardstick for choosing
/// who plays, and the wrong one for choosing what they wear: a set is worth
/// having because of what the enemies resist and what the other three members
/// enable. This is the second pass, run only on the teams that made the cut.
struct AbyssArtifactAdvice: Sendable, Equatable {
    /// One id for a 4-piece set, two ids for two 2-piece sets.
    let setIDs: [String]
    let sands: AbyssMainStat
    let goblet: AbyssMainStat
    let circlet: AbyssMainStat
    /// Substat keys in descending share of the roll budget, ties broken by name.
    let substatPriority: [String]
    /// Team-score gain over the sets the neutral first pass had picked.
    /// `0.06` = the team scores 6% higher with these artifacts. Zero means the
    /// context-free pick was already the best one here.
    let gainOverNeutralPick: Double
    /// The runner-up, for when the best set is not farmed yet.
    let alternativeSetIDs: [String]
    /// How much worse the runner-up is, as a fraction of the team score.
    let alternativeGap: Double
    /// What the player has equipped right now, when their showcase says so.
    /// Empty when the character was not imported, or when it matches `setIDs`.
    var currentSetIDs: [String] = []
    /// What moving from `currentSetIDs` to `setIDs` is worth, as a fraction of
    /// the team score. Zero when they are already wearing the best option.
    var upgradeOverCurrent: Double = 0
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
    /// Some members were scored on their real artifacts and some on the
    /// standardised build, so the two are not strictly comparable — a
    /// well-built imported character and an assumed one are different claims.
    case mixedStatSources
}

struct AbyssTeamResult: Sendable, Identifiable {
    var id: String { memberIDs.joined(separator: "+") + "@" + onFieldID }

    let memberIDs: [String]
    let onFieldID: String
    let score: Double
    let perCharacterDamage: [String: Double]
    let assignment: [String: AbyssGearOption]
    let notes: [AbyssTeamNote]
    /// The score before artifacts were re-picked for this team and floor. Equal
    /// to `score` when the refinement pass did not run or found nothing better.
    var baseScore: Double = 0
    /// Per character. Empty when the refinement pass did not run.
    var artifactAdvice: [String: AbyssArtifactAdvice] = [:]

    /// How much the artifact pass added, as a fraction of the original score.
    var artifactGain: Double {
        guard baseScore > 0 else { return 0 }
        return score / baseScore - 1
    }
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
    /// "what could I build in theory" mode — with no reference gear, so
    /// refinement and constellation both fall back to their defaults even for
    /// things the player actually owns. Pass a real roster and set the pool
    /// flags below instead when only *part* of the search should be
    /// unrestricted; the roster still supplies real refinement/constellation
    /// values wherever they are known, whichever way the pool flags point.
    var roster: AbyssRoster?
    /// Ignores `roster` for which characters are candidates, without touching
    /// which weapons are.
    var usesFullCharacterPool: Bool = false
    /// Ignores `roster` for which weapons are candidates, without touching
    /// which characters are.
    var usesFullWeaponPool: Bool = false
    /// `nil` runs the deepest floor only — floor 12, or the highest the cycle
    /// file actually has. Floors 9-11 are cleared by anything that clears 12,
    /// so ranking teams for them spent three quarters of the search on an
    /// answer nobody acts on. Pass an explicit list to override.
    var floors: [Int]?
    var topN: Int = 5
    /// Ceiling on how many characters get combined. C(n,4) grows fast enough
    /// that the whole roster would be wasteful, and characters that rank far
    /// down on solo damage do not appear in good teams.
    var poolSize: Int = 40
    /// Re-pick each surviving team's artifacts for its actual floor and team
    /// mates, then re-rank on the result.
    ///
    /// Off is the reference implementation's behaviour, which is why the golden
    /// fixture runs with it off: that fixture's job is to hold the port to the
    /// Python's numbers, and this pass has no Python counterpart.
    var refinesArtifacts: Bool = true
    /// Characters whose real stats were imported from the player's showcase.
    /// These are scored on what they actually have rather than on the
    /// standardised build.
    var showcase: [AbyssShowcaseBuild] = []

    init(roster: AbyssRoster? = nil, usesFullCharacterPool: Bool = false, usesFullWeaponPool: Bool = false,
         floors: [Int]? = nil, topN: Int = 5, poolSize: Int = 40,
         refinesArtifacts: Bool = true, showcase: [AbyssShowcaseBuild] = []) {
        self.roster = roster
        self.usesFullCharacterPool = usesFullCharacterPool
        self.usesFullWeaponPool = usesFullWeaponPool
        self.floors = floors
        self.topN = topN
        self.poolSize = poolSize
        self.refinesArtifacts = refinesArtifacts
        self.showcase = showcase
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
