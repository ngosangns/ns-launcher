import { describe, expect, it } from "vitest";
import { fightTeam, type FightMember } from "./fight";

function carry(ids: string[], weaponFor: Record<string, string> = {}): FightMember[] {
  return ids.map((characterId) => ({
    characterId,
    weaponId: weaponFor[characterId] ?? null,
    artifactSetId: null,
    role: characterId === ids[0] ? "dps" : "support",
  }));
}

describe("team order", () => {
  it("ranks a vaporize Hu Tao team above four Pyro with no aura partner", () => {
    const vape = fightTeam(
      carry(["hu-tao", "xingqiu", "bennett", "sucrose"], {
        "hu-tao": "staff-of-homa",
        bennett: "skyward-blade",
      }),
    );
    const pyro = fightTeam(carry(["amber", "xiangling", "yanfei", "xinyan"]));
    expect(vape.dps).toBeGreaterThan(pyro.dps);
  });

  it("ranks National above the same pyro core without Hydro", () => {
    const national = fightTeam(
      carry(["xiangling", "xingqiu", "bennett", "sucrose"], {
        bennett: "skyward-blade",
        xingqiu: "sacrificial-sword",
      }),
    );
    const pyro = fightTeam(carry(["xiangling", "bennett", "yanfei", "amber"], { bennett: "skyward-blade" }));
    expect(national.dps).toBeGreaterThan(pyro.dps);
  });

  it("ranks an aggravate team above electro without Dendro", () => {
    const aggravate = fightTeam(carry(["keqing", "fischl", "nahida", "sucrose"]));
    const electro = fightTeam(carry(["keqing", "fischl", "beidou", "lisa"]));
    expect(aggravate.dps).toBeGreaterThan(electro.dps);
  });

  it("ranks hyperbloom above dendro and hydro with no Electro trigger", () => {
    const hyper = fightTeam(carry(["nahida", "xingqiu", "kuki-shinobu", "collei"]));
    const bloom = fightTeam(carry(["nahida", "xingqiu", "collei", "yaoyao"]));
    expect(hyper.reactions.some((reaction) => reaction.id === "hyperbloom" || reaction.id === "bloom")).toBe(true);
    expect(hyper.dps).toBeGreaterThan(bloom.dps);
  });
});
