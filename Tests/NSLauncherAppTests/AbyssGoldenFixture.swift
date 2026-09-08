import Foundation
import XCTest
@testable import NSLauncherApp

/// Reads `Fixtures/abyss-golden.json` — the values the Python reference
/// implementation produces for the same bundled data.
///
/// The port's most dangerous failure mode is silent: the stat-name mapping is a
/// long switch, and one branch wired to the wrong field produces numbers that
/// look plausible forever. Comparing intermediates against a recorded run is
/// the only thing that catches that class of mistake.
///
/// Regenerate deliberately, never to make a red test green:
/// `python3 optimize_abyss.py --dump-golden ../../Tests/NSLauncherAppTests/Fixtures/abyss-golden.json`
struct AbyssGoldenFixture: Decodable {
    struct Term: Decodable {
        let multiplier: Double
        let basis: String
        let category: String
    }

    struct Stats: Decodable {
        let base_atk: Double
        let base_hp: Double
        let base_def: Double
        let atk_pct: Double
        let hp_pct: Double
        let def_pct: Double
        let flat_atk: Double
        let flat_hp: Double
        let flat_def: Double
        let em: Double
        let er: Double
        let crit_rate: Double
        let crit_dmg: Double
        let healing_bonus: Double
        let dmg_elemental: [String: Double]
        let dmg_all: Double
        let dmg_normal: Double
        let dmg_charged: Double
        let dmg_skill: Double
        let dmg_burst: Double
        let party_atk_pct: Double
        let party_em: Double
        let party_dmg: Double
    }

    struct Gear: Decodable {
        let weaponId: String?
        let setIds: [String]
        let soloScore: Double
        let stats: Stats
    }

    struct Character: Decodable {
        let scalingBasis: String
        let role: String
        let profile: [Term]
        let topGear: Gear
    }

    struct Buff: Decodable {
        let bonus: Double
        let elements: [String]
        let reactions: [String]
        let normalAttackOnly: Bool
        let raw: String
    }

    struct Floor: Decodable {
        let monsterLevel: Int
        let res: [String: Double]
        let shieldElements: [String]
        let buffs: [Buff]
    }

    struct Team: Decodable {
        let memberIds: [String]
        let onFieldId: String
        let score: Double
        let perCharacter: [String: Double]
    }

    let characters: [String: Character]
    let floors: [String: Floor]
    let teams: [String: [Team]]

    /// The same roster the fixture's teams were generated from, copied from
    /// `toi-uu-doi-hinh/optimizer/roster.example.json`. Loading it here also
    /// pins the on-disk format the two implementations share.
    static func exampleRoster(file: StaticString = #filePath, line: UInt = #line) throws -> AbyssRoster {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/roster.example", withExtension: "json")
                ?? Bundle.module.url(forResource: "roster.example", withExtension: "json"),
            "roster.example.json is not in the test bundle",
            file: file, line: line)
        return try JSONDecoder().decode(AbyssRoster.self, from: Data(contentsOf: url))
    }

    static func load(file: StaticString = #filePath, line: UInt = #line) throws -> AbyssGoldenFixture {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/abyss-golden", withExtension: "json")
                ?? Bundle.module.url(forResource: "abyss-golden", withExtension: "json"),
            "abyss-golden.json is not in the test bundle — check the testTarget's resources in Package.swift",
            file: file, line: line)
        return try JSONDecoder().decode(AbyssGoldenFixture.self, from: Data(contentsOf: url))
    }
}
