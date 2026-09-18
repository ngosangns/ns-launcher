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
    /// Mean level across the floor's chambers, weighted by the HP each holds
    /// when the data gives it: time is spent where the HP is, and that is where
    /// the DEF multiplier applies.
    let monsterLevel: Int
    /// Only elements the data actually mentions; everything else falls back to
    /// the 10% baseline from `damage-formula.json`.
    let resistances: [GenshinElement: Double]
    let buffs: [AbyssFloorBuff]
    /// Elemental shields present on the floor, sorted for stable output.
    let shieldElements: [GenshinElement]
    /// All the HP this fight holds — see `AbyssEnemyHP.swift` — or nil when
    /// any monster in it has none in the data.
    var enemyHP: Double?

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
                      enemyHP table: AbyssEnemyHPTable? = nil,
                      diagnostics: inout AbyssParseDiagnostics) -> AbyssFloorContext? {
        guard let floor = cycle.floors.first(where: { $0.floor == floorNumber }) else { return nil }

        // HP first: when every monster in the fight has it, resistances and
        // level are weighted by it, because time is spent in proportion to HP
        // — a 3.8M-HP wave of Ruin Scouts is most of that half's fight, not one
        // line in six. When any monster lacks it, every monster weighs the same,
        // as before.
        var totalHP: Double? = 0
        for chamber in floor.chambers {
            for wave in waves(of: chamber, half: half) {
                for monster in wave.monsters {
                    guard let hp = monster.totalHP(level: chamber.monsterLevel,
                                                   multiplier: floor.enemyHPMultiplier, table: table) else {
                        totalHP = nil
                        continue
                    }
                    totalHP = totalHP.map { $0 + hp }
                }
            }
        }
        if totalHP == nil {
            diagnostics.fightHPUnknown.insert("floor \(floorNumber)" + (half.map { " half \($0)" } ?? ""))
        }

        var levels: [(level: Int, weight: Double)] = []
        var resistanceSamples: [GenshinElement: [(value: Double, weight: Double)]] = [:]
        var shields: Set<GenshinElement> = []

        for chamber in floor.chambers {
            var chamberHP = 0.0
            for wave in waves(of: chamber, half: half) {
                for monster in wave.monsters {
                    chamberHP += monster.totalHP(level: chamber.monsterLevel, multiplier: floor.enemyHPMultiplier,
                                                 table: table) ?? 0
                }
            }
            if let level = chamber.monsterLevel { levels.append((level, totalHP == nil ? 1 : chamberHP)) }
            for wave in waves(of: chamber, half: half) {
                for monster in wave.monsters {
                    let weight = totalHP == nil ? 1
                        : monster.totalHP(level: chamber.monsterLevel, multiplier: floor.enemyHPMultiplier,
                                          table: table) ?? 0
                    // Three sources, in this order, and a monster's own
                    // resistance is settled the moment the first of them
                    // speaks for a given element:
                    //
                    //   1. `resistanceNotes`, transcribed from the wiki. Can
                    //      state a resistance the game's static files cannot
                    //      — "rất yếu Pyro (pyro_res -220% khi 'Rooted')" is a
                    //      combat *state*, not the monster's base stat, and
                    //      only a person watching the fight could write it
                    //      down.
                    //   2. `resistances`, this monster's real base resistance
                    //      table, written by
                    //      `scripts/sync-abyss-monster-resistance.py` straight
                    //      from the game's own files.
                    //   3. The flat inference: assume `ownElementResistance`
                    //      more, for a monster (2) has not been matched for
                    //      yet. Used to be the *only* source, and checking it
                    //      against (2) for this rotation's floor 12 is what
                    //      showed it wrong in both directions at once: a flat
                    //      +30pp invented a bonus the Cryo Abyss Mage does not
                    //      have, and understated the Icewind Suite's real
                    //      +60pp by half.
                    //
                    // (2) and (3) both still only speak for an element the
                    // monster's own `elements` names — the set of elements
                    // this floor's resistance is even asked about does not
                    // change, only how well each answer is informed. A
                    // matched monster's real table is complete (every one of
                    // the seven elements is in it, including the ones sitting
                    // at the 10% baseline — "this monster does not specially
                    // resist Dendro" is itself real information), but only
                    // the elements it is already on record as attacking or
                    // shielding with draw on that completeness here.
                    var spokenFor: Set<GenshinElement> = []
                    for (target, delta) in AbyssTextParser.resistanceNotes(monster.resistanceNotes,
                                                                          diagnostics: &diagnostics) {
                        // Physical resistance is parsed but not modelled: no
                        // character has Physical as their element, so it never
                        // reaches the damage calculation.
                        if case .element(let element) = target {
                            resistanceSamples[element, default: []].append((defaultResistance + delta, weight))
                            spokenFor.insert(element)
                        }
                    }

                    for raw in monster.elements {
                        guard let element = GenshinElement(rawValue: raw),
                              !spokenFor.contains(element) else { continue }
                        resistanceSamples[element, default: []].append(
                            (monster.resistances?[raw] ?? ownElementResistance, weight))
                    }
                    shields.formUnion(shieldElements(in: monster))
                }
            }
        }

        let resistances = resistanceSamples.compactMapValues { samples -> Double? in
            let weight = samples.reduce(0) { $0 + $1.weight }
            return weight > 0 ? samples.reduce(0) { $0 + $1.value * $1.weight } / weight : nil
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
        let levelWeight = levels.reduce(0) { $0 + $1.weight }
        let meanLevel = levels.isEmpty || levelWeight <= 0
            ? 90
            : Int((levels.reduce(0) { $0 + Double($1.level) * $1.weight } / levelWeight)
                .rounded(.toNearestOrEven))

        // Monster level is a property of the chamber, so both halves of a floor
        // are fought at the same level.
        return AbyssFloorContext(
            floor: floorNumber,
            half: half,
            monsterLevel: meanLevel,
            resistances: resistances,
            buffs: buffs,
            shieldElements: shields.sorted { $0.rawValue < $1.rawValue },
            enemyHP: totalHP)
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
