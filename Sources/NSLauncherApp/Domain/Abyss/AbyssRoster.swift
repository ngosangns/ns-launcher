// AbyssRoster.swift
//
// What the player actually owns: characters and weapons, and nothing about
// artifacts. Artifact sets are farmable, so "which sets do you have" is not a
// constraint on the answer — the useful recommendation is the best set that
// exists, and the optimiser always searches all of them.
//
// The file layout stays compatible with the Python tool's `roster.json` (same
// keys, same shapes) so it can still be copied in either direction; an
// `artifactSets` key left over from an older file decodes and is ignored.

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

    static let empty = AbyssRoster(characters: [], weapons: [])

    init(characters: [OwnedCharacter] = [], weapons: [OwnedWeapon] = []) {
        self.characters = characters
        self.weapons = weapons
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

    /// The example roster file carries a `_huong_dan` key of usage notes, and
    /// older files an `artifactSets` list. Decoding ignores unknown keys, so
    /// both round-trip as a plain roster — re-encoding just drops them, which
    /// is why export writes the two real keys only.
    private enum CodingKeys: String, CodingKey {
        case characters, weapons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        characters = try container.decodeIfPresent([OwnedCharacter].self, forKey: .characters) ?? []
        weapons = try container.decodeIfPresent([OwnedWeapon].self, forKey: .weapons) ?? []
    }
}
