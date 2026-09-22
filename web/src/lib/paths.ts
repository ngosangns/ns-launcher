export type TopTab = "home" | "story" | "abyss";

export type StoryPath = {
  docId?: string;
  sectionId?: string;
  entityId?: string;
};

export type AbyssPath = {
  section: string;
  id?: string;
};

export function topTab(pathname: string): TopTab {
  if (pathname.startsWith("/story")) return "story";
  if (pathname.startsWith("/abyss")) return "abyss";
  return "home";
}

export function parseStoryPath(pathname: string): StoryPath {
  const entity = pathname.match(/^\/story\/e\/([^/]+)/u);
  if (entity) return { entityId: decodeURIComponent(entity[1]) };
  const document = pathname.match(/^\/story\/d\/([^/]+)(?:\/([^/]+))?/u);
  if (document) {
    return {
      docId: decodeURIComponent(document[1]),
      sectionId: document[2] ? decodeURIComponent(document[2]) : undefined,
    };
  }
  return {};
}

export function parseAbyssPath(pathname: string): AbyssPath {
  const parts = pathname.split("/").filter(Boolean);
  if (parts[0] !== "abyss") return { section: "team" };
  return { section: parts[1] ?? "team", id: parts[2] };
}

export function abyssSectionActive(pathname: string, section: string): boolean {
  const parsed = parseAbyssPath(pathname);
  if (section === "characters") return parsed.section === "characters";
  if (section === "weapons") return parsed.section === "weapons";
  if (section === "artifacts") return parsed.section === "artifacts";
  return parsed.section === section && !parsed.id;
}
