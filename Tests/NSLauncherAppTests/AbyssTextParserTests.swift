import XCTest
@testable import NSLauncherApp

/// Table-driven cases for the text parsers, written so a failure names the rule
/// that broke rather than just a number that moved.
///
/// The strings here are real shapes taken from `Resources/Abyss/`, including the
/// awkward ones — mixed separators, approximation tildes, Traveler gender
/// variants, and Vietnamese element names.
final class AbyssTextParserTests: XCTestCase {

    private func parse(_ text: String) -> (multiplier: Double, basis: ScalingBasis)? {
        AbyssTextParser.scalingValue(text)
    }

    func testScalingValueReadsMultiplierAndBasis() {
        let cases: [(input: String, multiplier: Double, basis: ScalingBasis)] = [
            ("172.53% DEF", 1.7253, .def),
            ("99.93% ATK", 0.9993, .atk),
            // No named basis: ATK is the game's default.
            ("82.04%", 0.8204, .atk),
            // Sequential hits in one branch are summed.
            ("118%+128% ATK", 2.46, .atk),
            // Mutually exclusive variants: the strongest wins.
            ("86.7% / 223.2%", 2.232, .atk),
            ("45.4%/77.9% MaxHP", 0.779, .hp),
            ("127.84%/159.68% ATK", 1.5968, .atk),
            // An approximation marker must not break the number.
            ("~504% ATK", 5.04, .atk),
            // Gender variants are alternatives, not extra hits.
            ("Aether 118%+128% ATK / Lumine 118%+153% ATK", 2.71, .atk),
        ]

        for testCase in cases {
            guard let parsed = parse(testCase.input) else {
                XCTFail("failed to parse \"\(testCase.input)\"")
                continue
            }
            XCTAssertEqual(parsed.multiplier, testCase.multiplier, accuracy: 1e-9,
                           "wrong multiplier for \"\(testCase.input)\"")
            XCTAssertEqual(parsed.basis, testCase.basis,
                           "wrong basis for \"\(testCase.input)\"")
        }
    }

    func testScalingValueIgnoresConstellationVariantsInParentheses() {
        // The parenthetical is a C3/C5 upgrade of the same hit, not another hit;
        // summing it would inflate the character by a constellation they may
        // not own.
        let parsed = parse("172.8% ATK (cấp 13: 204%)")
        XCTAssertEqual(parsed?.multiplier ?? 0, 1.728, accuracy: 1e-9)
    }

    func testScalingValueRejectsNonDamageText() {
        for text in ["6.0s", "20", "14.0s", ""] {
            XCTAssertNil(parse(text), "\"\(text)\" is not a damage multiplier")
        }
    }

    func testResistanceNotesReadSignAndElement() {
        var diagnostics = AbyssParseDiagnostics()

        let resisted = AbyssTextParser.resistanceNotes("kháng Anemo +20%", diagnostics: &diagnostics)
        XCTAssertEqual(resisted, [.element(.anemo): 0.20])

        let weak = AbyssTextParser.resistanceNotes("rất yếu Pyro (pyro_res -20%)", diagnostics: &diagnostics)
        XCTAssertEqual(weak, [.element(.pyro): -0.20])

        // One clause naming two elements applies to both.
        let combined = AbyssTextParser.resistanceNotes("kháng Dendro/Geo +20~30%", diagnostics: &diagnostics)
        XCTAssertEqual(combined, [.element(.dendro): 0.20, .element(.geo): 0.20])
    }

    func testResistanceNotesUnderstandVietnameseElementNames() {
        var diagnostics = AbyssParseDiagnostics()
        let parsed = AbyssTextParser.resistanceNotes("kháng Băng +40%", diagnostics: &diagnostics)
        XCTAssertEqual(parsed, [.element(.cryo): 0.40])
    }

    func testFloorBuffsSplitClausesAndScopeThem() {
        var diagnostics = AbyssParseDiagnostics()
        let text = "Nửa 1 (nửa trước): Sát thương Superconduct +200%, sát thương Stellar-Conduct +75%. "
            + "Nửa 2 (nửa sau): Sát thương Thường công (Normal Attack) hệ Pyro +75%."
        let buffs = AbyssTextParser.floorBuffs(text, diagnostics: &diagnostics)

        XCTAssertEqual(buffs.count, 3, "expected one buff per clause")
        XCTAssertEqual(buffs[0].bonus, 2.0, accuracy: 1e-9)
        XCTAssertTrue(buffs[0].reactions.contains(.superconduct))
        XCTAssertEqual(buffs[1].bonus, 0.75, accuracy: 1e-9)
        XCTAssertTrue(buffs[1].reactions.contains(.stellarConduct))
        XCTAssertTrue(buffs[2].normalAttackOnly, "the last clause only buffs normal attacks")
        XCTAssertTrue(buffs[2].elements.contains(.pyro))
    }

    func testFloorBuffsIgnoreNumbersThatAreNotBuffs() {
        var diagnostics = AbyssParseDiagnostics()
        // A percentage with nothing to attach it to is prose, not a buff.
        let buffs = AbyssTextParser.floorBuffs("Hiệu ứng này kích hoạt tối đa 1 lần mỗi 4 giây",
                                               diagnostics: &diagnostics)
        XCTAssertTrue(buffs.isEmpty)
    }

    /// Reproduces a Python quirk on purpose: the combo-hit pattern matches a
    /// plain hyphen, so a label written with an en dash is skipped and that hit
    /// never reaches the model. Changing it would move every affected
    /// character's score away from the reference implementation, so it has to
    /// change in both at once — this test is here to make that deliberate.
    func testEnDashHitLabelIsSkippedLikeTheReferenceImplementation() {
        let hyphen = AbyssCharacter.ScalingEntry(label: "1-Hit", values: ["lv10": "100% ATK"])
        let enDash = AbyssCharacter.ScalingEntry(label: "1–2-Hit", values: ["lv10": "100% ATK"])

        XCTAssertEqual(comboHitCount(labels: [hyphen]), 1)
        XCTAssertEqual(comboHitCount(labels: [enDash]), 0,
                       "en-dash labels are skipped by the reference implementation too")
    }

    private func comboHitCount(labels: [AbyssCharacter.ScalingEntry]) -> Int {
        let character = AbyssCharacter.stub(normalAttackHits: labels)
        return AbyssTextParser.normalAttackCombo(character).count
    }
}

// MARK: - Test helpers

extension AbyssCharacter {
    /// Minimal character for parser tests. Only the fields under test are
    /// meaningful; the rest carry neutral values.
    static func stub(id: String = "test-character",
                     element: GenshinElement = .pyro,
                     weaponType: WeaponType = .sword,
                     normalAttackHits: [ScalingEntry] = [],
                     skillScaling: [ScalingEntry] = [],
                     burstScaling: [ScalingEntry] = []) -> AbyssCharacter {
        let json: [String: Any] = [
            "id": id,
            "name": id,
            "element": element.rawValue,
            "weaponType": weaponType.rawValue,
            "rarity": 5,
            "nationInGame": "Mondstadt",
            "releaseDate": NSNull(),
            "baseStats": [
                "lv1": ["hp": 1000.0, "atk": 20.0, "def": 60.0],
                "lv90": ["hp": 12000.0, "atk": 250.0, "def": 700.0,
                         "ascensionStatType": "CRIT Rate", "ascensionStatValue": 0.192],
            ],
            "normalAttack": [
                "name": "Test",
                "hits": normalAttackHits.map { ["label": $0.label, "values": $0.values] },
            ],
            "elementalSkill": [
                "name": "Skill", "description": "",
                "scaling": skillScaling.map { ["label": $0.label, "values": $0.values] },
                "cooldown": NSNull(), "energyCost": NSNull(),
            ],
            "elementalBurst": [
                "name": "Burst", "description": "",
                "scaling": burstScaling.map { ["label": $0.label, "values": $0.values] },
                "cooldown": NSNull(), "energyCost": NSNull(),
            ],
            "passives": [],
            "constellations": [],
            "abyssRoleNotes": NSNull(),
            "sourceFile": "test",
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(AbyssCharacter.self, from: data)
    }
}

extension AbyssCharacter.ScalingEntry {
    init(label: String, values: [String: String]) {
        let data = try! JSONSerialization.data(withJSONObject: ["label": label, "values": values])
        self = try! JSONDecoder().decode(AbyssCharacter.ScalingEntry.self, from: data)
    }
}
