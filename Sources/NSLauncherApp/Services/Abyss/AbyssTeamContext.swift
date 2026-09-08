// AbyssTeamContext.swift
//
// What a particular set of four characters unlocks: elemental resonances,
// Moonsign level, Hexerei, which reactions they can trigger, and whether anyone
// can keep the party alive. Ported from `build_team_context` in `scoring.py`.

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
            stellarJubilee: !ids.intersection(library.stellarJubileeIDs).isEmpty)
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
