// AbyssTuning.swift
//
// Decodable mirror of `Resources/Abyss/tuning.json`.
//
// These are the planner's assumptions, not game data — rotation length, the
// substat budget, energy rules. Buff uptimes and artifact set effects used to
// be here too, as a flat 60% and a hand-estimated %DMG per set; since Phase 5
// they are read from the game text (`passives.json`) and timed by
// `AbyssBuffTimeline`. Every number that decides a
// recommendation lives in that file rather than in this code, so changing an
// assumption is a data edit with the reasoning next to it.
//
// The file's `notes` object explains why each number has the value it does;
// that prose is load-bearing and is why the values live in JSON with a notes
// field rather than as bare Swift constants.

import Foundation

struct AbyssTuning: Decodable, Sendable {
    struct Energy: Decodable, Sendable {
        /// Energy one particle of the receiver's own element restores. A rule.
        let sameElementParticle: Double
        /// Energy one particle of another element restores. A rule.
        let otherElementParticle: Double
        /// Energy one clear (elementless) particle restores. A rule.
        let clearParticle: Double
        /// Share of a particle's energy an off-field character receives. A rule.
        let offFieldShare: Double
        /// Clear particles enemies drop per rotation. An assumption, and zero
        /// on purpose until Phase 6 knows how long a chamber takes.
        let enemyClearParticlesPerRotation: Double
        /// The most skill casts a rotation holds, whatever the cooldown. An
        /// assumption standing in for field time — see `notes.energy`.
        let maxSkillCastsPerRotation: Double
    }

    let artifactMainStats: [String: Double]
    let substatRollValue: [String: Double]
    let substatRollBudget: Double
    /// Role -> substat key -> share of the roll budget. Shares sum to 1.
    let substatPriority: [String: [String: Double]]
    /// Scaling basis -> substat key to redirect -> substat key to redirect it to.
    let scalingBasisSwap: [String: [String: String]]
    let rotationSeconds: Double
    /// Seconds a swap costs on top of the cast it is for. An assumption — see
    /// `notes.swapSeconds`.
    let swapSeconds: Double
    /// Energy rules and the one energy assumption — see `notes.energy`.
    let energy: Energy
    /// One source of enemy elemental resistance reduction.
    ///
    /// The channel the model never had. `resMultiplier` has always had a
    /// negative branch — below zero the resistance is only halved, so stripping
    /// resistance keeps paying where a DMG bonus saturates — and nothing in the
    /// model could ever push it there. Kazuha, Venti, Sucrose, Faruzan and
    /// Shenhe are mostly *this*, and without it they were close to invisible.
    struct ResistanceShred: Decodable, Sendable {
        let id: String
        /// The team must contain this element.
        ///
        /// An element, not a character, because these two entries are artifact
        /// sets: nothing has chosen who wears what at the point a team context
        /// is built, and in practice an Anemo support wears Viridescent Venerer.
        /// That makes them assumptions rather than facts, which is why they stay
        /// in this file while Faruzan's and Shenhe's live in
        /// `character-kits.json`.
        let requiresElement: GenshinElement?
        /// `GenshinElement` raw values, or `AbyssResistanceShredScope.swirled`.
        let elements: [String]
        let value: Double
        let uptime: Double
        let note: String
    }

    /// Resistance reduction the model credits to an artifact set the planner
    /// assumes somebody is wearing. The character-borne sources are in
    /// `character-kits.json`.
    let resistanceShred: [ResistanceShred]
    /// Where on the Stellar-Conduct coefficient ramp to sit, 0 for its minimum
    /// and 1 for its maximum. An assumption: the real coefficient climbs with
    /// the Cryo/Electro hits recorded before the reaction and the model does not
    /// count hits.
    let stellarConductRamp: Double
    /// What an enemy resists its *own* element at — the one it attacks or
    /// shields with. An inference, not data: see this key's note in
    /// `tuning.json` for where the number comes from and how to switch it off.
    let enemyOwnElementResistance: Double
    let noSustainPenalty: Double
    let shieldBreakBonus: Double
    let weaknessExploitBonus: Double

    func mainStat(_ key: String) -> Double { artifactMainStats[key] ?? 0 }
    func rollValue(_ key: String) -> Double { substatRollValue[key] ?? 0 }
}
