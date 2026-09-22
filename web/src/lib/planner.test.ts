import { describe, expect, it } from "vitest";
import { computeDynamicSecret } from "./hoyolab";
import { md5 } from "./md5";
import { findTeams } from "./planner";
import { parseRoster } from "./roster";
import rosterExample from "../../../Tests/NSLauncherAppTests/Fixtures/roster.example.json";

describe("md5 / HoYoLAB ds", () => {
  it("matches the genshin.py reference secret", () => {
    expect(md5("salt=6s25p5ox5y14umn1p61aqyyvbvvl3lrt&t=1700000000&r=AbCdEf")).toBe(
      "52762c606b53f6830e4692f53664105e",
    );
    expect(computeDynamicSecret(1_700_000_000, "AbCdEf")).toBe(
      "1700000000,AbCdEf,52762c606b53f6830e4692f53664105e",
    );
  });
});

describe("findTeams", () => {
  it("returns five disjoint floor-12 plans for the example roster", () => {
    const roster = parseRoster(rosterExample);
    const output = findTeams(roster, { fullCharacters: false, fullWeapons: false });
    expect(output.plans.length).toBeGreaterThan(0);
    expect(output.plans.length).toBeLessThanOrEqual(5);
    expect(output.plans[0].score).toBeGreaterThan(0);
    expect(output.plans[0].half1.rotation.length + output.plans[0].half2.rotation.length).toBeGreaterThan(0);
    for (const plan of output.plans) {
      const ids = [
        ...plan.half1.members.map((m) => m.characterId),
        ...plan.half2.members.map((m) => m.characterId),
      ];
      expect(ids).toHaveLength(8);
      expect(new Set(ids).size).toBe(8);
      expect(plan.half1.members).toHaveLength(4);
      expect(plan.half2.members).toHaveLength(4);
    }
  });

  it("can search the full character pool", () => {
    const output = findTeams(parseRoster({ characters: [], weapons: [] }), {
      fullCharacters: true,
      fullWeapons: true,
    });
    expect(output.plans.length).toBeGreaterThan(0);
  });
});
