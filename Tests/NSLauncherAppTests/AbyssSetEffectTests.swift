import XCTest
@testable import NSLauncherApp

/// What the popover behind a recommended artifact set is allowed to claim.
///
/// The recommendation names a set; the popover says what that set does and what
/// the model made of it. The second half is the part that can be quietly wrong:
/// some effects are not priced at all (reaction damage, healing, conditions a
/// single-target rotation never meets). A popover that printed "the model
/// applies …" over a set the model applies nothing for would be worse than one
/// that printed nothing.
final class AbyssSetEffectTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func set(_ id: String) throws -> AbyssArtifactSet {
        try XCTUnwrap(library.artifactSetsByID[id])
    }

    private func pricing(_ id: String) -> AbyssSetPricing {
        AbyssSetPricing.of(library.setBuffsByID[id]?.fourPiece ?? [])
    }

    // MARK: - What the model priced

    /// Viridescent Venerer's four-piece is reaction damage and a resistance
    /// shred, neither of which is a buff on the wearer's sheet — so the popover
    /// says it is not priced rather than "the model applies" something.
    func testAFourPieceWithNoStatBuffSaysSo() {
        XCTAssertEqual(pricing("viridescent-venerer"), .unpriced)
        XCTAssertEqual(pricing("maiden-beloved"), .unpriced)
    }

    /// Crimson Witch's stacking Pyro DMG is priced, and listed.
    func testAPricedFourPieceListsItsBuffs() throws {
        guard case .modelled(let buffs) = pricing("crimson-witch-of-flames") else {
            return XCTFail("crimson-witch-of-flames should be priced")
        }
        XCTAssertEqual(buffs.count, 1)
        let line = AppText(language: .english).abyssBuffLine(try XCTUnwrap(buffs.first))
        XCTAssertEqual(line, "+7.5% Pyro DMG ×3 (conditional)")
    }

    /// An effect whose every buff waits on something the model never grants
    /// (a defeated opponent, Witch's Homework) is not claimed as priced.
    func testAnUnreachableConditionIsNotClaimedAsPriced() {
        XCTAssertEqual(pricing("bloodstained-chivalry"), .unpriced)
        XCTAssertEqual(pricing("celestial-gift"), .unpriced)
    }

    /// Every five-star set has an answer for both pieces.
    func testEveryFiveStarSetHasAnAnswer() {
        for set in library.fiveStarArtifactSets {
            XCTAssertNotNil(library.setBuffsByID[set.id], "\(set.id) has no entry in passives.json")
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
}
