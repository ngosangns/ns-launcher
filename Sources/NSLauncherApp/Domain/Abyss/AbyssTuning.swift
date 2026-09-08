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

    let artifactMainStats: [String: Double]
    let substatRollValue: [String: Double]
    let substatRollBudget: Double
    /// Role -> substat key -> share of the roll budget. Shares sum to 1.
    let substatPriority: [String: [String: Double]]
    /// Scaling basis -> substat key to redirect -> substat key to redirect it to.
    let scalingBasisSwap: [String: [String: String]]
    let rotationSeconds: Double
    let normalCombosPerRotation: Double
    let offFieldUptime: Double
    let conditionalUptime: Double
    let assumedStacks: Double
    let amplifyingUptime: Double
    let noSustainPenalty: Double
    let shieldBreakBonus: Double
    let weaknessExploitBonus: Double
    let stellarJubileeCharacterIds: [String]
    let setEffectApprox: [SetEffectApproximation]

    func mainStat(_ key: String) -> Double { artifactMainStats[key] ?? 0 }
    func rollValue(_ key: String) -> Double { substatRollValue[key] ?? 0 }
}
