// AbyssTalentParams.swift
//
// Decodable mirror of `Resources/Abyss/talent-params.json`: every talent's
// multipliers as the game's own files state them, at every level.
//
// This is the structured counterpart to the prose scaling tables in
// `characters/*.json`. Those are wiki-transcribed — a Vietnamese label and a
// string like `"172.53% DEF"` per level — and `AbyssTextParser` reads them back
// with twenty-six regexes. This file is written by
// `scripts/sync-abyss-talent-params.py` straight from `gi.yatta.moe`, verbatim:
// the description lines in the game's English and the raw `params` array per
// level. Nothing here is interpreted; `AbyssTalentReader` does that, in Swift,
// where every rule is a test.
//
// Kept apart from `characters/*.json` on purpose. Those files are hand-curated
// and carry things no API has (Vietnamese names, role notes); this one is
// regenerated wholesale and must never be edited by hand. Mixing the two would
// put a generated block inside a hand-edited file, which is how a regeneration
// ends up silently overwriting somebody's correction.

import Foundation

struct AbyssTalentParams: Decodable, Sendable {
    /// One levelled talent, verbatim.
    struct Talent: Decodable, Sendable {
        let name: String
        /// Seconds. Zero for the normal attack.
        let cooldown: Double
        /// Burst energy cost; zero for the other two.
        let energyCost: Double
        /// The game's description lines at level 10, e.g.
        /// `"Skill DMG|{param1:P} Max HP"`.
        let lines: [String]
        /// Levels whose lines differ from `lines` in something the reader would
        /// see, keyed by level as a string. Rare — five talents change a word
        /// between levels, and two renumber their placeholders at level 15 —
        /// but real: a level-15 line has to be read against level-15 params
        /// with level 15's placeholder indices. See the sync script.
        let lineOverrides: [String: [String]]?
        /// `params[level - 1]` is the parameter array at that talent level;
        /// `{param3:P}` in a line reads `params[level - 1][2]`.
        let params: [[Double]]

        /// The parameter array at a 1-based talent level, or nil past the top.
        func params(atLevel level: Int) -> [Double]? {
            guard level >= 1, level <= params.count else { return nil }
            return params[level - 1]
        }

        /// The lines that describe `params(atLevel:)` at that same level.
        func lines(atLevel level: Int) -> [String] {
            lineOverrides?[String(level)] ?? lines
        }
    }

    /// The three tables a character has, by the key the file uses for them.
    /// `character-kits.json` names talents with the same spelling.
    enum Key: String, Decodable, Sendable, CaseIterable {
        case normalAttack, elementalSkill, elementalBurst
    }

    struct Character: Decodable, Sendable {
        let gameId: Int
        let normalAttack: Talent
        let elementalSkill: Talent
        let elementalBurst: Talent

        func talent(_ key: Key) -> Talent {
            switch key {
            case .normalAttack: return normalAttack
            case .elementalSkill: return elementalSkill
            case .elementalBurst: return elementalBurst
            }
        }
    }

    /// Keyed by character slug. The seven Traveler variants are absent — see
    /// the sync script — and read their talents from the prose path instead.
    let characters: [String: Character]
}
