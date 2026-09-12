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
    /// Rows in a character's normal-attack table that look like damage and were
    /// classified as nothing: not a numbered combo hit, not a charged attack the
    /// vocabulary or `tuning.chargedAttackLabels` recognises, not a plunge.
    ///
    /// They are dropped, and dropping them is how Ganyu lost every point of
    /// Frostflake Arrow. Listing them is the difference between a gap somebody
    /// can close and a gap nobody can see.
    var normalAttackRowsUnclassified: Set<String> = []
    /// Floor buffs that parsed cleanly and then reached nothing: they name a
    /// reaction the damage model does not price at all.
    ///
    /// Recorded because the alternative is what used to happen: the bonus was
    /// quietly added to every hit the team made instead, which is not a smaller
    /// error than dropping it, only a less visible one.
    var floorBuffsNotPriced: Set<String> = []

    mutating func merge(_ other: AbyssParseDiagnostics) {
        scalingParsed += other.scalingParsed
        scalingSkipped += other.scalingSkipped
        artifactBonusMapped += other.artifactBonusMapped
        artifactBonusUnmapped.formUnion(other.artifactBonusUnmapped)
        resistanceNotesUnparsed.formUnion(other.resistanceNotesUnparsed)
        leyLineUnparsed.formUnion(other.leyLineUnparsed)
        talentPartyBuffUnresolved.formUnion(other.talentPartyBuffUnresolved)
        damageFormulaUnread.formUnion(other.damageFormulaUnread)
        floorBuffsNotPriced.formUnion(other.floorBuffsNotPriced)
        normalAttackRowsUnclassified.formUnion(other.normalAttackRowsUnclassified)
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

/// Which main stat sits in each of the three slots the model varies.
///
/// Flower and Plume are not here: they are fixed HP and ATK in game, so there is
/// nothing to decide. The other three are decided by search — see
/// `AbyssBuildAssembler.mainStatCandidates`. They used to be a fixed rule
/// (ATK% sands, elemental goblet, CRIT DMG circlet), which handed a
/// reaction-driven character a goblet and a circlet that contribute nothing to
/// the reaction damage the model was crediting them with.
struct AbyssMainStatPlan: Sendable, Equatable, Hashable {
    var sands: AbyssMainStat
    var goblet: AbyssMainStat
    var circlet: AbyssMainStat

    var slots: [AbyssMainStat] { [sands, goblet, circlet] }
}

/// One way to equip a character: a weapon, one 4-piece set or two 2-piece sets,
/// and a main stat in each of the three slots that carry a choice.
struct AbyssGearOption: Sendable {
    let stats: AbyssStats
    let weaponID: String?
    let setIDs: [String]
    let mainStats: AbyssMainStatPlan
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
        AbyssGearOption(stats: stats, weaponID: weaponID, setIDs: setIDs, mainStats: mainStats,
                        role: role, soloScore: soloScore, statSource: statSource)
    }

    /// Same option with different artifact main stats. The sets are untouched:
    /// the advisor moves one at a time so it can tell which of the two moved the
    /// score.
    func replacingMainStats(_ plan: AbyssMainStatPlan, stats: AbyssStats) -> AbyssGearOption {
        AbyssGearOption(stats: stats, weaponID: weaponID, setIDs: setIDs, mainStats: plan,
                        role: role, soloScore: soloScore, statSource: statSource)
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
/// rendered in either language: the original implementation baked Vietnamese
/// sentences into its results, which cannot ship in a bilingual app.
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

/// One half of a floor: the enemies one of the two teams meets, and the buffs
/// in force while they do.
///
/// Every Abyss chamber is fought twice — a first team clears the first half, a
/// second team the second — and a rotation can give the two halves different
/// Ley Line Disorders. This one does: floor 12's first half pays +200% for
/// Superconduct and its second +75% for Pyro normal attacks, so the two are not
/// even the same optimisation problem, let alone the same team.
struct AbyssHalfReport: Sendable, Identifiable {
    var id: Int { half }

    /// 1 for the first half ("nửa trước"), 2 for the second ("nửa sau").
    let half: Int
    /// Only what this half has and the other does not. Buffs both halves share
    /// stay on `AbyssFloorReport` so they are not printed twice.
    let buffs: [AbyssFloorBuff]
    let shieldElements: [GenshinElement]
    let weakElements: [GenshinElement]
}

/// A whole floor: one team for each half, with nobody in both.
///
/// The two halves cannot be planned separately and stapled together, because
/// their best teams almost always want the same four people — deciding which
/// half gives way is the actual problem, and it is what this type is the answer
/// to.
struct AbyssFloorPlan: Sendable, Identifiable {
    var id: String { firstHalf.id + " | " + secondHalf.id }

    let firstHalf: AbyssTeamResult
    let secondHalf: AbyssTeamResult
    /// `AbyssFloorPlan.combine(firstHalf.score, secondHalf.score)`.
    let score: Double

    var byHalf: [(half: Int, team: AbyssTeamResult)] {
        [(1, firstHalf), (2, secondHalf)]
    }

    /// How two half scores make one plan score.
    ///
    /// Both halves have to be cleared inside one timer, so a plan is ranked on
    /// how long it takes rather than on how much damage it does. Time is
    /// proportional to 1/damage, so the plan that minimises t₁ + t₂ is the one
    /// that maximises the harmonic mean of the two scores. Adding the scores
    /// instead would let a crushing first half pay for a second half that
    /// cannot clear at all, which is backwards: the half you are slow at is the
    /// half that costs the star.
    ///
    /// This treats the two halves as holding a similar amount of enemy HP,
    /// which the data does not record. That assumption is what makes two very
    /// different score scales comparable at all — this rotation's first half
    /// carries a +200% Superconduct bonus the second half has no equivalent of,
    /// and its scores run several times higher for reasons that have nothing to
    /// do with how good the team is.
    static func combine(_ firstHalf: Double, _ secondHalf: Double) -> Double {
        guard firstHalf > 0, secondHalf > 0 else { return 0 }
        return 2 * firstHalf * secondHalf / (firstHalf + secondHalf)
    }
}

struct AbyssFloorReport: Sendable, Identifiable {
    var id: Int { floor }

    let floor: Int
    let monsterLevel: Int
    /// Buffs in force for the whole floor. On a split floor that is the ones
    /// both halves share — a half's own are on `AbyssHalfReport`.
    let buffs: [AbyssFloorBuff]
    let shieldElements: [GenshinElement]
    /// Elements the floor's enemies resist less than the 10% baseline.
    let weakElements: [GenshinElement]
    /// Ranked teams for the floor fought as one. Empty when the floor was
    /// planned as two halves, because on such a floor there is no such thing as
    /// one team for the whole of it — see `plans`.
    let teams: [AbyssTeamResult]
    /// The two halves, when the floor was split. Empty otherwise.
    var halves: [AbyssHalfReport] = []
    /// Ranked plans: a team for each half, sharing no character. Empty when the
    /// floor was fought as one.
    var plans: [AbyssFloorPlan] = []
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
    /// The golden fixture runs with it off. That fixture's subject is the
    /// damage model, and this pass re-picks gear per floor and per team — it
    /// would move every number in the file for reasons the file is not about.
    var refinesArtifacts: Bool = true
    /// Plan each floor as its two halves — a team for the first, a different
    /// team for the second, sharing nobody — instead of as one fight.
    ///
    /// On is what the game asks for: floor 12 is cleared by two teams, and this
    /// rotation's Ley Line Disorder is not even the same for the two. Off reads
    /// a floor's disorder whole and ranks one team for it, which is the shape
    /// the golden fixture holds, and the shape any test wants whose subject is
    /// how a single team is scored rather than how two are chosen.
    var splitsHalves: Bool = true
    /// Rank imported characters on the stats they actually have, instead of on
    /// the standardised build everyone else is given.
    ///
    /// Off, and the reason is measurable. An imported character is scored on
    /// real gear — level 80, half-finished artifacts — while the other forty are
    /// scored at level 90 with 25 substat rolls and the best five-star set that
    /// exists. Those are not the same yardstick, and the gap is not small: on a
    /// real account the eight imported characters scored 8% to 53% of what the
    /// same characters score modelled, and not one of them reached a single team
    /// in the top five plans. Importing your showcase pushed the eight
    /// characters you have actually built *out* of your own recommendations.
    ///
    /// So the ranking asks one question of everybody — "what could this
    /// character do, built" — and the showcase is still read for everything it
    /// is authoritative about: constellation, weapon, refinement, and what the
    /// artifact advice compares against when it says an upgrade is worth
    /// something. Turn this on to ask the other question instead, of a roster
    /// where every character is imported.
    var usesMeasuredStats: Bool = false
    /// Characters whose real stats were imported from the player's showcase.
    var showcase: [AbyssShowcaseBuild] = []

    init(roster: AbyssRoster? = nil, usesFullCharacterPool: Bool = false, usesFullWeaponPool: Bool = false,
         floors: [Int]? = nil, topN: Int = 5, poolSize: Int = 40,
         refinesArtifacts: Bool = true, splitsHalves: Bool = true,
         usesMeasuredStats: Bool = false, showcase: [AbyssShowcaseBuild] = []) {
        self.roster = roster
        self.usesFullCharacterPool = usesFullCharacterPool
        self.usesFullWeaponPool = usesFullWeaponPool
        self.floors = floors
        self.topN = topN
        self.poolSize = poolSize
        self.refinesArtifacts = refinesArtifacts
        self.splitsHalves = splitsHalves
        self.usesMeasuredStats = usesMeasuredStats
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
