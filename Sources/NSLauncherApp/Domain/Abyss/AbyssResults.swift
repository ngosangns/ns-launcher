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
struct AbyssFloorBuff: Sendable, Equatable, Codable {
    /// Which of the Abyss's two buff layers a clause came from. Carried so the
    /// UI can say which, rather than presenting a cycle-wide blessing and a
    /// floor's own disorder as the same thing.
    enum Source: Sendable, Equatable, Codable {
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
    /// Entries in `character-kits.json`'s `buffs` whose scaling label no
    /// longer exists. That table points at rows in the character data by name;
    /// without this, a renamed row would make a buff quietly vanish instead of
    /// failing loudly.
    var talentBuffUnresolved: Set<String> = []
    /// Entries in `character-kits.json` that name a character the data does
    /// not have — or a reaction it does not have, or the same character twice.
    ///
    /// The gap this closes is the whole reason that file exists. The seven
    /// tables it replaces were spread over three files, and six of them were
    /// read with no check at all: a mistyped id in `stellarJubileeCharacterIds`
    /// removed the mechanic for everybody and looked exactly like a rotation
    /// where nobody had it.
    var unknownKitCharacterIDs: Set<String> = []
    /// References in `character-kits.json` that named a row, a param or a stat
    /// the data does not have — a hit, a conversion or a shred that is now
    /// contributing nothing. Pinned empty by `AbyssCharacterKitTests`.
    var kitReferencesUnresolved: Set<String> = []
    /// Parts of `damage-formula.json` the loader could not read, so the planner
    /// fell back to the values the port was written with.
    var damageFormulaUnread: Set<String> = []
    /// Rows in a character's normal-attack table that look like damage and were
    /// classified as nothing: not a numbered combo hit, not a charged attack the
    /// vocabulary or `character-kits.json`'s `chargedAttackLabels`
    /// recognises, not a plunge.
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
    /// Lines in `talent-params.json` that say DMG and that `AbyssTalentReader`
    /// could not read as a hit: an expression shape the grammar does not know.
    /// Every shape in the data was enumerated before the reader was written, so
    /// an entry here is new data, not a known gap — and it is a row the model
    /// is scoring as zero until somebody looks.
    var talentParamsUnread: Set<String> = []
    /// Characters whose skill particles could not be read from
    /// `particles.json` and the kit together, and so use the median of every
    /// character that could. Each is an energy economy the model is
    /// approximating; pinned by name in `AbyssEnergyTests`.
    var particlesEstimated: Set<String> = []

    mutating func merge(_ other: AbyssParseDiagnostics) {
        scalingParsed += other.scalingParsed
        scalingSkipped += other.scalingSkipped
        artifactBonusMapped += other.artifactBonusMapped
        artifactBonusUnmapped.formUnion(other.artifactBonusUnmapped)
        resistanceNotesUnparsed.formUnion(other.resistanceNotesUnparsed)
        leyLineUnparsed.formUnion(other.leyLineUnparsed)
        talentBuffUnresolved.formUnion(other.talentBuffUnresolved)
        unknownKitCharacterIDs.formUnion(other.unknownKitCharacterIDs)
        kitReferencesUnresolved.formUnion(other.kitReferencesUnresolved)
        damageFormulaUnread.formUnion(other.damageFormulaUnread)
        floorBuffsNotPriced.formUnion(other.floorBuffsNotPriced)
        normalAttackRowsUnclassified.formUnion(other.normalAttackRowsUnclassified)
        talentParamsUnread.formUnion(other.talentParamsUnread)
        particlesEstimated.formUnion(other.particlesEstimated)
    }
}

/// One party-wide buff a character's talents grant, with its number already
/// read out of the character data and scaled by the assumed uptime.
///
/// Resolved once at load, like `AbyssDamageProfile`, so the label matching that
/// links `tuning.json` to the character data happens in one place and reports
/// itself when it fails.
struct AbyssTalentBuff: Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        /// Multiply by the caster's Base ATK to get flat ATK for the party.
        case flatATKFromBaseATK
        /// A DMG bonus for the caster's own element, party-wide.
        case elementalDMG
        /// One slot of the caster's own sheet: Xiao's burst raising his own
        /// normal-attack damage, Hu Tao's passive raising her own Pyro bonus.
        case ownStat(AbyssStatField)
    }

    let kind: Kind
    /// Already multiplied by the entry's uptime.
    let value: Double
    /// Granted by the burst, so up only as often as the burst is — the scorer
    /// scales a party buff by the caster's burst casts per rotation.
    var fromBurst: Bool = false
}

/// A stat a character's kit turns into ATK, resolved from `character-kits.json`
/// at load. Lands on the sheet as a rate (`AbyssStats.atkFromHPRate`), not a
/// number, so the search sees the conversion move when the stat moves.
struct AbyssStatConversion: Sendable, Equatable {
    let from: ScalingBasis
    /// Already multiplied by the entry's uptime.
    let rate: Double
}

/// A character's damage-relevant multipliers, parsed once at load.
struct AbyssDamageProfile: Sendable, Equatable {
    /// How often a hit happens in a rotation — the thing `category` used to
    /// stand in for. They are the same for every row the reader infers: a
    /// normal-attack row is part of the combo string, a charged row is one
    /// charged attack, a skill or burst row is once per cast. A kit can pull
    /// them apart, because the game does: Raiden's Musou Isshin strikes are
    /// her attack string (`combo`) and are priced as Elemental Burst DMG
    /// (`category: .burst`), and Kinich's Loop Shots are his attack string
    /// and Elemental Skill DMG. The scorer counts by `action` and buffs by
    /// `category` — and since Phase 3 counts a skill and a burst differently,
    /// because energy decides one and not the other.
    enum Action: String, Sendable, Codable, CaseIterable {
        /// One numbered hit of the attack string, made `normalCombosPerRotation` times.
        case combo
        /// One charged attack, made `chargedAttacksPerRotation` times.
        case charged
        /// One skill cast, made `skillCastsPerRotation` times.
        case skill
        /// One burst cast, made as often as energy and cooldown allow.
        case burst

        /// What a row of that category is, absent a kit saying otherwise.
        init(defaultFor category: HitCategory) {
            switch category {
            case .normal: self = .combo
            case .charged: self = .charged
            case .skill: self = .skill
            case .burst: self = .burst
            }
        }
    }

    struct Term: Sendable, Equatable, Hashable {
        let multiplier: Double
        let basis: ScalingBasis
        let category: HitCategory
        let action: Action

        init(multiplier: Double, basis: ScalingBasis, category: HitCategory, action: Action? = nil) {
            self.multiplier = multiplier
            self.basis = basis
            self.category = category
            self.action = action ?? Action(defaultFor: category)
        }
    }

    /// Every parsed hit, in source order. Compared against the golden fixture.
    let hits: [Term]
    /// `hits` collapsed to one term per (basis, category, action) triple. The
    /// scorer runs over this instead: it is the same number, in 3-5 terms
    /// instead of 10-20, and the scorer evaluates it a million times per run.
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
struct AbyssMainStatPlan: Sendable, Equatable, Hashable, Codable {
    var sands: AbyssMainStat
    var goblet: AbyssMainStat
    var circlet: AbyssMainStat

    var slots: [AbyssMainStat] { [sands, goblet, circlet] }

    /// The two slots that carry no choice: a Flower is flat HP and a Plume flat
    /// ATK, always. Named here rather than spelled as two string keys where they
    /// are applied, so they are part of the same vocabulary as the three that do
    /// carry a choice — and so a test can require `artifactMainStats` to hold a
    /// value for all five and nothing else.
    static let fixedSlots: [AbyssStatField] = [.flatHP, .flatATK]
}

/// One way to equip a character: a weapon, one 4-piece set or two 2-piece sets,
/// and a main stat in each of the three slots that carry a choice.
struct AbyssGearOption: Sendable, Codable {
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
enum AbyssMainStat: Sendable, Equatable, Hashable, Codable {
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
struct AbyssArtifactAdvice: Sendable, Equatable, Codable {
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
enum AbyssTeamNote: Sendable, Equatable, Hashable, Codable {
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

struct AbyssTeamResult: Sendable, Identifiable, Codable {
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
struct AbyssHalfReport: Sendable, Identifiable, Codable {
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
struct AbyssFloorPlan: Sendable, Identifiable, Codable {
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

struct AbyssFloorReport: Sendable, Identifiable, Codable {
    /// How the floor was planned, and therefore what there is to show.
    ///
    /// An enum rather than three arrays, because the three were never all
    /// meaningful at once: a floor planned as two halves has no "best team for
    /// the floor", and a floor fought whole has no halves. Carried as arrays,
    /// that rule lived in four "Empty when…" comments and in one
    /// `report.plans.isEmpty` in the view — a reader had to know which emptiness
    /// meant "not applicable" and which meant "nothing found". Here the question
    /// cannot be asked of the wrong shape.
    enum Outcome: Sendable, Codable {
        /// Ranked teams for the floor fought as one.
        case whole([AbyssTeamResult])
        /// A team for each half, sharing no character, with the halves they
        /// were ranked against.
        case split(halves: [AbyssHalfReport], plans: [AbyssFloorPlan])
    }

    var id: Int { floor }

    let floor: Int
    let monsterLevel: Int
    /// Buffs in force for the whole floor. On a split floor that is the ones
    /// both halves share — a half's own are on `AbyssHalfReport`.
    let buffs: [AbyssFloorBuff]
    let shieldElements: [GenshinElement]
    /// Elements the floor's enemies resist less than the 10% baseline.
    let weakElements: [GenshinElement]
    let outcome: Outcome

    /// Every team this report puts forward, however the floor was planned. For
    /// callers that only want to count characters or check a roster — anything
    /// that does not care which half a team is for.
    var allTeams: [AbyssTeamResult] {
        switch outcome {
        case .whole(let teams): return teams
        case .split(_, let plans): return plans.flatMap { [$0.firstHalf, $0.secondHalf] }
        }
    }

    /// Ranked teams for the floor fought as one, or `nil` when it was planned as
    /// two halves.
    ///
    /// Optional, not empty. "No team was found" and "this floor has no such
    /// thing as a team for the whole of it" are different answers, and an empty
    /// array said both. A caller that unwraps this is stating which shape it
    /// expects, which is what the old `teams` array let it skip.
    var wholeFloorTeams: [AbyssTeamResult]? {
        if case .whole(let teams) = outcome { return teams }
        return nil
    }

    /// Ranked plans — a team per half, sharing nobody — or `nil` when the floor
    /// was fought as one.
    var halfPlans: [AbyssFloorPlan]? {
        if case .split(_, let plans) = outcome { return plans }
        return nil
    }

    /// The two halves a split floor was planned against, or `nil`.
    var halves: [AbyssHalfReport]? {
        if case .split(let halves, _) = outcome { return halves }
        return nil
    }
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

/// What one run of the optimiser produced.
///
/// `Codable`, and that conformance is load-bearing rather than incidental: this
/// is what `AbyssSearchCacheStore` persists so a search does not have to be
/// re-run every time the tab is opened. Every type this contains had to grow
/// the same conformance — see `AbyssSearchCache` for why that is safe (the
/// search is a pure function of its inputs) and what is deliberately not
/// captured by the cache key.
struct AbyssOptimizerOutput: Sendable, Codable {
    let reports: [AbyssFloorReport]
    let consideredCharacterIDs: [String]
    /// Ids in the roster that no longer exist in the data — surfaced so a
    /// renamed character shows up as a warning instead of quietly shrinking
    /// the pool.
    let unknownRosterIDs: [String]
}
