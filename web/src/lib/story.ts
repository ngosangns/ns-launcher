import { charactersByID } from "./abyss";
import { leadingNumber, storySlug } from "./slug";
import { parseDocument, type StoryDocument } from "./markdown";

export type { StoryDocument } from "./markdown";
import {
  ENTITY_KIND_ORDER,
  linkDocument,
  occurrencesIn,
  type StoryEntity,
  type StoryEntityKind,
  type StoryOccurrence,
} from "./entityLinker";

const chapterModules = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Story/chapters/*.md",
  { query: "?raw", eager: true, import: "default" },
) as Record<string, string>;

const chapterModulesEN = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Story/chapters/en/*.md",
  { query: "?raw", eager: true, import: "default" },
) as Record<string, string>;

const questModules = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Story/quests/*.md",
  { query: "?raw", eager: true, import: "default" },
) as Record<string, string>;

const questModulesEN = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Story/quests/en/*.md",
  { query: "?raw", eager: true, import: "default" },
) as Record<string, string>;

import entitiesJson from "../../../Sources/NSLauncherApp/Resources/Story/story-entities.json";

function stem(path: string): string {
  const file = path.split("/").pop() ?? path;
  return file.replace(/\.md$/u, "");
}

function loadKind(
  modules: Record<string, string>,
  kind: StoryDocument["kind"],
): StoryDocument[] {
  return Object.entries(modules).map(([path, raw]) => {
    const id = stem(path);
    return parseDocument(id, kind, leadingNumber(id), raw);
  });
}

export type StoryLibrary = {
  documents: StoryDocument[];
  documentsByID: Record<string, StoryDocument>;
  entities: StoryEntity[];
  entitiesByID: Record<string, StoryEntity>;
  occurrences: Record<string, StoryOccurrence[]>;
};

function buildLibrary(lang: "vi" | "en"): StoryLibrary {
  const entities = (entitiesJson as StoryEntity[])
    .map((entity) =>
      lang === "en"
        ? {
            ...entity,
            displayName: entity.displayNameEN ?? entity.displayName,
            aliases: entity.aliasesEN ?? entity.aliases,
            summary: entity.summaryEN ?? entity.summary,
            homeHeading: entity.homeHeadingEN ?? entity.homeHeading,
          }
        : entity,
    )
    .slice()
    .sort((a, b) => a.displayName.localeCompare(b.displayName, lang === "vi" ? "vi" : "en"));
  const parsed =
    lang === "en"
      ? [
          ...loadKind(chapterModulesEN, "narrativeChapter"),
          ...loadKind(questModulesEN, "questReference"),
        ]
      : [
          ...loadKind(chapterModules, "narrativeChapter"),
          ...loadKind(questModules, "questReference"),
        ];
  const linked = parsed
    .map((document) => linkDocument(document, entities))
    .sort((a, b) => a.order - b.order);


  const documentsByID = Object.fromEntries(linked.map((doc) => [doc.id, doc]));
  const entitiesByID = Object.fromEntries(entities.map((entity) => [entity.id, entity]));
  const occurrences: Record<string, StoryOccurrence[]> = {};

  for (const document of linked) {
    for (const { entityID, sectionID } of occurrencesIn(document)) {
      const section = document.sections.find((item) => item.id === sectionID);
      if (!section) continue;
      (occurrences[entityID] ??= []).push({
        documentID: document.id,
        documentTitle: document.title,
        documentKind: document.kind,
        sectionID: section.id,
        sectionHeading: section.heading,
      });
    }
  }

  for (const entity of entities) {
    const homeDocument = documentsByID[entity.homeDocument];
    if (!homeDocument) continue;
    const homeSection =
      (entity.homeHeading
        ? homeDocument.sections.find((section) => section.heading === entity.homeHeading)
        : undefined) ?? homeDocument.sections[0];
    if (!homeSection) continue;
    const home: StoryOccurrence = {
      documentID: homeDocument.id,
      documentTitle: homeDocument.title,
      documentKind: homeDocument.kind,
      sectionID: homeSection.id,
      sectionHeading: homeSection.heading,
    };
    const list = (occurrences[entity.id] ?? []).filter(
      (item) => !(item.documentID === home.documentID && item.sectionID === home.sectionID),
    );
    list.unshift(home);
    occurrences[entity.id] = list;
  }

  return { documents: linked, documentsByID, entities, entitiesByID, occurrences };
}

export const storyLibrary = buildLibrary("vi");
export const storyLibraryEN = buildLibrary("en");

export function chaptersOf(library: StoryLibrary): StoryDocument[] {
  return library.documents.filter((doc) => doc.kind === "narrativeChapter");
}

export function questsOf(library: StoryLibrary): StoryDocument[] {
  return library.documents.filter((doc) => doc.kind === "questReference");
}

export type QuestFace = {
  sectionID: string;
  title: string;
  iconId?: string;
};

// Chapter portraits for the Archon Quest sidebar. Song of the Welkin Moon
// uses Columbina, the playable lead of that chapter.
const ARCHON_CHAPTER_ICONS: Array<[RegExp, string]> = [
  [/^prologue\b/i, "venti"],
  [/^chapter i:/i, "zhongli"],
  [/^chapter ii:/i, "raiden-shogun"],
  [/^chapter iii:/i, "nahida"],
  [/^chapter iv:/i, "furina"],
  [/^chapter v:/i, "mavuika"],
  [/^song of the welkin moon\b/i, "columbina"],
  [/^chapter vii:/i, "tsaritsa"],
];

function knownIcon(id: string | undefined): string | undefined {
  if (id && charactersByID[id]) return id;
  return undefined;
}

function iconIdForName(name: string): string | undefined {
  const stripped = name.replace(/\s*\([^)]*\)\s*/gu, " ").replace(/\s+/gu, " ").trim();
  return knownIcon(storySlug(stripped));
}

/** Character story chapters and Archon Quest chapters, for sidebar avatars. */
export function questFaces(doc: StoryDocument): QuestFace[] {
  if (doc.id === "02-story-quests") {
    return doc.sections
      .filter((section) => section.level === 3 && section.heading)
      .map((section) => {
        const name = section.heading.split(/\s+[—–]\s+/u).at(-1)?.trim() ?? section.heading;
        return { sectionID: section.id, title: section.heading, iconId: iconIdForName(name) };
      });
  }
  if (doc.id === "01-archon-quests") {
    return doc.sections
      .filter((section) => section.level === 2 && section.heading && section.heading !== "Nguồn")
      .map((section) => {
        const iconId = ARCHON_CHAPTER_ICONS.find(([pattern]) => pattern.test(section.heading))?.[1];
        return { sectionID: section.id, title: section.heading, iconId: knownIcon(iconId) };
      });
  }
  return [];
}

// Entity ids that differ from their character icon id.
const ENTITY_ICON_ALIASES: Record<string, string> = {
  ayaka: "kamisato-ayaka",
  ayato: "kamisato-ayato",
  traveler: "traveler-anemo",
};

/** Character icon id for a story entity, when one exists. */
export function entityIconId(entity: StoryEntity): string | undefined {
  if (entity.kind !== "character" && entity.kind !== "archon") return undefined;
  return knownIcon(ENTITY_ICON_ALIASES[entity.id] ?? entity.id);
}

export function entitiesByKind(
  entities: StoryEntity[],
): Array<{ kind: StoryEntityKind; entities: StoryEntity[] }> {
  return ENTITY_KIND_ORDER.flatMap((kind) => {
    const matches = entities.filter((entity) => entity.kind === kind);
    return matches.length === 0 ? [] : [{ kind, entities: matches }];
  });
}

export function documentHref(id: string, sectionID?: string): string {
  return sectionID ? `/story/d/${id}/${sectionID}` : `/story/d/${id}`;
}
