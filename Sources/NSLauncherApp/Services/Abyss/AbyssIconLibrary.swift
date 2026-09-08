// AbyssIconLibrary.swift
//
// Resolves the character and weapon portrait files bundled under
// `Resources/Abyss/icons/`, fetched once by `scripts/fetch-abyss-icons.py`.
//
// The script matches by name against gi.yatta.moe — the same source the rest
// of the Abyss data was transcribed from — and saves each file under our own
// slug, so nothing here needs to know Yatta's internal icon codenames: this is
// exactly the same "id -> Resources/Abyss/<kind>/<id>" convention the rest of
// the data already uses, just for a `.png` instead of a `.json`.
//
// Availability is checked once, not per lookup: the roster grid can ask for an
// icon on every redraw while scrolling, and hitting the filesystem that often
// adds up against a membership check in a small precomputed set.

import Foundation

struct AbyssIconLibrary: Sendable {
    private let charactersDirectory: URL?
    private let weaponsDirectory: URL?
    private let availableCharacterIDs: Set<String>
    private let availableWeaponIDs: Set<String>

    static let empty = AbyssIconLibrary(root: nil)

    init(root: URL?) {
        charactersDirectory = root?.appendingPathComponent("icons/characters")
        weaponsDirectory = root?.appendingPathComponent("icons/weapons")
        availableCharacterIDs = Self.pngStems(in: charactersDirectory)
        availableWeaponIDs = Self.pngStems(in: weaponsDirectory)
    }

    func characterIconURL(_ id: String) -> URL? {
        guard availableCharacterIDs.contains(id) else { return nil }
        return charactersDirectory?.appendingPathComponent("\(id).png")
    }

    func weaponIconURL(_ id: String) -> URL? {
        guard availableWeaponIDs.contains(id) else { return nil }
        return weaponsDirectory?.appendingPathComponent("\(id).png")
    }

    private static func pngStems(in directory: URL?) -> Set<String> {
        guard let directory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        return Set(names.filter { $0.hasSuffix(".png") }.map { String($0.dropLast(4)) })
    }
}
