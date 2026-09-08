import XCTest
@testable import NSLauncherApp

/// `StoryEntityLinker` rewrites narrative text into `story://entity/<id>`
/// links; these fixtures use a small fabricated registry instead of the real
/// `story-entities.json` so each behavior is isolated.
final class StoryEntityLinkerTests: XCTestCase {

    private func entity(
        id: String,
        name: String,
        aliases: [String] = [],
        home: String = "doc"
    ) -> StoryEntity {
        StoryEntity(id: id, kind: .character, displayName: name, aliases: aliases, summary: nil, homeDocument: home, homeHeading: nil)
    }

    func testLinksExactDisplayNameMention() {
        let doc = StoryMarkdownParser.parseDocument(
            id: "doc", kind: .narrativeChapter, order: 0,
            rawText: "## Mục\n\nZhongli bước ra khỏi bóng tối."
        )
        let linked = StoryEntityLinker.link(document: doc, entities: [entity(id: "zhongli", name: "Zhongli")])
        guard case .paragraph(let text) = linked.sections[0].blocks[0] else { return XCTFail() }
        XCTAssertEqual(text.markdown, "[Zhongli](story://entity/zhongli) bước ra khỏi bóng tối.")
    }

    func testPrefersLongestAliasOverShorterOverlappingName() {
        let doc = StoryMarkdownParser.parseDocument(
            id: "doc", kind: .narrativeChapter, order: 0,
            rawText: "## Mục\n\nKamisato Ayaka xuất hiện."
        )
        let entities = [
            entity(id: "ayaka", name: "Ayaka", aliases: ["Kamisato Ayaka"]),
            entity(id: "ayato", name: "Ayato", aliases: ["Kamisato Ayato"])
        ]
        let linked = StoryEntityLinker.link(document: doc, entities: entities)
        guard case .paragraph(let text) = linked.sections[0].blocks[0] else { return XCTFail() }
        XCTAssertEqual(text.markdown, "[Kamisato Ayaka](story://entity/ayaka) xuất hiện.")
    }

    func testDoesNotMatchSubstringInsideALongerWord() {
        let doc = StoryMarkdownParser.parseDocument(
            id: "doc", kind: .narrativeChapter, order: 0,
            rawText: "## Mục\n\nEi thắp sáng Inazuma, nhưng Eirlys thì không liên quan."
        )
        let linked = StoryEntityLinker.link(document: doc, entities: [entity(id: "ei", name: "Ei")])
        guard case .paragraph(let text) = linked.sections[0].blocks[0] else { return XCTFail() }
        XCTAssertEqual(text.markdown, "[Ei](story://entity/ei) thắp sáng Inazuma, nhưng Eirlys thì không liên quan.")
    }

    func testTablesListsAndTreesAreNeverLinked() {
        let raw = """
        ## Mục

        | Nhân vật | Ghi chú |
        |---|---|
        | Zhongli | Morax |

        - Zhongli xuất hiện ở đây

        ├── Zhongli
        """
        let doc = StoryMarkdownParser.parseDocument(id: "doc", kind: .questReference, order: 0, rawText: raw)
        let linked = StoryEntityLinker.link(document: doc, entities: [entity(id: "zhongli", name: "Zhongli")])
        for block in linked.sections[0].blocks {
            switch block {
            case .table(_, let rows):
                XCTAssertEqual(rows, [["Zhongli", "Morax"]])
            case .list(let items):
                XCTAssertEqual(items.map(\.markdown), ["Zhongli xuất hiện ở đây"])
            case .tree(let lines):
                XCTAssertEqual(lines, ["├── Zhongli"])
            case .paragraph, .callout:
                XCTFail("unexpected block kind")
            }
        }
    }

    func testCalloutTextIsAlsoLinked() {
        let doc = StoryMarkdownParser.parseDocument(
            id: "doc", kind: .narrativeChapter, order: 0,
            rawText: "## Mục\n\n> **Bước ngoặt.** Zhongli từ bỏ thần quyền."
        )
        let linked = StoryEntityLinker.link(document: doc, entities: [entity(id: "zhongli", name: "Zhongli")])
        guard case .callout(_, let text) = linked.sections[0].blocks[0] else { return XCTFail() }
        XCTAssertTrue(text.markdown.contains("[Zhongli](story://entity/zhongli)"))
    }

    func testOccurrencesReportsSectionsContainingLinks() {
        let raw = "## Mở đầu\n\nZhongli xuất hiện.\n\n## Kết\n\nKhông có ai."
        let doc = StoryMarkdownParser.parseDocument(id: "doc", kind: .narrativeChapter, order: 0, rawText: raw)
        let linked = StoryEntityLinker.link(document: doc, entities: [entity(id: "zhongli", name: "Zhongli")])
        let found = StoryEntityLinker.occurrences(in: linked)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.entityID, "zhongli")
        XCTAssertEqual(found.first?.sectionID, "mo-dau")
    }
}
