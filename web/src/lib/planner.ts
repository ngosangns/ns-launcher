import {
  activeResonances,
  artifactSets,
  characters,
  charactersByID,
  currentCycle,
  floor12 as floor12Of,
  monsterHP,
  splitDisorder,
  weapons,
  type Character,
  type CycleFloor,
  type ElementName,
  type Weapon,
} from "./abyss";
import { enemyOfHalf, fightTeam, reactionBonusFromText } from "./combat/fight";
import { artifactMains, scalingBasis, type ArtifactMains } from "./combat/sheet";
import { characterProfile } from "./combat/talent";
import { foldVi } from "./slug";
import type { Roster } from "./roster";

export type MemberBuild = {
  characterId: string;
  weaponId: string | null;
  artifactSetId: string | null;
  role: string;
  /** Optional on results saved before these fields existed. */
  artifactMains?: ArtifactMains;
  constellation?: number;
  refinement?: number;
};

export type PlannedTeam = {
  members: MemberBuild[];
  score: number;
  resonances: ReturnType<typeof activeResonances>;
  notes: string[];
  reactions: Array<{ id: string; count: number }>;
  rotation: Array<{ characterId: string; casts: Array<"E" | "Q"> }>;
  onFieldId: string;
  confidence: "kit" | "fallback";
  fallbackIds: string[];
  shockwaves: number;
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

export function roleOf(character: Character): Role {
  // Judge only the character's own description: the "combo phổ biến" tail lists
  // teammates (their shields/heals are not this character's), and "cần/thiếu"
  // clauses describe what the character needs, not what they provide.
  const text = foldVi(character.abyssRoleNotes ?? "")
    .split(/combo pho bien|doi hinh mau|pho bien cung|combo:/u)[0]
    .replace(/(?:can|thieu|phai co)\b[^.,;]*/gu, "");
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
  // Word boundaries matter: "phòng", "bằng", "lợi", "nhầm", "thảo" would all
  // false-positive as elements if matched as bare substrings.
  return {
    swirl: /\b(khuech tan|stellar swirl|tinh[-\s]?khuech|swirl)\b/u.test(folded),
    electroCharged: /\b(dien cam|electro[-\s]?charged|lunar[-\s]?charged|nguyet[-\s]?dien)\b/u.test(folded),
    pyro: /\b(hoa|pyro)\b/u.test(folded),
    hydro: /\b(thuy|hydro)\b/u.test(folded),
    cryo: /\b(bang|cryo)\b/u.test(folded),
    electro: /\b(loi|electro)\b/u.test(folded),
    anemo: /\b(phong|anemo)\b/u.test(folded),
    dendro: /\b(thao|dendro)\b/u.test(folded),
    geo: /\b(nham|geo)\b/u.test(folded),
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

function draftScore(members: Character[], text: string): number {
  let score = members.reduce((sum, character) => sum + characterHalfScore(character, text), 0);
  const roles = members.map(roleOf);
  if (roles.includes("dps")) score += 4;
  if (roles.includes("shield") || roles.includes("healer")) score += 2;
  const elements = new Set(members.map((item) => item.element));
  if (elements.size === 1) score -= 3;
  // Combos that can actually trigger the buffed reaction rank above piles of
  // individually strong characters that never interact.
  const flags = halfFlags(text);
  if (flags.swirl && elements.has("Anemo") && ["Pyro", "Hydro", "Electro", "Cryo"].some((el) => elements.has(el as ElementName))) score += 6;
  if (flags.electroCharged && elements.has("Electro") && elements.has("Hydro")) score += 6;
  return score;
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

function pickArtifact(character: Character, role: Role): string | null {
  const name = foldVi(character.name);
  const named = artifactSets.find((set) =>
    set.bestCharacters.some((entry) => foldVi(entry).includes(name) || name.includes(foldVi(entry))),
  );
  if (named) return named.id;
  // Role-aware fallbacks: a healer in Crimson Witch or an Anemo carry in
  // Viridescent Venerer is worse than a generic fit.
  if (role === "healer") return "maiden-beloved";
  if (role === "shield") return "tenacity-of-the-millelith";
  if (character.element === "Anemo") return role === "dps" ? "desert-pavilion-chronicle" : "viridescent-venerer";
  if (character.element === "Dendro") return role === "dps" ? "gilded-dreams" : "deepwood-memories";
  if (role === "support") return "noblesse-oblige";
  return ELEMENT_SETS[character.element] ?? null;
}

function pickWeapon(
  character: Character,
  byType: Map<string, Weapon[]>,
  used: Set<string>,
  role: Role,
): string | null {
  const available = (byType.get(character.weaponType) ?? []).filter((weapon) => !used.has(weapon.id));
  if (available.length === 0) return null;
  const name = foldVi(character.name);
  const named = available.filter((weapon) =>
    weapon.bestCharacters.some((entry) => foldVi(entry).includes(name) || name.includes(foldVi(entry))),
  );
  if (named.length > 0) return named[0].id;
  // No signature weapon: score by substat synergy with the member's job.
  const basis = scalingBasis(character.id);
  const wantsEr =
    (role === "support" || role === "healer" || role === "shield") &&
    characterProfile(character.id).burstCost > 0;
  const scored = available
    .map((weapon) => {
      const sub = (weapon.subStat.type ?? "").toLowerCase();
      let score = weapon.rarity * 10 + (weapon.atkLv90 ?? 0) / 100;
      if (wantsEr && (sub.includes("energy") || weapon.id.startsWith("favonius-") || weapon.id.startsWith("sacrificial-"))) score += 8;
      if (basis === "EM" && sub.includes("mastery")) score += 8;
      if (basis === "HP" && sub.includes("hp")) score += 4;
      if (basis === "DEF" && sub.includes("def")) score += 4;
      if (role === "dps" && sub.includes("crit")) score += 4;
      return { weapon, score };
    })
    .sort((a, b) => b.score - a.score);
  return scored[0]?.weapon.id ?? null;
}

function equipTeam(
  ids: string[],
  byType: Map<string, Weapon[]>,
  roster: Roster,
): {
  characters: Character[];
  members: MemberBuild[];
  resonances: ReturnType<typeof activeResonances>;
  notes: string[];
} {
  const membersChars = ids.map((id) => charactersByID[id]).filter(Boolean);
  const notes: string[] = [];
  const roles = membersChars.map(roleOf);
  if (!roles.includes("dps")) notes.push("Thiếu DPS đứng sân");
  const constellationOf = (id: string) => roster.characters.find((item) => item.id === id)?.constellation ?? 0;
  const refinementOf = (id: string | null) => roster.weapons.find((item) => item.id === id)?.refinement ?? 1;
  const used = new Set<string>();
  const members: MemberBuild[] = membersChars.map((character, index) => {
    const role = roles[index] ?? roleOf(character);
    const weaponId = pickWeapon(character, byType, used, role);
    if (weaponId) used.add(weaponId);
    return {
      characterId: character.id,
      weaponId,
      artifactSetId: pickArtifact(character, role),
      role,
      artifactMains: artifactMains(character.id, role),
      constellation: constellationOf(character.id),
      refinement: weaponId ? refinementOf(weaponId) : undefined,
    };
  });
  const resonances = activeResonances(membersChars.map((item) => item.element));
  for (const item of resonances) notes.push(item.nameVI ?? item.name);
  return { characters: membersChars, members, resonances, notes };
}

function simulateTeam(
  equipped: ReturnType<typeof equipTeam>,
  text: string,
  enemy: { level: number; res: Record<string, number>; hp?: number; targets?: number; groups?: number },
  shockwave: boolean,
): PlannedTeam {
  const result = fightTeam(
    equipped.members.map((member) => ({
      characterId: member.characterId,
      weaponId: member.weaponId,
      artifactSetId: member.artifactSetId,
      role: member.role,
      refinement: member.refinement,
      constellation: member.constellation,
    })),
    {
      enemyLevel: enemy.level,
      res: enemy.res,
      reactionBonus: reactionBonusFromText(text),
      shockwave,
      targets: enemy.targets,
      hp: enemy.hp,
      groups: enemy.groups,
    },
  );
  return {
    members: equipped.members,
    score: result.dps,
    resonances: equipped.resonances,
    notes: equipped.notes,
    reactions: result.reactions,
    rotation: result.rotation,
    onFieldId: result.onFieldId,
    confidence: result.confidence,
    fallbackIds: result.fallbackIds,
    shockwaves: result.shockwaves,
  };
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
  options: { fullCharacters: boolean; fullWeapons: boolean; lang?: "vi" | "en" },
): PlannerOutput {
  const cycle = currentCycle();
  const floor = floor12Of(cycle);
  const split = floor ? splitDisorder(floor.leyLineDisorder) : {};
  const half1Text = split.half1 ?? floor?.leyLineDisorder ?? "";
  const half2Text = split.half2 ?? floor?.leyLineDisorder ?? "";
  const displayDisorder = options.lang === "en" ? floor?.leyLineDisorderEN ?? floor?.leyLineDisorder : floor?.leyLineDisorder;
  const displaySplit = displayDisorder ? splitDisorder(displayDisorder) : {};
  const displayHalf1 = displaySplit.half1 ?? displayDisorder ?? "";
  const displayHalf2 = displaySplit.half2 ?? displayDisorder ?? "";
  const displayRecommendation = options.lang === "en" ? floor?.recommendationEN ?? floor?.recommendation : floor?.recommendation;

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
    return { plans: [], half1Text: displayHalf1, half2Text: displayHalf2, recommendation: displayRecommendation };
  }

  const shockwave = /khuech|swirl/i.test(foldVi(`${cycle.blessingOfTheAbyssalMoon.description} ${half1Text} ${half2Text}`));
  // 40 teams measured about 1.3s. 24 keeps a full-roster search near one second.
  const SIMULATED_PER_HALF = 24;
  const rankHalf = (text: string, half: 1 | 2) => {
    const ranked = characterPool
      .map((character) => ({ character, score: characterHalfScore(character, text) }))
      .sort((a, b) => b.score - a.score)
      .slice(0, 12)
      .map((item) => item.character);
    const enemy = floor ? enemyOfHalf(floor, half) : { level: 90, hp: 0, res: {} };
    return combinations(ranked, 4)
      .map((combo) => equipTeam(combo.map((item) => item.id), weaponsByType, roster))
      .sort((a, b) => draftScore(b.characters, text) - draftScore(a.characters, text))
      .slice(0, SIMULATED_PER_HALF)
      .map((equipped) => simulateTeam(equipped, text, enemy, shockwave))
      .sort((a, b) => b.score - a.score);
  };

  const first = rankHalf(half1Text, 1);
  const second = rankHalf(half2Text, 2);
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
    half1Text: displayHalf1,
    half2Text: displayHalf2,
    recommendation: displayRecommendation,
  };
}

export function clearSeconds(hp: number | null, score: number): number | null {
  if (hp == null || score <= 0) return null;
  return hp / score;
}

export { charactersByID };
