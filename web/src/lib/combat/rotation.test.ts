import { describe, expect, it } from "vitest";
import { ROTATION_FRAMES } from "./catalog";
import { scheduleTeam } from "./rotation";
import { characterProfile } from "./talent";

describe("rotation", () => {
  const team = ["bennett", "xiangling", "xingqiu", "sucrose"];

  it("casts Bennett's skill twice and gates his burst on energy", () => {
    const funded = scheduleTeam(team, "bennett", { bennett: 5, xiangling: 1, xingqiu: 1, sucrose: 1 });
    expect(funded.actions.filter((action) => action.owner === "bennett" && action.kind === "skill")).toHaveLength(2);
    expect(funded.actions.filter((action) => action.owner === "bennett" && action.kind === "burst")).toHaveLength(1);

    const broke = scheduleTeam(team, "bennett", { bennett: 1, xiangling: 1, xingqiu: 1, sucrose: 1 });
    expect(broke.actions.filter((action) => action.owner === "bennett" && action.kind === "burst")).toHaveLength(0);
  });

  it("never overlaps two casts and gives the on-fielder the remaining frames", () => {
    const rotation = scheduleTeam(team, "bennett", { bennett: 5, xiangling: 1, xingqiu: 1, sucrose: 1 });
    const casts = rotation.actions.filter((action) => action.kind === "skill" || action.kind === "burst");
    for (let i = 1; i < casts.length; i++) {
      expect(casts[i].start).toBeGreaterThanOrEqual(casts[i - 1].start + casts[i - 1].frames);
    }
    const combo = characterProfile("bennett").comboFrames.reduce((sum, frame) => sum + frame, 0);
    expect(rotation.attackFrames + rotation.busyFrames).toBeLessThanOrEqual(ROTATION_FRAMES);
    expect(ROTATION_FRAMES - rotation.attackFrames - rotation.busyFrames).toBeLessThan(combo);
  });

  it("marks missing frame data and substitutes the median", () => {
    const furina = characterProfile("furina");
    expect(furina.framesEstimated).toBe(true);
    expect(furina.skillFrames).toBeGreaterThan(0);
  });
});
