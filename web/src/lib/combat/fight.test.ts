import { describe, expect, it } from "vitest";
import { fightTeam, reactionBonusFromText, type FightMember } from "./fight";

function team(ids: string[]): FightMember[] {
  return ids.map((characterId) => ({ characterId, weaponId: null, artifactSetId: null, role: "dps" }));
}

function count(result: { reactions: Array<{ id: string; count: number }> }, id: string): number {
  return result.reactions.find((reaction) => reaction.id === id)?.count ?? 0;
}

describe("fight", () => {
  it("reads the current floor-12 ley line bonuses", () => {
    const first = reactionBonusFromText(
      "Nửa 1: Nhân vật tăng 200% sát thương phản ứng Khuếch Tán, tăng 75% sát thương Tinh-Khuếch Tán (Stellar Swirl).",
    );
    const second = reactionBonusFromText(
      "Nửa 2: Nhân vật tăng 200% sát thương phản ứng Điện Cảm (Electro-Charged), tăng 75% sát thương Nguyệt-Điện Cảm (Lunar-Charged).",
    );
    expect(first.swirl).toBeCloseTo(2);
    expect(first["stellar-swirl"]).toBeCloseTo(0.75);
    expect(second["electro-charged"]).toBeCloseTo(2);
    expect(second["lunar-charged"]).toBeCloseTo(0.75);
  });

  it("vaporizes with Xiangling and Xingqiu, and not with pyro or hydro alone", () => {
    const vape = fightTeam(team(["xiangling", "xingqiu", "bennett", "sucrose"]));
    const pyro = fightTeam(team(["xiangling", "bennett", "yanfei", "amber"]));
    const hydro = fightTeam(team(["xingqiu", "mona", "barbara", "sangonomiya-kokomi"]));
    expect(count(vape, "vaporize")).toBeGreaterThan(0);
    expect(count(pyro, "vaporize")).toBe(0);
    expect(count(hydro, "vaporize")).toBe(0);
  });

  it("applies Bennett's burst attack only inside the burst window", () => {
    const result = fightTeam(
      [
        { characterId: "bennett", weaponId: "skyward-blade", artifactSetId: null, role: "dps", energyRecharge: 5 },
        { characterId: "xiangling", weaponId: null, artifactSetId: null, role: "dps" },
        { characterId: "xingqiu", weaponId: null, artifactSetId: null, role: "dps" },
        { characterId: "sucrose", weaponId: null, artifactSetId: null, role: "dps" },
      ],
      { onFieldId: "bennett" },
    );
    const burstAt = result.hits.find((hit) => hit.owner === "bennett" && hit.kind === "burst")?.time;
    expect(burstAt).toBeDefined();
    const ratio = (from: number, to: number) => {
      const hits = result.hits.filter(
        (hit) => hit.owner === "bennett" && hit.kind === "combo" && hit.motion > 0 && hit.time >= from && hit.time < to,
      );
      if (hits.length === 0) return null;
      return hits.reduce((sum, hit) => sum + hit.damage / hit.motion, 0) / hits.length;
    };
    const start = burstAt ?? 0;
    const inside = ratio(start, start + 12);
    const outside = ratio(start + 12, 30);
    expect(inside).not.toBeNull();
    expect(outside).not.toBeNull();
    expect(inside ?? 0).toBeGreaterThan(outside ?? 0);
  });

  it("does not lose damage when resistance is shredded", () => {
    const members = team(["hu-tao", "xingqiu", "bennett", "sucrose"]);
    const plain = fightTeam(members, { res: { Pyro: 0.1, Hydro: 0.1, Anemo: 0.1, Physical: 0.1 } });
    const shredded = fightTeam(members, {
      res: { Pyro: 0.1, Hydro: 0.1, Anemo: 0.1, Physical: 0.1 },
      extraResShred: 0.4,
    });
    expect(shredded.damage).toBeGreaterThanOrEqual(plain.damage);
  });

  it("keeps Xiangling's pyronado and Xingqiu's rain swords going for their duration", () => {
    const result = fightTeam(
      [
        { characterId: "xiangling", weaponId: null, artifactSetId: null, role: "dps", energyRecharge: 4 },
        { characterId: "xingqiu", weaponId: null, artifactSetId: null, role: "support", energyRecharge: 4 },
        { characterId: "bennett", weaponId: "skyward-blade", artifactSetId: null, role: "support", energyRecharge: 4 },
        { characterId: "sucrose", weaponId: null, artifactSetId: null, role: "support" },
      ],
      { onFieldId: "xiangling" },
    );
    const span = (owner: string, kind: "skill" | "burst") => {
      const times = result.hits.filter((hit) => hit.owner === owner && hit.kind === kind).map((hit) => hit.time);
      if (times.length === 0) return 0;
      return Math.max(...times) - Math.min(...times);
    };
    const bursts = (owner: string) => result.hits.filter((hit) => hit.owner === owner && hit.kind === "burst");
    expect(bursts("xiangling").length).toBeGreaterThan(6);
    expect(span("xiangling", "burst")).toBeGreaterThan(6);
    expect(bursts("xingqiu").length).toBeGreaterThan(8);
    expect(span("xingqiu", "burst")).toBeGreaterThan(10);
    expect(bursts("bennett")).toHaveLength(1);
    const oz = fightTeam([{ characterId: "fischl", weaponId: null, artifactSetId: null, role: "dps" }, ...team(["bennett", "xiangling", "xingqiu"]).slice(0, 3)]);
    expect(oz.hits.filter((hit) => hit.owner === "fischl" && hit.kind === "skill").length).toBeGreaterThanOrEqual(8);
  });

  it("raises swirl damage with the ley line, and a vaporize team outdamages four Pyro", () => {
    const swirl = team(["sucrose", "xiangling", "kaeya", "bennett"]);
    const bonus = reactionBonusFromText("Nhân vật tăng 200% sát thương phản ứng Khuếch Tán.");
    const buffed = fightTeam(swirl, { reactionBonus: bonus });
    const plain = fightTeam(swirl);
    const geo = fightTeam(team(["noelle", "ningguang", "zhongli", "albedo"]));
    expect(count(buffed, "swirl")).toBeGreaterThan(0);
    expect(count(geo, "swirl")).toBe(0);
    expect(buffed.dps).toBeGreaterThan(plain.dps);

    const vape = fightTeam([
      { characterId: "hu-tao", weaponId: "staff-of-homa", artifactSetId: "crimson-witch-of-flames", role: "dps" },
      { characterId: "xingqiu", weaponId: "sacrificial-sword", artifactSetId: "emblem-of-severed-fate", role: "support" },
      { characterId: "bennett", weaponId: "skyward-blade", artifactSetId: "noblesse-oblige", role: "support" },
      { characterId: "sucrose", weaponId: "sacrificial-fragments", artifactSetId: "viridescent-venerer", role: "support" },
    ]);
    const pyro = fightTeam([
      { characterId: "amber", weaponId: null, artifactSetId: null, role: "dps" },
      { characterId: "xiangling", weaponId: null, artifactSetId: null, role: "dps" },
      { characterId: "yanfei", weaponId: null, artifactSetId: null, role: "dps" },
      { characterId: "xinyan", weaponId: null, artifactSetId: null, role: "dps" },
    ]);
    expect(count(vape, "vaporize")).toBeGreaterThan(0);
    expect(count(pyro, "vaporize")).toBe(0);
    expect(vape.dps).toBeGreaterThan(pyro.dps);
  });
});
