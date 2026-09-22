import { describe, expect, it } from "vitest";
import { charactersByID, weaponsByID } from "../abyss";
import { buildSheet } from "./sheet";

describe("stat sheet", () => {
  it("adds Hu Tao's HP conversion and Staff of Homa's HP-to-ATK", () => {
    const sheet = buildSheet({
      characterId: "hu-tao",
      weaponId: "staff-of-homa",
      artifactSetId: "crimson-witch-of-flames",
      role: "dps",
    });
    expect(sheet.atkFromConversion).toBeCloseTo(sheet.hp * 0.05658, 0);
    expect(sheet.atkFromHp).toBeCloseTo(sheet.hp * 0.008, 1);
    expect(sheet.atk).toBeGreaterThan(sheet.baseAtk + sheet.atkFromConversion);
  });

  it("keeps Bennett's base ATK separate from artifact flats", () => {
    const sheet = buildSheet({
      characterId: "bennett",
      weaponId: "skyward-blade",
      artifactSetId: "noblesse-oblige",
      role: "support",
    });
    const character = charactersByID["bennett"];
    const weapon = weaponsByID["skyward-blade"];
    expect(sheet.baseAtk).toBeCloseTo((character?.baseStats.lv90.atk ?? 0) + (weapon?.atkLv90 ?? 0), 2);
    expect(sheet.atk).toBeGreaterThan(sheet.baseAtk);
  });

  it("does not turn an energy-only weapon passive into attack", () => {
    const sheet = buildSheet({
      characterId: "bennett",
      weaponId: "amenoma-kageuchi",
      artifactSetId: null,
      role: "support",
    });
    const base = (charactersByID["bennett"]?.baseStats.lv90.atk ?? 0) + (weaponsByID["amenoma-kageuchi"]?.atkLv90 ?? 0);
    const atkPct = 0.551 + 25 * 0.1 * 0.0583;
    expect(sheet.baseAtk).toBeCloseTo(base, 2);
    expect(sheet.atk).toBeCloseTo(base * (1 + atkPct) + 311, 0);
  });
});
