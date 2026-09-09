// AbyssDamageMath.swift
//
// The game's core damage formula, implemented from
// `Resources/Abyss/damage-formula.json` (sections 1.6-1.8 and 2).
//
// `damage-formula.json` also carries a fully worked example taken from the
// wiki; `AbyssDamageFormulaTests` runs these functions over its inputs and
// checks the published result, which is what makes this file trustworthy rather
// than merely plausible.
//
// The *numbers* come from that file at load time, through
// `AbyssDamageConstants` — the EM curves, the amplifying coefficients, the
// transformative coefficients and the level multiplier. What stays written here
// is the *shape* of the formulas: the three-branch resistance curve and the
// defence formula, which the data expresses as prose rather than as numbers,
// and the level-90 assumption the whole data set is written for. A test pins
// the few remaining literals against the file so the two cannot drift.

import Foundation

/// The numbers the damage formulas work from, resolved once from
/// `damage-formula.json`.
///
/// Falling back rather than failing: a missing or reshaped file leaves the
/// planner scoring with the values the port was written with, and records what
/// it could not read in `AbyssParseDiagnostics` — the same bargain the rest of
/// the loader makes.
struct AbyssDamageConstants: Sendable {
    let amplifyingEM: AbyssDamageFormula.EMCurve
    let transformativeEM: AbyssDamageFormula.EMCurve
    let catalyzeEM: AbyssDamageFormula.EMCurve
    let amplifyingCoefficients: [AbyssDamageMath.Pair: Double]
    let transformativeCoefficients: [AbyssReaction: Double]
    /// `transformative.levelMultiplier` at `AbyssDamageMath.characterLevel`.
    let transformativeLevelMultiplier: Double

    init(amplifyingEM: AbyssDamageFormula.EMCurve,
         transformativeEM: AbyssDamageFormula.EMCurve,
         catalyzeEM: AbyssDamageFormula.EMCurve,
         amplifyingCoefficients: [AbyssDamageMath.Pair: Double],
         transformativeCoefficients: [AbyssReaction: Double],
         transformativeLevelMultiplier: Double) {
        self.amplifyingEM = amplifyingEM
        self.transformativeEM = transformativeEM
        self.catalyzeEM = catalyzeEM
        self.amplifyingCoefficients = amplifyingCoefficients
        self.transformativeCoefficients = transformativeCoefficients
        self.transformativeLevelMultiplier = transformativeLevelMultiplier
    }

    /// What the port was written with, before the numbers were read from data.
    static let fallback = AbyssDamageConstants(
        amplifyingEM: .init(numerator: 2.78, offset: 1400),
        transformativeEM: .init(numerator: 16, offset: 2000),
        catalyzeEM: .init(numerator: 5, offset: 1200),
        amplifyingCoefficients: [
            AbyssDamageMath.Pair(trigger: .pyro, existing: .hydro): 1.5,
            AbyssDamageMath.Pair(trigger: .pyro, existing: .cryo): 2.0,
            AbyssDamageMath.Pair(trigger: .hydro, existing: .pyro): 2.0,
            AbyssDamageMath.Pair(trigger: .cryo, existing: .pyro): 1.5,
        ],
        transformativeCoefficients: [:],
        transformativeLevelMultiplier: 0)

    /// The data's names for the four amplifying coefficients, and which
    /// (trigger, existing) pair each one prices.
    private static let amplifyingPairs: [String: AbyssDamageMath.Pair] = [
        "meltPyroTrigger": .init(trigger: .pyro, existing: .cryo),
        "meltCryoTrigger": .init(trigger: .cryo, existing: .pyro),
        "vaporizeHydroTrigger": .init(trigger: .hydro, existing: .pyro),
        "vaporizePyroTrigger": .init(trigger: .pyro, existing: .hydro),
    ]

    init(formula: AbyssDamageFormula?, diagnostics: inout AbyssParseDiagnostics) {
        guard let formula else {
            self = .fallback
            diagnostics.damageFormulaUnread.insert("damage-formula.json is missing")
            return
        }

        func curve(_ text: String, _ name: String, fallback: AbyssDamageFormula.EMCurve)
            -> AbyssDamageFormula.EMCurve {
            guard let parsed = AbyssDamageFormula.EMCurve.parse(text) else {
                diagnostics.damageFormulaUnread.insert("\(name): \(text)")
                return fallback
            }
            return parsed
        }

        amplifyingEM = curve(formula.amplifying.emBonusFormula, "amplifying.emBonusFormula",
                             fallback: Self.fallback.amplifyingEM)
        transformativeEM = curve(formula.transformative.emBonusFormula,
                                 "transformative.emBonusFormula",
                                 fallback: Self.fallback.transformativeEM)
        catalyzeEM = curve(formula.catalyze.emBonusFormula, "catalyze.emBonusFormula",
                           fallback: Self.fallback.catalyzeEM)

        var amplifying: [AbyssDamageMath.Pair: Double] = [:]
        for (name, value) in formula.amplifying.coefficients {
            guard let pair = Self.amplifyingPairs[name] else {
                diagnostics.damageFormulaUnread.insert("amplifying.coefficients.\(name)")
                continue
            }
            amplifying[pair] = value
        }
        amplifyingCoefficients = amplifying.isEmpty ? Self.fallback.amplifyingCoefficients : amplifying

        var transformative: [AbyssReaction: Double] = [:]
        let byKey = Dictionary(
            AbyssReaction.allCases.compactMap { reaction in
                reaction.transformativeKey.map { ($0, reaction) }
            },
            uniquingKeysWith: { first, _ in first })
        for (name, value) in formula.transformative.coefficients {
            guard let reaction = byKey[name] else {
                diagnostics.damageFormulaUnread.insert("transformative.coefficients.\(name)")
                continue
            }
            transformative[reaction] = value
        }
        transformativeCoefficients = transformative

        let level = String(AbyssDamageMath.characterLevel)
        if let entry = formula.transformative.levelMultiplier[level] {
            transformativeLevelMultiplier = entry.character
        } else {
            transformativeLevelMultiplier = 0
            diagnostics.damageFormulaUnread.insert("transformative.levelMultiplier.\(level)")
        }
    }
}

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
    static func emBonusAmplifying(_ elementalMastery: Double,
                                  constants: AbyssDamageConstants = .fallback) -> Double {
        constants.amplifyingEM.bonus(elementalMastery)
    }

    static func amplifyingMultiplier(coefficient: Double,
                                     elementalMastery: Double,
                                     reactionBonus: Double = 0,
                                     constants: AbyssDamageConstants = .fallback) -> Double {
        coefficient * (1 + emBonusAmplifying(elementalMastery, constants: constants) + reactionBonus)
    }

    /// A transformative reaction's damage, which depends on nothing but the
    /// triggering character's level and Elemental Mastery.
    ///
    /// No ATK, no DMG bonus, no CRIT, no enemy DEF — the reaction is its own
    /// hit. That is what lets it be scored once for the team instead of per
    /// member, and it is also why a support with high EM and no damage of their
    /// own can be the biggest contributor on a Bloom team.
    static func transformativeDamage(coefficient: Double,
                                     elementalMastery: Double,
                                     resistance: Double,
                                     constants: AbyssDamageConstants) -> Double {
        coefficient
            * constants.transformativeLevelMultiplier
            * (1 + constants.transformativeEM.bonus(elementalMastery))
            * resMultiplier(resistance)
    }

    struct Pair: Hashable, Sendable {
        let trigger: GenshinElement
        let existing: GenshinElement
    }

    /// Best amplifying coefficient this character can trigger given the team's
    /// elements; 1.0 when no amplifying reaction is available.
    ///
    /// The trigger matters: Pyro onto Cryo melts for 2.0, Cryo onto Pyro only
    /// 1.5, which is why the table is keyed by (triggering element, element
    /// already on the enemy).
    static func amplifyingCoefficient(for element: GenshinElement,
                                      teamElements: Set<GenshinElement>,
                                      constants: AbyssDamageConstants = .fallback) -> Double {
        var best = 1.0
        for (pair, coefficient) in constants.amplifyingCoefficients
        where pair.trigger == element && teamElements.contains(pair.existing) {
            best = max(best, coefficient)
        }
        return best
    }
}
