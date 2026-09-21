import { storySlug } from "./slug";

export type StoryDocumentKind = "narrativeChapter" | "questReference";

export type StoryCalloutKind = "turningPoint" | "openMystery" | "note";

export type StoryBlock =
  | { type: "paragraph"; markdown: string }
  | { type: "callout"; kind: StoryCalloutKind; markdown: string }
  | { type: "table"; headers: string[]; rows: string[][] }
  | { type: "list"; items: string[] }
  | { type: "tree"; lines: string[] };

export type StorySection = {
  id: string;
  level: number;
  heading: string;
  blocks: StoryBlock[];
};

export type StoryDocument = {
  id: string;
  kind: StoryDocumentKind;
  title: string;
  order: number;
  sections: StorySection[];
};

type LineKind = "blank" | "blockquote" | "table" | "list" | "tree" | "plain";

function headingInfo(line: string): { level: number; text: string } | null {
  let count = 0;
  while (count < line.length && line[count] === "#") count += 1;
  if (count === 0 || count >= line.length || line[count] !== " ") return null;
  return { level: count, text: line.slice(count + 1).trim() };
}

function classify(line: string): LineKind {
  const trimmed = line.trim();
  if (trimmed.length === 0) return "blank";
  if (trimmed.startsWith(">")) return "blockquote";
  if (trimmed.startsWith("|")) return "table";
  if (trimmed.startsWith("- ")) return "list";
  const first = trimmed[0];
  if (first === "├" || first === "└" || first === "│") return "tree";
  return "plain";
}

function stripQuotePrefix(line: string): string {
  let text = line.trim();
  if (!text.startsWith(">")) return text;
  text = text.slice(1);
  if (text.startsWith(" ")) text = text.slice(1);
  return text;
}

function parseRow(line: string): string[] {
  let text = line.trim();
  if (text.startsWith("|")) text = text.slice(1);
  if (text.endsWith("|")) text = text.slice(0, -1);
  return text.split("|").map((cell) => cell.trim());
}

function makeCallout(lines: string[]): StoryBlock {
  const joined = lines.map(stripQuotePrefix).join(" ");
  let kind: StoryCalloutKind = "note";
  if (joined.startsWith("**Bước ngoặt.**")) kind = "turningPoint";
  else if (joined.startsWith("**Bí ẩn còn bỏ ngỏ.**")) kind = "openMystery";
  return { type: "callout", kind, markdown: joined };
}

function makeTable(lines: string[]): StoryBlock | null {
  if (lines.length < 2) return null;
  const headers = parseRow(lines[0]);
  const rows = lines.slice(2).map(parseRow);
  return { type: "table", headers, rows };
}

function makeList(lines: string[]): StoryBlock {
  const items = lines.map((line) => {
    let text = line.trim();
    if (text.startsWith("- ")) text = text.slice(2);
    return text;
  });
  return { type: "list", items };
}

export function parseBlocks(lines: string[]): StoryBlock[] {
  const blocks: StoryBlock[] = [];
  let buffer: string[] = [];
  let bufferKind: LineKind = "blank";

  const flush = () => {
    if (buffer.length === 0) return;
    switch (bufferKind) {
      case "blockquote":
        blocks.push(makeCallout(buffer));
        break;
      case "table": {
        const table = makeTable(buffer);
        if (table) blocks.push(table);
        break;
      }
      case "list":
        blocks.push(makeList(buffer));
        break;
      case "tree":
        blocks.push({ type: "tree", lines: [...buffer] });
        break;
      case "plain":
        blocks.push({
          type: "paragraph",
          markdown: buffer.map((line) => line.trim()).join(" "),
        });
        break;
      case "blank":
        break;
    }
    buffer = [];
  };

  for (const rawLine of lines) {
    const kind = classify(rawLine);
    if (kind === "blank") {
      flush();
      bufferKind = "blank";
      continue;
    }
    if (kind !== bufferKind) {
      flush();
      bufferKind = kind;
    }
    buffer.push(rawLine);
  }
  flush();
  return blocks;
}

export function parseSections(lines: string[]): StorySection[] {
  const sections: StorySection[] = [];
  const usedSlugs = new Set<string>();
  let currentHeading = "";
  let currentLevel = 1;
  let body: string[] = [];

  const flush = () => {
    const blocks = parseBlocks(body);
    body = [];
    if (blocks.length === 0) return;
    const base = currentHeading.length === 0 ? "mo-dau" : storySlug(currentHeading);
    let slug = base;
    let suffix = 2;
    while (usedSlugs.has(slug)) {
      slug = `${base}-${suffix}`;
      suffix += 1;
    }
    usedSlugs.add(slug);
    sections.push({
      id: slug,
      level: currentLevel,
      heading: currentHeading,
      blocks,
    });
  };

  for (const line of lines) {
    const heading = headingInfo(line);
    if (heading && heading.level <= 3) {
      flush();
      currentHeading = heading.text;
      currentLevel = heading.level;
    } else {
      body.push(line);
    }
  }
  flush();
  return sections;
}

export function parseDocument(
  id: string,
  kind: StoryDocumentKind,
  order: number,
  rawText: string,
): StoryDocument {
  let lines = rawText.split("\n");
  let title = id;
  let leadingIndex = 0;
  while (leadingIndex < lines.length && lines[leadingIndex].trim() === "") {
    leadingIndex += 1;
  }
  if (leadingIndex < lines.length) {
    const heading = headingInfo(lines[leadingIndex]);
    if (heading && heading.level === 1) {
      title = heading.text;
      leadingIndex += 1;
    }
  }
  lines = lines.slice(leadingIndex);
  return { id, kind, title, order, sections: parseSections(lines) };
}
