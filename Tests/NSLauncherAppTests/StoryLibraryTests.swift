import XCTest
@testable import NSLauncherApp

/// Loads the real bundled `Resources/Story/` content (not a fixture) to guard
/// against drift: a chapter/quest file renamed or reworded should fail a test
/// here rather than silently break links or shrink the sidebar in the app.
final class StoryLibraryTests: XCTestCase {

    func testLoadsAllBundledDocuments() {
        let library = StoryLibrary()
        let chapters = library.documents.filter { $0.kind == .narrativeChapter }
        let quests = library.documents.filter { $0.kind == .questReference }
        XCTAssertEqual(chapters.count, 9, "expected the 9 narrative chapters under Resources/Story/chapters")
        XCTAssertEqual(quests.count, 12, "expected the 12 quest reference files under Resources/Story/quests")
    }

    func testChaptersAreOrderedByFilenamePrefix() {
        let library = StoryLibrary()
        let chapterOrders = library.documents.filter { $0.kind == .narrativeChapter }.map(\.order)
        XCTAssertEqual(chapterOrders, chapterOrders.sorted())
        XCTAssertEqual(chapterOrders, Array(0...8))
    }

    func testEveryEntityHasAResolvableHomeSection() {
        let library = StoryLibrary()
        for entity in library.entities {
            let home = try? XCTUnwrap(library.documentsByID[entity.homeDocument], "missing homeDocument for \(entity.id)")
            guard let home else { continue }
            if let heading = entity.homeHeading {
                XCTAssertTrue(
                    home.sections.contains { $0.heading == heading },
                    "\(entity.id): no section titled \"\(heading)\" in \(entity.homeDocument)"
                )
            }
        }
    }

    /// Every alias in the registry must appear literally somewhere in the
    /// bundled corpus — an alias that matches nothing is either a typo or
    /// leftover from a renamed passage.
    func testEveryAliasAppearsSomewhereInTheCorpus() {
        let library = StoryLibrary()
        let corpus = library.documents.flatMap { document in
            document.sections.flatMap { section in
                section.blocks.compactMap { block -> String? in
                    switch block {
                    case .paragraph(let text), .callout(_, let text):
                        return text.markdown
                    case .table, .list, .tree:
                        return nil
                    }
                }
            }
        }.joined(separator: "\n")

        for entity in library.entities {
            for alias in entity.aliases {
                XCTAssertTrue(
                    corpus.contains(alias),
                    "alias \"\(alias)\" for \(entity.id) does not appear in any narrative paragraph/callout"
                )
            }
        }
    }

    func testKnownEntityResolvesAndLinksAtLeastOnce() {
        let library = StoryLibrary()
        let zhongli = try? XCTUnwrap(library.entitiesByID["zhongli"])
        XCTAssertEqual(zhongli?.kind, .archon)
        XCTAssertFalse(library.occurrences["zhongli"]?.isEmpty ?? true)
    }

    func testEntityIDsAreUnique() {
        let library = StoryLibrary()
        XCTAssertEqual(library.entities.count, Set(library.entities.map(\.id)).count)
    }
}
