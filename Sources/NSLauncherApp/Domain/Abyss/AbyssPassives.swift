// AbyssPassives.swift
//
// Weapon passives and artifact set bonuses as structured buffs, Phase 5 of
// `docs/redesign.md`.
//
// Two files, split the way `character-kits.json` and `talent-params.json` are:
// `passive-text.json` is the game's text with its numbers at every refinement
// (generated from Yatta), `passives.json` is what each effect means (written by
// hand). A value in the second is the R1 number as the text writes it, and
// resolving it means finding the column of the first whose R1 it is — so a
// number is only ever read from the game, and a reference that points at
// nothing is reported instead of priced.
//
// What an effect is worth over a rotation — how often its trigger fires, how
// many stacks it holds on average — is not here: see `AbyssBuffTimeline`.

import Foundation

/// Decodable mirror of `Resources/Abyss/passive-text.json`.
struct AbyssPassiveText: Decodable, Sendable {
    /// One number the game tags as changing with refinement, R1–R5; or, for a
    /// tag that holds a list ("8/16/28%"), its text at each refinement.
    enum Column: Decodable, Sendable {
        case numbers([Double])
        case strings([String])

        init(from decoder: Decoder) throws {
            if let numbers = try? [Double](from: decoder) {
                self = .numbers(numbers)
            } else {
                self = .strings(try [String](from: decoder))
            }
        }
    }

    struct Weapon: Decodable, Sendable {
        let text: String
        let values: [Column]
    }

    struct ArtifactSet: Decodable, Sendable {
        let twoPiece: String?
        let fourPiece: String
    }

    let weapons: [String: Weapon]
    let sets: [String: ArtifactSet]
}

/// Decodable mirror of `Resources/Abyss/passives.json`.
struct AbyssPassiveKnowledge: Decodable, Sendable {
    struct Trigger: Decodable, Sendable {
        let kind: String
        let by: [String]?
        let elemental: Bool?
        let seconds: Double?
        let elements: [String]?
        let reactions: [String]?
        let percent: Double?
        let level: Int?
        let match: String?
        let atLeast: Int?
        let below: Int?
        let includeWearer: Bool?
        let types: [String]?
        let reason: String?
    }

    /// One condition, or a list that must all hold.
    struct Triggers: Decodable, Sendable {
        let all: [Trigger]

        init(from decoder: Decoder) throws {
            if let list = try? [Trigger](from: decoder) {
                all = list
            } else {
                all = [try Trigger(from: decoder)]
            }
        }
    }

    struct Effect: Decodable, Sendable {
        let stat: String
        let value: Double?
        let column: Int?
        let tiers: [Double]?
        let cap: Double?
        let from: String?
        let per: Double?
        let on: [String]?
        let scope: String?
        let trigger: Triggers?
        let duration: Double?
        let stacks: Int?
        let cooldown: Double?
        let scale: Double?
        let group: String?
    }

    struct Weapon: Decodable, Sendable {
        let effects: [Effect]
    }

    struct ArtifactSet: Decodable, Sendable {
        let twoPiece: [Effect]
        let fourPiece: [Effect]
    }

    let weapons: [String: Weapon]
    let sets: [String: ArtifactSet]
}

/// One buff, resolved against the game text.
struct AbyssBuff: Sendable, Equatable {
    enum Stat: Sendable, Equatable {
        case atkPercent, hpPercent, defPercent, flatATK
        case elementalMastery, energyRecharge, critRate, critDMG
        /// A bonus to every hit's damage: "DMG", "All Elemental DMG Bonus".
        case dmg
        /// The wearer's own element.
        case ownElementDMG
        case elementDMG(GenshinElement)
    }

    /// The wearer's stat a rate is taken of.
    enum Source: String, Sendable, Equatable {
        case em, hp, def, atk, er
        case erOver100 = "er-over-100"
    }

    enum Scope: String, Sendable, Equatable {
        case wearer = "self"
        case party, others, active
    }

    struct Actions: OptionSet, Sendable, Hashable {
        let rawValue: UInt8
        static let normal = Actions(rawValue: 1)
        static let charged = Actions(rawValue: 2)
        static let plunge = Actions(rawValue: 4)
        static let skill = Actions(rawValue: 8)
        static let burst = Actions(rawValue: 16)

        init(rawValue: UInt8) { self.rawValue = rawValue }

        init?(names: [String]) {
            var actions = Actions()
            for name in names {
                switch name {
                case "normal": actions.insert(.normal)
                case "charged": actions.insert(.charged)
                case "plunge": actions.insert(.plunge)
                case "skill": actions.insert(.skill)
                case "burst": actions.insert(.burst)
                default: return nil
                }
            }
            self = actions
        }

        func reaches(_ category: HitCategory) -> Bool {
            switch category {
            case .normal: return contains(Actions.normal)
            case .charged: return contains(Actions.charged)
            case .skill: return contains(Actions.skill)
            case .burst: return contains(Actions.burst)
            }
        }
    }

    enum Match: Sendable, Equatable {
        case sameElement, otherElement, natlanOrOtherElement, liyue
        case element(GenshinElement)
    }

    enum Condition: Sendable, Equatable {
        /// Using those actions. Empty for none the model has.
        case cast(Actions)
        /// Hits of those actions; empty for any hit. `elemental`: only hits
        /// that deal Elemental DMG.
        case hit(Actions, elemental: Bool)
        case every(Double)
        case onField, offField, swapIn
        case aura([GenshinElement])
        case reaction
        case shield, healed, heals, hpChange
        case hpAbove, hpBelow
        case bondOfLife, nightsoul, crystallize
        case moonsign(Int)
        case hexerei
        case partyMembers(Match, atLeast: Int?, includeWearer: Bool)
        case distinctElements(atLeast: Int)
        case weaponType([String])
        case energyFull, energyEmpty
        case enemiesAtLeast(Int), enemiesBelow(Int)
        case defeat
        case unmodelled
    }

    let stat: Stat
    /// Per refinement, R1 first; a set has one.
    let values: [Double]
    /// Per refinement, the value at 1, 2, 3… stacks. Empty unless tiered.
    let tiers: [[Double]]
    let caps: [Double]
    let source: Source?
    let per: Double
    /// Empty for every hit.
    let on: Actions
    let scope: Scope
    /// Every one must hold.
    let conditions: [Condition]
    let duration: Double?
    let stacks: Int
    let cooldown: Double?
    let scale: Double
    let group: String?

    func value(refinement: Int) -> Double {
        pick(values, refinement) * scale
    }

    func tiers(refinement: Int) -> [Double] {
        tiers.isEmpty ? [] : pick(tiers, refinement).map { $0 * scale }
    }

    func cap(refinement: Int) -> Double? {
        caps.isEmpty ? nil : pick(caps, refinement)
    }

    private func pick<T>(_ list: [T], _ refinement: Int) -> T {
        list[min(max(refinement, 1), list.count) - 1]
    }

    var isAlwaysOn: Bool { conditions.isEmpty }
}

/// Reads `passives.json` against `passive-text.json`.
enum AbyssPassiveResolver {
    /// Every weapon's buffs and every set's, by id, plus a line per reference
    /// that did not resolve.
    static func resolve(knowledge: AbyssPassiveKnowledge, text: AbyssPassiveText)
        -> (weapons: [String: [AbyssBuff]], sets: [String: (twoPiece: [AbyssBuff], fourPiece: [AbyssBuff])],
            unresolved: Set<String>) {
        var unresolved: Set<String> = []
        var weapons: [String: [AbyssBuff]] = [:]
        for (id, entry) in knowledge.weapons {
            guard let source = text.weapons[id] else {
                unresolved.insert("\(id): no such weapon in passive-text.json")
                continue
            }
            weapons[id] = entry.effects.enumerated().compactMap { index, effect in
                resolve(effect, where: "\(id)[\(index)]", text: source.text, columns: source.values,
                        unresolved: &unresolved)
            }
        }
        for id in text.weapons.keys where knowledge.weapons[id] == nil {
            unresolved.insert("\(id): weapon has game text but no entry in passives.json")
        }

        var sets: [String: (twoPiece: [AbyssBuff], fourPiece: [AbyssBuff])] = [:]
        for (id, entry) in knowledge.sets {
            guard let source = text.sets[id] else {
                unresolved.insert("\(id): no such set in passive-text.json")
                continue
            }
            let two = entry.twoPiece.enumerated().compactMap { index, effect in
                resolve(effect, where: "\(id).twoPiece[\(index)]", text: source.twoPiece ?? "", columns: nil,
                        unresolved: &unresolved)
            }
            let four = entry.fourPiece.enumerated().compactMap { index, effect in
                resolve(effect, where: "\(id).fourPiece[\(index)]", text: source.fourPiece, columns: nil,
                        unresolved: &unresolved)
            }
            sets[id] = (two, four)
        }
        for id in text.sets.keys where knowledge.sets[id] == nil {
            unresolved.insert("\(id): set has game text but no entry in passives.json")
        }
        return (weapons, sets, unresolved)
    }

    // MARK: - One effect

    static func resolve(_ effect: AbyssPassiveKnowledge.Effect, where place: String, text: String,
                        columns: [AbyssPassiveText.Column]?, unresolved: inout Set<String>) -> AbyssBuff? {
        func fail(_ reason: String) -> AbyssBuff? {
            unresolved.insert("\(place): \(reason)")
            return nil
        }
        let numbers = Self.numbers(in: text)
        func inText(_ value: Double) -> Bool { numbers.contains { abs($0 - value) < 1e-6 } }

        guard let stat = stat(effect.stat) else { return fail("unknown stat \(effect.stat)") }
        var source: AbyssBuff.Source?
        if let from = effect.from {
            guard let parsed = AbyssBuff.Source(rawValue: from) else { return fail("unknown from \(from)") }
            source = parsed
        }
        guard let on = AbyssBuff.Actions(names: effect.on ?? []) else { return fail("unknown action in on") }
        guard let scope = AbyssBuff.Scope(rawValue: effect.scope ?? "self") else {
            return fail("unknown scope \(effect.scope ?? "")")
        }
        for (name, number) in [("duration", effect.duration), ("cooldown", effect.cooldown), ("per", effect.per),
                               ("scale", effect.scale), ("stacks", effect.stacks.map(Double.init))] {
            if let number, !inText(number) { return fail("\(name) \(number) is not in the text") }
        }

        var values: [Double] = []
        var tiers: [[Double]] = []
        if let tierList = effect.tiers {
            if let columns {
                guard let index = effect.column, index < columns.count,
                      case .strings(let strings) = columns[index] else {
                    return fail("tiers need a column holding a list")
                }
                let parsed = strings.map(Self.list)
                guard let first = parsed.first, first.count == tierList.count,
                      zip(first, tierList).allSatisfy({ abs($0 - $1) < 1e-6 }) else {
                    return fail("tiers \(tierList) are not column \(index)")
                }
                tiers = parsed
            } else {
                // A set has one refinement: its tiers are the numbers written.
                guard tierList.allSatisfy(inText) else { return fail("tiers \(tierList) are not in the text") }
                tiers = [tierList]
            }
        } else {
            guard let value = effect.value else { return fail("no value") }
            guard let resolved = Self.column(for: value, explicit: effect.column, columns: columns, inText: inText)
            else { return fail("value \(value) is in no column of the text") }
            values = resolved
        }
        var caps: [Double] = []
        if let cap = effect.cap {
            guard let resolved = Self.column(for: cap, explicit: nil, columns: columns, inText: inText) else {
                return fail("cap \(cap) is in no column of the text")
            }
            caps = resolved
        }

        // "Increased by 10% until it reaches 60%": a cap on a buff that is not a
        // rate is a stack count the text writes as a total.
        var cappedStacks: Int?
        if source == nil, let cap = effect.cap, let value = effect.value, value > 0 {
            cappedStacks = Int((cap / value).rounded())
        }

        var conditions: [AbyssBuff.Condition] = []
        for trigger in effect.trigger?.all ?? [] {
            guard let condition = condition(trigger, inText: inText) else {
                return fail("trigger \(trigger.kind) is not understood")
            }
            conditions.append(condition)
        }
        return AbyssBuff(stat: stat, values: values, tiers: tiers, caps: caps, source: source,
                         per: effect.per ?? 1, on: on, scope: scope, conditions: conditions,
                         duration: effect.duration, stacks: max(effect.stacks ?? tiers.first?.count ?? cappedStacks ?? 1, 1),
                         cooldown: effect.cooldown, scale: effect.scale ?? 1, group: effect.group)
    }

    /// R1–R5 for a value: the column whose R1 it is, or — for a number that
    /// does not change with refinement, and for sets — the number itself.
    private static func column(for value: Double, explicit: Int?, columns: [AbyssPassiveText.Column]?,
                               inText: (Double) -> Bool) -> [Double]? {
        let magnitude = abs(value)
        let sign: Double = value < 0 ? -1 : 1
        if let columns {
            let numeric = columns.enumerated().compactMap { index, column -> (Int, [Double])? in
                if case .numbers(let numbers) = column, let first = numbers.first,
                   abs(first - magnitude) < 1e-6 { return (index, numbers) }
                return nil
            }
            if let explicit {
                return numeric.first { $0.0 == explicit }.map { $0.1.map { $0 * sign } }
            }
            let distinct = Set(numeric.map { $0.1.map { ($0 * 1e6).rounded() } })
            if distinct.count == 1, let match = numeric.first { return match.1.map { $0 * sign } }
            if distinct.count > 1 { return nil }
        }
        return inText(magnitude) ? [value] : nil
    }

    private static func condition(_ trigger: AbyssPassiveKnowledge.Trigger,
                                  inText: (Double) -> Bool) -> AbyssBuff.Condition? {
        let actions = AbyssBuff.Actions(names: trigger.by ?? [])
        switch trigger.kind {
        case "cast": return actions.map { .cast($0) }
        case "hit": return actions.map { .hit($0, elemental: trigger.elemental ?? false) }
        case "every":
            guard let seconds = trigger.seconds, inText(seconds) else { return nil }
            return .every(seconds)
        case "on-field": return .onField
        case "off-field": return .offField
        case "swap-in": return .swapIn
        case "aura":
            let elements = (trigger.elements ?? []).compactMap(element)
            guard !elements.isEmpty, elements.count == trigger.elements?.count else { return nil }
            return .aura(elements)
        case "reaction": return .reaction
        case "shield": return .shield
        case "healed": return .healed
        case "heals": return .heals
        case "hp-change": return .hpChange
        case "hp-above": return .hpAbove
        case "hp-below": return .hpBelow
        case "bond-of-life": return .bondOfLife
        case "nightsoul": return .nightsoul
        case "crystallize": return .crystallize
        case "moonsign": return .moonsign(trigger.level ?? 1)
        case "hexerei": return .hexerei
        case "party-members":
            let match: AbyssBuff.Match
            switch trigger.match {
            case "same-element": match = .sameElement
            case "other-element": match = .otherElement
            case "natlan-or-other-element": match = .natlanOrOtherElement
            case "liyue": match = .liyue
            case let name?:
                guard let element = element(name) else { return nil }
                match = .element(element)
            case nil: return nil
            }
            return .partyMembers(match, atLeast: trigger.atLeast, includeWearer: trigger.includeWearer ?? false)
        case "distinct-elements":
            guard let atLeast = trigger.atLeast else { return nil }
            return .distinctElements(atLeast: atLeast)
        case "weapon-type": return .weaponType(trigger.types ?? [])
        case "energy-full": return .energyFull
        case "energy-empty": return .energyEmpty
        case "enemies":
            if let atLeast = trigger.atLeast { return .enemiesAtLeast(atLeast) }
            if let below = trigger.below { return .enemiesBelow(below) }
            return nil
        case "defeat": return .defeat
        case "unmodelled": return .unmodelled
        default: return nil
        }
    }

    private static func stat(_ name: String) -> AbyssBuff.Stat? {
        switch name {
        case "atk%": return .atkPercent
        case "hp%": return .hpPercent
        case "def%": return .defPercent
        case "flat-atk": return .flatATK
        case "em": return .elementalMastery
        case "er": return .energyRecharge
        case "crit-rate": return .critRate
        case "crit-dmg": return .critDMG
        case "dmg": return .dmg
        case "own-element-dmg": return .ownElementDMG
        default:
            guard name.hasSuffix("-dmg"), let element = element(String(name.dropLast(4))) else { return nil }
            return .elementDMG(element)
        }
    }

    private static func element(_ name: String) -> GenshinElement? {
        GenshinElement.allCases.first { $0.rawValue.lowercased() == name }
    }

    /// Every number written in a text, as written and as a fraction when it
    /// carries a percent sign: "16%" → 16 and 0.16, "1,000" → 1000.
    static func numbers(in text: String) -> [Double] {
        var found: [Double] = []
        let pattern = try! NSRegularExpression(pattern: "(\\d[\\d,]*(?:\\.\\d+)?)(%?)")
        let range = NSRange(text.startIndex..., in: text)
        for match in pattern.matches(in: text, range: range) {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let value = Double(text[numberRange].replacingOccurrences(of: ",", with: "")) else { continue }
            found.append(value)
            if match.range(at: 2).length > 0 { found.append(value / 100) }
        }
        return found
    }

    /// "10/20/30/48%" → [0.1, 0.2, 0.3, 0.48]; a percent sign anywhere makes
    /// every number a percentage.
    static func list(_ text: String) -> [Double] {
        let percent = text.contains("%")
        return text.split(whereSeparator: { !"0123456789.".contains($0) })
            .compactMap { Double($0) }
            .map { percent ? $0 / 100 : $0 }
    }
}
