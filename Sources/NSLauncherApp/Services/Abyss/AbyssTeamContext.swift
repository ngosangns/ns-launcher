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
            resistanceShred: shred(elements: Set(elements), ids: ids, library: library))
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
        // assumption about who wears what; `character-traits.json` holds the
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
            for source in library.traitsByCharacterID[id]?.resistanceShred ?? [] {
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
    /// The Lunar and Stellar variants are *added* here, not substituted. They
    /// have their own coefficients and their own EM curve in
    /// `damage-formula.json`, and which of the pair is worth more depends on the
    /// floor — this rotation's floor 12 triples Superconduct, so a Stellar
    /// Jubilee team's plain Superconduct can beat its Stellar-Conduct. Offering
    /// both and letting the pricing choose is the only way to get that right;
    /// substituting would have thrown the answer away before it was asked.
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

        // Stellar Glimmer needs a character who upgrades the reaction; Lunar
        // needs a Moonsign.
        if stellarJubilee {
            if elements.isSuperset(of: [.electro, .cryo]) { found.insert(.stellarConduct) }
            if elements.isSuperset(of: [.anemo, .cryo]) { found.insert(.stellarSwirl) }
        }
        if moonsignLevel >= 1 {
            if elements.isSuperset(of: [.electro, .hydro]) { found.insert(.lunarCharged) }
            if elements.isSuperset(of: [.dendro, .hydro]) { found.insert(.lunarBloom) }
            if elements.isSuperset(of: [.geo, .hydro]) { found.insert(.lunarCrystallize) }
        }
        return found
    }

    /// Party-wide stats granted by the active elemental resonances.
    ///
    /// Only the resonance bonuses that map onto a modelled stat are counted;
    /// the rest (stamina, movement speed, cooldown) do not affect damage.
    func resonanceStats(conditionalUptime: Double) -> (atkPercent: Double, elementalMastery: Double, dmg: Double) {
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
                    // Enduring Rock's damage bonus only applies while shielded.
                    dmg += bonus.value * conditionalUptime
                }
            }
        }
        return (atkPercent, elementalMastery, dmg)
    }
}

/// Whether a character can keep the party alive.
struct AbyssSustain: Sendable, Equatable {
    let canHeal: Bool
    let canShield: Bool
}
