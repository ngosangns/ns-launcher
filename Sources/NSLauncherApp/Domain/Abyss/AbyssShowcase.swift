// AbyssShowcase.swift
//
// A player's Character Showcase, as fetched from Enka.Network with nothing but
// their UID.
//
// This is the one place in the Abyss tab where the numbers are *measured*
// rather than modelled. Everywhere else a character is given a standardised
// build out of `tuning.json`, because the app has no idea what the player
// actually rolled; here it does, for the handful of characters they have chosen
// to put on display.
//
// Two limits are worth stating plainly, because they shape the whole feature:
// the showcase holds at most eight characters, and it only exists at all if the
// player turned on "Show Character Details" in their in-game profile. There is
// no public way to read a full roster — that data is not exposed to anyone
// without the account's own login session.

import Foundation

/// One fetch of a player's showcase.
struct AbyssShowcase: Codable, Sendable, Equatable {
    let uid: String
    /// Enka's region tag for the UID, e.g. "os_euro". The UID's first digit
    /// already encodes this, which is why the tab never asks for a server.
    let region: String
    let nickname: String
    let adventureRank: Int
    let worldLevel: Int
    let fetchedAt: Date
    /// Seconds Enka will keep serving this same snapshot before it asks the
    /// game for a fresh one. Re-fetching sooner returns identical data and
    /// still spends the rate limit, so the client refuses to.
    let refreshInterval: Int
    let builds: [AbyssShowcaseBuild]
    /// Game ids `game-ids.json` had no slug for — a character or weapon newer
    /// than the bundled data. Reported rather than dropped so a missing entry
    /// looks like a stale mapping table instead of a missing character.
    let unmappedIDs: [String]

    var nextRefreshDate: Date { fetchedAt.addingTimeInterval(TimeInterval(refreshInterval)) }

    static let empty = AbyssShowcase(uid: "", region: "", nickname: "", adventureRank: 0,
                                     worldLevel: 0, fetchedAt: .distantPast, refreshInterval: 0,
                                     builds: [], unmappedIDs: [])
}

/// One character as they are actually equipped in game.
struct AbyssShowcaseBuild: Codable, Sendable, Equatable {
    let characterID: String
    let level: Int
    /// 0-6, from how many constellations are unlocked.
    let constellation: Int
    let weaponID: String?
    let weaponLevel: Int
    /// 1-5.
    let weaponRefinement: Int
    /// How many pieces of each set are worn. A player is often wearing a
    /// half-finished spread, so this is a count and not a list of "the" sets.
    let setPieces: [String: Int]
    let stats: AbyssMeasuredStats

    /// The set bonuses actually active: one set with four pieces, or up to two
    /// sets with two pieces each. Anything else contributes nothing, exactly as
    /// in game.
    var activeSetIDs: [String] {
        if let fourPiece = setPieces.filter({ $0.value >= 4 }).keys.sorted().first {
            return [fourPiece]
        }
        return setPieces.filter { $0.value >= 2 }.keys.sorted().prefix(2).map { $0 }
    }
}

/// The character screen's numbers, straight from the game.
///
/// Stored as named scalars rather than as an `AbyssStats` so the file on disk
/// stays readable and stable if the internal stat sheet is ever reorganised.
///
/// These come from Enka's `fightPropMap`, which reports each stat already split
/// into base, percentage and flat parts — the same shape `AbyssStats` uses, so
/// the conversion is a rename rather than a reconstruction. `critRate`,
/// `critDMG` and `energyRecharge` include the character's innate 5% / 50% /
/// 100%, so they are assigned rather than added.
struct AbyssMeasuredStats: Codable, Sendable, Equatable {
    var baseATK: Double = 0
    var atkPercent: Double = 0
    var flatATK: Double = 0
    var baseHP: Double = 0
    var hpPercent: Double = 0
    var flatHP: Double = 0
    var baseDEF: Double = 0
    var defPercent: Double = 0
    var flatDEF: Double = 0
    var critRate: Double = 0.05
    var critDMG: Double = 0.5
    var energyRecharge: Double = 1
    var elementalMastery: Double = 0
    var healingBonus: Double = 0
    /// Keyed by `GenshinElement.rawValue`; only the non-zero ones are stored.
    var elementalDMG: [String: Double] = [:]

    var stats: AbyssStats {
        var sheet = AbyssStats(baseATK: baseATK, baseHP: baseHP, baseDEF: baseDEF)
        sheet.atkPercent = atkPercent
        sheet.flatATK = flatATK
        sheet.hpPercent = hpPercent
        sheet.flatHP = flatHP
        sheet.defPercent = defPercent
        sheet.flatDEF = flatDEF
        sheet.critRate = critRate
        sheet.critDMG = critDMG
        sheet.energyRecharge = energyRecharge
        sheet.elementalMastery = elementalMastery
        sheet.healingBonus = healingBonus
        for (raw, value) in elementalDMG {
            guard let element = GenshinElement(rawValue: raw) else { continue }
            sheet.add(value, to: .elemental(element))
        }
        return sheet
    }
}

/// Where a character's numbers came from, so the UI never presents a modelled
/// build and a measured one as if they were the same kind of claim.
enum AbyssStatSource: String, Codable, Sendable, Equatable {
    /// A standardised build from `tuning.json`.
    case modelled
    /// The player's own artifacts, read from their showcase.
    case measured
}
