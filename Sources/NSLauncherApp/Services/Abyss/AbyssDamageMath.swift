// AbyssDamageMath.swift
//
// The game's core damage formula, implemented from
// `Resources/Abyss/damage-formula.json` (sections 1.6-1.8 and 2).
//
// `damage-formula.json` also carries a fully worked example taken from the
// wiki; `AbyssDamageFormulaTests` runs these four functions over its inputs and
// checks the published result, which is what makes this file trustworthy rather
// than merely plausible.

import Foundation

enum AbyssDamageMath {
    /// Every character is modelled at 90 — the level the whole data set and all
    /// the stat assumptions are written for.
    static let characterLevel = 90

    /// How much of a hit survives the enemy's defence.
    ///
    /// `defReduction` is the enemy's DEF being lowered; `defIgnore` is armour
    /// being bypassed. They stack multiplicatively, not additively.
    static func defMultiplier(characterLevel: Int,
                              monsterLevel: Int,
                              defReduction: Double = 0,
                              defIgnore: Double = 0) -> Double {
        let k = (1 - defReduction) * (1 - defIgnore)
        return Double(characterLevel + 100)
            / (k * Double(monsterLevel + 100) + Double(characterLevel + 100))
    }

    /// Resistance is piecewise, and the negative branch is why stripping enemy
    /// resistance beats stacking damage bonus: below zero it is halved, so it
    /// keeps paying off instead of saturating.
    static func resMultiplier(_ res: Double) -> Double {
        if res < 0 { return 1 - res / 2 }
        if res < 0.75 { return 1 - res }
        return 1 / (4 * res + 1)
    }

    /// Elemental Mastery's contribution to an amplifying reaction (Vaporize,
    /// Melt). Saturating: the first points of EM are worth far more than the last.
    static func emBonusAmplifying(_ elementalMastery: Double) -> Double {
        2.78 * elementalMastery / (elementalMastery + 1400)
    }

    static func amplifyingMultiplier(coefficient: Double,
                                     elementalMastery: Double,
                                     reactionBonus: Double = 0) -> Double {
        coefficient * (1 + emBonusAmplifying(elementalMastery) + reactionBonus)
    }

    /// Amplifying reaction coefficients, keyed by who triggers the reaction.
    ///
    /// The trigger matters: Pyro onto Cryo melts for 2.0, Cryo onto Pyro only
    /// 1.5. The key is (triggering element, element already on the enemy).
    static let amplifyingCoefficients: [Pair: Double] = [
        Pair(trigger: .pyro, existing: .hydro): 1.5,
        Pair(trigger: .pyro, existing: .cryo): 2.0,
        Pair(trigger: .hydro, existing: .pyro): 2.0,
        Pair(trigger: .cryo, existing: .pyro): 1.5,
    ]

    struct Pair: Hashable, Sendable {
        let trigger: GenshinElement
        let existing: GenshinElement
    }

    /// Best amplifying coefficient this character can trigger given the team's
    /// elements; 1.0 when no amplifying reaction is available.
    static func amplifyingCoefficient(for element: GenshinElement,
                                      teamElements: Set<GenshinElement>) -> Double {
        var best = 1.0
        for (pair, coefficient) in amplifyingCoefficients
        where pair.trigger == element && teamElements.contains(pair.existing) {
            best = max(best, coefficient)
        }
        return best
    }
}
