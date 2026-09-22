import type { StoryBlock, StoryDocument } from "./markdown";

export type StoryEntityKind =
  | "character"
  | "archon"
  | "faction"
  | "nation"
  | "event"
  | "concept";

export type StoryEntity = {
  id: string;
  kind: StoryEntityKind;
  displayName: string;
  displayNameEN?: string;
  aliases: string[];
  aliasesEN?: string[];
  summary: string | null;
  summaryEN?: string | null;
  homeDocument: string;
  homeHeading: string | null;
  homeHeadingEN?: string | null;
};

export type StoryOccurrence = {
  documentID: string;
  documentTitle: string;
  documentKind: StoryDocument["kind"];
  sectionID: string;
  sectionHeading: string;
};

export const ENTITY_KIND_ORDER: StoryEntityKind[] = [
  "archon",
  "character",
  "nation",
  "faction",
  "event",
  "concept",
];

export function entityHref(id: string): string {
  return `/story/e/${id}`;
}

function matchTerms(entity: StoryEntity): string[] {
  return [entity.displayName, ...entity.aliases].sort((a, b) => b.length - a.length);
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function buildLookup(entities: StoryEntity[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const entity of entities) {
    for (const term of matchTerms(entity)) {
      if (!map.has(term)) map.set(term, entity.id);
    }
  }
  return map;
}

function buildRegex(entities: StoryEntity[]): RegExp | null {
  const terms = entities.flatMap(matchTerms).sort((a, b) => b.length - a.length);
  if (terms.length === 0) return null;
  const pattern = `(?<![\\p{L}\\p{N}])(${terms.map(escapeRegExp).join("|")})(?![\\p{L}\\p{N}])`;
  return new RegExp(pattern, "gu");
}

function linkedMarkdown(text: string, regex: RegExp, lookup: Map<string, string>): string {
  regex.lastIndex = 0;
  let result = "";
  let lastEnd = 0;
  for (const match of text.matchAll(regex)) {
    const index = match.index ?? 0;
    if (index < lastEnd) continue;
    result += text.slice(lastEnd, index);
    const matchedText = match[0];
    const id = lookup.get(matchedText);
    result += id ? `[${matchedText}](${entityHref(id)})` : matchedText;
    lastEnd = index + matchedText.length;
  }
  result += text.slice(lastEnd);
  return result;
}

function linkBlocks(blocks: StoryBlock[], regex: RegExp, lookup: Map<string, string>): StoryBlock[] {
  return blocks.map((block) => {
    if (block.type === "paragraph") {
      return { ...block, markdown: linkedMarkdown(block.markdown, regex, lookup) };
    }
    if (block.type === "callout") {
      return { ...block, markdown: linkedMarkdown(block.markdown, regex, lookup) };
    }
    return block;
  });
}

export function linkDocument(document: StoryDocument, entities: StoryEntity[]): StoryDocument {
  const regex = buildRegex(entities);
  if (!regex) return document;
  const lookup = buildLookup(entities);
  return {
    ...document,
    sections: document.sections.map((section) => ({
      ...section,
      blocks: linkBlocks(section.blocks, regex, lookup),
    })),
  };
}

const ENTITY_LINK = /\/story\/e\/([a-z0-9-]+)/g;

export function entityIDsIn(markdown: string): string[] {
  const ids: string[] = [];
  ENTITY_LINK.lastIndex = 0;
  for (const match of markdown.matchAll(ENTITY_LINK)) {
    ids.push(match[1]);
  }
  return ids;
}

export function occurrencesIn(
  document: StoryDocument,
): Array<{ entityID: string; sectionID: string }> {
  const found: Array<{ entityID: string; sectionID: string }> = [];
  for (const section of document.sections) {
    const ids = new Set<string>();
    for (const block of section.blocks) {
      if (block.type === "paragraph" || block.type === "callout") {
        for (const id of entityIDsIn(block.markdown)) ids.add(id);
      }
    }
    for (const entityID of ids) {
      found.push({ entityID, sectionID: section.id });
    }
  }
  return found;
}
