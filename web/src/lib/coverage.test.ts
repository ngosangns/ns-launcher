import { describe, expect, it } from "vitest";
import {
  artifactSets,
  characters,
  charactersWithTag,
  cycles,
  damageFormula,
  teamBonus,
  weapons,
} from "./abyss";
import { chaptersOf, questFaces, questsOf, storyLibrary } from "./story";

describe("story coverage", () => {
  it("loads every bundled chapter, quest file, and entity", () => {
    expect(chaptersOf(storyLibrary).map((d) => d.id)).toEqual([
      "00-mo-dau-mondstadt",
      "01-liyue",
      "02-inazuma",
      "03-sumeru",
      "04-fontaine",
      "05-natlan",
      "06-nod-krai",
      "07-snezhnaya",
      "08-buc-tranh-lon",
    ]);
    expect(questsOf(storyLibrary)).toHaveLength(12);
    expect(storyLibrary.entities).toHaveLength(98);
  });

  it("gives character and archon quest chapters an avatar id", () => {
    const story = questFaces(storyLibrary.documentsByID["02-story-quests"]);
    expect(story.find((face) => face.title.includes("Amber"))?.iconId).toBe("amber");
    expect(story.find((face) => face.title.includes("Hu Tao"))?.iconId).toBe("hu-tao");
    expect(story.find((face) => face.title.includes("Tartaglia"))?.iconId).toBe("tartaglia");
    expect(story.every((face) => face.iconId)).toBe(true);

    const archon = questFaces(storyLibrary.documentsByID["01-archon-quests"]);
    expect(archon.find((face) => face.title.startsWith("Prologue"))?.iconId).toBe("venti");
    expect(archon.find((face) => face.title.startsWith("Chapter I:"))?.iconId).toBe("zhongli");
    expect(archon.find((face) => face.title.startsWith("Chapter III:"))?.iconId).toBe("nahida");
    expect(archon.some((face) => face.title === "Nguồn")).toBe(false);
  });

  it("parses hangout quest trees", () => {
    const hangout = storyLibrary.documentsByID["09-hangout-events"];
    const trees = hangout.sections.flatMap((s) => s.blocks.filter((b) => b.type === "tree"));
    expect(trees.length).toBeGreaterThan(0);
  });
});

describe("abyss coverage", () => {
  it("loads the full catalogs and the current cycle", () => {
    expect(characters).toHaveLength(125);
    expect(weapons).toHaveLength(246);
    expect(artifactSets).toHaveLength(63);
    expect(cycles.map((cycle) => cycle.fileId)).toEqual(["2026-09-16-den-2026-10-15"]);
    expect(cycles[0]?.floors.some((floor) => floor.floor === 12)).toBe(true);
  });

  it("keeps kit tags and talent tables on characters", () => {
    expect(charactersWithTag("moonsign").length).toBeGreaterThanOrEqual(10);
    expect(charactersWithTag("hexerei").length).toBeGreaterThanOrEqual(12);
    const huTao = characters.find((c) => c.id === "hu-tao");
    expect(huTao?.elementalSkill.scaling?.length).toBeGreaterThan(0);
    expect(huTao?.kit?.conversions?.length).toBeGreaterThan(0);
  });

  it("covers the planner use case on the example roster", async () => {
    const { parseRoster } = await import("./roster");
    const { findTeams } = await import("./planner");
    const { default: example } = await import(
      "../../../Tests/NSLauncherAppTests/Fixtures/roster.example.json"
    );
    const output = findTeams(parseRoster(example), { fullCharacters: false, fullWeapons: false });
    expect(output.half1Text).toMatch(/Khuếch Tán|Swirl/i);
    expect(output.half2Text).toMatch(/Điện Cảm|Electro-Charged/i);
    expect(output.plans.length).toBeGreaterThan(0);
  });

  it("exposes every damage-formula and team-bonus section", () => {
    expect(teamBonus.elementalResonance).toHaveLength(8);
    expect(teamBonus.moonsign.lunarReactionDmgBonusByElement?.length).toBeGreaterThan(0);
    expect(damageFormula.lunarStellar?.direct).toBeTruthy();
    expect(damageFormula.workedExample?.result.value).toBeGreaterThan(0);
  });
});
