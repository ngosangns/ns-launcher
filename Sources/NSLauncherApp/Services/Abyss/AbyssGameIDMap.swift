// AbyssGameIDMap.swift
//
// Numeric game ids -> the slugs the Abyss data uses.
//
// Regenerate with `scripts/generate-abyss-game-ids.py` after adding characters,
// weapons or artifact sets. The table is generated and committed rather than
// resolved at runtime: it changes only when the data does, and building it
// needs two upstreams that a launcher should not have to reach at startup.

import Foundation

struct AbyssGameIDMap: Decodable, Sendable {
    let generatedAt: String
    let source: String
    /// Avatar id -> character slug. Excludes the Traveler, whose element is not
    /// in the avatar id.
    let characters: [String: String]
    /// The Traveler's element lives in a separate "skill depot" id that comes
    /// alongside the avatar id.
    let travelerSkillDepots: [String: String]
    let weapons: [String: String]
    let artifactSets: [String: String]

    static let empty = AbyssGameIDMap(generatedAt: "", source: "", characters: [:],
                                      travelerSkillDepots: [:], weapons: [:], artifactSets: [:])

    /// The character an Enka avatar entry refers to.
    ///
    /// The Traveler is the whole reason this takes two arguments: every Traveler
    /// is avatar 10000005 (or 10000007 for the other twin), and which element
    /// they are attuned to right now is only in the skill depot.
    func characterID(avatarID: Int, skillDepotID: Int?) -> String? {
        if let slug = characters[String(avatarID)] { return slug }
        guard let skillDepotID else { return nil }
        return travelerSkillDepots[String(skillDepotID)]
    }

    func weaponID(itemID: Int) -> String? { weapons[String(itemID)] }
    func artifactSetID(setID: Int) -> String? { artifactSets[String(setID)] }
}
