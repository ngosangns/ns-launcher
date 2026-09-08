import XCTest
@testable import NSLauncherApp

/// The character/weapon portraits fetched by `scripts/fetch-abyss-icons.py`
/// into `Resources/Abyss/icons/`. These are real bundled files, not fixtures —
/// the point of the test is to catch a script regenerated with gaps, or a
/// character/weapon added without a matching icon fetched for it.
final class AbyssIconLibraryTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    /// Every character and weapon in the data should have a portrait. A
    /// shortfall here means `fetch-abyss-icons.py` needs a re-run, not that
    /// the app should silently fall back to glyphs for the missing ones.
    func testEveryCharacterAndWeaponHasAnIcon() {
        let missingCharacters = library.characters
            .filter { library.icons.characterIconURL($0.id) == nil }
            .map(\.id)
        XCTAssertTrue(missingCharacters.isEmpty,
                      "characters with no fetched icon: \(missingCharacters.joined(separator: ", "))")

        let missingWeapons = library.weapons
            .filter { library.icons.weaponIconURL($0.id) == nil }
            .map(\.id)
        XCTAssertTrue(missingWeapons.isEmpty,
                      "weapons with no fetched icon: \(missingWeapons.joined(separator: ", "))")
    }

    /// An id the data has never heard of must resolve to nil, not to a URL
    /// that happens not to exist — callers use presence of a URL to decide
    /// whether to draw a portrait or fall back to a glyph.
    func testUnknownIDsResolveToNil() {
        XCTAssertNil(library.icons.characterIconURL("not-a-real-character"))
        XCTAssertNil(library.icons.weaponIconURL("not-a-real-weapon"))
    }

    /// The URLs returned actually point at readable, non-empty files — not
    /// just at paths that happen to exist in the filename set.
    func testResolvedURLsPointAtRealImageFiles() throws {
        let characterURL = try XCTUnwrap(library.icons.characterIconURL("hu-tao"))
        let weaponURL = try XCTUnwrap(library.icons.weaponIconURL("staff-of-homa"))

        for url in [characterURL, weaponURL] {
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 1000, "\(url.lastPathComponent) is suspiciously small for a 256×256 PNG")
            // PNG magic bytes, so a truncated or HTML-error download fails loudly here
            // instead of surfacing later as a blank tile in the roster grid.
            XCTAssertEqual(Array(data.prefix(8)), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        }
    }

    /// Every Traveler variant shares one portrait (the game has no per-element
    /// art for them) — confirms that convention actually landed for all seven,
    /// not just the one used in ad hoc checks elsewhere.
    func testEveryTravelerVariantHasAnIcon() {
        let travelers = library.characters.map(\.id).filter { $0.hasPrefix("traveler-") }
        XCTAssertEqual(travelers.count, 7, "expected 7 Traveler element variants in the data")
        for id in travelers {
            XCTAssertNotNil(library.icons.characterIconURL(id), "\(id) has no icon")
        }
    }
}
