import XCTest
@testable import NSLauncherApp

/// `AbyssTalentReader` against the grammar of `talent-params.json`, and
/// against the prose path it replaces.
///
/// Two kinds of test. The grammar tests pin each expression shape the data
/// was found to contain — every one was enumerated before the reader was
/// written — with a hand-built talent, so a rule can be checked without
/// wondering which character exercises it. The comparison test then runs both
/// readers over every character that has structured data and reports where
/// they disagree; a disagreement means one of them is wrong, and the whole
/// point of Phase 1 is that it is usually the transcription.
final class AbyssTalentReaderTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func talent(_ lines: [String], params: [Double]) -> AbyssTalentParams.Talent {
        AbyssTalentParams.Talent(name: "t", cooldown: 0, energyCost: 0, lines: lines,
                                 lineOverrides: nil, params: Array(repeating: params, count: 15))
    }

    private func terms(_ lines: [String], params: [Double],
                       category: HitCategory = .skill) -> [AbyssDamageProfile.Term] {
        var diagnostics = AbyssParseDiagnostics()
        return AbyssTalentReader.abilityTerms(talent(lines, params: params), level: 10,
                                              category: category, characterID: "x",
                                              diagnostics: &diagnostics)
    }

    // MARK: - The grammar, one shape at a time

    func testAPlainPercentIsAnATKHit() {
        XCTAssertEqual(terms(["Skill DMG|{param1:P}"], params: [3.024]),
                       [.init(multiplier: 3.024, basis: .atk, category: .skill)])
    }

    func testASuffixNamesTheBasis() {
        XCTAssertEqual(terms(["Skill DMG|{param1:F2P} Max HP"], params: [0.231552]),
                       [.init(multiplier: 0.231552, basis: .hp, category: .skill)])
        XCTAssertEqual(terms(["ATK Bonus|{param1:F1P} DEF", "Skill DMG|{param2:P} DEF"], params: [1.0, 2.0]),
                       [.init(multiplier: 2.0, basis: .def, category: .skill)],
                       "ATK Bonus is a buff, not a hit, whatever its suffix")
        XCTAssertEqual(terms(["Skill DMG|{param1:P} Elemental Mastery"], params: [4.0]),
                       [.init(multiplier: 4.0, basis: .em, category: .skill)])
    }

    /// Xingqiu: `{p1}+{p2}` — two hits that both land, so they add.
    func testPlusAddsSimultaneousHits() {
        XCTAssertEqual(terms(["Skill DMG|{param1:P}+{param2:P}"], params: [3.024, 3.4416]),
                       [.init(multiplier: 6.4656, basis: .atk, category: .skill)])
    }

    /// Kazuha's 5-hit: `{p}×3`. And the wrapped form `({a} ATK+{b} EM)×2`.
    func testTimesMultipliesAHit() {
        let tripled = terms(["Skill DMG|{param1:F1P}×3"], params: [0.5015])
        XCTAssertEqual(tripled.count, 1)
        XCTAssertEqual(tripled.first?.multiplier ?? 0, 1.5045, accuracy: 1e-9)
        XCTAssertEqual(tripled.first?.basis, .atk)
        let mixed = terms(["Skill DMG|({param1:P} ATK+{param2:P} Elemental Mastery)×2"], params: [1.0, 2.0])
        XCTAssertEqual(Set(mixed), [.init(multiplier: 2.0, basis: .atk, category: .skill),
                                    .init(multiplier: 4.0, basis: .em, category: .skill)])
    }

    /// A sum across two bases is two terms, not one guessed basis.
    func testAMixedBasisSumKeepsBothTerms() {
        let mixed = terms(["Skill DMG|{param1:P} ATK+{param2:P} DEF"], params: [1.5, 0.5])
        XCTAssertEqual(Set(mixed), [.init(multiplier: 1.5, basis: .atk, category: .skill),
                                    .init(multiplier: 0.5, basis: .def, category: .skill)])
    }

    /// `{a}/{b}` inside one line is two alternatives; the stronger is the one
    /// that counts — the reading the prose path gives "a% / b%".
    func testSlashInsideALineTakesTheStrongerAlternative() {
        XCTAssertEqual(terms(["Skill DMG|{param1:P}/{param2:P}"], params: [1.0, 1.5]),
                       [.init(multiplier: 1.5, basis: .atk, category: .skill)])
    }

    /// A `/` followed by a unit is a rate, not an alternative, and a rate is
    /// not a hit. Neither is a duration.
    func testRatesAndDurationsAreNotHits() {
        XCTAssertEqual(terms(["Skill DMG|{param1:P}/s"], params: [1.0]), [])
        XCTAssertEqual(terms(["Skill DMG|{param1:P} per Fighting Spirit"], params: [1.0]), [])
        XCTAssertEqual(terms(["Skill DMG|{param1:F1}s"], params: [6.0]), [])
        XCTAssertEqual(terms(["Skill DMG|{param1:I}"], params: [60]), [], "an integer format is a count")
    }

    /// The vocabulary that makes a row not a hit even when it says DMG.
    func testNonDamageLabelsAreSkipped() {
        for label in ["Skill DMG Bonus", "DMG Increase", "Damage Reduction Ratio", "Shield DMG Absorption",
                      "HP Regeneration", "Charged Attack Stamina Cost", "Duration", "CD", "Energy Cost",
                      "Inherited HP", "ATK Increase"] {
            XCTAssertEqual(terms(["\(label)|{param1:P}"], params: [1.0]), [], "\(label) was read as a hit")
        }
    }

    /// Hu Tao's burst: "Skill DMG" and "Low HP Skill DMG" are one hit on two
    /// sides of a threshold, and she is on one side of it.
    func testVariantRowsKeepOnlyTheStrongest() {
        XCTAssertEqual(terms(["Skill DMG|{param1:P}", "Low HP Skill DMG|{param2:P}"], params: [4.93952, 6.1744]),
                       [.init(multiplier: 6.1744, basis: .atk, category: .skill)])
        XCTAssertEqual(terms(["Press Skill DMG|{param1:P}", "Hold Skill DMG|{param2:P}"], params: [3.456, 4.6944]),
                       [.init(multiplier: 4.6944, basis: .atk, category: .skill)])
    }

    /// Two differently named hits both land; nothing about them is a variant.
    func testDifferentlyNamedRowsBothCount() {
        XCTAssertEqual(terms(["Slashing DMG|{param1:P}", "DoT|{param2:P}"], params: [4.7232, 2.16]).count, 2)
    }

    /// The platform layout tag the game puts in front of some labels.
    func testLayoutTagsAreStripped() {
        let split = AbyssTalentReader.split("#{LAYOUT_MOBILE#Tap}{LAYOUT_PC#Press}{LAYOUT_PS#Press} Skill DMG|{param1:P}")
        XCTAssertEqual(split?.label, "Press Skill DMG")
    }

    // MARK: - Normal attacks

    func testTheComboIsTheNumberedHitsOnly() {
        let na = talent(["1-Hit DMG|{param1:F1P}", "2-Hit DMG|{param2:F1P}+{param3:F1P}",
                         "Charged Attack|{param4:F1P}", "Plunge DMG|{param5:F1P}",
                         "Low/High Plunge DMG|{param6:P}/{param7:P}"],
                        params: [0.8, 0.5, 0.6, 2.4, 1.1, 2.3, 2.9])
        XCTAssertEqual(AbyssTalentReader.comboTerms(na, level: 10).map(\.multiplier), [0.8, 1.1])
        XCTAssertEqual(AbyssTalentReader.chargedTerms(na, level: 10, extraLabels: []).map(\.multiplier), [2.4])
        XCTAssertEqual(AbyssTalentReader.unclassifiedRows(na, level: 10, characterID: "x", extraLabels: []), [],
                       "plunges are dropped on purpose, not reported")
    }

    /// A bow's plain and fully-charged shots are one action; the strongest
    /// wins, as on the prose path. A character-specific label from
    /// `character-traits.json` joins the charged set.
    func testChargedIsTheStrongestNamedRow() {
        let bow = talent(["Aimed Shot|{param1:F1P}", "Fully-Charged Aimed Shot|{param2:P}",
                          "Frostflake Arrow DMG|{param3:P}", "Charged Attack Stamina Cost|{param4:F1}"],
                         params: [0.867, 2.232, 2.304, 20])
        XCTAssertEqual(AbyssTalentReader.chargedTerms(bow, level: 10, extraLabels: []).map(\.multiplier), [2.232])
        XCTAssertEqual(AbyssTalentReader.chargedTerms(bow, level: 10, extraLabels: ["Frostflake Arrow"])
                            .map(\.multiplier), [2.304])
        XCTAssertEqual(AbyssTalentReader.unclassifiedRows(bow, level: 10, characterID: "ganyu", extraLabels: []),
                       ["ganyu: Frostflake Arrow DMG"],
                       "without the trait label, the row is reported rather than dropped")
    }

    // MARK: - What a kit names

    private func character(normal: AbyssTalentParams.Talent,
                           skill: AbyssTalentParams.Talent,
                           burst: AbyssTalentParams.Talent) -> AbyssTalentParams.Character {
        AbyssTalentParams.Character(gameId: 0, normalAttack: normal, elementalSkill: skill, elementalBurst: burst)
    }

    private func reference(talent: AbyssTalentParams.Key? = nil, label: String? = nil, param: Int? = nil,
                           basis: ScalingBasis? = nil, count: Double? = nil, category: HitCategory? = nil,
                           factor: AbyssCharacterKit.HitReference.Factor? = nil) -> AbyssCharacterKit.HitReference {
        .init(talent: talent, label: label, param: param, basis: basis, count: count, category: category, factor: factor)
    }

    private func kitTerms(_ references: [AbyssCharacterKit.HitReference],
                          slot: AbyssCharacterKit.HitSlot,
                          in structured: AbyssTalentParams.Character,
                          diagnostics: inout AbyssParseDiagnostics) -> [AbyssDamageProfile.Term] {
        AbyssTalentReader.kitTerms(references, slot: slot, structured: structured, level: { _ in 10 },
                                   characterID: "x", diagnostics: &diagnostics)
    }

    /// A label reads the row through the same grammar as everything else —
    /// `{a}+{b}` adds, a suffix names the basis — times its count, in the
    /// slot's bucket and at the slot's cadence unless the reference says
    /// otherwise.
    func testAKitReferenceReadsARowByLabelTimesItsCount() {
        let skill = talent(["Press DMG|{param1:P}", "Charge Level 2 DMG|{param2:P}+{param3:P}",
                            "Tick DMG|{param4:F2P} Max HP"], params: [1.0, 2.0, 3.0, 0.05])
        let none = talent([], params: [])
        let structured = character(normal: none, skill: skill, burst: none)
        var diagnostics = AbyssParseDiagnostics()
        let terms = kitTerms([reference(label: "Press DMG"), reference(label: "Tick DMG", count: 2)],
                             slot: .skill, in: structured, diagnostics: &diagnostics)
        XCTAssertEqual(terms, [.init(multiplier: 1.0, basis: .atk, category: .skill, action: .skill),
                               .init(multiplier: 0.1, basis: .hp, category: .skill, action: .skill)])
        XCTAssertEqual(diagnostics.kitReferencesUnresolved, [])
    }

    /// Raiden's stance: rows of the burst table that are her attack string —
    /// counted like a combo, priced like a burst.
    func testASlotAndACategoryCanDiffer() {
        let burst = talent(["Musou no Hitotachi Base DMG|{param1:P}", "1-Hit DMG|{param2:F1P}"], params: [7.2, 0.8])
        let none = talent([], params: [])
        let structured = character(normal: none, skill: none, burst: burst)
        var diagnostics = AbyssParseDiagnostics()
        let terms = kitTerms([reference(talent: .elementalBurst, label: "1-Hit DMG", category: .burst)],
                             slot: .combo, in: structured, diagnostics: &diagnostics)
        XCTAssertEqual(terms, [.init(multiplier: 0.8, basis: .atk, category: .burst, action: .combo)])
    }

    /// A bare param is for rows the grammar refuses on purpose — a per-stack
    /// rate — and needs the kit to say how many. It must be printed as a
    /// percentage somewhere, or it is a count or a duration and no multiplier.
    func testABareParamNeedsToBeAPercentage() {
        let burst = talent(["Resolve Bonus|{param1:F2P} Initial/{param2:F2P} Per Stack", "Duration|{param3:F1}s"],
                           params: [0.07, 0.013, 7])
        let none = talent([], params: [])
        let structured = character(normal: none, skill: none, burst: burst)
        var diagnostics = AbyssParseDiagnostics()
        let terms = kitTerms([reference(param: 1, count: 60), reference(param: 3, count: 2)],
                             slot: .burst, in: structured, diagnostics: &diagnostics)
        XCTAssertEqual(terms.map(\.multiplier), [4.2])
        XCTAssertEqual(diagnostics.kitReferencesUnresolved.count, 1, "the duration was read as a multiplier")
    }

    /// A share of another hit: Yoimiya's Blazing Arrow is `{p} Normal Attack
    /// DMG`, so the combo rows are read times that param of the skill.
    func testAFactorMultipliesByAnotherTalentsParam() {
        let normal = talent(["1-Hit DMG|{param1:F1P}"], params: [0.5])
        let skill = talent(["Blazing Arrow DMG|{param4:F1P} Normal Attack DMG"], params: [10, 18, 3, 1.6])
        let none = talent([], params: [])
        let structured = character(normal: normal, skill: skill, burst: none)
        var diagnostics = AbyssParseDiagnostics()
        let terms = kitTerms([reference(label: "1-Hit DMG", factor: .init(talent: .elementalSkill, param: 4))],
                             slot: .combo, in: structured, diagnostics: &diagnostics)
        XCTAssertEqual(terms.count, 1)
        XCTAssertEqual(terms.first?.multiplier ?? 0, 0.8, accuracy: 1e-12)
        XCTAssertEqual(terms.first?.action, .combo)
    }

    /// A reference that resolves to nothing is reported, not skipped: a kit
    /// that names a row is claiming that row is the character's damage.
    func testAnUnresolvedReferenceIsReported() {
        let skill = talent(["Skill DMG|{param1:P}"], params: [1.0])
        let none = talent([], params: [])
        let structured = character(normal: none, skill: skill, burst: none)
        var diagnostics = AbyssParseDiagnostics()
        let terms = kitTerms([reference(label: "Skill DMG"), reference(label: "Renamed Row DMG"),
                              reference(label: "Skill DMG", param: 1)],
                             slot: .skill, in: structured, diagnostics: &diagnostics)
        XCTAssertEqual(terms.count, 1)
        XCTAssertEqual(diagnostics.kitReferencesUnresolved.count, 2)
    }

    /// An empty list is a claim too: nothing in this slot.
    func testAnEmptySlotMeansNoHits() throws {
        let params = try XCTUnwrap(library.talentParams?.characters["xilonen"])
        var diagnostics = AbyssParseDiagnostics()
        let terms = kitTerms([], slot: .charged, in: params, diagnostics: &diagnostics)
        XCTAssertEqual(terms, [])
        let xilonen = try XCTUnwrap(library.profilesByCharacterID["xilonen"])
        XCTAssertFalse(xilonen.hits.contains { $0.category == .charged },
                       "Blade Roller cannot charge; the kit says so and the profile should agree")
    }

    // MARK: - Against the data

    /// The DMG lines in the real data the reader deliberately does not count
    /// as hits, named exactly. The grammar refuses three shapes: a share of
    /// *another* hit ("{p} Normal Attack DMG"), a per-stack rate ("per
    /// Verdant Dew"), and another character's stat ("Corresponding
    /// Character's ATK"). The first two kinds now have kits that say what the
    /// share multiplies (Razor, Wanderer, Wriothesley, Yoimiya) or that the
    /// rate is a Phase 4 reaction (Lauma), and a kit that overrides a slot
    /// takes the talent out of this reader's hands — so what is left is
    /// Nicole's, which scales on somebody else's ATK and has no home yet. A
    /// new entry here is a shape the grammar has not seen; one vanishing means
    /// the data changed under it. Either way, look.
    func testTheDamageLinesNotReadAsHitsAreKnownOnes() {
        let known: Set<String> = [
            "nicole: Arcane Projection DMG|{param2:F1P} Corresponding Character's ATK",
        ]
        XCTAssertEqual(library.diagnostics.talentParamsUnread, known,
                       "new: \(library.diagnostics.talentParamsUnread.subtracting(known).sorted()) "
                       + "gone: \(known.subtracting(library.diagnostics.talentParamsUnread).sorted())")
    }

    /// Level 13 exists for everyone now, so a C3/C5 talent boost reads real
    /// numbers for every structured character rather than only the ones whose
    /// prose carried an `lv13` column. Checked per boosted slot, and only where
    /// that slot has hits — a boost to a burst that is pure buff (Sethos)
    /// rightly changes nothing.
    func testLevelThirteenIsRealForEveryStructuredCharacter() throws {
        let params = try XCTUnwrap(library.talentParams)
        var checked = 0
        for id in params.characters.keys {
            guard let boosts = library.talentBoostsByCharacterID[id], !boosts.isEmpty else { continue }
            let base = try XCTUnwrap(library.profile(for: id, constellation: 0))
            let boosted = try XCTUnwrap(library.profile(for: id, constellation: 6))
            for slot in Set(boosts.values) {
                let category: HitCategory = slot == .skill ? .skill : .burst
                let before = base.hits.filter { $0.category == category }.map(\.multiplier).reduce(0, +)
                let after = boosted.hits.filter { $0.category == category }.map(\.multiplier).reduce(0, +)
                guard before > 0 else { continue }
                XCTAssertGreaterThan(after, before, "\(id): \(category) did not grow from level 10 to 13")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 50, "too few boosted slots exercised")
    }
}
