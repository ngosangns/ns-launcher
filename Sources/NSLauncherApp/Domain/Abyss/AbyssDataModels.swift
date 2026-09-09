// AbyssDataModels.swift
//
// Decodable mirrors of the JSON under `Resources/Abyss/`. Property names match
// the JSON keys exactly (the data is authored camelCase), so no CodingKeys and
// no key strategy — the same arrangement as `StoryModels.swift`.
//
// Numeric fields are optional wherever the data model allows null: the source
// Markdown records "chưa xác nhận" for values nobody could confirm, and those
// come through as null rather than a fabricated number. Treating them as
// non-optional here would turn a documented gap into a decode failure that
// silently empties the whole tab.

import Foundation

// MARK: - Characters

struct AbyssCharacter: Decodable, Sendable, Identifiable {
    struct BaseStats: Decodable, Sendable {
        struct Level: Decodable, Sendable {
            let hp: Double?
            let atk: Double?
            let def: Double?
        }

        struct MaxLevel: Decodable, Sendable {
            let hp: Double?
            let atk: Double?
            let def: Double?
            let ascensionStatType: String?
            let ascensionStatValue: Double?
        }

        let lv1: Level
        let lv90: MaxLevel
    }

    /// One row of a talent's scaling table. `values` maps a talent level key
    /// ("lv1", "lv10") to the raw text, e.g. `"172.53% DEF"` — parsing that
    /// text is `AbyssTextParser`'s job.
    struct ScalingEntry: Decodable, Sendable {
        let label: String
        let values: [String: String]
    }

    struct Talent: Decodable, Sendable {
        let name: String?
        let description: String
        let scaling: [ScalingEntry]
        let cooldown: String?
        let energyCost: Double?
    }

    struct NormalAttack: Decodable, Sendable {
        let name: String?
        let hits: [ScalingEntry]
    }

    struct Passive: Decodable, Sendable {
        let name: String
        let unlock: String
        let description: String
    }

    struct Constellation: Decodable, Sendable {
        let level: Int
        let name: String
        let description: String
    }

    let id: String
    let name: String
    let nameVI: String
    let element: GenshinElement
    let weaponType: WeaponType
    let rarity: Int
    let nationInGame: String
    let releaseDate: String?
    let baseStats: BaseStats
    let normalAttack: NormalAttack
    let elementalSkill: Talent
    let elementalBurst: Talent
    let additionalTalents: [Talent]?
    let passives: [Passive]
    let constellations: [Constellation]
    let abyssRoleNotes: String?
    let sourceFile: String
}

// MARK: - Weapons

struct AbyssWeapon: Decodable, Sendable, Identifiable {
    struct SubStat: Decodable, Sendable {
        let type: String?
        let valueLv90: Double?
    }

    /// One numeric track of a weapon passive across refinements R1-R5.
    ///
    /// The schema allows number, string or null per refinement because a few
    /// weapons' data carries text there; anything non-numeric is treated as
    /// absent, matching the Python's `isinstance(value, (int, float))` guard.
    struct PassiveEffect: Decodable, Sendable {
        let stat: String
        let r1: Double?
        let r2: Double?
        let r3: Double?
        let r4: Double?
        let r5: Double?

        private enum CodingKeys: String, CodingKey {
            case stat, r1, r2, r3, r4, r5
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            stat = try container.decode(String.self, forKey: .stat)
            r1 = try container.decodeLenientDouble(forKey: .r1)
            r2 = try container.decodeLenientDouble(forKey: .r2)
            r3 = try container.decodeLenientDouble(forKey: .r3)
            r4 = try container.decodeLenientDouble(forKey: .r4)
            r5 = try container.decodeLenientDouble(forKey: .r5)
        }

        /// Value at a refinement level, clamped to R1-R5 like the Python's
        /// `max(1, min(5, refinement))`.
        func value(refinement: Int) -> Double? {
            switch max(1, min(5, refinement)) {
            case 1: return r1
            case 2: return r2
            case 3: return r3
            case 4: return r4
            default: return r5
            }
        }
    }

    struct Passive: Decodable, Sendable {
        let name: String?
        let description: String
        let effects: [PassiveEffect]
    }

    let id: String
    let name: String
    let nameVI: String
    let type: WeaponType
    let rarity: Int
    let atkLv1: Double?
    let atkLv90: Double?
    let subStat: SubStat
    let passive: Passive?
    let acquisition: String
    let bestCharacters: [String]
    let sourceFile: String
}

// MARK: - Artifacts

struct AbyssArtifactSet: Decodable, Sendable, Identifiable {
    struct Bonus: Decodable, Sendable {
        let stat: String
        let value: Double
    }

    struct Effect: Decodable, Sendable {
        let description: String
        let bonuses: [Bonus]
    }

    let id: String
    let name: String
    let nameVI: String
    let rarity: String
    let twoPiece: Effect
    let fourPiece: Effect
    let domain: String?
    let region: String?
    let bestCharacters: [String]
    let sourceFile: String

    /// Whether the set exists at 5★. Builds are modelled at 5★ level 20, so
    /// sets that cap at 3★/4★ cannot reach the assumed main stats and are left
    /// out of gear selection entirely.
    var existsAtFiveStar: Bool { rarity.contains("5") }
}

// MARK: - Abyss cycle

struct AbyssCycle: Decodable, Sendable {
    struct Blessing: Decodable, Sendable {
        let name: String
        let description: String
        let timeStart: String
        let timeEnd: String
        let relatedMechanic: String?
    }

    struct Monster: Decodable, Sendable {
        let name: String
        let count: String
        let size: String
        let elements: [String]
        let resistanceNotes: String?
        let weakpoint: Bool?
        let mechanics: String?
        let hpRatio: String?
    }

    struct Wave: Decodable, Sendable {
        let wave: Int
        let monsters: [Monster]
    }

    struct Chamber: Decodable, Sendable {
        let chamber: Int
        let monsterLevel: Int?
        let waves: [Wave]
    }

    struct Floor: Decodable, Sendable {
        let floor: Int
        let leyLineDisorder: String
        let chambers: [Chamber]
        let recommendation: String
    }

    let sourceFile: String?
    let dataFetchDate: String?
    let periodStart: String
    let periodEnd: String
    let gameVersion: String
    let mechanicNotes: String?
    let blessingOfTheAbyssalMoon: Blessing
    let floors: [Floor]
}

// MARK: - Team bonuses

struct AbyssTeamBonus: Decodable, Sendable {
    struct Bonus: Decodable, Sendable {
        let stat: String
        let value: Double
    }

    struct Resonance: Decodable, Sendable, Identifiable {
        let id: String
        let name: String
        let elements: [GenshinElement]
        let requiredCount: Int
        let requiresUniqueElements: Bool?
        let description: String
        let bonuses: [Bonus]
    }

    struct Moonsign: Decodable, Sendable {
        struct Level: Decodable, Sendable {
            let name: String
            let requiredCount: Int
            let description: String
        }

        let characterIds: [String]
        let note: String?
        let levels: [Level]
    }

    struct Hexerei: Decodable, Sendable {
        let characterIds: [String]
        let requiredCount: Int
        let description: String
        let requirement: String
    }

    let elementalResonance: [Resonance]
    let moonsign: Moonsign
    let hexerei: Hexerei
}

// MARK: - Damage formula

/// Only the parts the engine reads. The file also carries prose explaining each
/// formula; `AbyssDamageMath` implements them and the worked example is what
/// proves the implementation matches.
struct AbyssDamageFormula: Decodable, Sendable {
    struct WorkedExample: Decodable, Sendable {
        struct Inputs: Decodable, Sendable {
            let characterLevel: Int
            let monsterLevel: Int
            let atk: Double
            let elementalMastery: Double
            let critDmg: Double
            let hydroDmgBonus: Double
            let klee_c2_reactionDmgBonus: Double
            let skillMultiplierStellarisPhantasmLv6: Double
            let defReductionFromKleeC2: Double
            let resHydroBase: Double
            let resHydroReductionFromSucroseSwirl: Double
        }

        struct Result: Decodable, Sendable {
            let value: Double
            let unit: String
        }

        let scenario: String
        let inputs: Inputs
        let result: Result
    }

    struct ResMultiplier: Decodable, Sendable {
        let defaultMonsterResAllElements: Double
    }

    let resMultiplier: ResMultiplier
    let workedExample: WorkedExample
}

// MARK: - Decoding helpers

private extension KeyedDecodingContainer {
    /// Decodes a number that the data model allows to be a number, a string or
    /// null. Non-numeric values read as absent rather than throwing, matching
    /// the Python's `isinstance(value, (int, float))` check — a weapon whose
    /// refinement track carries text simply has no numeric buff there.
    func decodeLenientDouble(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        return nil
    }
}
