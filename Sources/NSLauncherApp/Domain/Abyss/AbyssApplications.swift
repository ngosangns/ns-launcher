// AbyssApplications.swift
//
// How often each character applies their element, Phase 4 of
// `docs/redesign.md`: the count reactions are priced from, in place of a flat
// `amplifyingUptime` on every hit and `transformativeReactionsPerRotation` for
// every team.
//
// Built from `gauge.json` (Yatta's per-hit gauge and internal cooldown), the
// character's timings (`frames.json`), their kit (summons' event counts, which
// attacks are infused) and the talent tables' durations. Nothing here depends
// on gear or on the team.

import Foundation

/// Decodable mirror of `Resources/Abyss/gauge.json`.
struct AbyssGauge: Decodable, Sendable {
    struct Row: Decodable, Sendable {
        let name: String
        let units: Double
        let icdTag: String?
        let icdRule: String?
        let icdHits: Int?
        let icdSeconds: Double?
    }

    struct Character: Decodable, Sendable {
        let normalAttack: [Row]
        let elementalSkill: [Row]
        let elementalBurst: [Row]
    }

    let characters: [String: Character]
}

/// One character's element applications per action, gauge-weighted.
struct AbyssApplicationProfile: Sendable, Equatable {
    struct Action: Sendable, Equatable {
        /// Hits the action lands on an enemy.
        var hits: Double = 0
        /// Of those, how many apply the character's element, after internal
        /// cooldown.
        var applications: Double = 0
        /// `applications` weighted by each hit's gauge units.
        var units: Double = 0

        /// Share of the action's hits that can react.
        var applyingShare: Double { hits > 0 ? min(1, applications / hits) : 0 }

        static let none = Action()
    }

    /// Per normal-attack string, per charged attack, per skill cast, per burst
    /// cast.
    var combo = Action.none
    var charged = Action.none
    var skill = Action.none
    var burst = Action.none

    static let none = AbyssApplicationProfile()
}

enum AbyssApplicationCounting {
    /// Applications from `hits` hits under one internal cooldown group spread
    /// over `seconds`: the element lands on the first hit, then on every
    /// `hitsPerApplication`-th hit or once `secondsPerApplication` have passed,
    /// whichever comes first — the game's rule, written as a count.
    static func applications(hits: Double, hitsPerApplication: Int?, secondsPerApplication: Double?,
                             seconds: Double) -> Double {
        guard hits > 0 else { return 0 }
        var count = 0.0
        if let everyHits = hitsPerApplication, everyHits > 0 { count = (hits / Double(everyHits)).rounded(.up) }
        if let everySeconds = secondsPerApplication, everySeconds > 0 {
            count = max(count, 1 + (seconds / everySeconds).rounded(.down))
        }
        if hitsPerApplication == nil, secondsPerApplication == nil { count = hits }
        return min(hits, max(count, 1))
    }

    /// Rows that are a hit on an enemy, and whose element this character
    /// applies: a positive gauge, and not a self aura, a constellation or
    /// passive extra ("(C4)", "(A1)"), a plunge or a knockback.
    static func isHit(_ row: AbyssGauge.Row) -> Bool {
        guard row.units > 0 else { return false }
        let name = row.name
        for marker in ["Self", "(C", "(A1", "(A4", "Plunge", "Knockback", "Shield", "Weak Spot"] where name.contains(marker) {
            return false
        }
        return true
    }

    /// A group of consecutive rows sharing one cooldown tag, as one pool of hits.
    private struct Group {
        var hits = 0.0
        var units = 0.0
        var hitsPerApplication: Int?
        var secondsPerApplication: Double?
    }

    private static func groups(_ rows: [AbyssGauge.Row]) -> [Group] {
        var result: [Group] = []
        var lastTag: String??
        for row in rows {
            let tag = row.icdTag
            if tag != nil, lastTag == .some(tag), !result.isEmpty {
                result[result.count - 1].hits += 1
                result[result.count - 1].units += row.units
            } else {
                result.append(Group(hits: 1, units: row.units,
                                    hitsPerApplication: row.icdHits, secondsPerApplication: row.icdSeconds))
            }
            lastTag = .some(tag)
        }
        return result
    }

    static func action(_ rows: [AbyssGauge.Row], seconds: Double) -> AbyssApplicationProfile.Action {
        var action = AbyssApplicationProfile.Action()
        for group in groups(rows) {
            let applications = Self.applications(hits: group.hits, hitsPerApplication: group.hitsPerApplication,
                                                 secondsPerApplication: group.secondsPerApplication,
                                                 seconds: seconds)
            action.hits += group.hits
            action.applications += applications
            action.units += applications * group.units / group.hits
        }
        return action
    }
}
