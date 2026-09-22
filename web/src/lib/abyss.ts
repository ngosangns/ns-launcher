import { todayISO } from "./format";

export type ElementName =
  | "Anemo"
  | "Geo"
  | "Electro"
  | "Dendro"
  | "Hydro"
  | "Pyro"
  | "Cryo";

export const ELEMENTS: ElementName[] = [
  "Pyro",
  "Hydro",
  "Anemo",
  "Electro",
  "Dendro",
  "Cryo",
  "Geo",
];

export type WeaponType = "Sword" | "Claymore" | "Polearm" | "Bow" | "Catalyst";

export const WEAPON_TYPES: WeaponType[] = [
  "Sword",
  "Claymore",
  "Polearm",
  "Bow",
  "Catalyst",
];

export type TalentHit = {
  label: string;
  values: Record<string, string>;
};

export type Talent = {
  name: string | null;
  description?: string;
  hits?: TalentHit[];
  scaling?: TalentHit[];
  cooldown?: string | null;
  energyCost?: number | string | null;
};

export type CharacterKit = {
  characterId: string;
  tags?: string[];
  conversions?: Array<{ talent?: string; label?: string; uptime?: number; note?: string }>;
  buffs?: Array<{
    scope?: string;
    kind?: string;
    stat?: string;
    talent?: string;
    label?: string;
    uptime?: number;
    note?: string;
  }>;
  energy?: {
    eventsPerCast?: number;
    particlesPerCast?: number;
    skillCastsPerRotation?: number;
    collectedBy?: string;
    note?: string;
  };
  hits?: { note?: string };
  reactionBaseDamageBonus?: Array<{ reactions: string[]; value: number }>;
  resistanceShred?: Array<{ element?: string; value?: number; note?: string }>;
  attack?: { infused?: boolean; note?: string };
  chargedAttackLabels?: string[];
};

export type Character = {
  id: string;
  name: string;
  nameVI?: string;
  element: ElementName;
  weaponType: WeaponType;
  rarity: number;
  nationInGame: string;
  releaseDate?: string | null;
  baseStats: {
    lv1: { hp: number | null; atk: number | null; def: number | null };
    lv90: {
      hp: number | null;
      atk: number | null;
      def: number | null;
      ascensionStatType: string | null;
      ascensionStatValue: number | null;
    };
  };
  normalAttack: Talent;
  elementalSkill: Talent;
  elementalBurst: Talent;
  additionalTalents?: Talent[];
  passives: Array<{ name: string; unlock: string; description: string }>;
  constellations: Array<{ level: number; name: string; description: string }>;
  abyssRoleNotes?: string;
  tags: string[];
  kit?: CharacterKit;
};

export type Weapon = {
  id: string;
  name: string;
  nameVI?: string;
  type: WeaponType;
  rarity: number;
  atkLv1: number | null;
  atkLv90: number | null;
  subStat: { type: string | null; valueLv90: number | null };
  passive: {
    name: string | null;
    description: string;
    effects: Array<{
      stat: string;
      r1: number | string | null;
      r2: number | string | null;
      r3: number | string | null;
      r4: number | string | null;
      r5: number | string | null;
    }>;
  } | null;
  acquisition: string;
  bestCharacters: string[];
};

export type ArtifactSet = {
  id: string;
  name: string;
  nameVI?: string;
  rarity: string;
  twoPiece: { description: string; descriptionVI?: string };
  fourPiece: { description: string; descriptionVI?: string };
  domain?: string;
  region?: string;
  bestCharacters: string[];
};

export type Resistances = Partial<Record<ElementName, number>> & {
  Physical?: number;
};

export type Monster = {
  name: string;
  count: string;
  size: string | null;
  elements: string[];
  resistanceNotes: string | null;
  weakpoint: boolean | null;
  mechanics: string | null;
  hpRatio: string | null;
  gameId?: number;
  resistances?: Record<string, number>;
  physicalResistance?: number;
  spawns?: number | null;
  hp?: { page: string; variant: string; ratio: number; type: string } | null;
};

export type CycleFloor = {
  floor: number;
  leyLineDisorder: string;
  enemyHPMultiplier?: number;
  chambers: Array<{
    chamber: number;
    monsterLevel: number;
    waves: Array<{ wave: number; monsters: Monster[] }>;
  }>;
  recommendation?: string;
};

export type AbyssCycle = {
  periodStart: string;
  periodEnd: string;
  gameVersion?: string;
  blessingOfTheAbyssalMoon: {
    name: string;
    nameVI?: string;
    description: string;
    relatedMechanic?: string;
  };
  floors: CycleFloor[];
  fileId: string;
};

export type Resonance = {
  id: string;
  name: string;
  nameVI?: string;
  elements: ElementName[];
  requiredCount: number;
  requiresUniqueElements?: boolean;
  description: string;
};

export type TeamBonus = {
  elementalResonance: Resonance[];
  moonsign: {
    levels: Array<{ name: string; requiredCount: number; description: string }>;
    lunarReactionDmgBonusByElement?: Array<{
      elements: string[];
      statBasis: string;
      ratePer100OrPer1000: number;
      note?: string;
    }>;
    maxBuffThresholds?: Array<{
      elements: string[];
      statBasis: string;
      thresholdValue: number;
    }>;
    note?: string;
  };
  hexerei: { requiredCount: number; description: string; requirement?: string };
  nightsoulBurst: {
    description: string;
    intervalsByCount: Array<{ natlanCharacterCount: string; intervalSeconds: number }>;
    exclusionNote?: string;
  };
};

export type DamageFormula = {
  resMultiplier: {
    formula: string;
    breakpoints: Array<{ condition: string; formula: string }>;
    note?: string;
    defaultMonsterResAllElements?: number;
  };
  defMultiplier: { formula: string };
  elevationMultiplier?: { formula: string; note?: string };
  critMultiplier: {
    expectedValueFormula: string;
    critFormula?: string;
    noCritFormula?: string;
  };
  amplifying: {
    formula: string;
    emBonusFormula: string;
    coefficients: Record<string, number>;
    note?: string;
  };
  catalyze?: { formula: string; emBonusFormula: string; coefficients: Record<string, number> };
  transformative?: {
    formula?: string;
    emBonusFormula: string;
    coefficients?: Record<string, number>;
    levelMultiplier?: Record<string, { character: number; monster: number }>;
    note?: string;
  };
  lunarStellar?: {
    emBonusFormula: string;
    note?: string;
    indirect?: {
      appliesTo: string[];
      perCharacterFormula: string;
      coefficients: Record<string, number>;
      aggregationFormula: string;
    };
    direct?: {
      appliesTo: string[];
      formula: string;
      coefficients: Record<string, number>;
      note?: string;
    };
  };
  trueDamage?: { note: string };
  critValueHeuristic?: { formula: string; targetRatio: string };
  workedExample?: {
    scenario: string;
    inputs: Record<string, number | string>;
    steps: Record<string, string>;
    result: { value: number; unit: string };
  };
};

const characterModules = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Abyss/characters/*.json",
  { eager: true, import: "default" },
) as Record<string, Array<Omit<Character, "tags" | "kit">>>;

const weaponModules = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Abyss/weapons/*.json",
  { eager: true, import: "default" },
) as Record<string, Weapon[]>;

const cycleModules = import.meta.glob(
  "../../../Sources/NSLauncherApp/Resources/Abyss/abyss-monsters/*.json",
  { eager: true, import: "default" },
) as Record<string, Omit<AbyssCycle, "fileId">>;

import artifactSetsJson from "../../../Sources/NSLauncherApp/Resources/Abyss/artifact-sets.json";
import teamBonusJson from "../../../Sources/NSLauncherApp/Resources/Abyss/team-bonus.json";
import kitsJson from "../../../Sources/NSLauncherApp/Resources/Abyss/character-kits.json";
import enemyHpJson from "../../../Sources/NSLauncherApp/Resources/Abyss/enemy-hp.json";
import damageFormulaJson from "../../../Sources/NSLauncherApp/Resources/Abyss/damage-formula.json";

type KitsFile = {
  kits: CharacterKit[];
};

type EnemyHpFile = {
  types: Record<string, number[]>;
};

export const kitsByID = Object.fromEntries(
  (kitsJson as KitsFile).kits.map((kit) => [kit.characterId, kit]),
);

function stem(path: string): string {
  const file = path.split("/").pop() ?? path;
  return file.replace(/\.json$/u, "");
}

export const characters: Character[] = Object.values(characterModules)
  .flat()
  .map((character) => {
    const kit = kitsByID[character.id];
    return {
      ...character,
      tags: kit?.tags ?? [],
      kit,
    };
  })
  .sort((a, b) => a.name.localeCompare(b.name, "en"));

export function charactersWithTag(tag: string): Character[] {
  return characters.filter((character) => character.tags.includes(tag));
}

export const charactersByID = Object.fromEntries(characters.map((c) => [c.id, c]));

export const weapons: Weapon[] = Object.values(weaponModules)
  .flat()
  .sort((a, b) => a.name.localeCompare(b.name, "en"));

export const weaponsByID = Object.fromEntries(weapons.map((w) => [w.id, w]));

export const artifactSets = (artifactSetsJson as ArtifactSet[]).slice().sort((a, b) =>
  a.name.localeCompare(b.name, "en"),
);

export const artifactSetsByID = Object.fromEntries(artifactSets.map((s) => [s.id, s]));

export const cycles: AbyssCycle[] = Object.entries(cycleModules)
  .map(([path, cycle]) => ({ ...cycle, fileId: stem(path) }))
  .sort((a, b) => b.periodStart.localeCompare(a.periodStart));

export function currentCycle(now = todayISO()): AbyssCycle {
  return cycles.find((cycle) => cycle.periodStart <= now && now <= cycle.periodEnd) ?? cycles[0];
}

export const teamBonus = teamBonusJson as TeamBonus;
export const damageFormula = damageFormulaJson as DamageFormula;

const hpCurves = (enemyHpJson as EnemyHpFile).types;

export function monsterHP(monster: Monster, level: number, floorMultiplier = 1): number | null {
  return monsterHPBreakdown(monster, level, floorMultiplier)?.total ?? null;
}

export function monsterHPBreakdown(
  monster: Monster,
  level: number,
  floorMultiplier = 1,
): { perSpawn: number; total: number; ratio: number; type: string } | null {
  const ratio = monster.hp?.ratio;
  const type = monster.hp?.type;
  if (ratio == null || type == null) return null;
  const curve = hpCurves[type];
  if (!curve) return null;
  const base = curve[level - 1];
  if (base == null) return null;
  const perSpawn = ratio * base * floorMultiplier;
  const spawns = monster.spawns ?? 1;
  return { perSpawn, total: perSpawn * spawns, ratio, type };
}

export function monsterIconId(monster: Monster): string {
  if (monster.gameId != null) return String(monster.gameId);
  return monster.name.toLowerCase().replace(/[^a-z0-9]+/g, "");
}

export function iconUrl(
  kind: "characters" | "weapons" | "artifact-sets" | "monsters",
  id: string,
): string {
  return `/icons/${kind}/${id}.png`;
}

export function splitDisorder(text: string): { half1?: string; half2?: string } {
  const half1 = text.match(/Nửa 1:\s*([\s\S]+?)(?=\s*Nửa 2:|$)/u)?.[1]?.trim();
  const half2 = text.match(/Nửa 2:\s*([\s\S]+)$/u)?.[1]?.trim();
  return { half1, half2 };
}

export function activeResonances(elements: ElementName[]): Resonance[] {
  const counts = new Map<ElementName, number>();
  for (const element of elements) counts.set(element, (counts.get(element) ?? 0) + 1);
  const unique = new Set(elements).size;
  return teamBonus.elementalResonance.filter((resonance) => {
    if (resonance.requiresUniqueElements) {
      return unique >= resonance.requiredCount && elements.length >= resonance.requiredCount;
    }
    if (resonance.elements.length === 0) return false;
    return resonance.elements.every(
      (element) => (counts.get(element) ?? 0) >= resonance.requiredCount,
    );
  });
}

export function nationKey(raw: string): string {
  const cut = raw.split(/[（(—–]/u)[0]?.trim() ?? raw;
  if (!cut || cut === "—" || cut === "-") return "Khác";
  return cut;
}

export const NATIONS = [...new Set(characters.map((c) => nationKey(c.nationInGame)))].sort((a, b) =>
  a.localeCompare(b, "vi"),
);
