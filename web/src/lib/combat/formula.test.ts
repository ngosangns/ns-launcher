import { describe, expect, it } from "vitest";
import {
  aggregateIndirect,
  amplifyingEmBonus,
  amplifyingMultiplier,
  defMultiplier,
  directHit,
  resMultiplier,
} from "./formula";

describe("damage formula", () => {
  it("reproduces the wiki Mona burst worked example", () => {
    const def = defMultiplier(70, 75, 0.23);
    const res = resMultiplier(0.1 - 0.4);
    const em = amplifyingEmBonus(150);
    const amp = amplifyingMultiplier(2, 150);
    expect(def).toBeCloseTo(0.55783, 4);
    expect(res).toBeCloseTo(1.15, 5);
    expect(em).toBeCloseTo(0.26903, 4);
    expect(amp).toBeCloseTo(2.53806, 4);

    const damage = directHit({
      motion: 6.19,
      stat: 1500,
      dmgBonus: 0.4 + 0.52,
      critRate: 1,
      critDmg: 0.8,
      characterLevel: 70,
      enemyLevel: 75,
      res: -0.3,
      defReduction: 0.23,
      amplifying: { coefficient: 2, em: 150 },
      guaranteedCrit: true,
    });
    expect(damage).toBeCloseTo(52246.5, 0);
  });

  it("aggregates indirect lunar damage with the published weights", () => {
    expect(aggregateIndirect([100, 80, 40, 10])).toBeCloseTo(86.5, 5);
    expect(aggregateIndirect([100, 50])).toBeCloseTo(75, 5);
  });
});
