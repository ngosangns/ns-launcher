import XCTest
@testable import NSLauncherApp

/// Covers the five block shapes `StoryMarkdownParser` understands. It is not a
/// general CommonMark parser, so these fixtures mirror the exact subset used
/// under `Resources/Story/` rather than probing arbitrary markdown.
final class StoryMarkdownParserTests: XCTestCase {

    func testTitleAndImplicitLeadingSection() {
        let doc = StoryMarkdownParser.parseDocument(
            id: "01-test",
            kind: .narrativeChapter,
            order: 1,
            rawText: "# Chương Thử Nghiệm\n\n*Tóm tắt.*\n\nĐoạn mở đầu.\n"
        )
        XCTAssertEqual(doc.title, "Chương Thử Nghiệm")
        XCTAssertEqual(doc.sections.count, 1)
        XCTAssertEqual(doc.sections[0].heading, "")
        XCTAssertEqual(doc.sections[0].id, "mo-dau")
        guard case .paragraph(let first) = doc.sections[0].blocks[0] else {
            return XCTFail("expected paragraph")
        }
        XCTAssertEqual(first.markdown, "*Tóm tắt.*")
    }

    func testHeadingsSplitSectionsAndSlugifyVietnamese() {
        let raw = """
        # Tiêu đề

        ## Bí mật của Zhongli

        Nội dung một.

        ## Chân dung nhân vật

        Nội dung hai.
        """
        let doc = StoryMarkdownParser.parseDocument(id: "x", kind: .narrativeChapter, order: 0, rawText: raw)
        XCTAssertEqual(doc.sections.map(\.heading), ["Bí mật của Zhongli", "Chân dung nhân vật"])
        XCTAssertEqual(doc.sections.map(\.id), ["bi-mat-cua-zhongli", "chan-dung-nhan-vat"])
    }

    func testDuplicateHeadingsGetDistinctSlugs() {
        let raw = "## Ghi chú\n\nA\n\n## Ghi chú\n\nB\n"
        let sections = StoryMarkdownParser.parseSections(raw.components(separatedBy: "\n"))
        XCTAssertEqual(sections.map(\.id), ["ghi-chu", "ghi-chu-2"])
    }

    func testWrappedParagraphLinesJoinWithSpace() {
        let blocks = StoryMarkdownParser.parseBlocks([
            "Dòng một chưa hết câu", "và tiếp tục ở dòng hai."
        ])
        guard case .paragraph(let text) = blocks.first else { return XCTFail("expected paragraph") }
        XCTAssertEqual(text.markdown, "Dòng một chưa hết câu và tiếp tục ở dòng hai.")
    }

    func testCalloutDetectsTurningPointAndOpenMystery() {
        let turningPoint = StoryMarkdownParser.parseBlocks([
            "> **Bước ngoặt.** Mọi thứ thay đổi."
        ])
        guard case .callout(let kind, let text) = turningPoint.first else { return XCTFail("expected callout") }
        XCTAssertEqual(kind, .turningPoint)
        XCTAssertEqual(text.markdown, "**Bước ngoặt.** Mọi thứ thay đổi.")

        let openMystery = StoryMarkdownParser.parseBlocks([
            "> **Bí ẩn còn bỏ ngỏ.** Ai đứng sau tất cả?"
        ])
        guard case .callout(let kind, _) = openMystery.first else { return XCTFail("expected callout") }
        XCTAssertEqual(kind, .openMystery)

        let plainNote = StoryMarkdownParser.parseBlocks(["> Một ghi chú khác."])
        guard case .callout(let kind, _) = plainNote.first else { return XCTFail("expected callout") }
        XCTAssertEqual(kind, .note)
    }

    func testMultiLineCalloutJoinsWithSpace() {
        let blocks = StoryMarkdownParser.parseBlocks([
            "> **Bước ngoặt.** Dòng một", "> vẫn tiếp tục ở dòng hai."
        ])
        guard case .callout(_, let text) = blocks.first else { return XCTFail("expected callout") }
        XCTAssertEqual(text.markdown, "**Bước ngoặt.** Dòng một vẫn tiếp tục ở dòng hai.")
    }

    func testTableParsesHeaderAndRowsSkippingSeparator() {
        let blocks = StoryMarkdownParser.parseBlocks([
            "| Act | Nhiệm vụ |",
            "|---|---|",
            "| A | Một |",
            "| B | Hai |"
        ])
        guard case .table(let headers, let rows) = blocks.first else { return XCTFail("expected table") }
        XCTAssertEqual(headers, ["Act", "Nhiệm vụ"])
        XCTAssertEqual(rows, [["A", "Một"], ["B", "Hai"]])
    }

    func testListStripsBulletPerLine() {
        let blocks = StoryMarkdownParser.parseBlocks(["- Một", "- Hai", "- Ba"])
        guard case .list(let items) = blocks.first else { return XCTFail("expected list") }
        XCTAssertEqual(items.map(\.markdown), ["Một", "Hai", "Ba"])
    }

    func testBoxDrawingTreeKeptVerbatimAsOwnBlock() {
        let lines = ["├── The Church's Affairs", "│   └── A Very Special Beverage", "└── Sudden Shouting"]
        let blocks = StoryMarkdownParser.parseBlocks(lines)
        guard case .tree(let treeLines) = blocks.first else { return XCTFail("expected tree") }
        XCTAssertEqual(treeLines, lines)
    }

    func testBlankLinesSeparateDistinctBlocksOfSameKind() {
        let blocks = StoryMarkdownParser.parseBlocks(["Đoạn một.", "", "Đoạn hai."])
        XCTAssertEqual(blocks.count, 2)
    }

    func testAdjacentDifferentKindsFlushWithoutBlankLine() {
        let blocks = StoryMarkdownParser.parseBlocks(["Đoạn văn.", "- Mục danh sách"])
        XCTAssertEqual(blocks.count, 2)
        guard case .paragraph = blocks[0] else { return XCTFail("expected paragraph first") }
        guard case .list = blocks[1] else { return XCTFail("expected list second") }
    }
}
