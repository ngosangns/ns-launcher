// AbyssHoyolabRoster.swift
//
// A player's full character list, read from HoYoLAB's Battle Chronicle rather
// than from Enka. Where a Showcase import (`AbyssShowcase`) is capped at eight
// characters but carries their complete rolled stats, this is the reverse
// trade: every character the player has ever obtained, but only what HoYoLAB's
// character list actually reports — level, constellation, and the weapon
// equipped with its refinement. No artifacts, so these characters are still
// scored on the standardised build, the same as any other roster entry;
// `AbyssGearOption.statSource` for them is `.modelled`, never `.measured`.

import Foundation

struct AbyssHoyolabRoster: Sendable, Equatable {
    let uid: String
    let fetchedAt: Date
    let characters: [AbyssHoyolabCharacter]
    /// Game ids `game-ids.json` had no slug for — reported rather than
    /// dropped, the same reasoning as `AbyssShowcase.unmappedIDs`.
    let unmappedIDs: [String]

    static let empty = AbyssHoyolabRoster(uid: "", fetchedAt: .distantPast, characters: [], unmappedIDs: [])
}

struct AbyssHoyolabCharacter: Sendable, Equatable {
    let characterID: String
    /// 0-6.
    let constellation: Int
    let weaponID: String?
    /// 1-5. Meaningless when `weaponID` is nil.
    let weaponRefinement: Int
}
