import { leadingNumber } from "./slug";
import { parseDocument, type StoryDocument } from "./markdown";
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

const questModules = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Story/quests/*.md",
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

function buildLibrary(): StoryLibrary {
  const entities = (entitiesJson as StoryEntity[]).slice().sort((a, b) =>
    a.displayName.localeCompare(b.displayName, "vi"),
  );
  const parsed = [
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

export const storyLibrary = buildLibrary();

export function chaptersOf(library: StoryLibrary): StoryDocument[] {
  return library.documents.filter((doc) => doc.kind === "narrativeChapter");
}

export function questsOf(library: StoryLibrary): StoryDocument[] {
  return library.documents.filter((doc) => doc.kind === "questReference");
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
