// AbyssEnemyHP.swift
//
// How much HP an Abyss fight holds, Phase 6 of `docs/redesign.md`: what turns
// a team's damage per second into the time it takes to clear a half.
//
// A monster's HP is its wiki `hp_ratio` × `enemy-hp.json`'s table at its
// level × the floor's Spiral Abyss multiplier, times how many of it spawn —
// all written by `scripts/sync-abyss-monster-hp.py`, which checks the table
// against the game's own HP curves. A fight with any monster the script could
// not resolve has no HP rather than a guessed one.

import Foundation

/// Decodable mirror of `Resources/Abyss/enemy-hp.json`.
struct AbyssEnemyHPTable: Decodable, Sendable {
    /// Scaling type -> HP at levels 1, 2, 3…
    let types: [String: [Double]]

    /// HP of one monster, or nil when its type or level is not in the table.
    func hp(ratio: Double, type: String, level: Int) -> Double? {
        guard let levels = types[type], level >= 1, level <= levels.count else { return nil }
        return ratio * levels[level - 1]
    }
}

extension AbyssCycle.Monster {
    /// Everything this monster puts into its fight at `level` on a floor with
    /// `multiplier`, or nil when the data does not say.
    func totalHP(level: Int?, multiplier: Double?, table: AbyssEnemyHPTable?) -> Double? {
        guard let level, let multiplier, let table, let spawns, let hp,
              let one = table.hp(ratio: hp.ratio, type: hp.type, level: level) else { return nil }
        return one * multiplier * Double(spawns)
    }
}
