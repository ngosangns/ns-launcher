// AbyssFloorContext.swift
//
// Collapses one Abyss floor — three chambers of waves of monsters — into the
// handful of numbers the scorer needs: how tough the enemies are, what they
// resist, what shields must be broken, and which buffs the floor grants.

import Foundation

struct AbyssFloorContext: Sendable {
    let floor: Int
    /// Which half of the floor this describes: 1 for the first team's fight, 2
    /// for the second's, nil for the floor taken as one.
    ///
    /// A half, not a floor, is what a team is actually scored against. Both
    /// halves have to be cleared, by two teams that share nobody, and they are
    /// not the same fight — different enemies, and this rotation different Ley
    /// Line Disorders.
    var half: Int?
    /// Mean level across the floor's chambers. All three must be cleared, so
    /// the average is a fairer basis for the DEF multiplier than either extreme.
    let monsterLevel: Int
    /// Only elements the data actually mentions; everything else falls back to
    /// the 10% baseline from `damage-formula.json`.
    let resistances: [GenshinElement: Double]
    let buffs: [AbyssFloorBuff]
    /// Elemental shields present on the floor, sorted for stable output.
    let shieldElements: [GenshinElement]

    /// Enemies default to 10% resistance to everything unless the data says
    /// otherwise — see `damage-formula.json`, `resMultiplier`.
    static let defaultResistance = 0.10

    func resistance(for element: GenshinElement) -> Double {
        resistances[element] ?? Self.defaultResistance
    }

    /// Elements this floor's enemies are *weaker* than baseline against.
    var weakElements: [GenshinElement] {
        resistances
            .filter { $0.value < Self.defaultResistance }
            .keys
            .sorted { $0.rawValue < $1.rawValue }
    }

    /// Which elements break which elemental shield.
    static let shieldCounters: [GenshinElement: [GenshinElement]] = [
        .cryo: [.pyro],
        .pyro: [.hydro],
        .electro: [.cryo, .hydro],
        .hydro: [.electro, .cryo],
        .geo: [.dendro, .anemo],
        .anemo: [.anemo],
        .dendro: [.pyro],
    ]

    /// Elements that would break at least one shield on this floor.
    var shieldBreakingElements: Set<GenshinElement> {
        Set(shieldElements.flatMap { Self.shieldCounters[$0] ?? [] })
    }

    private static let shieldHint = try? NSRegularExpression(
        pattern: "khiên\\s+([A-Za-zÀ-ỹ]+)", options: [.caseInsensitive])

    /// Whether this floor is fought as two halves.
    ///
    /// The data records a chamber's two halves as its two waves — chamber 1 of
    /// floor 12 lists the Ruin machines the first team meets and the Icewind
    /// Suite the second one does. A chamber recorded any other way cannot be
    /// taken apart that way, so a floor holding one is planned whole rather
    /// than split down a line that was guessed at.
    static func splitsIntoHalves(_ floor: AbyssCycle.Floor) -> Bool {
        !floor.chambers.isEmpty && floor.chambers.allSatisfy { $0.waves.count == 2 }
    }

    /// The waves one half fights, or all of them when the floor is taken whole.
    private static func waves(of chamber: AbyssCycle.Chamber, half: Int?) -> [AbyssCycle.Wave] {
        guard let half, chamber.waves.count == 2 else { return chamber.waves }
        let ordered = chamber.waves.sorted { $0.wave < $1.wave }
        return [ordered[min(max(half, 1), ordered.count) - 1]]
    }

    /// - Parameter ownElementResistance: what an enemy resists the element it
    ///   attacks or shields with at. `AbyssTuning.enemyOwnElementResistance`;
    ///   pass `defaultResistance` to leave enemy elements out of the model.
    static func build(cycle: AbyssCycle,
                      floor floorNumber: Int,
                      half: Int? = nil,
                      ownElementResistance: Double,
                      diagnostics: inout AbyssParseDiagnostics) -> AbyssFloorContext? {
        guard let floor = cycle.floors.first(where: { $0.floor == floorNumber }) else { return nil }

        var levels: [Int] = []
        var resistanceSamples: [GenshinElement: [Double]] = [:]
        var shields: Set<GenshinElement> = []

        for chamber in floor.chambers {
            if let level = chamber.monsterLevel { levels.append(level) }
            for wave in waves(of: chamber, half: half) {
                for monster in wave.monsters {
                    var spokenFor: Set<GenshinElement> = []
                    for (target, delta) in AbyssTextParser.resistanceNotes(monster.resistanceNotes,
                                                                          diagnostics: &diagnostics) {
                        // Physical resistance is parsed but not modelled: no
                        // character has Physical as their element, so it never
                        // reaches the damage calculation.
                        if case .element(let element) = target {
                            resistanceSamples[element, default: []].append(defaultResistance + delta)
                            spokenFor.insert(element)
                        }
                    }

                    // An enemy resists what it throws. The data does not say so
                    // — `elements` is documented as the elements a monster
                    // attacks or shields *with* — and it does not say anything
                    // else either: on floor 12 this rotation not one monster
                    // carries a resistance note, so without this every element
                    // sat at the 10% baseline and bringing Cryo against a Cryo
                    // Abyss Mage cost a team nothing. Only for elements this
                    // monster's own note did not already price, so a note and
                    // the inference never count twice.
                    for raw in monster.elements {
                        guard let element = GenshinElement(rawValue: raw),
                              !spokenFor.contains(element) else { continue }
                        resistanceSamples[element, default: []].append(ownElementResistance)
                    }
                    shields.formUnion(shieldElements(in: monster))
                }
            }
        }

        let resistances = resistanceSamples.compactMapValues { samples -> Double? in
            samples.isEmpty ? nil : samples.reduce(0, +) / Double(samples.count)
        }

        // Ley Line Disorder is per-floor; the Blessing of the Abyssal Moon
        // applies to the whole Abyss for the cycle, so every floor gets it.
        //
        // The blessing is read from `relatedMechanic` as well as `description`,
        // and that is where its numbers actually live: the description is
        // flavour prose about what the mechanic does, while the percentages a
        // team can be scored on ("+20% sát thương Cryo/Electro" for characters
        // inside the field) are written into the mechanic note. Parsing only
        // the description meant the blessing contributed nothing at all — the
        // model quietly scored every floor as if the cycle had no blessing.
        //
        // The disorder itself can differ between the two halves, and this
        // rotation's floor 12 is written that way. Parsing the sentence whole
        // and handing the result to both teams gave a Cryo/Electro first-half
        // team the second half's Pyro normal-attack bonus as well.
        let leyLine = half.flatMap { AbyssTextParser.leyLineHalves(floor.leyLineDisorder)[$0] }
            ?? floor.leyLineDisorder
        var buffs = AbyssTextParser.floorBuffs(leyLine, source: .leyLine,
                                               diagnostics: &diagnostics)
        let blessing = cycle.blessingOfTheAbyssalMoon
        var blessingBuffs = AbyssTextParser.floorBuffs(blessing.description, source: .blessing,
                                                       diagnostics: &diagnostics)
        blessingBuffs += AbyssTextParser.floorBuffs(blessing.relatedMechanic, source: .blessing,
                                                    diagnostics: &diagnostics)
        // The two fields overlap in wording often enough that the same clause
        // can be parsed twice; counting it twice would double the bonus.
        var seen: Set<String> = []
        buffs += blessingBuffs.filter { seen.insert($0.raw).inserted }

        // A buff that names only reactions the damage model cannot price has
        // nowhere to go. Say so rather than let it evaporate: this rotation's
        // Stellar-Conduct clauses are exactly that, and until they were pulled
        // out of the direct-damage path they were silently worth +75% to every
        // hit a Cryo/Electro team made.
        for buff in buffs where !buff.reactions.isEmpty {
            let pricable = buff.reactions.contains { reaction in
                reaction.transformativeKey != nil || reaction.lunarStellarKey != nil
                    || reaction == .vaporize || reaction == .melt
            }
            if !pricable { diagnostics.floorBuffsNotPriced.insert(buff.raw) }
        }

        // Rounded half-to-even, which is what the golden fixture's numbers were
        // produced with. Swift's default `.rounded()` rounds halves away from
        // zero, which would differ on a floor whose chamber levels average to
        // exactly .5 — no such floor exists today, so the difference would first
        // appear on a future rotation with nothing to point at it.
        let meanLevel = levels.isEmpty
            ? 90
            : Int((Double(levels.reduce(0, +)) / Double(levels.count)).rounded(.toNearestOrEven))

        // Monster level is a property of the chamber, so both halves of a floor
        // are fought at the same level.
        return AbyssFloorContext(
            floor: floorNumber,
            half: half,
            monsterLevel: meanLevel,
            resistances: resistances,
            buffs: buffs,
            shieldElements: shields.sorted { $0.rawValue < $1.rawValue })
    }

    /// Elemental shields named in a monster's mechanics or resistance notes.
    private static func shieldElements(in monster: AbyssCycle.Monster) -> Set<GenshinElement> {
        let text = [monster.mechanics, monster.resistanceNotes]
            .compactMap { $0 }
            .joined(separator: " ")
        guard !text.isEmpty, let shieldHint else { return [] }

        let nsText = text as NSString
        var found: Set<GenshinElement> = []
        for match in shieldHint.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { continue }
            if case .element(let element)? = AbyssTextParser.resistanceTarget(fromToken: nsText.substring(with: range)) {
                found.insert(element)
            }
        }
        return found
    }
}
