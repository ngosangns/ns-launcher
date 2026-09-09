// AbyssTextParser.swift
//
// Turns the data's free text into numbers: talent multipliers ("172.53% DEF"),
// enemy resistance notes ("kháng Anemo +20%"), and floor buff clauses
// ("Sát thương Superconduct +200%").
//
// This is a deliberate line-for-line port of `data.py`, down to the pattern
// strings, so the two can be diffed side by side. `NSRegularExpression` rather
// than Swift `Regex` for the same reason — the patterns paste across unchanged,
// it is ICU like Python's engine is close to, and it is already the precedent
// in `StoryEntityLinker`.
//
// Two Python behaviours are reproduced on purpose even though they look like
// bugs, because "fixing" them silently moves every score in the app away from
// the reference implementation and the golden fixture:
//   - a label written with an en dash ("1–2-Hit") does not match the combo-hit
//     pattern, so that hit is skipped;
//   - `default_role` never returns `sub-dps` or `support` (see AbyssScorer).
// Both are worth changing eventually — together, in both implementations, with
// the fixture regenerated.

import Foundation

enum AbyssTextParser {
    // MARK: - Patterns (kept verbatim from data.py)

    private static let nonDamageLabel = regex(
        "hồi máu|heal|khiên|shield|absorption|hấp thụ|thời lượng|duration|"
        + "^cd$|hồi chiêu|cooldown|năng lượng|energy|tốc đánh|atk spd|spd|"
        + "bond of life|kháng|res\\b|stamina|thể lực|tầm|bán kính|số lần|"
        + "atk bonus|def bonus|hp bonus|em bonus|buff|giảm|tăng crit|crit rate|crit dmg",
        options: [.caseInsensitive])

    private static let percent = regex("(\\d+(?:[.,]\\d+)?)\\s*%")
    private static let parenthetical = regex("\\([^)]*\\)")
    private static let wordHP = regex("\\bHP\\b")
    private static let wordDEF = regex("\\bDEF\\b")

    /// Splits alternatives that are mutually exclusive ("Press / Hold",
    /// "low / high plunge") while leaving a "/" between digits alone.
    private static let branchSplit = regex("(?<!\\d)\\s*/\\s*|(?<=%)\\s*/\\s*")

    private static let comboHit = regex("^(?:\\d+-hit|đòn\\s*\\d+)", options: [.caseInsensitive])

    /// A charged attack, however the transcription spells it. Plunging attacks
    /// ("nhảy") are deliberately not here: no rotation the model assumes uses
    /// them, and their bonus already routes to `dmgNormal`.
    private static let chargedHit = regex("đòn nặng|trọng kích|charged|aimed|ngắm bắn|bắn nhắm",
                                          options: [.caseInsensitive])

    private static let resistancePatterns = [
        // "kháng Anemo +20%", "kháng Dendro/Geo +20~30%"
        regex("kháng\\s+([A-Za-zÀ-ỹ/ ]+?)\\s*([+\\-−])\\s*(\\d+(?:\\.\\d+)?)", options: [.caseInsensitive]),
        // "pyro_res -20%", "pyro_res −220%"
        regex("([a-z]+)_res\\s*([+\\-−])?\\s*(\\d+(?:\\.\\d+)?)", options: [.caseInsensitive]),
    ]

    private static let resistanceMentioned = regex("kháng|res", options: [.caseInsensitive])
    private static let clauseSplit = regex("[;.]|(?<=%)\\s*,\\s*")
    private static let normalAttackOnly = regex("thường công|normal attack|đòn thường", options: [.caseInsensitive])

    /// Vietnamese element names as they appear in resistance notes.
    private static let vietnameseElements: [String: ResistanceTarget] = [
        "băng": .element(.cryo), "hoả": .element(.pyro), "hỏa": .element(.pyro),
        "lôi": .element(.electro), "điện": .element(.electro),
        "thuỷ": .element(.hydro), "thủy": .element(.hydro),
        "phong": .element(.anemo), "nham": .element(.geo), "thảo": .element(.dendro),
        "vật lý": .physical,
    ]

    /// Substrings that name a reaction in buff text, lowercased for matching.
    private static let reactionKeywords: [(needle: String, reaction: AbyssReaction)] = [
        ("stellar swirl", .stellarSwirl),
        ("stellar-conduct", .stellarConduct),
        ("superconduct", .superconduct),
        ("siêu dẫn", .superconduct),
        ("lunar-charged", .lunarCharged),
        ("lunar-bloom", .lunarBloom),
        ("lunar-crystallize", .lunarCrystallize),
        ("overloaded", .overloaded),
        ("vaporize", .vaporize),
        ("bốc hơi", .vaporize),
        ("melt", .melt),
        ("tan chảy", .melt),
    ]

    // MARK: - Talent scaling

    /// `"172.53% DEF"` -> `(1.7253, .def)`. Returns nil when the text carries no
    /// damage percentage.
    ///
    /// - Parentheticals are dropped first: they hold constellation variants
    ///   ("(cấp 13: 204%)") that would otherwise be summed into the base hit.
    /// - `a%+b%` in one branch are sequential hits and are summed.
    /// - `a% / b%` are mutually exclusive variants; the strongest is taken.
    /// - No named basis means ATK, which is the game's default.
    static func scalingValue(_ text: String) -> (multiplier: Double, basis: ScalingBasis)? {
        guard !text.isEmpty else { return nil }

        var cleaned = replaceMatches(parenthetical, in: text, with: " ")
        cleaned = cleaned.replacingOccurrences(of: "~", with: " ")

        var basis = ScalingBasis.atk
        let upper = cleaned.uppercased()
        if upper.replacingOccurrences(of: " ", with: "").contains("MAXHP")
            || upper.contains("MAX HP")
            || matches(wordHP, upper) {
            basis = .hp
        }
        if matches(wordDEF, upper) { basis = .def }
        if upper.split(whereSeparator: \.isWhitespace).contains("EM") || upper.contains("ELEMENTAL MASTERY") {
            basis = .em
        }

        var best = 0.0
        for branch in split(cleaned, by: branchSplit) {
            let values = captures(percent, in: branch).compactMap { groups -> Double? in
                guard let raw = groups.indices.contains(1) ? groups[1] : nil else { return nil }
                return Double(raw.replacingOccurrences(of: ",", with: "."))
            }
            guard !values.isEmpty else { continue }
            best = max(best, values.reduce(0, +))
        }
        guard best > 0 else { return nil }
        return (best / 100.0, basis)
    }

    /// Damage rows of one talent, dropping healing/shield/cooldown rows.
    static func talentDamageEntries(_ talent: AbyssCharacter.Talent,
                                    levelKey: String = "lv10",
                                    diagnostics: inout AbyssParseDiagnostics) -> [(Double, ScalingBasis)] {
        var out: [(Double, ScalingBasis)] = []
        for entry in talent.scaling {
            if matches(nonDamageLabel, entry.label) {
                diagnostics.scalingSkipped += 1
                continue
            }
            let raw = entry.values[levelKey] ?? entry.values["lv10"] ?? entry.values["lv1"] ?? ""
            guard let parsed = scalingValue(raw) else {
                diagnostics.scalingSkipped += 1
                continue
            }
            diagnostics.scalingParsed += 1
            out.append(parsed)
        }
        return out
    }

    /// Only the numbered hits of the normal-attack string; charged and plunging
    /// attacks are counted separately by the scorer.
    static func normalAttackCombo(_ character: AbyssCharacter,
                                  levelKey: String = "lv10") -> [(Double, ScalingBasis)] {
        var out: [(Double, ScalingBasis)] = []
        for hit in character.normalAttack.hits {
            let label = hit.label.trimmingCharacters(in: .whitespaces)
            guard matches(comboHit, label) else { continue }
            let raw = hit.values[levelKey] ?? hit.values["lv10"] ?? hit.values["lv1"] ?? ""
            if let parsed = scalingValue(raw) { out.append(parsed) }
        }
        return out
    }

    /// The character's charged attack, or nil when they have none the parser
    /// recognises.
    ///
    /// The **strongest** charged row, not the sum of them. A charged attack is
    /// one action and a character uses their best one, but the data does not say
    /// which rows are alternatives and which are sequential: a bow's "Aimed
    /// Shot" and "Aimed Shot sạc đầy" are two ways to fire the same arrow, while
    /// a claymore's spin and finisher happen one after the other. Summing would
    /// double every bow in the data; taking the maximum only under-counts the
    /// handful of claymores, which is the safer way to be wrong.
    static func chargedAttack(_ character: AbyssCharacter,
                              levelKey: String = "lv10") -> (Double, ScalingBasis)? {
        var best: (Double, ScalingBasis)?
        for hit in character.normalAttack.hits {
            let label = hit.label.trimmingCharacters(in: .whitespaces)
            guard matches(chargedHit, label) else { continue }
            let raw = hit.values[levelKey] ?? hit.values["lv10"] ?? hit.values["lv1"] ?? ""
            guard let parsed = scalingValue(raw) else { continue }
            if best == nil || parsed.multiplier > best!.0 { best = (parsed.multiplier, parsed.basis) }
        }
        return best
    }

    // MARK: - Constellations

    /// The data writes a talent-level constellation two ways — "Tăng cấp X thêm
    /// 3" and "X +3 cấp" — and matching only the first missed a third of them,
    /// Xingqiu's C3/C5 among them.
    private static let talentLevelBoost = regex(
        "tăng cấp|\\+\\s*3\\s*cấp|cấp\\s*\\+\\s*3|thêm 3 cấp", options: [.caseInsensitive])
    private static let normalAttackBoost = regex("đòn thường|normal attack", options: [.caseInsensitive])
    private static let burstWord = regex("\\bburst\\b|bùng nổ|\\bnộ\\b", options: [.caseInsensitive])
    private static let skillWord = regex("kỹ năng|\\bskill\\b", options: [.caseInsensitive])

    /// Which talent a constellation raises by three levels, or nil when it does
    /// not raise one.
    ///
    /// Resolved by counting how many words of each talent's *name* appear in the
    /// constellation text, and only falling back to the generic words ("Tăng cấp
    /// kỹ năng thêm 3") when neither name wins. Counting rather than merely
    /// looking for a name is what separates the characters whose two talents
    /// share a prefix — Skirk's "Havoc: Warp" and "Havoc: Ruin", Candace's two
    /// "Sacred Rite" — where a first-match rule picks the wrong one half the
    /// time. Across the bundled data this resolves every boosting constellation.
    ///
    /// A normal-attack boost returns nil on purpose: normal attacks are read at
    /// their base level and no constellation in the data raises the rows the
    /// model actually uses.
    static func boostedTalent(byConstellation description: String,
                              of character: AbyssCharacter) -> AbyssTalentSlot? {
        guard matches(talentLevelBoost, description), !matches(normalAttackBoost, description) else {
            return nil
        }
        let lowered = description.lowercased()

        func score(_ name: String?) -> Int {
            guard let name else { return 0 }
            let words = Set(name.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .filter { $0.count >= 4 })
            return words.filter { lowered.contains($0) }.count
        }

        let skill = score(character.elementalSkill.name)
        let burst = score(character.elementalBurst.name)
        if skill > burst { return .skill }
        if burst > skill { return .burst }
        if matches(burstWord, description) { return .burst }
        if matches(skillWord, description) { return .skill }
        return nil
    }

    /// The stat a character mostly scales off.
    ///
    /// Ties between non-ATK bases resolve through `ScalingBasis.tieBreakOrder`;
    /// see the comment there for why that order is not arbitrary.
    static func scalingBasis(for character: AbyssCharacter,
                             diagnostics: inout AbyssParseDiagnostics) -> ScalingBasis {
        var counts: [ScalingBasis: Int] = [.atk: 0, .def: 0, .hp: 0, .em: 0]
        for talent in [character.elementalSkill, character.elementalBurst] {
            for (_, basis) in talentDamageEntries(talent, diagnostics: &diagnostics) {
                counts[basis, default: 0] += 1
            }
        }
        let atkCount = counts[.atk] ?? 0
        var bestBasis: ScalingBasis?
        var bestCount = 0
        for basis in ScalingBasis.tieBreakOrder where (counts[basis] ?? 0) > bestCount {
            bestBasis = basis
            bestCount = counts[basis] ?? 0
        }
        guard let bestBasis, bestCount > atkCount else { return .atk }
        return bestBasis
    }

    /// The `index`-th percentage on the talent row named exactly `label`.
    ///
    /// Only `tuning.json`'s party-buff table uses this. Those rows are
    /// deliberately *not* damage instances, so `talentDamageEntries` drops them
    /// — but their numbers are real and they live in the character data, which
    /// is where they should be read from rather than retyped into the tuning
    /// file where a talent correction would never reach them.
    ///
    /// Parentheticals are stripped first, exactly as `scalingValue` does, so a
    /// constellation variant ("(cấp 14: 126%)") cannot be mistaken for the
    /// second half of a two-part row.
    static func talentPercentage(in talent: AbyssCharacter.Talent,
                                 label: String,
                                 index: Int = 0,
                                 levelKey: String = "lv10") -> Double? {
        guard let entry = talent.scaling.first(where: { $0.label == label }) else { return nil }
        let raw = entry.values[levelKey] ?? entry.values["lv10"] ?? entry.values["lv1"] ?? ""
        let cleaned = replaceMatches(parenthetical, in: raw, with: " ")
        let values = captures(percent, in: cleaned).compactMap { groups -> Double? in
            guard let raw = groups.indices.contains(1) ? groups[1] : nil else { return nil }
            return Double(raw.replacingOccurrences(of: ",", with: "."))
        }
        guard index >= 0, index < values.count else { return nil }
        return values[index] / 100.0
    }

    // MARK: - Enemy resistance

    /// `"kháng Anemo +20%"` -> `[.element(.anemo): 0.20]`,
    /// `"pyro_res -20%"` -> `[.element(.pyro): -0.20]`.
    static func resistanceNotes(_ note: String?,
                                diagnostics: inout AbyssParseDiagnostics) -> [ResistanceTarget: Double] {
        guard let note, !note.isEmpty else { return [:] }
        var found: [ResistanceTarget: Double] = [:]

        for pattern in resistancePatterns {
            for groups in captures(pattern, in: note) {
                guard groups.count > 3,
                      let rawTargets = groups[1], let rawValue = groups[3],
                      let magnitude = Double(rawValue) else { continue }
                let sign = groups[2]
                var delta = magnitude / 100.0
                if sign == "-" || sign == "−" { delta = -delta }
                for token in rawTargets.split(whereSeparator: { $0 == "/" || $0 == "," }) {
                    if let target = resistanceTarget(fromToken: String(token)) {
                        found[target] = delta
                    }
                }
            }
        }

        if found.isEmpty, matches(resistanceMentioned, note) {
            diagnostics.resistanceNotesUnparsed.insert(note)
        }
        return found
    }

    static func resistanceTarget(fromToken token: String) -> ResistanceTarget? {
        let normalized = token.trimmingCharacters(in: .whitespaces).lowercased()
        if let element = GenshinElement.allCases.first(where: { $0.rawValue.lowercased() == normalized }) {
            return .element(element)
        }
        return vietnameseElements[normalized]
    }

    // MARK: - Floor buffs

    /// Pulls "+X% to <something>" clauses out of a Ley Line Disorder or
    /// Blessing description.
    static func floorBuffs(_ text: String?,
                           source: AbyssFloorBuff.Source = .leyLine,
                           diagnostics: inout AbyssParseDiagnostics) -> [AbyssFloorBuff] {
        guard let text, !text.isEmpty else { return [] }
        var buffs: [AbyssFloorBuff] = []

        for clause in split(text, by: clauseSplit) {
            let percents = captures(percent, in: clause).compactMap { groups -> Double? in
                guard let raw = groups.indices.contains(1) ? groups[1] : nil else { return nil }
                return Double(raw.replacingOccurrences(of: ",", with: "."))
            }
            guard let first = percents.first else { continue }

            let lowered = clause.lowercased()
            let reactions = Set(reactionKeywords.filter { lowered.contains($0.needle) }.map(\.reaction))
            let elements = Set(GenshinElement.allCases.filter { lowered.contains($0.rawValue.lowercased()) })
            let normalOnly = matches(normalAttackOnly, lowered)

            // A number with no qualifier is prose, not a buff.
            guard !reactions.isEmpty || !elements.isEmpty || normalOnly else { continue }

            buffs.append(AbyssFloorBuff(
                bonus: first / 100.0,
                elements: elements,
                reactions: reactions,
                normalAttackOnly: normalOnly,
                raw: clause.trimmingCharacters(in: .whitespaces),
                source: source))
        }

        if buffs.isEmpty, matches(percent, text) {
            diagnostics.leyLineUnparsed.insert(text)
        }
        return buffs
    }

    // MARK: - Regex plumbing

    /// Patterns here are fixed literals written above; a typo is a programmer
    /// error that should surface on first use, not degrade into "matches
    /// nothing" at runtime.
    private static func regex(_ pattern: String,
                              options: NSRegularExpression.Options = []) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            preconditionFailure("invalid Abyss parser pattern \(pattern): \(error)")
        }
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    /// All matches, each as its capture groups indexed by group number
    /// (0 = whole match). Groups that did not participate are nil, mirroring
    /// Python's `None`.
    private static func captures(_ regex: NSRegularExpression, in text: String) -> [[String?]] {
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, range: range).map { match in
            (0..<match.numberOfRanges).map { index -> String? in
                let groupRange = match.range(at: index)
                return groupRange.location == NSNotFound ? nil : nsText.substring(with: groupRange)
            }
        }
    }

    private static func replaceMatches(_ regex: NSRegularExpression, in text: String, with template: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    /// Foundation has no `re.split`, so this reproduces it: slice the text
    /// between matches, keeping empty pieces exactly as Python does.
    static func split(_ text: String, by regex: NSRegularExpression) -> [String] {
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)
        var pieces: [String] = []
        var cursor = 0
        for match in regex.matches(in: text, range: full) {
            // A zero-width match would not advance and would loop forever.
            guard match.range.length > 0 || match.range.location > cursor else { continue }
            pieces.append(nsText.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            cursor = match.range.location + match.range.length
        }
        pieces.append(nsText.substring(from: cursor))
        return pieces
    }
}
