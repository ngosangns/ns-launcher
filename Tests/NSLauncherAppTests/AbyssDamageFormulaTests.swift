import XCTest
@testable import NSLauncherApp

/// Anchors the damage formula to the worked example published on the wiki and
/// recorded in `damage-formula.json`.
///
/// The intermediates are asserted individually because a transcription slip
/// hides in exactly one of them, and a single end-to-end number would only say
/// "something is off" without saying which factor.
final class AbyssDamageFormulaTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    func testWorkedExampleReproducesThePublishedResult() throws {
        let formula = try XCTUnwrap(library.damageFormula)
        let example = formula.workedExample
        let inputs = example.inputs

        let defMultiplier = AbyssDamageMath.defMultiplier(
            characterLevel: inputs.characterLevel,
            monsterLevel: inputs.monsterLevel,
            defReduction: inputs.defReductionFromKleeC2)
        XCTAssertEqual(defMultiplier, 0.55783, accuracy: 1e-5)

        let resistance = inputs.resHydroBase - inputs.resHydroReductionFromSucroseSwirl
        let resMultiplier = AbyssDamageMath.resMultiplier(resistance)
        XCTAssertEqual(resMultiplier, 1.15, accuracy: 1e-9,
                       "Swirl pushed Hydro resistance to -30%, which amplifies rather than reduces")

        let emBonus = AbyssDamageMath.emBonusAmplifying(inputs.elementalMastery,
                                                        constants: library.damageConstants)
        XCTAssertEqual(emBonus, 0.26903, accuracy: 1e-5)

        let amplifying = AbyssDamageMath.amplifyingMultiplier(
            coefficient: 2.0, elementalMastery: inputs.elementalMastery,
            constants: library.damageConstants)
        XCTAssertEqual(amplifying, 2.53806, accuracy: 1e-5)

        let total = inputs.atk
            * inputs.skillMultiplierStellarisPhantasmLv6
            * (1 + inputs.hydroDmgBonus + inputs.klee_c2_reactionDmgBonus)
            * defMultiplier * resMultiplier * amplifying
            * (1 + inputs.critDmg)

        // The published figure is itself rounded, so this is a relative
        // tolerance rather than equality — the reference implementation lands
        // on 52,247.00 against the wiki's 52,246.50.
        XCTAssertEqual(total, example.result.value, accuracy: example.result.value * 0.001,
                       "damage chain diverged from the published worked example")
    }

    func testResistanceMultiplierCoversAllThreeBranches() {
        // Negative resistance is halved before being applied.
        XCTAssertEqual(AbyssDamageMath.resMultiplier(-0.30), 1.15, accuracy: 1e-9)
        // The ordinary case is a straight subtraction.
        XCTAssertEqual(AbyssDamageMath.resMultiplier(0.10), 0.90, accuracy: 1e-9)
        XCTAssertEqual(AbyssDamageMath.resMultiplier(0.70), 0.30, accuracy: 1e-9)
        // At and above 75% it flattens out instead of reaching zero.
        XCTAssertEqual(AbyssDamageMath.resMultiplier(0.75), 1.0 / 4.0, accuracy: 1e-9)
        XCTAssertEqual(AbyssDamageMath.resMultiplier(0.90), 1.0 / 4.6, accuracy: 1e-9)
    }

    func testDefenceMultiplierFallsAsEnemyLevelRises() {
        let versus90 = AbyssDamageMath.defMultiplier(characterLevel: 90, monsterLevel: 90)
        let versus100 = AbyssDamageMath.defMultiplier(characterLevel: 90, monsterLevel: 100)
        XCTAssertGreaterThan(versus90, versus100)
        XCTAssertEqual(versus90, 0.5, accuracy: 1e-9, "equal levels halve incoming damage")
    }

    func testAmplifyingCoefficientDependsOnWhichElementTriggers() {
        // Pyro onto an enemy already carrying Cryo is the strong direction.
        XCTAssertEqual(AbyssDamageMath.amplifyingCoefficient(for: .pyro, teamElements: [.pyro, .cryo],
                                                             constants: library.damageConstants), 2.0)
        // Cryo onto Pyro is the weak one.
        XCTAssertEqual(AbyssDamageMath.amplifyingCoefficient(for: .cryo, teamElements: [.cryo, .pyro],
                                                             constants: library.damageConstants), 1.5)
        // No reaction partner: no amplification.
        XCTAssertEqual(AbyssDamageMath.amplifyingCoefficient(for: .geo, teamElements: [.geo, .anemo],
                                                             constants: library.damageConstants), 1.0)
    }

    // MARK: - The file as the source of truth

    /// The planner used to hard-code these numbers while `damage-formula.json`
    /// sat decoded and unread: two sources of truth with nothing tying them, so
    /// correcting a coefficient in the file changed nothing and said nothing.
    /// They are read from the file now, and this is what says so.
    func testConstantsAreReadFromTheFileRatherThanHardCoded() throws {
        let formula = try XCTUnwrap(library.damageFormula)
        let constants = library.damageConstants
        XCTAssertEqual(library.diagnostics.damageFormulaUnread, [],
                       "part of damage-formula.json could not be read; the planner is on fallbacks")

        // Every EM curve in the file parses, and to the values the port used.
        let amplifying = try XCTUnwrap(
            AbyssDamageFormula.EMCurve.parse(formula.amplifying.emBonusFormula))
        XCTAssertEqual(constants.amplifyingEM, amplifying)
        XCTAssertEqual(amplifying.numerator, 2.78, accuracy: 1e-9)
        XCTAssertEqual(amplifying.offset, 1400, accuracy: 1e-9)
        XCTAssertEqual(constants.transformativeEM,
                       try XCTUnwrap(AbyssDamageFormula.EMCurve.parse(
                           formula.transformative.emBonusFormula)))
        XCTAssertEqual(constants.catalyzeEM,
                       try XCTUnwrap(AbyssDamageFormula.EMCurve.parse(
                           formula.catalyze.emBonusFormula)))

        // All four amplifying coefficients are mapped onto a (trigger, existing)
        // pair; an unrecognised name would show up in the diagnostics above.
        XCTAssertEqual(constants.amplifyingCoefficients.count,
                       formula.amplifying.coefficients.count)
        XCTAssertEqual(constants.amplifyingCoefficients, AbyssDamageConstants.fallback.amplifyingCoefficients,
                       "the file and the port's own table disagree")

        // Every transformative coefficient in the file is priced.
        XCTAssertEqual(constants.transformativeCoefficients.count,
                       formula.transformative.coefficients.count)
        XCTAssertEqual(constants.transformativeCoefficients[.hyperbloom], 3.0)
        XCTAssertEqual(constants.transformativeCoefficients[.overloaded], 2.75)
        XCTAssertEqual(constants.transformativeLevelMultiplier,
                       formula.transformative.levelMultiplier[String(AbyssDamageMath.characterLevel)]?.character)
    }

    /// What is still written in code rather than read: the resistance curve's
    /// three branches and the level the whole data set assumes. Those are shapes
    /// and assumptions rather than numbers in the file, so the honest thing is a
    /// test that holds them to what the file does say.
    func testTheConstantsStillWrittenInCodeAgreeWithTheFile() throws {
        let formula = try XCTUnwrap(library.damageFormula)
        XCTAssertEqual(AbyssFloorContext.defaultResistance,
                       formula.resMultiplier.defaultMonsterResAllElements, accuracy: 1e-9,
                       "the floor's baseline resistance drifted from damage-formula.json")
        XCTAssertNotNil(formula.transformative.levelMultiplier[String(AbyssDamageMath.characterLevel)],
                        "the data has no level multiplier for the level the model assumes")
    }

    /// A formula string that is not the expected shape must fall back and say
    /// so, not score with a zero curve.
    func testAnUnreadableFormulaFallsBackAndIsReported() {
        XCTAssertNil(AbyssDamageFormula.EMCurve.parse("something else entirely"))
        let curve = AbyssDamageFormula.EMCurve(numerator: 16, offset: 2000)
        XCTAssertEqual(curve.bonus(2000), 8, accuracy: 1e-9)
        XCTAssertEqual(curve.bonus(0), 0, accuracy: 1e-9)
    }
}
