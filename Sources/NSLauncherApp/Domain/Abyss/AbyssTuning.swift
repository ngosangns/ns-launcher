// AbyssTuning.swift
//
// Decodable mirror of `Resources/Abyss/tuning.json`.
//
// These are the planner's assumptions, not game data — rotation length, buff
// uptimes, and a hand-written approximation of the artifact set effects that
// were too conditional to extract mechanically. The Python reference reads the
// same file, so tweaking a number there changes both implementations and they
// cannot drift apart on the values that decide every recommendation.
//
// The file's `notes` object explains why each number has the value it does;
// that prose is load-bearing and is why the values live in JSON with a notes
// field rather than as bare Swift constants.

import Foundation

struct AbyssTuning: Decodable, Sendable {
    /// Effective %DMG credited to a 4-piece set whose real effect is too
    /// conditional to read off the data (stacking, HP thresholds, scaling from
    /// another stat). Hand-estimated — the most subjective input in the model.
    struct SetEffectApproximation: Decodable, Sendable {
        enum Requirement: String, Decodable, Sendable {
            /// Needs a Natlan character (Nightsoul's Blessing).
            case natlan
            /// Needs a Moonsign character.
            case moonsign
            /// Needs an element that takes part in Stellar Glimmer reactions.
            case stellar
        }

        let setId: String
        let note: String
        let damageBonus: Double
        let scope: HitCategoryScope
        let requirement: Requirement?
        /// The effect reaches the whole party, not just the wearer. Routed to
        /// `partyDMG` and, like every other party buff from a set, counted once
        /// however many members wear it.
        let party: Bool?
    }

    /// Which damage bucket a set approximation applies to. `all` is a separate
    /// case rather than a `HitCategory`, because it means "every category".
    enum HitCategoryScope: String, Decodable, Sendable {
        case all, normal, charged, skill, burst

        var statField: AbyssStatField {
            switch self {
            case .all: return .dmgAll
            case .normal: return .dmgNormal
            case .charged: return .dmgCharged
            case .skill: return .dmgSkill
            case .burst: return .dmgBurst
            }
        }
    }

    /// A party-wide buff one character's talents grant, and how to read it.
    ///
    /// The *number* is not here: it is read out of the character's own talent
    /// table by `label`, so a corrected talent value reaches the model without
    /// anyone editing this file. What is here is the part no rule can infer —
    /// "ATK Bonus: 100.8% Base ATK" (a flat buff for the whole party) and "ATK
    /// Bonus (%DEF): 103.7%" (the caster converting their own DEF) are the same
    /// three words, and `AbyssTextParser`'s damage filter drops both because
    /// neither is a damage instance.
    struct TalentPartyBuff: Decodable, Sendable {
        enum Talent: String, Decodable, Sendable { case skill, burst }

        enum Kind: String, Decodable, Sendable {
            /// The value is a share of the caster's Base ATK, handed to every
            /// member as flat ATK.
            case flatATKFromBaseATK = "flat-atk-from-base-atk"
            /// The value is a DMG bonus for the caster's own element, party-wide.
            case elementalDMG = "elemental-dmg"
        }

        let characterId: String
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

    let artifactMainStats: [String: Double]
    let substatRollValue: [String: Double]
    let substatRollBudget: Double
    /// Role -> substat key -> share of the roll budget. Shares sum to 1.
    let substatPriority: [String: [String: Double]]
    /// Scaling basis -> substat key to redirect -> substat key to redirect it to.
    let scalingBasisSwap: [String: [String: String]]
    let rotationSeconds: Double
    let normalCombosPerRotation: Double
    /// Charged attacks the on-field character makes in one rotation. Far fewer
    /// than normal combos: a charged attack costs stamina and takes about a
    /// second, and most characters use one only to break a shield or to trigger
    /// an ability.
    let chargedAttacksPerRotation: Double
    let offFieldUptime: Double
    let conditionalUptime: Double
    let assumedStacks: Double
    let amplifyingUptime: Double
    /// Transformative reactions per rotation. The most subjective number in the
    /// file: transformative damage ignores ATK, DMG bonus, CRIT and enemy DEF,
    /// so the frequency — not the formula — is what decides where reaction teams
    /// rank. See `notes.transformativeReactionsPerRotation`.
    let transformativeReactionsPerRotation: Double
    let noSustainPenalty: Double
    let shieldBreakBonus: Double
    let weaknessExploitBonus: Double
    let stellarJubileeCharacterIds: [String]
    let setEffectApprox: [SetEffectApproximation]
    let talentPartyBuff: [TalentPartyBuff]

    func mainStat(_ key: String) -> Double { artifactMainStats[key] ?? 0 }
    func rollValue(_ key: String) -> Double { substatRollValue[key] ?? 0 }
}
