// AbyssRoster.swift
//
// What the player actually owns. Deliberately byte-compatible with the Python
// tool's `roster.json` (same keys, same shapes) so the file can be copied in
// either direction between the app and the command line.

import Foundation

struct AbyssRoster: Codable, Sendable, Equatable {
    struct OwnedCharacter: Codable, Sendable, Equatable, Identifiable {
        let id: String
        /// Stored but **not** scored yet — the model has no constellation
        /// effects. Kept because it is the first thing anyone would want and
        /// re-entering 100+ values later would be worse than carrying it now.
        var constellation: Int

        init(id: String, constellation: Int = 0) {
            self.id = id
            self.constellation = constellation
        }
    }

    struct OwnedWeapon: Codable, Sendable, Equatable, Identifiable {
        let id: String
        var refinement: Int

        init(id: String, refinement: Int = 1) {
            self.id = id
            self.refinement = refinement
        }
    }

    var characters: [OwnedCharacter]
    /// Each entry is assumed to be a single copy: two characters on the same
    /// team cannot both hold it.
    var weapons: [OwnedWeapon]
    /// Empty means "any set is farmable", which is the normal case — artifact
    /// sets are grindable, unlike weapons.
    var artifactSets: [String]

    static let empty = AbyssRoster(characters: [], weapons: [], artifactSets: [])

    init(characters: [OwnedCharacter] = [], weapons: [OwnedWeapon] = [], artifactSets: [String] = []) {
        self.characters = characters
        self.weapons = weapons
        self.artifactSets = artifactSets
    }

    var isEmpty: Bool { characters.isEmpty && weapons.isEmpty }

    func constellation(for characterID: String) -> Int? {
        characters.first { $0.id == characterID }?.constellation
    }

    func refinement(for weaponID: String) -> Int {
        weapons.first { $0.id == weaponID }?.refinement ?? 1
    }

    var characterIDs: Set<String> { Set(characters.map(\.id)) }
    var weaponIDs: Set<String> { Set(weapons.map(\.id)) }

    /// The example roster file carries a `_huong_dan` key of usage notes.
    /// Decoding ignores unknown keys, so it round-trips as a plain roster —
    /// but re-encoding drops the notes, which is why export writes the three
    /// real keys only.
    private enum CodingKeys: String, CodingKey {
        case characters, weapons, artifactSets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        characters = try container.decodeIfPresent([OwnedCharacter].self, forKey: .characters) ?? []
        weapons = try container.decodeIfPresent([OwnedWeapon].self, forKey: .weapons) ?? []
        artifactSets = try container.decodeIfPresent([String].self, forKey: .artifactSets) ?? []
    }
}
