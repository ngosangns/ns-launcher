// AbyssTeamContext.swift
//
// What a particular set of four characters unlocks: elemental resonances,
// Moonsign level, Hexerei, which reactions they can trigger, and whether anyone
// can keep the party alive.

import Foundation

struct AbyssTeamContext: Sendable {
    let elements: [GenshinElement]
    let resonances: [AbyssTeamBonus.Resonance]
    /// 0, 1 (Nascent Gleam) or 2 (Ascendant Gleam).
    let moonsignLevel: Int
    let hexerei: Bool
    let hasHeal: Bool
    let hasShield: Bool
    /// Someone can turn Swirl/Superconduct into their Stellar variants.
    let stellarJubilee: Bool
    /// What the team adds to the *base damage* of a Lunar or Stellar reaction
    /// just by containing the right character — Lauma, Columbina, Sandrone and
    /// the rest of `damage-formula.json`'s `reactionBaseDmgBonusSources`.
    ///
    /// Per reaction, because that is how the data records it: Lauma raises
    /// Lunar-Bloom and nothing else, and a team bonus kept as one number handed
    /// her +14% to a Stellar-Conduct she has no part in.
    ///
    /// The best single bonus per reaction, not the sum: the sources overlap and
    /// the data records each as a maximum, so adding them would stack ceilings
    /// that do not stack in game.
    var reactionBaseDamageBonus: [AbyssReaction: Double] = [:]
    /// How much enemy resistance this team strips, per element, already scaled
    /// by each source's uptime.
    ///
    /// The strongest source per element rather than the sum: two sources of
    /// resistance reduction on the same element do not stack in game.
    var resistanceShred: [GenshinElement: Double] = [:]

    /// The floor's resistance to an element, after this team has worked on it.
    func resistance(_ base: Double, to element: GenshinElement) -> Double {
        base - (resistanceShred[element] ?? 0)
    }

    /// Each member's nation, in `elements` order.
    var nations: [String] = []

    var elementSet: Set<GenshinElement> { Set(elements) }

    static func build(members: [AbyssCharacter], library: AbyssDataLibrary) -> AbyssTeamContext {
        let elements = members.map(\.element)
        let ids = Set(members.map(\.id))

        var resonances: [AbyssTeamBonus.Resonance] = []
        for resonance in library.teamBonus?.elementalResonance ?? [] {
            if resonance.requiresUniqueElements == true {
                // Protective Canopy: a full party of four different elements.
                if members.count == 4 && Set(elements).count == 4 {
                    resonances.append(resonance)
                }
            } else if let element = resonance.elements.first,
                      elements.filter({ $0 == element }).count >= resonance.requiredCount {
                resonances.append(resonance)
            }
        }

        let moonsignCount = ids.intersection(library.moonsignIDs).count
        let hexereiCount = ids.intersection(library.hexereiIDs).count

        // Read from the library's precomputed table: this runs once per team,
        // and re-deriving it by regex here dominated the whole optimisation.
        var heal = false
        var shield = false
        for member in members {
            let capability = library.sustainByCharacterID[member.id] ?? capabilities(of: member)
            heal = heal || capability.canHeal
            shield = shield || capability.canShield
        }

        return AbyssTeamContext(
            elements: elements,
            resonances: resonances,
            moonsignLevel: min(moonsignCount, 2),
            hexerei: hexereiCount >= (library.teamBonus?.hexerei.requiredCount ?? .max),
            hasHeal: heal,
            hasShield: shield,
            stellarJubilee: !ids.intersection(library.stellarJubileeIDs).isEmpty,
            reactionBaseDamageBonus: members.reduce(into: [AbyssReaction: Double]()) { found, member in
                for (reaction, bonus) in library.reactionBaseDamageBonusByCharacterID[member.id] ?? [:] {
                    found[reaction] = max(found[reaction] ?? 0, bonus)
                }
            },
            resistanceShred: shred(elements: Set(elements), ids: ids, library: library),
            nations: members.map(\.nationInGame))
    }

    // MARK: - Sustain

    private static let healHint = try? NSRegularExpression(pattern: "hồi máu|heal", options: [.caseInsensitive])
    private static let shieldHint = try? NSRegularExpression(pattern: "khiên|shield", options: [.caseInsensitive])
    /// Healing only counts as party sustain when the description says it reaches
    /// the party. Several damage dealers heal *themselves* as a side effect of
    /// spending HP (Hu Tao), and counting those as healers would credit teams
    /// with survivability they do not have.
    private static let partyScope = try? NSRegularExpression(
        pattern: "cả đội|toàn đội|đồng đội|trong vùng|đang chiến đấu|party|all characters|nearby",
        options: [.caseInsensitive])

    static func capabilities(of character: AbyssCharacter) -> AbyssSustain {
        var canHeal = false
        var canShield = false

        for talent in [character.elementalSkill, character.elementalBurst] {
            let labels = talent.scaling.map(\.label).joined(separator: " ")
            if matches(healHint, labels), matches(partyScope, talent.description) {
                canHeal = true
            }
            // Shields in Genshin only ever cover the character on field, so
            // unlike healing they need no party-scope qualifier.
            if matches(shieldHint, labels) {
                canShield = true
            }
        }
        return AbyssSustain(canHeal: canHeal, canShield: canShield)
    }

    private static func matches(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        guard let regex else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// What the team strips off the enemy's resistance, by element.
    private static func shred(elements: Set<GenshinElement>,
                              ids: Set<String>,
                              library: AbyssDataLibrary) -> [GenshinElement: Double] {
        // Anemo and Geo are not swirled, so they are never the element a
        // Viridescent Venerer wearer strips.
        let swirlable = elements.subtracting([.anemo, .geo])
        var found: [GenshinElement: Double] = [:]

        // Two lists, because there are two kinds of claim. `tuning.json` holds
        // the artifact sets, gated on an element the team has, which is an
        // assumption about who wears what; `character-kits.json` holds the
        // talents, gated on the character being present, which is a fact.
        func credit(_ names: [String], _ value: Double, _ uptime: Double) {
            let scaled = value * uptime
            let targets: [GenshinElement] = names.flatMap { name -> [GenshinElement] in
                name == AbyssResistanceShredScope.swirled
                    ? Array(swirlable)
                    : GenshinElement(rawValue: name).map { [$0] } ?? []
            }
            for element in targets {
                found[element] = max(found[element] ?? 0, scaled)
            }
        }

        for source in library.tuning?.resistanceShred ?? [] {
            if let required = source.requiresElement, !elements.contains(required) { continue }
            credit(source.elements, source.value, source.uptime)
        }
        for id in ids {
            for source in library.resistanceShredByCharacterID[id] ?? [] {
                credit(source.elements, source.value, source.uptime)
            }
        }
        return found
    }

    // MARK: - Reactions

    /// Reactions this team can actually trigger, used to decide which floor
    /// buffs apply. Moonsign and Stellar Jubilee upgrade a reaction in place —
    /// Superconduct becomes Stellar-Conduct, Bloom becomes Lunar-Bloom — which
    /// is what makes those characters worth a slot on the right floor.
    var enabledReactions: Set<AbyssReaction> {
        let elements = elementSet
        var found: Set<AbyssReaction> = []

        if elements.isSuperset(of: [.pyro, .hydro]) { found.insert(.vaporize) }
        if elements.isSuperset(of: [.pyro, .cryo]) { found.insert(.melt) }
        if elements.isSuperset(of: [.electro, .cryo]) {
            found.insert(stellarJubilee ? .stellarConduct : .superconduct)
        }
        if elements.isSuperset(of: [.anemo, .cryo]), stellarJubilee {
            found.insert(.stellarSwirl)
        }
        if elements.isSuperset(of: [.electro, .hydro]) {
            found.insert(moonsignLevel >= 1 ? .lunarCharged : .electroCharged)
        }
        if elements.isSuperset(of: [.electro, .pyro]) { found.insert(.overloaded) }
        if elements.isSuperset(of: [.geo, .hydro]), moonsignLevel >= 1 {
            found.insert(.lunarCrystallize)
        }
        if elements.isSuperset(of: [.dendro, .hydro]) {
            found.insert(moonsignLevel >= 1 ? .lunarBloom : .bloom)
        }
        return found
    }

    /// The transformative reactions this team can trigger, which is a different
    /// question from `enabledReactions`.
    ///
    /// Stellar Swirl is *added* here, not substituted: it has its own
    /// coefficient and its own EM curve in `damage-formula.json`, and whether
    /// it or a plain Swirl is worth more depends on the floor — this
    /// rotation's floor 12 triples Superconduct, so a Stellar Jubilee team's
    /// plain Swirl can beat its Stellar one. Offering both and letting the
    /// pricing choose is the only way to get that right; substituting would
    /// have thrown the answer away before it was asked.
    ///
    /// Lunar-Charged and Lunar-Crystallize are absent on purpose:
    /// `damage-formula.json`'s `lunarStellar.indirect` prices them by a
    /// different formula entirely — ranked per contributor, weighted
    /// 0.6/0.3/0.05/0.05, each at their own Elemental Mastery and CRIT, not
    /// the team's single best Elemental Mastery the way a candidate here is —
    /// see `AbyssScorer.indirectLunarStellarDamage`. Lunar-Bloom and
    /// Stellar-Conduct are absent too, and stay that way: the data records
    /// both as direct-only, so a team gets them only from a character whose
    /// own kit deals that damage, never from bare elemental overlap.
    ///
    /// The two-step reactions are derived: Hyperbloom and Burgeon need a Bloom
    /// core to already exist, so they want three elements rather than two.
    ///
    /// Shatter is absent: it needs a frozen target and a blunt hit, neither of
    /// which the element list can tell us.
    var transformativeReactions: Set<AbyssReaction> {
        let elements = elementSet
        var found: Set<AbyssReaction> = []

        if elements.isSuperset(of: [.electro, .cryo]) { found.insert(.superconduct) }
        if elements.isSuperset(of: [.electro, .hydro]) { found.insert(.electroCharged) }
        if elements.isSuperset(of: [.electro, .pyro]) { found.insert(.overloaded) }
        if elements.isSuperset(of: [.dendro, .pyro]) { found.insert(.burning) }
        if elements.isSuperset(of: [.dendro, .hydro]) {
            found.insert(.bloom)
            // A Bloom core is what Electro and Pyro detonate.
            if elements.contains(.electro) { found.insert(.hyperbloom) }
            if elements.contains(.pyro) { found.insert(.burgeon) }
        }
        if elements.contains(.anemo), !elements.isDisjoint(with: [.pyro, .hydro, .electro, .cryo]) {
            found.insert(.swirl)
        }

        // Stellar Glimmer needs a character who upgrades the reaction.
        if stellarJubilee, elements.isSuperset(of: [.anemo, .cryo]) { found.insert(.stellarSwirl) }
        return found
    }

    /// Party-wide stats granted by the active elemental resonances.
    ///
    /// Only the resonance bonuses that map onto a modelled stat are counted;
    /// the rest (stamina, movement speed, cooldown) do not affect damage.
    func resonanceStats() -> (atkPercent: Double, elementalMastery: Double, dmg: Double) {
        var atkPercent = 0.0
        var elementalMastery = 0.0
        var dmg = 0.0

        for resonance in resonances {
            for bonus in resonance.bonuses {
                let stat = bonus.stat.lowercased()
                if stat == "atk" {
                    atkPercent += bonus.value
                } else if stat.contains("elemental mastery") {
                    elementalMastery += bonus.value
                } else if stat.contains("dmg bonus") && stat.contains("khi có khiên") {
                    // Enduring Rock's damage bonus holds while shielded: a
                    // team with a shielder keeps it up, one without never has it.
                    dmg += hasShield ? bonus.value : 0
                }
            }
        }
        return (atkPercent, elementalMastery, dmg)
    }

    /// What this team holds for a member's gated buffs — see `AbyssGates`.
    ///
    /// Counts are of the *other* members: "for every party member of a
    /// different Elemental Type" does not count the wearer.
    func conditions(for character: AbyssCharacter) -> AbyssTeamConditions {
        var conditions = AbyssTeamConditions.zero
        let own = character.element
        for element in elementSet {
            conditions[AbyssTeamCondition.auraFirst.rawValue + element.simdIndex] = 1
        }
        conditions[AbyssTeamCondition.shield.rawValue] = hasShield ? 1 : 0
        conditions[AbyssTeamCondition.healed.rawValue] = hasHeal ? 1 : 0
        conditions[AbyssTeamCondition.hpChange.rawValue] = hasHeal ? 1 : 0
        conditions[AbyssTeamCondition.moonsignAscendant.rawValue] = moonsignLevel >= 2 ? 1 : 0
        conditions[AbyssTeamCondition.hexerei.rawValue] = hexerei ? 1 : 0
        conditions[AbyssTeamCondition.crystallize.rawValue] = elementSet.contains(.geo)
            && !elementSet.isDisjoint(with: [.pyro, .hydro, .electro, .cryo]) ? 1 : 0
        conditions[AbyssTeamCondition.distinctElements.rawValue] = Double(elementSet.count)

        // The other members: this team without one copy of the character.
        var skippedSelf = false
        var reacts = false
        var liyue = 0.0
        for (index, element) in elements.enumerated() {
            let nation = index < nations.count ? nations[index] : ""
            if !skippedSelf, element == own, nations.isEmpty || nation == character.nationInGame {
                skippedSelf = true
                continue
            }
            if element == own {
                conditions[AbyssTeamCondition.sameElement.rawValue] += 1
            } else {
                conditions[AbyssTeamCondition.otherElement.rawValue] += 1
                reacts = reacts || Self.react(own, element)
            }
            if element != own || nation == "Natlan" {
                conditions[AbyssTeamCondition.natlanOrOtherElement.rawValue] += 1
            }
            if nation == "Liyue" { liyue += 1 }
            conditions[AbyssTeamCondition.members(element)] += 1
        }
        conditions[AbyssTeamCondition.liyue.rawValue] = liyue
        conditions[AbyssTeamCondition.liyueWithWearer.rawValue] = liyue + (character.nationInGame == "Liyue" ? 1 : 0)
        conditions[AbyssTeamCondition.reaction.rawValue] = reacts ? 1 : 0
        return conditions
    }

    /// Whether two elements react when they meet.
    static func react(_ first: GenshinElement, _ second: GenshinElement) -> Bool {
        guard first != second else { return false }
        let auras: Set<GenshinElement> = [.pyro, .hydro, .electro, .cryo]
        switch (first, second) {
        case (.anemo, .geo), (.geo, .anemo): return false
        case (.anemo, _), (.geo, _): return auras.contains(second)
        case (_, .anemo), (_, .geo): return auras.contains(first)
        case (.cryo, .dendro), (.dendro, .cryo): return false
        default: return true
        }
    }
}

/// Whether a character can keep the party alive.
struct AbyssSustain: Sendable, Equatable {
    let canHeal: Bool
    let canShield: Bool
}
