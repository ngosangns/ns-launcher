import { describe, expect, it } from "vitest";
import { computeDynamicSecret, parseHoyolabCredential, pickGameRole } from "./hoyolab";
import { md5 } from "./md5";
import { findTeams, roleOf } from "./planner";
import { artifactMains } from "./combat/sheet";
import { charactersByID } from "./abyss";
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

  it("reads a pasted cookie and picks the requested or highest-level role", () => {
    expect(parseHoyolabCredential("ltuid_v2=98671210; ltoken_v2=v2_abc", "")).toEqual({
      ltuid: "98671210",
      ltoken: "v2_abc",
    });
    const roles = [
      { game_uid: "800000001", region: "os_asia", level: 48, nickname: "asia" },
      { game_uid: "700000001", region: "os_euro", level: 59, nickname: "euro" },
    ];
    expect(pickGameRole(roles).game_uid).toBe("700000001");
    expect(pickGameRole(roles, "800000001").nickname).toBe("asia");
    expect(() => pickGameRole(roles, "612345678")).toThrow(/không nằm trong tài khoản/);
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

  it("attaches artifact main-stat advice to every planned member", () => {
    const output = findTeams(parseRoster({ characters: [], weapons: [] }), {
      fullCharacters: true,
      fullWeapons: true,
    });
    const members = output.plans.flatMap((plan) => [...plan.half1.members, ...plan.half2.members]);
    expect(members.length).toBeGreaterThan(0);
    for (const member of members) {
      expect(member.artifactMains?.sands).toBeTruthy();
      expect(member.artifactMains?.goblet).toBeTruthy();
      expect(member.artifactMains?.circlet).toBeTruthy();
    }
  });
});

describe("roleOf", () => {
  // Regression: sustain words inside "cần …"/"combo phổ biến" clauses describe
  // teammates, so on-field carries used to be misread as shielders/healers.
  it.each([
    ["yoimiya", "dps"],
    ["xiao", "dps"],
    ["sandrone", "dps"],
    ["eula", "dps"],
    ["furina", "support"],
    ["charlotte", "healer"],
    ["zhongli", "shield"],
    ["kuki-shinobu", "healer"],
  ])("%s is %s", (id, expected) => {
    const character = charactersByID[id];
    expect(character, id).toBeTruthy();
    expect(roleOf(character)).toBe(expected);
  });
});

describe("artifactMains", () => {
  it("recommends ER + elemental DMG + CRIT for a burst-reliant support", () => {
    const mains = artifactMains("xingqiu", "support");
    expect(mains.sands).toBe("ER");
    expect(mains.goblet).toBe("Hydro DMG");
    expect(mains.circlet).toBe("CRIT Rate");
  });

  it("recommends full EM for Anemo supports (swirl drivers)", () => {
    expect(artifactMains("sucrose", "support")).toEqual({ sands: "EM", goblet: "EM", circlet: "EM" });
  });

  it("recommends healing builds for healers", () => {
    const mains = artifactMains("sangonomiya-kokomi", "healer");
    expect(mains.circlet).toBe("Healing Bonus");
    expect(mains.goblet).toBe("HP%");
  });
});
