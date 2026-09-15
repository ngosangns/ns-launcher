// AbyssTalentReader.swift
//
// Reads a character's damage profile out of `talent-params.json` — the game's
// own talent tables — instead of out of wiki prose.
//
// The input is a closed grammar over a closed vocabulary. Each line is
// `Label|expression`, where the expression is one or more placeholders
// `{paramN:FMT}` joined by `+`, optionally `×k`, optionally in alternatives
// separated by `/`, each placeholder optionally followed by the stat it scales
// off (" Max HP", " DEF", " Elemental Mastery"; nothing means ATK). Every one of
// those shapes was enumerated across all 118 characters before this was written
// — see `scripts/sync-abyss-talent-params.py` — so a shape this cannot read is a
// new one, and it is reported rather than guessed at.
//
// The label is the game's English, and the decisions made on it are the same
// ones `AbyssTextParser` makes on the transcription, so the two can be
// compared row for row: numbered hits are the normal-attack combo, charged rows
// take the strongest, plunges are dropped, skill and burst rows are damage when
// they say DMG and not when they say Bonus/Cost/Duration, and rows that are
// alternatives of one another ("Skill DMG" / "Low HP Skill DMG") keep the
// strongest. Where the two disagree, one of them is wrong, and on the first
// character checked it was the transcription three times.

import Foundation

enum AbyssTalentReader {

    // MARK: - The grammar

    /// One placeholder with what follows it: `{param5:F1P} Max HP` → index 5,
    /// percent, basis HP.
    private struct Placeholder {
        let index: Int
        let isPercent: Bool
        let basis: ScalingBasis?
        /// A suffix that is a unit rather than a stat — "s", "/s", "per
        /// Fighting Spirit". Such a term is a rate or a duration, never a hit.
        let isRate: Bool
    }

    /// `#{LAYOUT_MOBILE#Tap}{LAYOUT_PC#Press}{LAYOUT_PS#Press} Skill DMG`: one
    /// word per platform. The PC wording is kept — the label reads "Press
    /// Skill DMG", which is what makes it a variant of "Hold Skill DMG".
    private static let layoutTag = try? NSRegularExpression(
        pattern: "#?\\{LAYOUT_([A-Z]+)#([^}]*)\\}")
    private static let placeholder = try? NSRegularExpression(
        pattern: "\\{param(\\d+):([A-Z0-9]+)\\}")
    /// A `/` that begins an alternative: followed by another placeholder or a
    /// bracket. A `/` followed by a unit ("/s", "/Point") is not one.
    private static let alternativeSplit = try? NSRegularExpression(
        pattern: "\\s*/\\s*(?=[({])")
    private static let wrappedMultiplier = try? NSRegularExpression(
        pattern: "^\\((.*)\\)\\s*[×x*]\\s*(\\d+)$")
    private static let termMultiplier = try? NSRegularExpression(
        pattern: "\\s*[×x*]\\s*(\\d+)$")

    /// What a suffix after a placeholder means. Checked longest-first, because
    /// "Max HP" contains "HP" and "Elemental Mastery" is what the game writes
    /// for EM.
    private static let bases: [(String, ScalingBasis)] = [
        ("Elemental Mastery", .em), ("Max HP", .hp), ("Current HP", .hp), ("HP", .hp),
        ("DEF", .def), ("ATK", .atk),
    ]
    /// A suffix that says the row is one instance of something that happens
    /// several times: Albedo's "Fatal Blossom DMG|{p} each", Diona's "Icy Paw
    /// DMG|{p} per Paw". Not a rate over a stat ("per Fighting Spirit", "per
    /// 100 Points") — those have a stat or a number in them and stay rates.
    private static func isPerInstance(_ suffix: String) -> Bool {
        if suffix == "each" { return true }
        guard suffix.hasPrefix("per ") else { return false }
        let rest = suffix.dropFirst(4)
        return !rest.contains(where: \.isNumber) && !bases.contains { rest.contains($0.0) }
            && !rest.contains("Spirit") && !rest.contains("Point")
    }

    /// Suffixes that are the element of the hit rather than its basis — the
    /// hit still scales off ATK. Physical is not modelled and lands on the
    /// character's element like everything else, which is the same reading
    /// the prose path gives it.
    private static let elementSuffixes = ["Pyro", "Hydro", "Electro", "Cryo", "Anemo", "Geo", "Dendro", "Physical"]

    private static func placeholderTerms(_ expression: String) -> [Placeholder]? {
        guard let placeholder else { return nil }
        let ns = expression as NSString
        let matches = placeholder.matches(in: expression, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return nil }

        var terms: [Placeholder] = []
        for (position, match) in matches.enumerated() {
            guard let index = Int(ns.substring(with: match.range(at: 1))) else { return nil }
            let format = ns.substring(with: match.range(at: 2))
            let end = match.range.location + match.range.length
            let next = position + 1 < matches.count ? matches[position + 1].range.location : ns.length
            var suffix = ns.substring(with: NSRange(location: end, length: next - end))
                .trimmingCharacters(in: .whitespaces)
            // The joiner to the next term is not part of this term's suffix.
            if suffix.hasSuffix("+") { suffix = String(suffix.dropLast()).trimmingCharacters(in: .whitespaces) }
            if let termMultiplier,
               let m = termMultiplier.firstMatch(in: suffix, range: NSRange(suffix.startIndex..., in: suffix)),
               let range = Range(m.range, in: suffix) {
                suffix = String(suffix[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }

            var basis: ScalingBasis?
            var isRate = false
            if suffix.isEmpty {
                basis = .atk
            } else if let known = bases.first(where: { suffix == $0.0 }) {
                basis = known.1
            } else if elementSuffixes.contains(suffix) {
                basis = .atk
            } else if isPerInstance(suffix) {
                // "each", "per Paw": one instance of a hit whose count lives
                // elsewhere in the kit. Read as one hit — the prose path did the
                // same — and reported, because one is a floor, not the answer.
                basis = .atk
            } else {
                isRate = true
            }
            terms.append(Placeholder(index: index, isPercent: format.hasSuffix("P"), basis: basis, isRate: isRate))
        }
        return terms
    }

    /// The multiplier a single alternative adds up to, per basis, or nil when
    /// the expression is not a hit (a duration, a rate, a count).
    private static func evaluate(_ alternative: String, params: [Double]) -> [ScalingBasis: Double]? {
        var body = alternative.trimmingCharacters(in: .whitespaces)
        var wrapper = 1.0
        if let wrappedMultiplier,
           let m = wrappedMultiplier.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)),
           let inner = Range(m.range(at: 1), in: body), let k = Range(m.range(at: 2), in: body) {
            wrapper = Double(body[k]) ?? 1
            body = String(body[inner])
        }
        guard let terms = placeholderTerms(body) else { return nil }
        // A hit is a percentage of a stat, every term of it. One duration or
        // rate anywhere in the expression makes the whole line something else.
        guard terms.allSatisfy({ $0.isPercent && !$0.isRate }) else { return nil }

        // Per-term ×k, read from the raw text between placeholders.
        let ns = body as NSString
        guard let placeholder else { return nil }
        let matches = placeholder.matches(in: body, range: NSRange(location: 0, length: ns.length))
        var totals: [ScalingBasis: Double] = [:]
        for (position, term) in terms.enumerated() {
            guard term.index >= 1, term.index <= params.count, let basis = term.basis else { return nil }
            let end = matches[position].range.location + matches[position].range.length
            let next = position + 1 < matches.count ? matches[position + 1].range.location : ns.length
            let between = ns.substring(with: NSRange(location: end, length: next - end))
            var multiplier = 1.0
            if let termMultiplier,
               let m = termMultiplier.firstMatch(in: between, range: NSRange(between.startIndex..., in: between)),
               let range = Range(m.range(at: 1), in: between) {
                multiplier = Double(between[range]) ?? 1
            }
            totals[basis, default: 0] += params[term.index - 1] * multiplier * wrapper
        }
        return totals
    }

    /// A line's damage per basis, taking the strongest of its alternatives —
    /// "Low/High Plunge DMG|{p1}/{p2}" style — the way the prose path reads
    /// "a% / b%". Nil when the line is not a hit at all.
    static func hit(in line: String, params: [Double]) -> [ScalingBasis: Double]? {
        guard let alternativeSplit else { return nil }
        let alternatives = alternativeSplit.stringByReplacingMatches(
            in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "\u{1F}")
            .split(separator: "\u{1F}").map(String.init)
        var best: [ScalingBasis: Double]?
        for alternative in alternatives {
            guard let totals = evaluate(alternative, params: params) else { continue }
            let sum = totals.values.reduce(0, +)
            if best == nil || sum > best!.values.reduce(0, +) { best = totals }
        }
        return best
    }

    // MARK: - The vocabulary

    /// A label naming something that is not a hit, whatever else it says.
    /// "Charged Attack Stamina Cost" says Charged Attack and is not one.
    private static let nonDamage = try? NSRegularExpression(
        pattern: "\\b(Bonus|Increase|Reduction|Ratio|Absorption|Shield|Heal|Healing|Regeneration|"
            + "Restored?|Cost|Duration|CD|Interval|Stamina|Loss|Inherited|Energy|Chance|Range|Radius|"
            + "Limit|Speed|SPD|Resistance|RES|Efficiency|Conversion|Consumption|Threshold|Charges|"
            + "Trigger|Multiplier|Scaling|per|each)\\b")
    /// A label that is a hit. "DoT" is the game's own word for a damage tick.
    private static let damage = try? NSRegularExpression(pattern: "\\b(DMG|DoT)\\b")
    /// A numbered hit — or, for the one catalyst whose whole string is a single
    /// hit (Ningguang), the bare "Normal Attack DMG". Anchored, so a stance's
    /// own numbered hits ("Blade Roller 1-Hit DMG") and a conditional
    /// ("Mid-Air Normal Attack DMG") do not join the combo; those are
    /// alternatives to it, and land in `unclassifiedRows` until a kit says
    /// which applies.
    private static let comboHit = try? NSRegularExpression(pattern: "^(\\d+-Hit DMG|Normal Attack DMG)$")
    private static let plunge = try? NSRegularExpression(pattern: "\\bPlunge\\b")
    /// Charged attacks as the game names them — anywhere in the label, since a
    /// stance puts its name first ("Fiery Passion Charged Attack DMG"), and
    /// every claymore's spin and finisher both say it. A per-character label
    /// from `character-traits.json` extends this, exactly as it extends the
    /// prose.
    private static let charged = try? NSRegularExpression(
        pattern: "\\b(Charged Attack|Aimed Shot)\\b")
    /// A word that makes a row one *alternative* of another row: "Skill DMG"
    /// and "Low HP Skill DMG" are the same hit on two sides of a threshold;
    /// "Prism Shot DMG" and "Prism Shot Stellar-Conduct DMG" are the same shot
    /// with and without a reaction; "Stack 3 Conductive Hold DMG" is one stack
    /// count of one hold. Only one of each set happens. Stripping the marker
    /// gives the stem the rows share.
    ///
    /// What this cannot see is a *stance* that renames a hit outright —
    /// Varesa's "Rush DMG" and "Fiery Passion Rush DMG", Bennett's "Press
    /// DMG" against "Charge Level 2 DMG" — because telling those apart is
    /// knowledge of the kit, not of the words. Those rows add, which
    /// over-counts a cast by one alternative; it is the same reading the prose
    /// path gave them, and the kit file of Phase 2 is where it gets fixed.
    private static let variantMarker = try? NSRegularExpression(
        pattern: "\\b(Low HP|High HP|Press|Hold|Tap|Max|Min|Level \\d+|\\d+[- ]?Stacks?|Stacks? \\d+|"
            + "Stellar-Conduct|Stellar Swirl|Lunar-[A-Za-z]+)\\b\\)?",
        options: [.caseInsensitive])

    private static func matches(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        guard let regex else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// The line with the platform layout tags gone and the label split off.
    static func split(_ line: String) -> (label: String, expression: String)? {
        guard let layoutTag else { return nil }
        var clean = line
        for match in layoutTag.matches(in: line, range: NSRange(line.startIndex..., in: line)).reversed() {
            guard let whole = Range(match.range, in: clean),
                  let platform = Range(match.range(at: 1), in: clean),
                  let word = Range(match.range(at: 2), in: clean) else { continue }
            clean.replaceSubrange(whole, with: clean[platform] == "PC" ? String(clean[word]) + " " : "")
        }
        clean = clean.split(separator: " ").joined(separator: " ")
        guard let bar = clean.firstIndex(of: "|") else { return nil }
        return (String(clean[..<bar]).trimmingCharacters(in: .whitespaces),
                String(clean[clean.index(after: bar)...]).trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Reading a talent

    /// Damage terms for a skill or burst at one level.
    static func abilityTerms(_ talent: AbyssTalentParams.Talent,
                             level: Int,
                             category: HitCategory,
                             characterID: String,
                             diagnostics: inout AbyssParseDiagnostics) -> [AbyssDamageProfile.Term] {
        guard let params = talent.params(atLevel: level) else { return [] }
        var terms: [AbyssDamageProfile.Term] = []
        // Rows that are alternatives of one another: stem -> the slice of
        // `terms` the current winner occupies, and its total.
        var alternatives: [String: (range: Range<Int>, total: Double)] = [:]

        for line in talent.lines(atLevel: level) {
            guard let (label, expression) = split(line) else { continue }
            // Plunges are dropped wherever they appear — a burst that turns
            // into a normal-attack stance lists one, and no rotation the model
            // assumes uses it, same as on the normal-attack table.
            guard matches(damage, label), !matches(nonDamage, label), !matches(plunge, label) else { continue }
            guard let totals = hit(in: expression, params: params) else {
                diagnostics.talentParamsUnread.insert("\(characterID): \(label)|\(expression)")
                continue
            }
            let ordered = totals.sorted { $0.key.rawValue < $1.key.rawValue }
                .map { AbyssDamageProfile.Term(multiplier: $0.value, basis: $0.key, category: category) }
            let total = totals.values.reduce(0, +)

            // Every row is keyed by its stem — the label with any variant
            // marker taken off — so "Skill DMG" and a later "Low HP Skill DMG"
            // meet in the same slot. A row with no marker is its own stem; two
            // rows can only collide if one is a marked variant of the other.
            guard let variantMarker else { terms += ordered; continue }
            let stem = variantMarker.stringByReplacingMatches(
                in: label, range: NSRange(label.startIndex..., in: label), withTemplate: " ")
                .split(separator: " ").joined(separator: " ").lowercased()
            if let incumbent = alternatives[stem] {
                if total > incumbent.total {
                    terms.replaceSubrange(incumbent.range, with: ordered)
                    alternatives[stem] = (incumbent.range.lowerBound..<incumbent.range.lowerBound + ordered.count, total)
                    // Later ranges shift; recompute by rebuilding is simpler
                    // than tracking, and this list is a dozen entries long.
                    let shift = ordered.count - incumbent.range.count
                    for (key, entry) in alternatives where entry.range.lowerBound > incumbent.range.lowerBound {
                        alternatives[key] = (entry.range.lowerBound + shift..<entry.range.upperBound + shift, entry.total)
                    }
                }
            } else {
                alternatives[stem] = (terms.count..<terms.count + ordered.count, total)
                terms += ordered
            }
        }
        return terms
    }

    /// The numbered hits of the normal-attack string, in order.
    static func comboTerms(_ talent: AbyssTalentParams.Talent, level: Int) -> [AbyssDamageProfile.Term] {
        guard let params = talent.params(atLevel: level) else { return [] }
        var terms: [AbyssDamageProfile.Term] = []
        for line in talent.lines(atLevel: level) {
            guard let (label, expression) = split(line), matches(comboHit, label),
                  let totals = hit(in: expression, params: params) else { continue }
            terms += totals.sorted { $0.key.rawValue < $1.key.rawValue }
                .map { AbyssDamageProfile.Term(multiplier: $0.value, basis: $0.key, category: .normal) }
        }
        return terms
    }

    /// The character's charged attack: one action, the best one, so a bow's
    /// plain and fully-charged shots do not both count.
    ///
    /// "Best" is by raw multiplier, which only means something between rows
    /// on the same basis — 246% of ATK against 14.5% of Max HP is not a
    /// comparison, and for Neuvillette the second is four times the damage.
    /// So a row a `character-traits.json` label names wins outright over the
    /// generic vocabulary: that label exists precisely to say which row *is*
    /// this character's charged attack. The multiplier decides only among
    /// rows of the same standing.
    static func chargedTerms(_ talent: AbyssTalentParams.Talent,
                             level: Int,
                             extraLabels: [String]) -> [AbyssDamageProfile.Term] {
        guard let params = talent.params(atLevel: level) else { return [] }
        var best: (named: Bool, total: Double, terms: [AbyssDamageProfile.Term])?
        for line in talent.lines(atLevel: level) {
            guard let (label, expression) = split(line) else { continue }
            let named = extraLabels.contains { label.range(of: $0, options: .caseInsensitive) != nil }
            guard named || matches(charged, label), !matches(nonDamage, label),
                  let totals = hit(in: expression, params: params) else { continue }
            let total = totals.values.reduce(0, +)
            let outranks = best.map { (named && !$0.named) || (named == $0.named && total > $0.total) } ?? true
            if outranks {
                best = (named, total, totals.sorted { $0.key.rawValue < $1.key.rawValue }
                    .map { AbyssDamageProfile.Term(multiplier: $0.value, basis: $0.key, category: .charged) })
            }
        }
        return best?.terms ?? []
    }

    /// Normal-attack rows that are hits and landed in no bucket — the
    /// structured counterpart of `AbyssTextParser.unclassifiedNormalAttackRows`.
    static func unclassifiedRows(_ talent: AbyssTalentParams.Talent,
                                 level: Int,
                                 characterID: String,
                                 extraLabels: [String]) -> [String] {
        guard let params = talent.params(atLevel: level) else { return [] }
        return talent.lines(atLevel: level).compactMap { line in
            guard let (label, expression) = split(line) else { return nil }
            if matches(comboHit, label) || matches(charged, label) || matches(plunge, label)
                || matches(nonDamage, label) || !matches(damage, label) { return nil }
            if extraLabels.contains(where: { label.range(of: $0, options: .caseInsensitive) != nil }) { return nil }
            guard hit(in: expression, params: params) != nil else { return nil }
            return "\(characterID): \(label)"
        }
    }
}
