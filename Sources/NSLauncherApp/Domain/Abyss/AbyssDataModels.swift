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
    /// absent rather than as a decode failure.
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

        /// Value at a refinement level, clamped to R1-R5: a roster may carry
        /// a refinement outside that range and it should read as the nearest
        /// real one rather than as nothing.
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
        /// A prose summary's stat lines. Not read for scoring since Phase 5:
        /// weapon passives are structured buffs from the game text, in
        /// `passives.json` — see `AbyssPassives.swift`.
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

    /// One piece bonus. The two descriptions are the game's own text in each
    /// language, written by `scripts/sync-abyss-artifact-text.py` from the
    /// official localisation — never paraphrased or translated here, because a
    /// description that reads differently from the one in game is a claim about
    /// the set the player cannot check. `bonuses` is the separate, structured
    /// reading the damage model uses; nothing parses the prose.
    struct Effect: Decodable, Sendable {
        let description: String
        /// Optional so a hand-supplied data file without it still decodes; the
        /// popover then shows the English text rather than nothing.
        let descriptionVI: String?
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
        /// The game's own numeric id for this monster, written by
        /// `scripts/sync-abyss-monster-resistance.py`. Present only for a
        /// monster the script could resolve; absent is not an error; see
        /// `resistances`.
        let gameId: Int?
        /// This monster's real elemental resistance, straight from the game's
        /// files (`gi.yatta.moe`'s `resistance` block) rather than inferred.
        /// `GenshinElement` raw values -> fraction, e.g. `0.7` = 70%.
        ///
        /// Complete when present: every one of the seven elements the monster
        /// does *not* specially resist is still in here at the 10% baseline,
        /// because that is itself real information the old inference could not
        /// state — see `AbyssFloorContext.build`'s resistance precedence.
        let resistances: [String: Double]?
        /// The monster's real resistance to Physical damage, same source as
        /// `resistances`. Decoded and reported so a real number is not thrown
        /// away, but **not consumed anywhere yet**: no playable character's
        /// damage profile is modelled as Physical (normal attacks are read as
        /// the character's own element), so there is nothing in the engine to
        /// apply it to. A monster like the Ruin-series machines can carry a
        /// large Physical resistance (Ruin Cruiser 30%, Perpetual Mechanical
        /// Array 70%) that this data captures but the damage model still
        /// cannot see — a gap worth stating plainly rather than leaving silent.
        let physicalResistance: Double?
        /// How many of this monster the half spawns in all, from the cycle's
        /// wiki page, written by `scripts/sync-abyss-monster-hp.py`. `count`
        /// above is prose and is not read.
        let spawns: Int?
        /// Which wiki stat block this monster's HP scales by — see
        /// `AbyssEnemyHPTable`. Absent for a monster the script could not
        /// resolve.
        let hp: HPScaling?

        struct HPScaling: Decodable, Sendable {
            /// The wiki page and variant ("Normal", "Battle-Hardened") the
            /// ratio was read from, for audit.
            let page: String
            let variant: String
            let ratio: Double
            let type: String
        }
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
        /// Enemy HP on this floor against the open world (2.5 on floor 12),
        /// from the wiki's Spiral Abyss page. Absent when the script refused
        /// the floor.
        let enemyHPMultiplier: Double?
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
        let nameVI: String
        let elements: [GenshinElement]
        let requiredCount: Int
        let requiresUniqueElements: Bool?
        let description: String
        let bonuses: [Bonus]
    }

    /// The rules, not the roster. Which characters count towards Moonsign and
    /// Hexerei is in `character-kits.json` — a roster changes with every
    /// banner and a rule changes with a game version, so they are edited at
    /// different times by different evidence.
    struct Moonsign: Decodable, Sendable {
        struct Level: Decodable, Sendable {
            let name: String
            let requiredCount: Int
            let description: String
        }

        let note: String?
        let levels: [Level]
    }

    struct Hexerei: Decodable, Sendable {
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

    /// One `a * EM / (EM + b)` curve. All four EM curves in the data share this
    /// shape, and the data writes them as prose ("2.78 * EM / (EM + 1400)")
    /// rather than as two numbers, so they are parsed rather than decoded.
    struct EMCurve: Sendable, Equatable {
        let numerator: Double
        let offset: Double

        func bonus(_ elementalMastery: Double) -> Double {
            numerator * elementalMastery / (elementalMastery + offset)
        }

        /// `"16 * EM / (EM + 2000)"` -> `EMCurve(16, 2000)`. Returns nil when the
        /// text is not that shape, so the caller can fall back and say so rather
        /// than silently scoring with a zero curve.
        static func parse(_ text: String) -> EMCurve? {
            guard let regex = try? NSRegularExpression(
                pattern: "([0-9.]+)\\s*\\*\\s*EM\\s*/\\s*\\(\\s*EM\\s*\\+\\s*([0-9.]+)\\s*\\)",
                options: [.caseInsensitive]) else { return nil }
            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 2,
                  let numeratorRange = Range(match.range(at: 1), in: text),
                  let offsetRange = Range(match.range(at: 2), in: text),
                  let numerator = Double(text[numeratorRange]),
                  let offset = Double(text[offsetRange]) else { return nil }
            return EMCurve(numerator: numerator, offset: offset)
        }
    }

    struct Amplifying: Decodable, Sendable {
        let emBonusFormula: String
        /// Keyed by the data's own names: `meltPyroTrigger`, `vaporizeHydroTrigger`…
        let coefficients: [String: Double]
    }

    struct LevelMultiplier: Decodable, Sendable {
        let character: Double
        let monster: Double
    }

    struct Transformative: Decodable, Sendable {
        let emBonusFormula: String
        /// Keyed by reaction: `hyperbloom`, `overloaded`, `swirl`…
        let coefficients: [String: Double]
        /// Keyed by character level as a string: "70", "80", "85", "90".
        let levelMultiplier: [String: LevelMultiplier]
    }

    struct Catalyze: Decodable, Sendable {
        let emBonusFormula: String
        let coefficients: [String: Double]
    }

    /// The Lunar and Stellar Glimmer reactions — Lunar-Charged, Lunar-Bloom,
    /// Lunar-Crystallize, Stellar-Conduct, Stellar Swirl.
    ///
    /// Their own block because they are their own mechanic: a different EM
    /// curve, and coefficients that depend on whether the reaction is dealt
    /// directly or aggregated across everyone who applied an element. The
    /// base-damage bonus a handful of characters bring is in
    /// `character-kits.json`, with the reactions each one raises written out.
    struct LunarStellar: Decodable, Sendable {
        struct Branch: Decodable, Sendable {
            let coefficients: [String: Double]
        }

        let emBonusFormula: String
        let direct: Branch
        let indirect: Branch
    }

    let resMultiplier: ResMultiplier
    let amplifying: Amplifying
    let transformative: Transformative
    let catalyze: Catalyze
    let lunarStellar: LunarStellar?
    let workedExample: WorkedExample
}

// MARK: - Decoding helpers

private extension KeyedDecodingContainer {
    /// Decodes a number that the data model allows to be a number, a string or
    /// null. Non-numeric values read as absent rather than throwing — a weapon
    /// whose refinement track carries text simply has no numeric buff there.
    func decodeLenientDouble(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        return nil
    }
}
