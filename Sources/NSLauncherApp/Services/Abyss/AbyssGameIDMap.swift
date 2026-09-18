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

    /// The game's own element names ("Wind", "Fire", ...), matching the
    /// element string HoYoLAB's Battle Chronicle reports directly on each
    /// character — the same seven names `scripts/generate-abyss-game-ids.py`
    /// maps from Enka's store for the Traveler's skill depots.
    private static let travelerElementNames: [String: String] = [
        "Wind": "anemo", "Rock": "geo", "Electric": "electro", "Grass": "dendro",
        "Water": "hydro", "Fire": "pyro", "Ice": "cryo",
    ]

    /// The two avatar ids shared by every Traveler, regardless of element —
    /// the same ones `travelerSkillDepots` resolves for Enka.
    private static let travelerAvatarIDs: Set<Int> = [10_000_005, 10_000_007]

    /// The character a HoYoLAB Battle Chronicle entry refers to.
    ///
    /// HoYoLAB reports the Traveler's element as a plain name rather than a
    /// skill depot id, so this needs no depot table lookup — just the avatar
    /// id, or the avatar id plus which element string came back. The element
    /// fallback only fires for the Traveler's own avatar ids: an *unmapped*
    /// id (a character newer than the bundled data) must stay unmapped rather
    /// than being guessed at just because it happens to carry a recognised
    /// element name.
    func characterID(avatarID: Int, hoyolabElementName: String?) -> String? {
        if let slug = characters[String(avatarID)] { return slug }
        guard Self.travelerAvatarIDs.contains(avatarID),
              let hoyolabElementName, let element = Self.travelerElementNames[hoyolabElementName] else { return nil }
        return "traveler-\(element)"
    }
}
