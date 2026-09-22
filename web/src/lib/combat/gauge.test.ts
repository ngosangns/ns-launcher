import { describe, expect, it } from "vitest";
import { Gauge, icdReady } from "./gauge";

describe("elemental gauge", () => {
  it("applies on the first hit and again when either the hit count or the timer is reached", () => {
    const state = new Map<string, { hits: number; last: number }>();
    expect(icdReady(state, "na", 0, 3, 2.5)).toBe(true);
    expect(icdReady(state, "na", 0.1, 3, 2.5)).toBe(false);
    expect(icdReady(state, "na", 0.2, 3, 2.5)).toBe(false);
    expect(icdReady(state, "na", 0.3, 3, 2.5)).toBe(true);
  });

  it("forward melt consumes a 1U aura so the next pyro hit is not amplified", () => {
    const gauge = new Gauge();
    gauge.apply("cryo", 1, 0);
    const first = gauge.apply("pyro", 1, 0.1);
    const second = gauge.apply("pyro", 1, 0.2);
    expect(first.reaction).toBe("melt");
    expect(first.coefficient).toBe(2);
    expect(second.reaction).toBeUndefined();
  });
});
