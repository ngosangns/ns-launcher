import { describe, expect, it } from "vitest";
import { parseBlocks, parseDocument, parseSections } from "./markdown";
import { linkDocument, type StoryEntity } from "./entityLinker";

describe("StoryMarkdownParser", () => {
  it("takes the H1 as title and the lead as an implicit section", () => {
    const doc = parseDocument(
      "01-test",
      "narrativeChapter",
      1,
      "# Chương Thử Nghiệm\n\n*Tóm tắt.*\n\nĐoạn mở đầu.\n",
    );
    expect(doc.title).toBe("Chương Thử Nghiệm");
    expect(doc.sections).toHaveLength(1);
    expect(doc.sections[0].heading).toBe("");
    expect(doc.sections[0].id).toBe("mo-dau");
    expect(doc.sections[0].blocks[0]).toEqual({ type: "paragraph", markdown: "*Tóm tắt.*" });
  });

  it("splits headings and slugifies Vietnamese", () => {
    const raw = `# Tiêu đề

## Bí mật của Zhongli

Nội dung một.

## Chân dung nhân vật

Nội dung hai.
`;
    const doc = parseDocument("x", "narrativeChapter", 0, raw);
    expect(doc.sections.map((s) => s.heading)).toEqual([
      "Bí mật của Zhongli",
      "Chân dung nhân vật",
    ]);
    expect(doc.sections.map((s) => s.id)).toEqual(["bi-mat-cua-zhongli", "chan-dung-nhan-vat"]);
  });

  it("gives duplicate headings distinct slugs", () => {
    const sections = parseSections("## Ghi chú\n\nA\n\n## Ghi chú\n\nB\n".split("\n"));
    expect(sections.map((s) => s.id)).toEqual(["ghi-chu", "ghi-chu-2"]);
  });

  it("joins wrapped paragraph lines with a space", () => {
    const blocks = parseBlocks(["Dòng một chưa hết câu", "và tiếp tục ở dòng hai."]);
    expect(blocks[0]).toEqual({
      type: "paragraph",
      markdown: "Dòng một chưa hết câu và tiếp tục ở dòng hai.",
    });
  });

  it("detects turning-point and open-mystery callouts", () => {
    const turning = parseBlocks(["> **Bước ngoặt.** Mọi thứ thay đổi."]);
    expect(turning[0]).toMatchObject({
      type: "callout",
      kind: "turningPoint",
      markdown: "**Bước ngoặt.** Mọi thứ thay đổi.",
    });
    const mystery = parseBlocks(["> **Bí ẩn còn bỏ ngỏ.** Ai đứng sau tất cả?"]);
    expect(mystery[0]).toMatchObject({ type: "callout", kind: "openMystery" });
    const note = parseBlocks(["> Một ghi chú khác."]);
    expect(note[0]).toMatchObject({ type: "callout", kind: "note" });
  });

  it("joins multi-line callouts with a space", () => {
    const blocks = parseBlocks([
      "> **Bước ngoặt.** Dòng một",
      "> vẫn tiếp tục ở dòng hai.",
    ]);
    expect(blocks[0]).toMatchObject({
      markdown: "**Bước ngoặt.** Dòng một vẫn tiếp tục ở dòng hai.",
    });
  });

  it("parses a table, skipping the separator row", () => {
    const blocks = parseBlocks([
      "| Act | Nhiệm vụ |",
      "|---|---|",
      "| A | Một |",
      "| B | Hai |",
    ]);
    expect(blocks[0]).toEqual({
      type: "table",
      headers: ["Act", "Nhiệm vụ"],
      rows: [
        ["A", "Một"],
        ["B", "Hai"],
      ],
    });
  });

  it("strips list bullets", () => {
    const blocks = parseBlocks(["- Một", "- Hai", "- Ba"]);
    expect(blocks[0]).toEqual({ type: "list", items: ["Một", "Hai", "Ba"] });
  });

  it("keeps box-drawing trees verbatim", () => {
    const lines = [
      "├── The Church's Affairs",
      "│   └── A Very Special Beverage",
      "└── Sudden Shouting",
    ];
    expect(parseBlocks(lines)[0]).toEqual({ type: "tree", lines });
  });

  it("splits same-kind blocks on a blank line", () => {
    expect(parseBlocks(["Đoạn một.", "", "Đoạn hai."])).toHaveLength(2);
  });

  it("flushes when the kind changes without a blank line", () => {
    const blocks = parseBlocks(["Đoạn văn.", "- Mục danh sách"]);
    expect(blocks[0].type).toBe("paragraph");
    expect(blocks[1].type).toBe("list");
  });
});

describe("entity linker", () => {
  it("turns a display name into an internal link", () => {
    const entities: StoryEntity[] = [
      {
        id: "venti",
        kind: "archon",
        displayName: "Venti",
        aliases: ["Barbatos"],
        summary: null,
        homeDocument: "00-mo-dau-mondstadt",
        homeHeading: null,
      },
    ];
    const doc = parseDocument(
      "t",
      "narrativeChapter",
      0,
      "# T\n\nVenti lộ diện chính là Barbatos.\n",
    );
    const linked = linkDocument(doc, entities);
    const paragraph = linked.sections[0].blocks[0];
    expect(paragraph.type).toBe("paragraph");
    if (paragraph.type === "paragraph") {
      expect(paragraph.markdown).toContain("[Venti](/story/e/venti)");
      expect(paragraph.markdown).toContain("[Barbatos](/story/e/venti)");
    }
  });
});
