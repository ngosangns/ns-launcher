// AbyssCycleHistory.swift
//
// A short local log of past cycles' best plan, kept only to answer "how did
// last cycle's suggestion compare" — not a leaderboard, not a claim that two
// cycles are the same fight. The roster, the gear and the monsters can all
// change between entries, so a reader compares these across time at their own
// risk; the UI that shows this says so next to the number.

import Foundation

/// One rotation's best plan for one floor.
struct AbyssCycleHistoryEntry: Codable, Sendable, Equatable {
    /// The same field `AbyssSearchCacheKey.cyclePeriodStart` keys a search
    /// cache by — the rotation this entry's plan was searched against, not a
    /// separately invented id.
    let cyclePeriodStart: String
    let computedAt: Date
    let floor: Int
    /// The top plan's score for this floor — the model's per-second ranking
    /// unit, not a real damage number. See `AbyssTeamResult.score`.
    let bestScore: Double
    /// Seconds the top plan is estimated to clear this floor in, when the
    /// enemy HP needed to compute it was available.
    let bestClearTimeSeconds: Double?
    let teamMemberIDs: [String]
}

/// A short log, newest first, capped by `AbyssCycleHistoryStore.maxEntries`.
struct AbyssCycleHistory: Codable, Sendable {
    var entries: [AbyssCycleHistoryEntry] = []

    /// The most recent entry for a floor from a cycle other than the one
    /// given — "last cycle's answer", skipping a re-run of the current one.
    func mostRecent(forFloor floor: Int, excludingCycle cyclePeriodStart: String?) -> AbyssCycleHistoryEntry? {
        entries
            .filter { $0.floor == floor && $0.cyclePeriodStart != cyclePeriodStart }
            .max { $0.computedAt < $1.computedAt }
    }
}
