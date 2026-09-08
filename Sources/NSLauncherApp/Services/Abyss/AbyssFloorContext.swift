// AbyssFloorContext.swift
//
// Collapses one Abyss floor — three chambers of waves of monsters — into the
// handful of numbers the scorer needs: how tough the enemies are, what they
// resist, what shields must be broken, and which buffs the floor grants.
// Ported from `build_floor_context` in the Python's `scoring.py`.

import Foundation

struct AbyssFloorContext: Sendable {
    let floor: Int
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

    static func build(cycle: AbyssCycle,
                      floor floorNumber: Int,
                      diagnostics: inout AbyssParseDiagnostics) -> AbyssFloorContext? {
        guard let floor = cycle.floors.first(where: { $0.floor == floorNumber }) else { return nil }

        var levels: [Int] = []
        var resistanceSamples: [GenshinElement: [Double]] = [:]
        var shields: Set<GenshinElement> = []

        for chamber in floor.chambers {
            if let level = chamber.monsterLevel { levels.append(level) }
            for wave in chamber.waves {
                for monster in wave.monsters {
                    for (target, delta) in AbyssTextParser.resistanceNotes(monster.resistanceNotes,
                                                                          diagnostics: &diagnostics) {
                        // Physical resistance is parsed but not modelled: no
                        // character has Physical as their element, so it never
                        // reaches the damage calculation.
                        if case .element(let element) = target {
                            resistanceSamples[element, default: []].append(defaultResistance + delta)
                        }
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
        var buffs = AbyssTextParser.floorBuffs(floor.leyLineDisorder, diagnostics: &diagnostics)
        buffs += AbyssTextParser.floorBuffs(cycle.blessingOfTheAbyssalMoon.description, diagnostics: &diagnostics)

        // Rounded half-to-even to match the reference implementation. Swift's
        // default `.rounded()` rounds halves away from zero, which would differ
        // on a floor whose chamber levels average to exactly .5 — no such floor
        // exists today, so the difference would first appear on a future
        // rotation with nothing to point at it.
        let meanLevel = levels.isEmpty
            ? 90
            : Int((Double(levels.reduce(0, +)) / Double(levels.count)).rounded(.toNearestOrEven))

        return AbyssFloorContext(
            floor: floorNumber,
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
