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

        let emBonus = AbyssDamageMath.emBonusAmplifying(inputs.elementalMastery)
        XCTAssertEqual(emBonus, 0.26903, accuracy: 1e-5)

        let amplifying = AbyssDamageMath.amplifyingMultiplier(
            coefficient: 2.0, elementalMastery: inputs.elementalMastery)
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
        XCTAssertEqual(AbyssDamageMath.amplifyingCoefficient(for: .pyro, teamElements: [.pyro, .cryo]), 2.0)
        // Cryo onto Pyro is the weak one.
        XCTAssertEqual(AbyssDamageMath.amplifyingCoefficient(for: .cryo, teamElements: [.cryo, .pyro]), 1.5)
        // No reaction partner: no amplification.
        XCTAssertEqual(AbyssDamageMath.amplifyingCoefficient(for: .geo, teamElements: [.geo, .anemo]), 1.0)
    }
}
