// AbyssCharacterKit.swift
//
// Decodable mirror of `Resources/Abyss/character-kits.json`: what the engine
// knows about one particular character that no game file states — how the kit
// is *played* — in one record.
//
// The file has two ancestors. `character-traits.json` (2026-09-12) gathered
// forty-eight per-character facts that had spread across three files in seven
// shapes, six of them read without ever checking the character existed, so a
// typo removed a mechanic in silence. Phase 1 of `docs/redesign.md` then put
// every talent multiplier in `talent-params.json`, straight from the game, and
// found the one thing the game's tables cannot say: which of their rows one
// cast actually deals. "Press DMG" and "Charge Level 2 DMG" are both in
// Bennett's skill table and a cast is one of them; Raiden's burst table lists
// a combo that replaces her normal attacks; Hu Tao's skill turns Max HP into
// ATK and nothing in a multiplier table can express that. Those are kit facts,
// and this file is where kit facts live.
//
// Every number here is either a *reference* into `talent-params.json` — a row
// label or a param index, read at the character's real talent level — or a
// literal from a passive's text, and every subjective choice (which stance,
// how many stacks, what uptime) carries a `note` saying how it was arrived at.
// A reference that no longer resolves is reported to `AbyssParseDiagnostics`
// and pinned empty by `AbyssCharacterKitTests`, so a renamed row is a red test
// rather than a character quietly losing half their damage.
//
// What is deliberately *not* here: assumptions that apply to every character.
// `rotationSeconds`, `conditionalUptime` and the artifact set estimates are
// claims about how the planner models a rotation, not claims about anybody,
// and they stay in `tuning.json`. The dividing line is whether the sentence
// names a character.

import Foundation

/// One character's entry. Every field is optional: most characters have a tag
/// and nothing else, and a character with no entry at all is the normal case —
/// they are read by `AbyssTalentReader`'s general rules.
struct AbyssCharacterKit: Decodable, Sendable, Identifiable {
    /// Something a character simply *is*, which some other file's rules then key
    /// off. The rule stays where it was — Moonsign's levels are still in
    /// `team-bonus.json` — because a rule changes with a game version and a
    /// roster changes with every banner.
    enum Tag: String, Decodable, Sendable, CaseIterable {
        case moonsign
        case hexerei
        /// Upgrades Swirl and Superconduct to their Stellar variants.
        case stellarJubilee = "stellar-jubilee"
    }

    /// Labels that name a charged attack the reader's generic vocabulary cannot
    /// see — "Frostflake Arrow", "Equitable Judgment".
    ///
    /// Listed per character rather than folded into a wider regex on purpose:
    /// deciding whether "Frostflake Arrow" is a charged attack or a normal one
    /// is knowledge about the game, not a rule about words, and getting it wrong
    /// moves a character's damage between two buckets the floor buffs treat
    /// differently.
    struct ChargedAttackLabels: Decodable, Sendable {
        let labels: [String]
        let note: String
    }

    // MARK: - Hits

    /// The four things the damage model counts, each once per rotation-shaped
    /// unit: a skill cast, a burst cast, one normal-attack string, one charged
    /// attack. A kit may replace what the reader infers for any of them.
    enum HitSlot: String, Decodable, Sendable, CaseIterable {
        case skill, burst, combo, charged

        /// The talent a reference in this slot reads from unless it says
        /// otherwise, and the bucket its damage lands in.
        var defaultTalent: AbyssTalentParams.Key {
            switch self {
            case .skill: return .elementalSkill
            case .burst: return .elementalBurst
            case .combo, .charged: return .normalAttack
            }
        }

        var defaultCategory: HitCategory {
            switch self {
            case .skill: return .skill
            case .burst: return .burst
            case .combo: return .normal
            case .charged: return .charged
            }
        }
    }

    /// One row of `talent-params.json`, or one raw param of it, counted some
    /// number of times.
    ///
    /// `label` names a row exactly as the game prints it ("Musou no Hitotachi
    /// Base DMG"); the expression on that row is read by the same grammar as
    /// everything else, so `{p1}+{p2}` adds and `{a}/{b}` takes the stronger.
    /// `param` names one placeholder by index for the rows the grammar refuses
    /// on purpose — a per-stack rate like Raiden's "Resolve Bonus", which is a
    /// hit only once a kit says how many stacks. `factor` multiplies by another
    /// talent's param, for the rows that are a share of a different hit
    /// ("Blazing Arrow DMG|{p} Normal Attack DMG").
    struct HitReference: Decodable, Sendable {
        struct Factor: Decodable, Sendable {
            let talent: AbyssTalentParams.Key
            let param: Int
        }

        /// Which of the three talent tables. Defaults to the slot's own.
        let talent: AbyssTalentParams.Key?
        let label: String?
        let param: Int?
        /// The stat a bare `param` scales off. Only meaningful with `param`; a
        /// labelled row carries its own suffix. Defaults to ATK, as the game
        /// does when it writes nothing.
        let basis: ScalingBasis?
        /// Times this row lands per unit. Defaults to once. Fractional is
        /// allowed and means "on average" — say so in the note.
        let count: Double?
        /// The bucket the damage counts in. Defaults to the slot's own; a
        /// stance combo the game calls "Elemental Burst DMG" (Raiden's Musou
        /// Isshin) says `burst` here even though it sits in the `combo` slot.
        let category: HitCategory?
        let factor: Factor?
    }

    /// Per-slot overrides. A slot that is present replaces the reader's whole
    /// inference for that slot — an empty list means "nothing", which is what
    /// a character who cannot charge in their stance (Xilonen) needs to say.
    /// A slot that is absent is read as usual.
    struct Hits: Decodable, Sendable {
        let skill: [HitReference]?
        let burst: [HitReference]?
        let combo: [HitReference]?
        let charged: [HitReference]?
        let note: String

        subscript(slot: HitSlot) -> [HitReference]? {
            switch slot {
            case .skill: return skill
            case .burst: return burst
            case .combo: return combo
            case .charged: return charged
            }
        }
    }

    // MARK: - Stats

    /// A stat this character turns into ATK: Hu Tao's Paramita Papilio ("ATK
    /// Increase|{p} Max HP"), Noelle's Sweeping Time ("ATK Bonus|{p} DEF").
    ///
    /// Only the row is named; which stat it converts *from* is the suffix the
    /// game wrote on it, so the file cannot say HP where the game says DEF.
    /// The rate lands on the stat sheet as a conversion rather than a number,
    /// so the substat search sees that HP is worth ATK to this character
    /// instead of being told so.
    struct Conversion: Decodable, Sendable {
        let talent: AbyssTalentParams.Key
        let label: String
        /// Share of the character's counted hits that happen with the
        /// conversion active. For a stance that *is* the character's damage
        /// window, 1 — the field-time question is Phase 3's.
        let uptime: Double
        let note: String
    }

    /// A buff a talent grants — to the party or to the character themself —
    /// and how to read it.
    ///
    /// The *number* is not here for a levelled talent: it is read out of
    /// `talent-params.json` by `label`, so a corrected value reaches the model
    /// without anyone editing this file. A passive has no table, so a passive's
    /// number is a `value` literal with the text quoted in the note. What is
    /// always here is the part no rule can infer — that "ATK Bonus Ratio" on
    /// Bennett's burst is a share of *his* Base ATK handed to everyone as flat
    /// ATK, and that Xiao's "Normal/Charged/Plunging Attack DMG Bonus" is his
    /// own.
    struct Buff: Decodable, Sendable {
        enum Scope: String, Decodable, Sendable { case party, `self` }

        enum Kind: String, Decodable, Sendable {
            /// Party: the value is a share of the caster's Base ATK, handed to
            /// every member as flat ATK.
            case flatATKFromBaseATK = "flat-atk-from-base-atk"
            /// Party: a DMG bonus for the caster's own element.
            case elementalDMG = "elemental-dmg"
            /// Self: one slot of the caster's own sheet, named by `stat` with
            /// an `AbyssStatField.tuningKey`, or `elemental_dmg` for the
            /// caster's own element.
            case stat
        }

        let scope: Scope
        let kind: Kind
        let stat: String?
        let talent: AbyssTalentParams.Key?
        /// The exact row to read the number from. Exact, not a pattern: this
        /// names one row, and a rename should be reported rather than guessed
        /// around.
        let label: String?
        /// A literal, for passives. Refused when `label` is also given.
        let value: Double?
        /// Share of a rotation the buff is actually up. The most subjective
        /// number here; each entry's `note` says how it was arrived at.
        let uptime: Double
        let note: String
    }

    /// Enemy elemental resistance this character strips.
    ///
    /// Its counterpart in `tuning.json` is conditioned on a team *element*
    /// standing in for an artifact set nobody has chosen yet; this one is
    /// conditioned on the character being present, which is a fact rather than
    /// an assumption. The amount is a row of the talent table when the game
    /// has one (`label`), a literal otherwise.
    struct ResistanceShred: Decodable, Sendable {
        /// `GenshinElement` raw values, or `AbyssResistanceShredScope.swirled`.
        let elements: [String]
        let talent: AbyssTalentParams.Key?
        let label: String?
        let value: Double?
        let uptime: Double
        let note: String
    }

    /// How much this character adds to the *base damage* of a Lunar or Stellar
    /// reaction just by being on the team.
    ///
    /// `reactions` is an explicit list, which is the whole improvement over the
    /// column it replaces: that one was free text (`"Lunar-Charged/Bloom/
    /// Crystallize"`, `"Stellar-Conduct, Stellar Swirl"`) and the engine never
    /// read it, so every source raised every Lunar and Stellar reaction. Lauma
    /// raises Lunar-Bloom and was paying for teams' Stellar-Conduct.
    struct ReactionBaseDamageBonus: Decodable, Sendable {
        /// `AbyssReaction` raw values.
        let reactions: [String]
        let value: Double
    }

    // MARK: - Energy

    /// What a particle count needs to become energy per rotation, beyond the
    /// wiki note in `particles.json`.
    struct Energy: Decodable, Sendable {
        enum Variant: String, Decodable, Sendable { case press, hold }

        /// Which of the note's two numbers the kit plays. Defaults to press.
        let variant: Variant?
        /// For a per-event note ("each of Oz's attacks"), how many such events
        /// one cast produces within a rotation. Also multiplies a numeric note
        /// whose number turns out to be per hit (Yae Miko's turrets).
        let eventsPerCast: Double?
        /// A literal count, for a page with no note. Replaces the note.
        let particlesPerCast: Double?
        /// Overrides `min(maxSkillCastsPerRotation, rotationSeconds / cooldown)`
        /// — for a skill that opens a window used once per rotation.
        let skillCastsPerRotation: Double?
        /// Defaults to `caster`.
        let collectedBy: AbyssEnergyProfile.Collector?
        let note: String
    }

    /// The talent whose window a character's attack string lives in.
    struct Stance: Decodable, Sendable {
        let talent: AbyssTalentParams.Key
        let note: String
    }

    var id: String { characterId }

    let characterId: String
    let tags: [Tag]?
    let chargedAttackLabels: ChargedAttackLabels?
    let hits: Hits?
    let conversions: [Conversion]?
    let buffs: [Buff]?
    let resistanceShred: [ResistanceShred]?
    let reactionBaseDamageBonus: [ReactionBaseDamageBonus]?
    let energy: Energy?
    let stance: Stance?

    func has(_ tag: Tag) -> Bool { tags?.contains(tag) ?? false }

    /// Whether the entry claims anything at all. An entry that carries nothing
    /// is a character listed for no reason, which is how a file like this
    /// rots: it stops being a claim and becomes a list.
    var isEmpty: Bool {
        (tags ?? []).isEmpty && chargedAttackLabels == nil && hits == nil
            && (conversions ?? []).isEmpty && (buffs ?? []).isEmpty
            && (resistanceShred ?? []).isEmpty && (reactionBaseDamageBonus ?? []).isEmpty
            && energy == nil && stance == nil
    }
}

/// The whole file.
struct AbyssCharacterKitsFile: Decodable, Sendable {
    let kits: [AbyssCharacterKit]
}

/// The token a resistance-shred entry uses to mean "every element this team can
/// swirl" rather than one named element. Shared by both files that carry shred
/// entries, so the two cannot drift apart on the spelling.
enum AbyssResistanceShredScope {
    static let swirled = "swirled"
}
