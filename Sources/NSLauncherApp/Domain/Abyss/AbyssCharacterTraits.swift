// AbyssCharacterTraits.swift
//
// Decodable mirror of `Resources/Abyss/character-traits.json`: everything the
// engine needs to know about one particular character, in one record.
//
// This file exists because of how the other files grew. Forty-eight facts about
// individual characters had accumulated across three files in seven shapes —
// `tuning.json` held four tables, `team-bonus.json` two flat id lists, and
// `damage-formula.json` one more — and each new character meant editing three of
// them in three different ways. Worse, only one of the seven was checked at
// load: a mistyped id in the other six removed a mechanic in silence, because a
// character who is not in a list and a character the list does not apply to look
// identical from the inside.
//
// So the axis was wrong. These tables are not "tuning" or "team bonus" or
// "damage formula"; they are *per character*, which is the thing that grows
// every six weeks. Keyed by character, they are one edit per release and one
// validation pass over the lot.
//
// What is deliberately *not* here: assumptions that apply to every character.
// `rotationSeconds`, `conditionalUptime` and the artifact set estimates are
// claims about how the planner models a rotation, not claims about anybody, and
// they stay in `tuning.json`. The dividing line is whether the sentence names a
// character.

import Foundation

/// One character's entry. Every field is optional: most characters have a tag
/// and nothing else, and a character with no entry at all is the normal case.
struct AbyssCharacterTraits: Decodable, Sendable, Identifiable {
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

    /// Labels that name a charged attack the parser's generic vocabulary cannot
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

    /// A party-wide buff this character's talents grant, and how to read it.
    ///
    /// The *number* is not here: it is read out of the character's own talent
    /// table by `label`, so a corrected talent value reaches the model without
    /// anyone editing this file. What is here is the part no rule can infer —
    /// "ATK Bonus: 100.8% Base ATK" (a flat buff for the whole party) and "ATK
    /// Bonus (%DEF): 103.7%" (the caster converting their own DEF) are the same
    /// three words, and `AbyssTextParser`'s damage filter drops both because
    /// neither is a damage instance.
    struct PartyBuff: Decodable, Sendable {
        enum Talent: String, Decodable, Sendable { case skill, burst }

        enum Kind: String, Decodable, Sendable {
            /// The value is a share of the caster's Base ATK, handed to every
            /// member as flat ATK.
            case flatATKFromBaseATK = "flat-atk-from-base-atk"
            /// The value is a DMG bonus for the caster's own element, party-wide.
            case elementalDMG = "elemental-dmg"
        }

        let talent: Talent
        /// The exact scaling label to read the number from. Exact, not a
        /// pattern: this names one row, and a rename should be reported rather
        /// than guessed around.
        let label: String
        let kind: Kind
        /// Which percentage on that row, for the rows that carry two.
        let valueIndex: Int?
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
    /// an assumption.
    struct ResistanceShred: Decodable, Sendable {
        /// `GenshinElement` raw values, or `AbyssResistanceShredScope.swirled`.
        let elements: [String]
        let value: Double
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

    var id: String { characterId }

    let characterId: String
    let tags: [Tag]?
    let chargedAttackLabels: ChargedAttackLabels?
    let partyBuffs: [PartyBuff]?
    let resistanceShred: [ResistanceShred]?
    let reactionBaseDamageBonus: [ReactionBaseDamageBonus]?

    func has(_ tag: Tag) -> Bool { tags?.contains(tag) ?? false }
}

/// The whole file.
struct AbyssCharacterTraitsFile: Decodable, Sendable {
    let traits: [AbyssCharacterTraits]
}

/// The token a resistance-shred entry uses to mean "every element this team can
/// swirl" rather than one named element. Shared by both files that carry shred
/// entries, so the two cannot drift apart on the spelling.
enum AbyssResistanceShredScope {
    static let swirled = "swirled"
}
