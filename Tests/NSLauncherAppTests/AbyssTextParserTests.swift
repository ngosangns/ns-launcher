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

    /// Official Vietnamese client text calls Stellar-Conduct "Tinh-Siêu Dẫn"
    /// and Stellar Swirl "Tinh-Khuếch Tán" — both compound terms that contain
    /// (or, for Stellar-Conduct, literally spell out) the plain-Superconduct
    /// needle "siêu dẫn". A clause naming the compound reaction must not also
    /// register as the reaction it is a variant of.
    func testCompoundStellarTermsDoNotAlsoMatchTheirPlainReaction() {
        var diagnostics = AbyssParseDiagnostics()

        let conduct = AbyssTextParser.floorBuffs(
            "Sát thương Tinh-Siêu Dẫn nhân vật gây ra tăng 50%.", diagnostics: &diagnostics)
        XCTAssertEqual(conduct.first?.reactions, [.stellarConduct],
                       "\"Tinh-Siêu Dẫn\" must not also read as plain Superconduct")

        let swirl = AbyssTextParser.floorBuffs(
            "Sát thương Tinh-Khuếch Tán nhân vật gây ra tăng 50%.", diagnostics: &diagnostics)
        XCTAssertEqual(swirl.first?.reactions, [.stellarSwirl])

        // Plain Superconduct, unprefixed, still reads correctly on its own.
        let plain = AbyssTextParser.floorBuffs(
            "Sát thương Siêu Dẫn nhân vật gây ra tăng 200%.", diagnostics: &diagnostics)
        XCTAssertEqual(plain.first?.reactions, [.superconduct])

        // Official Vietnamese "Nguyệt-Điện Cảm" (Lunar-Charged) contains
        // "Điện Cảm" (Electro-Charged) the same way "Tinh-Siêu Dẫn" contains
        // "Siêu Dẫn" above.
        let lunarCharged = AbyssTextParser.floorBuffs(
            "Nhân vật tăng 75% sát thương Nguyệt-Điện Cảm.", diagnostics: &diagnostics)
        XCTAssertEqual(lunarCharged.first?.reactions, [.lunarCharged],
                       "\"Nguyệt-Điện Cảm\" must not also read as plain Electro-Charged")

        let electroCharged = AbyssTextParser.floorBuffs(
            "Nhân vật tăng 200% sát thương phản ứng Điện Cảm.", diagnostics: &diagnostics)
        XCTAssertEqual(electroCharged.first?.reactions, [.electroCharged])
    }

    func testFloorBuffsIgnoreNumbersThatAreNotBuffs() {
        var diagnostics = AbyssParseDiagnostics()
        // A percentage with nothing to attach it to is prose, not a buff.
        let buffs = AbyssTextParser.floorBuffs("Hiệu ứng này kích hoạt tối đa 1 lần mỗi 4 giây",
                                               diagnostics: &diagnostics)
        XCTAssertTrue(buffs.isEmpty)
    }

    /// A "DMG Bonus" row is a bonus, not a hit.
    ///
    /// The filter that drops non-damage rows already listed ATK Bonus, DEF
    /// Bonus, HP Bonus and EM Bonus, and not DMG Bonus — so a row reading
    /// "DMG Bonus (Omen) 60%" was read as a hit for 60% of ATK, and Lauma's
    /// burst, whose only two rows are Bloom bonuses of 499% and 400%, was scored
    /// as nine times her ATK of damage that does not exist. It cost her 29% of
    /// her solo score to stop believing it.
    func testADamageBonusRowIsNotAHit() throws {
        let library = AbyssDataLibraryTests.library

        // Mona's burst is one real hit plus the Omen bonus; the multiplier must
        // be the hit alone.
        let mona = try XCTUnwrap(library.profilesByCharacterID["mona"])
        let burst = try XCTUnwrap(mona.aggregate.first { $0.category == .burst })
        XCTAssertEqual(burst.multiplier, 7.9632, accuracy: 1e-4,
                       "Mona's burst carries the Omen DMG bonus as damage")

        // Lauma's burst is nothing but bonuses, so it deals no direct damage at
        // all. Zero is the honest answer.
        let lauma = try XCTUnwrap(library.profilesByCharacterID["lauma"])
        XCTAssertNil(lauma.aggregate.first { $0.category == .burst },
                     "Lauma's burst has no damage row; the model invented one")

        for label in ["DMG Bonus (Omen)", "Lunar Reaction DMG Bonus",
                      "Bloom/Hyperbloom/Burgeon DMG Bonus", "Geo DMG Bonus (nếu đủ 3 Geo)",
                      // A rate is never one hit.
                      "Tăng DMG Burst /điểm NL", "Bonus/lớp Prop Surplus",
                      "Namisen Bonus/lớp (%MaxHP)", "Tăng DMG Xoáy Cuốn /100 EM",
                      "Resolve Bonus (khởi điểm/mỗi lớp)",
                      // A percentage *of another hit* is not a hit of its own.
                      "Blazing Arrow DMG (% ST đòn thường)",
                      "Repelling Fist tăng cường (%ST đòn thường)"] {
            XCTAssertTrue(damageRows(label).isEmpty, "\(label) was read as a hit")
        }

        // And the filter must not swallow a real one.
        for label in ["1-Hit DMG", "Skill DMG", "Burst DMG", "Charged Attack DMG",
                      "Illusory Bubble Explosion DMG", "Hold DMG (3 stack)"] {
            XCTAssertEqual(damageRows(label).count, 1, "\(label) is a damage row and was dropped")
        }
    }

    /// The scaling basis is normally in the value; sometimes it is only in the
    /// label.
    ///
    /// "Equitable Judgment (%MaxHP)" over a bare "14.47%" read as ATK scaling
    /// was Neuvillette's damage divided by about twenty-seven — reading the
    /// label instead more than doubled his score. The rule has to stay tight:
    /// Hu Tao's charged attack says "tốn HP thay thể lực", which is what it
    /// *costs*, not what it scales on, and a looser rule triples her.
    func testTheScalingBasisCanComeFromTheLabel() throws {
        func basis(_ value: String, _ label: String) -> ScalingBasis? {
            AbyssTextParser.scalingValue(value, label: label)?.basis
        }
        XCTAssertEqual(basis("14.47%", "Equitable Judgment (%MaxHP)"), .hp)
        XCTAssertEqual(basis("176.8%", "Sát thương kỹ năng (%DEF)"), .def)
        XCTAssertEqual(basis("2.68416%", "Bấm DMG (theo DEF)"), .def)
        XCTAssertEqual(basis("172.8%", "Phantasm bóng (%EM, ×3 đòn)"), .em)

        // The value still wins when it says anything.
        XCTAssertEqual(basis("172.53% DEF", "Sát thương (%MaxHP)"), .def)

        // And a label that mentions a stat for another reason must not move it.
        XCTAssertEqual(basis("153.36%", "Trọng kích (trong Paramita Papilio, tốn HP thay thể lực)"),
                       .atk, "Hu Tao's charged attack costs HP, it does not scale on it")
        XCTAssertEqual(basis("493.952%", "Sát thương (HP >50%)"), .atk,
                       "an HP threshold is a condition, not a basis")

        // Neuvillette really does come out of the library HP-scaling now.
        let library = AbyssDataLibraryTests.library
        XCTAssertEqual(library.profilesByCharacterID["neuvillette"]?.basis, .hp)

        // Inherited HP and HP drain are not damage at all.
        for label in ["HP kế thừa (theo Max HP Itto)", "Inherited HP (%Max HP Amber)",
                      "Kế thừa HP", "Tiêu hao HP"] {
            XCTAssertTrue(damageRows(label).isEmpty, "\(label) was read as a hit")
        }
    }

    /// Two rows for the same hit under different conditions are one hit.
    ///
    /// Lisa's skill lists Hold DMG at 0 stacks and at 3 stacks; only one of them
    /// happens, and summing them credited her with 14.5× ATK for a cast worth at
    /// most 8.8×. Hu Tao's burst has an above-50%-HP row and a below-50% row and
    /// she is on one side of that line. The rule is deliberately narrow, because
    /// two rows sharing a stem usually are *not* alternatives.
    func testAlternativeRowsAreNotSummed() throws {
        let library = AbyssDataLibraryTests.library
        func rows(_ id: String, _ talent: KeyPath<AbyssCharacter, AbyssCharacter.Talent>) throws
            -> [Double] {
            let character = try XCTUnwrap(library.charactersByID[id])
            var diagnostics = AbyssParseDiagnostics()
            return AbyssTextParser.talentDamageEntries(character[keyPath: talent],
                                                       diagnostics: &diagnostics).map(\.0)
        }
        func contains(_ values: [Double], _ wanted: Double) -> Bool {
            values.contains { abs($0 - wanted) < 1e-6 }
        }

        let lisa = try rows("lisa", \.elementalSkill)
        XCTAssertTrue(contains(lisa, 8.7696), "the strongest branch should be the one kept")
        XCTAssertFalse(contains(lisa, 5.76), "the 0-stack branch was counted as well")

        let huTao = try rows("hu-tao", \.elementalBurst)
        XCTAssertTrue(contains(huTao, 6.1744))
        XCTAssertFalse(contains(huTao, 4.93952), "both sides of an HP threshold were counted")

        // And the rule must leave alone two rows that both land: Tighnari's
        // burst fires in two waves, not one of two.
        let tighnari = try rows("tighnari", \.elementalBurst)
        XCTAssertTrue(contains(tighnari, 1.001) && contains(tighnari, 1.224),
                      "two waves of the same shaft are additive and were collapsed")
    }

    /// One skill row through the same filter the profile builder uses. Not
    /// `comboHitCount`: that goes through the normal-attack combo pattern, which
    /// rejects any label not shaped "1-Hit", so it would answer zero for a
    /// dropped row and a kept one alike.
    private func damageRows(_ label: String) -> [(Double, ScalingBasis)] {
        let character = AbyssCharacter.stub(skillScaling: [
            .init(label: label, values: ["lv10": "500% ATK"]),
        ])
        var diagnostics = AbyssParseDiagnostics()
        return AbyssTextParser.talentDamageEntries(character.elementalSkill,
                                                   diagnostics: &diagnostics)
    }

    /// An inherited quirk kept on purpose: the combo-hit pattern matches a
    /// plain hyphen, so a label written with an en dash is skipped and that hit
    /// never reaches the model. Fixing it would move every affected character's
    /// score and every number in the golden fixture, so it is a deliberate
    /// change with the fixture regenerated — this test is here to make sure it
    /// cannot happen by accident.
    func testEnDashHitLabelIsSkipped() {
        let hyphen = AbyssCharacter.ScalingEntry(label: "1-Hit", values: ["lv10": "100% ATK"])
        let enDash = AbyssCharacter.ScalingEntry(label: "1–2-Hit", values: ["lv10": "100% ATK"])

        XCTAssertEqual(comboHitCount(labels: [hyphen]), 1)
        XCTAssertEqual(comboHitCount(labels: [enDash]), 0,
                       "en-dash labels are skipped on purpose; see this test's note")
    }

    private func comboHitCount(labels: [AbyssCharacter.ScalingEntry]) -> Int {
        let character = AbyssCharacter.stub(normalAttackHits: labels)
        return AbyssTextParser.normalAttackCombo(character).count
    }

    /// A `,` can close one bonus ("...200%, tăng...", the old floor 12 text)
    /// or open the next one ("...Khuếch Tán, tăng 75%...", this cycle's floor
    /// 12 first half) — official Vietnamese buff text is not consistent about
    /// which side of the comma the number lands on, and `clauseSplit` has to
    /// split on both, or the second bonus in a clause is lost entirely
    /// (`floorBuffs` only reads `percents.first`).
    func testACommaSplitsWhicheverSideTheNumberIsOn() {
        var diagnostics = AbyssParseDiagnostics()
        let numberAfterName = AbyssTextParser.floorBuffs(
            "Nhân vật tăng 200% sát thương phản ứng Khuếch Tán, tăng 75% sát thương Tinh-Khuếch Tán (Stellar Swirl).",
            diagnostics: &diagnostics)
        XCTAssertEqual(numberAfterName.map(\.bonus), [2.0, 0.75])
        XCTAssertEqual(numberAfterName.map(\.reactions), [[.swirl], [.stellarSwirl]])

        let numberBeforeName = AbyssTextParser.floorBuffs(
            "Nhân vật tăng sát thương Siêu Dẫn (Superconduct) 200%, tăng sát thương Tinh-Siêu Dẫn (Stellar-Conduct) 75%.",
            diagnostics: &diagnostics)
        XCTAssertEqual(numberBeforeName.map(\.bonus), [2.0, 0.75])
        XCTAssertEqual(numberBeforeName.map(\.reactions), [[.superconduct], [.stellarConduct]])
    }
}

// MARK: - Test helpers

extension AbyssMainStatPlan {
    /// The plan the model used to hard-code for a damage dealer, kept as a
    /// fixture for tests whose subject is something other than which main stats
    /// win. It is no longer what the engine picks — `mainStatCandidates` and the
    /// searches in `AbyssOptimizer`/`AbyssArtifactAdvisor` decide that now.
    static func damage(for character: AbyssCharacter) -> AbyssMainStatPlan {
        AbyssMainStatPlan(sands: .atkPercent,
                          goblet: .elementalDMG(character.element),
                          circlet: .critDMG)
    }
}

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
            "nameVI": id,
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
