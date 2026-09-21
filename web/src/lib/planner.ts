import {
  activeResonances,
  artifactSets,
  characters,
  charactersByID,
  currentCycle,
  monsterHP,
  splitDisorder,
  weapons,
  type Character,
  type CycleFloor,
  type ElementName,
  type Weapon,
} from "./abyss";
import { foldVi } from "./slug";
import type { Roster } from "./roster";

export type MemberBuild = {
  characterId: string;
  weaponId: string | null;
  artifactSetId: string | null;
  role: string;
};

export type PlannedTeam = {
  members: MemberBuild[];
  score: number;
  resonances: ReturnType<typeof activeResonances>;
  notes: string[];
};

export type PlannedPlan = {
  half1: PlannedTeam;
  half2: PlannedTeam;
  score: number;
  firstHalfHP: number | null;
  secondHalfHP: number | null;
};

export type PlannerOutput = {
  plans: PlannedPlan[];
  half1Text?: string;
  half2Text?: string;
  recommendation?: string;
};

type Role = "dps" | "support" | "shield" | "healer";

function roleOf(character: Character): Role {
  const text = foldVi(character.abyssRoleNotes ?? "");
  if (/khien|shield/.test(text)) return "shield";
  if (/hoi mau|heal|tri lieu/.test(text)) return "healer";
  if (/\bdps\b|carry|on-field|on field|dung san|chu luc/.test(text)) return "dps";
  return "support";
}

function combinations<T>(items: T[], k: number): T[][] {
  const out: T[][] = [];
  const acc: T[] = [];
  const rec = (start: number) => {
    if (acc.length === k) {
      out.push(acc.slice());
      return;
    }
    for (let i = start; i <= items.length - (k - acc.length); i++) {
      acc.push(items[i]);
      rec(i + 1);
      acc.pop();
    }
  };
  rec(0);
  return out;
}

function halfFlags(text: string) {
  const folded = foldVi(text);
  return {
    swirl: /khuech tan|swirl|stellar swirl|tinh-khuech|tinh khuech/.test(folded),
    electroCharged: /dien cam|electro-charged|lunar-charged|nguyet-dien|nguyet dien/.test(folded),
    pyro: /hoa|pyro/.test(folded),
    hydro: /thuy|hydro/.test(folded),
    cryo: /bang|cryo/.test(folded),
    electro: /loi|electro/.test(folded),
    anemo: /phong|anemo/.test(folded),
    dendro: /thao|dendro/.test(folded),
    geo: /nham|geo/.test(folded),
  };
}

function characterHalfScore(character: Character, text: string): number {
  const flags = halfFlags(text);
  let score = character.rarity === 5 ? 1.2 : 0.8;
  const element = character.element;
  if (flags.swirl && (element === "Anemo" || element === "Cryo")) score += 4;
  if (flags.electroCharged && (element === "Electro" || element === "Hydro")) score += 4;
  if (flags.pyro && element === "Pyro") score += 2;
  if (flags.hydro && element === "Hydro") score += 1.5;
  if (flags.cryo && element === "Cryo") score += 1.5;
  if (flags.electro && element === "Electro") score += 1.5;
  if (flags.anemo && element === "Anemo") score += 1.5;
  if (flags.dendro && element === "Dendro") score += 1.5;
  if (flags.geo && element === "Geo") score += 1.5;
  if (flags.swirl && character.tags.includes("stellar-jubilee")) score += 5;
  if (flags.electroCharged && character.tags.includes("moonsign")) score += 5;
  if (character.tags.includes("hexerei")) score += 1;
  const role = roleOf(character);
  if (role === "dps") score += 1.4;
  if (role === "support") score += 1.1;
  if (role === "shield" || role === "healer") score += 0.9;
  return score;
}

function teamScore(members: Character[], text: string): { score: number; notes: string[] } {
  const notes: string[] = [];
  let score = members.reduce((sum, character) => sum + characterHalfScore(character, text), 0);
  const resonances = activeResonances(members.map((item) => item.element));
  score += resonances.length * 6;
  const roles = members.map(roleOf);
  if (roles.includes("dps")) score += 4;
  else notes.push("Thiếu DPS đứng sân");
  if (roles.includes("shield") || roles.includes("healer")) score += 2;
  const uniqueRoles = new Set(roles).size;
  if (uniqueRoles >= 3) score += 2;
  if (new Set(members.map((item) => item.element)).size === 1) score -= 3;
  return { score, notes };
}

const ELEMENT_SETS: Record<ElementName, string> = {
  Anemo: "viridescent-venerer",
  Pyro: "crimson-witch-of-flames",
  Hydro: "heart-of-depth",
  Cryo: "blizzard-strayer",
  Electro: "thundering-fury",
  Dendro: "gilded-dreams",
  Geo: "archaic-petra",
};

function pickArtifact(character: Character): string | null {
  const name = foldVi(character.name);
  const named = artifactSets.find((set) =>
    set.bestCharacters.some((entry) => foldVi(entry).includes(name) || name.includes(foldVi(entry))),
  );
  if (named) return named.id;
  return ELEMENT_SETS[character.element] ?? null;
}

function pickWeapon(
  character: Character,
  byType: Map<string, Weapon[]>,
  used: Set<string>,
): string | null {
  const available = (byType.get(character.weaponType) ?? []).filter((weapon) => !used.has(weapon.id));
  if (available.length === 0) return null;
  const name = foldVi(character.name);
  const named = available.filter((weapon) =>
    weapon.bestCharacters.some((entry) => foldVi(entry).includes(name) || name.includes(foldVi(entry))),
  );
  return (named[0] ?? available[0])?.id ?? null;
}

function buildTeam(ids: string[], text: string, byType: Map<string, Weapon[]>): PlannedTeam {
  const membersChars = ids.map((id) => charactersByID[id]).filter(Boolean);
  const { score, notes } = teamScore(membersChars, text);
  const used = new Set<string>();
  const members: MemberBuild[] = membersChars.map((character) => {
    const weaponId = pickWeapon(character, byType, used);
    if (weaponId) used.add(weaponId);
    return {
      characterId: character.id,
      weaponId,
      artifactSetId: pickArtifact(character),
      role: roleOf(character),
    };
  });
  const resonances = activeResonances(membersChars.map((item) => item.element));
  for (const item of resonances) {
    notes.push(item.nameVI ?? item.name);
  }
  return { members, score, resonances, notes };
}

function halfHP(floor: CycleFloor | undefined, half: 1 | 2): number | null {
  if (!floor) return null;
  let total = 0;
  let known = false;
  for (const chamber of floor.chambers) {
    const wave = chamber.waves.find((item) => item.wave === half);
    if (!wave) continue;
    for (const monster of wave.monsters) {
      const hp = monsterHP(monster, chamber.monsterLevel, floor.enemyHPMultiplier ?? 1);
      if (hp != null) {
        total += hp;
        known = true;
      }
    }
  }
  return known ? total : null;
}

export function findTeams(
  roster: Roster,
  options: { fullCharacters: boolean; fullWeapons: boolean },
): PlannerOutput {
  const cycle = currentCycle();
  const floor = cycle.floors.find((item) => item.floor === 12);
  const split = floor ? splitDisorder(floor.leyLineDisorder) : {};
  const half1Text = split.half1 ?? floor?.leyLineDisorder ?? "";
  const half2Text = split.half2 ?? floor?.leyLineDisorder ?? "";

  const characterPool = (
    options.fullCharacters ? characters : characters.filter((item) => roster.characters.some((owned) => owned.id === item.id))
  ).filter((item) => item.id);
  const weaponPool = options.fullWeapons
    ? weapons
    : weapons.filter((item) => roster.weapons.some((owned) => owned.id === item.id));
  const weaponsByType = new Map<string, Weapon[]>();
  for (const weapon of weaponPool) {
    const list = weaponsByType.get(weapon.type) ?? [];
    list.push(weapon);
    weaponsByType.set(weapon.type, list);
  }
  for (const list of weaponsByType.values()) {
    list.sort((a, b) => b.rarity - a.rarity || (b.atkLv90 ?? 0) - (a.atkLv90 ?? 0));
  }

  if (characterPool.length < 8 && !options.fullCharacters) {
    return { plans: [], half1Text, half2Text, recommendation: floor?.recommendation };
  }

  const rankHalf = (text: string) => {
    const ranked = characterPool
      .map((character) => ({ character, score: characterHalfScore(character, text) }))
      .sort((a, b) => b.score - a.score)
      .slice(0, 12)
      .map((item) => item.character);
    return combinations(ranked, 4)
      .map((combo) => buildTeam(combo.map((item) => item.id), text, weaponsByType))
      .sort((a, b) => b.score - a.score)
      .slice(0, 20);
  };

  const first = rankHalf(half1Text);
  const second = rankHalf(half2Text);
  const plans: PlannedPlan[] = [];
  const usedPair = new Set<string>();

  for (const a of first) {
    const idsA = new Set(a.members.map((m) => m.characterId));
    const weaponsA = new Set(a.members.map((m) => m.weaponId).filter(Boolean) as string[]);
    for (const b of second) {
      if (b.members.some((m) => idsA.has(m.characterId))) continue;
      if (b.members.some((m) => m.weaponId && weaponsA.has(m.weaponId))) continue;
      const key = [...idsA].sort().join(",") + "|" + b.members.map((m) => m.characterId).sort().join(",");
      if (usedPair.has(key)) continue;
      usedPair.add(key);
      const hp1 = halfHP(floor, 1);
      const hp2 = halfHP(floor, 2);
      const score =
        hp1 && hp2 && a.score > 0 && b.score > 0
          ? (hp1 + hp2) / (hp1 / a.score + hp2 / b.score)
          : (2 * a.score * b.score) / (a.score + b.score);
      plans.push({
        half1: a,
        half2: b,
        score,
        firstHalfHP: hp1,
        secondHalfHP: hp2,
      });
    }
  }

  plans.sort((a, b) => b.score - a.score);
  const unique: PlannedPlan[] = [];
  const seenChars = new Set<string>();
  for (const plan of plans) {
    const signature = plan.half1.members
      .map((m) => m.characterId)
      .concat(plan.half2.members.map((m) => m.characterId))
      .sort()
      .join(",");
    if (seenChars.has(signature)) continue;
    seenChars.add(signature);
    unique.push(plan);
    if (unique.length === 5) break;
  }

  return {
    plans: unique,
    half1Text,
    half2Text,
    recommendation: floor?.recommendation,
  };
}

export function clearSeconds(hp: number | null, score: number): number | null {
  if (hp == null || score <= 0) return null;
  return hp / score;
}

export { charactersByID };
