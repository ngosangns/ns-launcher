import XCTest
@testable import NSLauncherApp

/// What the popover behind a recommended artifact set is allowed to claim.
///
/// The recommendation names a set; the popover says what that set does and what
/// the model made of it. The second half is the part that can be quietly wrong,
/// because a third of the 4-piece effects in the data carry no machine-readable
/// numbers at all — they are either estimated by hand in `tuning.json` or not
/// priced. A popover that printed "the model applies …" over a set the model
/// applies nothing for would be worse than one that printed nothing.
final class AbyssSetEffectTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func set(_ id: String) throws -> AbyssArtifactSet {
        try XCTUnwrap(library.artifactSetsByID[id])
    }

    private func approximation(_ id: String) -> AbyssTuning.SetEffectApproximation? {
        library.tuning?.setEffectApprox.first { $0.setId == id }
    }

    private func pricing(_ id: String) throws -> AbyssSetPricing {
        AbyssSetPricing.of(try set(id).fourPiece, approximation: approximation(id))
    }

    // MARK: - Where the number came from

    /// Viridescent Venerer's 4-piece is a resistance shred the parser cannot
    /// read, and it is in the estimate table — so the popover says "estimated",
    /// not "the model applies +25%" as though the data said so.
    func testAnEstimatedFourPieceIsReportedAsEstimated() throws {
        guard case .estimated(let entry) = try pricing("viridescent-venerer") else {
            return XCTFail("viridescent-venerer should be priced by the estimate table")
        }
        XCTAssertEqual(entry.setId, "viridescent-venerer")
        XCTAssertTrue(try set("viridescent-venerer").fourPiece.bonuses.isEmpty,
                      "this test is about a set whose 4-piece the parser cannot read")
    }

    /// Maiden Beloved's 4-piece parses cleanly, so the popover quotes the data.
    func testAFourPieceTheDataPricesIsReportedFromTheData() throws {
        XCTAssertEqual(try pricing("maiden-beloved"), .fromData)
    }

    /// The disclosure that matters: a set with neither parsed bonuses nor an
    /// estimate was ranked on its 2-piece alone, and the popover has to say so.
    func testASetThatIsNotPricedAtAllSaysSo() throws {
        let unpriced = try library.fiveStarArtifactSets.filter {
            try pricing($0.id) == .unpriced
        }
        XCTAssertFalse(unpriced.isEmpty, "no unpriced sets left; this disclosure is now dead code")
        for set in unpriced {
            XCTAssertTrue(set.fourPiece.bonuses.isEmpty)
            XCTAssertNil(approximation(set.id))
        }
    }

    /// Every five-star set has to fall into exactly one of the three, or the
    /// popover would print nothing where a claim belongs.
    func testEveryFiveStarSetHasAnAnswer() throws {
        for set in library.fiveStarArtifactSets {
            let pricing = try pricing(set.id)
            if case .estimated = pricing { continue }
            XCTAssertEqual(pricing, set.fourPiece.bonuses.isEmpty ? .unpriced : .fromData,
                           "\(set.id) is described inconsistently")
        }
    }

    /// An estimate and parsed bonuses can both exist; the estimate is what
    /// `AbyssBuildAssembler` actually applies, so it is what gets shown.
    func testTheEstimateWinsWhenASetHasBoth() throws {
        let both = library.fiveStarArtifactSets.first {
            !$0.fourPiece.bonuses.isEmpty && approximation($0.id) != nil
        }
        guard let both else {
            throw XCTSkip("no set currently has both parsed bonuses and an estimate")
        }
        guard case .estimated = try pricing(both.id) else {
            return XCTFail("\(both.id): the parsed bonuses were shown over the estimate")
        }
    }

    // MARK: - Whose words

    /// The descriptions are the game's own text in both languages, written by
    /// `scripts/sync-abyss-artifact-text.py` from the official localisation.
    /// That provenance cannot be checked offline, but its footprint can: the
    /// script writes both languages together, so a piece with text in one and
    /// not the other was edited by hand afterwards — which is how the 4-piece
    /// descriptions came to be a paraphrase in the first place.
    func testEveryDescriptionExistsInBothLanguagesOrNeither() {
        for set in library.artifactSets {
            for (label, effect) in [("2pc", set.twoPiece), ("4pc", set.fourPiece)] {
                let vietnamese = effect.descriptionVI ?? ""
                XCTAssertEqual(effect.description.isEmpty, vietnamese.isEmpty,
                               "\(set.id) \(label): one language has text and the other does not; "
                               + "rerun scripts/sync-abyss-artifact-text.py rather than editing by hand")
                if !effect.description.isEmpty {
                    XCTAssertNotEqual(effect.description, vietnamese,
                                      "\(set.id) \(label): the Vietnamese text is the English one")
                }
            }
        }
    }

    /// Every set the popover can show — the five-star ones — has both pieces in
    /// both languages. A four-piece effect with no text would show a bonus the
    /// player cannot read.
    func testEveryRecommendableSetCanBeDescribed() {
        for set in library.fiveStarArtifactSets {
            XCTAssertFalse(set.nameVI.isEmpty, "\(set.id) has no Vietnamese name")
            for effect in [set.twoPiece, set.fourPiece] {
                XCTAssertFalse(effect.description.isEmpty, "\(set.id) is missing English text")
                XCTAssertFalse((effect.descriptionVI ?? "").isEmpty, "\(set.id) is missing Vietnamese text")
            }
        }
    }

    /// The game's text format writes a line break as the two characters `\n`;
    /// the sync turns them into real ones, and a raw one would print as-is.
    func testNoRawGameMarkupReachesTheText() {
        for set in library.artifactSets {
            for effect in [set.twoPiece, set.fourPiece] {
                for text in [effect.description, effect.descriptionVI ?? ""] {
                    XCTAssertFalse(text.contains("\\n"), "\(set.id): raw \\n in \"\(text.prefix(60))\"")
                    XCTAssertNil(text.range(of: "<color"), "\(set.id): colour markup in the text")
                }
            }
        }
    }

    func testThePopoverShowsTheViewersLanguage() throws {
        let effect = try set("viridescent-venerer").twoPiece
        XCTAssertEqual(effect.description(in: AppText(language: .english)), effect.description)
        XCTAssertEqual(effect.description(in: AppText(language: .vietnamese)), effect.descriptionVI)
    }

    // MARK: - Reading a bonus

    /// The data mixes percentages and flat values in one field, told apart only
    /// by magnitude: 0.15 is +15%, 80 is +80 Elemental Mastery.
    func testPercentagesAndFlatValuesAreTypeset() {
        func bonus(_ stat: String, _ value: Double) -> String {
            AbyssArtifactSet.Bonus(stat: stat, value: value).displayText
        }
        XCTAssertEqual(bonus("Anemo DMG Bonus", 0.15), "+15% Anemo DMG Bonus")
        XCTAssertEqual(bonus("Elemental Mastery", 80), "+80 Elemental Mastery")
        XCTAssertEqual(bonus("Max HP", 1000), "+1000 Max HP")
        XCTAssertEqual(bonus("Enemy Dendro RES", -0.3), "-30% Enemy Dendro RES")
    }

    /// The magnitude rule is only safe while the data keeps its two kinds apart.
    /// A flat bonus under 1, or a percentage at or above 1, would be typeset as
    /// the other thing.
    func testTheDataKeepsPercentagesAndFlatValuesApart() {
        for set in library.artifactSets {
            for bonus in set.twoPiece.bonuses + set.fourPiece.bonuses where abs(bonus.value) >= 1 {
                XCTAssertTrue(["Elemental Mastery", "Party Elemental Mastery", "DEF", "Max HP"]
                    .contains(bonus.stat),
                    "\(set.id): \"\(bonus.stat)\" is \(bonus.value) — if that is a percentage it "
                    + "will be typeset as a flat number")
            }
        }
    }
}
