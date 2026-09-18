// AbyssEnergy.swift
//
// Energy, Phase 3 of `docs/redesign.md`: how often a burst is actually up.
//
// Until this file every burst in the model was cast once per rotation, and
// the only concession to cooldowns was a flat `offFieldUptime = 0.85` on
// every off-field character's skill and burst alike. That made Energy
// Recharge worth exactly nothing to the score — so the search was forbidden
// from taking the Energy Recharge sands off a support, because it would have
// done so every time and called it an improvement.
//
// Three inputs replace the constant, each from a source rather than a guess:
// cooldowns and burst costs from the game's own tables (`talent-params.json`),
// particle counts from the Genshin Impact wiki (`particles.json`, cross-checked
// against gcsim's character code), and the per-character facts neither
// states — how many Oz attacks one cast is, whether particles land on the
// caster or on whoever is on field — from `character-kits.json` → `energy`.

import Foundation

/// Decodable mirror of `Resources/Abyss/particles.json`: the wiki's particle
/// note for each character's Elemental Skill, verbatim, with its reading.
struct AbyssParticles: Decodable, Sendable {
    struct Reading: Decodable, Sendable {
        struct PerEvent: Decodable, Sendable {
            let event: String
            let count: Double
        }

        /// Particles per press. Present for the numeric shapes.
        let press: Double?
        /// Particles per hold, when the note gives a second number.
        let hold: Double?
        /// Particles per *event* — "each of Oz's attacks" — when the note names
        /// one. How many events one cast is lives in the character's kit.
        let perEvent: PerEvent?
    }

    struct Character: Decodable, Sendable {
        let page: String
        let revid: Int
        /// The template's parameters verbatim, for audit.
        let notes: [[String]]
        /// Empty when the page carries no particle note.
        let readings: [Reading]
    }

    let characters: [String: Character]
}

/// Decodable mirror of `Resources/Abyss/frames.json`: gcsim's frame counts.
struct AbyssFrames: Decodable, Sendable {
    struct Character: Decodable, Sendable {
        let gcsim: String
        /// Frames from each normal-attack hit to the next.
        let comboFrames: [Int]?
        /// Frames from a charged attack to the next normal attack.
        let chargedFrames: Int?
        /// Frames until the character can swap out after a skill or burst.
        let skillFrames: Int?
        let burstFrames: Int?
    }

    let characters: [String: Character]
}

/// One character's energy economy, resolved once at load: everything about it
/// that does not depend on who else is in the team or on anybody's gear.
struct AbyssEnergyProfile: Sendable, Equatable {
    /// Who receives a particle at full value. Everyone else in the party
    /// receives `offFieldShare` of it — that part is a game rule.
    enum Collector: String, Sendable, Equatable, Decodable {
        /// The skill's particles arrive while the caster is still on field: an
        /// instant skill, or attacks the caster makes themselves.
        case caster
        /// They arrive while somebody else is on field: a summon or turret
        /// (Oz, Guoba, the Eye of Stormy Judgment).
        case field
    }

    /// Which talent gates this character's own attack string: Raiden's and
    /// Cyno's normal attacks in the model are the burst's, and exist only
    /// while it is up.
    enum Window: Sendable, Equatable {
        case none, burst, skill
    }

    /// What a character does with their time on field. Combo strings and
    /// string-plus-charged are open to everyone; charged attacks alone only to
    /// a bow (aimed shots cost no stamina) or a character whose kit says so
    /// (Neuvillette). A kit can also close the loops to one.
    struct AttackLoops: Sendable, Equatable {
        var combo: Bool
        var mixed: Bool
        var charged: Bool
    }

    let element: GenshinElement
    /// Particles this character's skill generates in one rotation.
    let particlesPerRotation: Double
    let collector: Collector
    /// Skill casts in one rotation: `min(maxSkillCastsPerRotation,
    /// rotationSeconds / cooldown)` unless the kit says otherwise.
    let skillCastsPerRotation: Double
    /// Zero for a burst that costs no Energy (Mavuika's Fighting Spirit).
    let burstCost: Double
    /// The most bursts one rotation can hold, energy aside:
    /// `min(1, rotationSeconds / cooldown)`.
    let burstCastsCap: Double
    let window: Window
    /// Seconds one normal-attack string takes, one charged attack, and a skill
    /// or burst cast until the character can swap out — gcsim's frames, or the
    /// median of every character that has them (`framesEstimated`).
    let comboSeconds: Double
    let chargedSeconds: Double
    let skillSeconds: Double
    let burstSeconds: Double
    /// Which attack loops this character's time on field can be spent on.
    let attackLoops: AttackLoops
    /// True when the particle count is the median of every resolved character
    /// rather than this character's own — see
    /// `AbyssParseDiagnostics.particlesEstimated`.
    let isEstimated: Bool
}
