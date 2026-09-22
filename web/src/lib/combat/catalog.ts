import { charactersByID, type ElementName, type WeaponType } from "../abyss";
import framesJson from "../../../../Sources/NSLauncherApp/Resources/Abyss/frames.json";
import gaugeJson from "../../../../Sources/NSLauncherApp/Resources/Abyss/gauge.json";
import particlesJson from "../../../../Sources/NSLauncherApp/Resources/Abyss/particles.json";
import passivesJson from "../../../../Sources/NSLauncherApp/Resources/Abyss/passives.json";
import passiveTextJson from "../../../../Sources/NSLauncherApp/Resources/Abyss/passive-text.json";
import talentParamsJson from "../../../../Sources/NSLauncherApp/Resources/Abyss/talent-params.json";
import tuningJson from "../../../../Sources/NSLauncherApp/Resources/Abyss/tuning.json";

export const TALENT_LEVEL = 8;
export const FPS = 60;

type TalentBlock = {
  cooldown?: number;
  energyCost?: number;
  lines: string[];
  params: number[][];
};

type GaugeHit = {
  name: string;
  units?: number;
  icdTag?: string | null;
  icdHits?: number | null;
  icdSeconds?: number | null;
};

export type PassiveEffect = {
  stat?: string;
  value?: number;
  tiers?: number[];
  column?: number;
  stacks?: number;
  duration?: number;
  cooldown?: number;
  scale?: number;
  from?: string;
  per?: number;
  cap?: number;
  scope?: string;
  on?: string[];
  trigger?: PassiveTrigger | PassiveTrigger[];
  note?: string;
};

type PassiveTrigger = {
  kind: string;
  by?: string[];
  elements?: string[];
  reactions?: string[];
  match?: string;
  atLeast?: number;
  percent?: number;
  level?: string;
  types?: string[];
  includeWearer?: boolean;
};

type PassiveEntry = {
  effects?: PassiveEffect[];
  twoPiece?: PassiveEffect[];
  fourPiece?: PassiveEffect[];
};

type Tuning = {
  artifactMainStats: Record<string, number>;
  substatRollValue: Record<string, number>;
  substatRollBudget: number;
  substatPriority: Record<string, Record<string, number>>;
  scalingBasisSwap: Record<string, Record<string, string>>;
  rotationSeconds: number;
  swapSeconds: number;
  energy: {
    sameElementParticle: number;
    otherElementParticle: number;
    clearParticle: number;
    offFieldShare: number;
    enemyClearParticlesPerRotation: number;
    maxSkillCastsPerRotation: number;
  };
  noSustainPenalty: number;
  enemyOwnElementResistance: number;
};

const talents = talentParamsJson as {
  characters: Record<string, Record<"normalAttack" | "elementalSkill" | "elementalBurst", TalentBlock>>;
};
const gauges = gaugeJson as { characters: Record<string, Record<string, GaugeHit[]>> };
const particles = particlesJson as {
  characters: Record<string, { readings?: Array<{ press?: number; hold?: number; perEvent?: { count: number; event?: string } }> }>;
};
const frames = framesJson as {
  characters: Record<
    string,
    { comboFrames: number[] | null; chargedFrames: number | null; skillFrames: number | null; burstFrames: number | null }
  >;
};
const passives = passivesJson as unknown as { weapons: Record<string, PassiveEntry>; sets: Record<string, PassiveEntry> };
const passiveText = passiveTextJson as {
  weapons: Record<string, { values?: Array<Array<number | string>> }>;
  sets?: Record<string, { values?: Array<Array<number | string>> }>;
};
const tuning = tuningJson as Tuning;

export const ROTATION_SECONDS = tuning.rotationSeconds;
export const SWAP_FRAMES = Math.round(tuning.swapSeconds * FPS);
export const ROTATION_FRAMES = Math.round(tuning.rotationSeconds * FPS);

export function tuningConstants(): Tuning {
  return tuning;
}

export function characterTalent(id: string): (typeof talents.characters)[string] | undefined {
  return talents.characters[id];
}

export function paramsAtTalentLevel(block: TalentBlock | undefined): number[] {
  if (!block) return [];
  return block.params[TALENT_LEVEL - 1] ?? block.params[block.params.length - 1] ?? [];
}

export function gaugeTable(id: string): Record<string, GaugeHit[]> {
  return gauges.characters[id] ?? {};
}

export function particleReading(id: string): { press: number; perEvent: number; event: string } {
  const reading = particles.characters[id]?.readings?.[0];
  return {
    press: reading?.press ?? 0,
    perEvent: reading?.perEvent?.count ?? 0,
    event: reading?.perEvent?.event ?? "",
  };
}

function median(values: number[]): number {
  if (values.length === 0) return FPS;
  const sorted = values.slice().sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
}

const frameLists = Object.values(frames.characters);
const medianFrames = {
  combo: median(frameLists.flatMap((row) => row.comboFrames ?? [])),
  charged: median(frameLists.flatMap((row) => (row.chargedFrames == null ? [] : [row.chargedFrames]))),
  skill: median(frameLists.flatMap((row) => (row.skillFrames == null ? [] : [row.skillFrames]))),
  burst: median(frameLists.flatMap((row) => (row.burstFrames == null ? [] : [row.burstFrames]))),
};

export function frameRow(id: string): {
  comboFrames: number[];
  chargedFrames: number;
  skillFrames: number;
  burstFrames: number;
  estimated: boolean;
} {
  const row = frames.characters[id];
  const estimated = !row || row.comboFrames == null || row.chargedFrames == null || row.skillFrames == null || row.burstFrames == null;
  return {
    comboFrames: row?.comboFrames ?? [medianFrames.combo],
    chargedFrames: row?.chargedFrames ?? medianFrames.charged,
    skillFrames: row?.skillFrames ?? medianFrames.skill,
    burstFrames: row?.burstFrames ?? medianFrames.burst,
    estimated,
  };
}

export function weaponPassive(id: string): PassiveEffect[] {
  return passives.weapons[id]?.effects ?? [];
}

export function setPassive(id: string): { two: PassiveEffect[]; four: PassiveEffect[] } {
  const entry = passives.sets[id];
  return { two: entry?.twoPiece ?? [], four: entry?.fourPiece ?? [] };
}

export function refinedValue(sourceId: string, r1: number, refinement: number, kind: "weapons" | "sets"): number {
  if (refinement <= 1) return r1;
  const columns = passiveText[kind]?.[sourceId]?.values ?? [];
  let best: Array<number | string> | null = null;
  let bestGap = Number.POSITIVE_INFINITY;
  for (const column of columns) {
    const first = typeof column[0] === "number" ? column[0] : Number.parseFloat(column[0]);
    if (!Number.isFinite(first)) continue;
    const gap = Math.abs(first - r1);
    if (gap < bestGap) {
      bestGap = gap;
      best = column;
    }
  }
  if (!best || bestGap > Math.max(1e-4, Math.abs(r1) * 0.02)) return r1;
  const cell = best[Math.min(refinement, best.length) - 1];
  const parsed = typeof cell === "number" ? cell : Number.parseFloat(cell);
  return Number.isFinite(parsed) ? parsed : r1;
}

export function elementOf(id: string): ElementName {
  return charactersByID[id]?.element ?? "Pyro";
}

export function weaponTypeOf(id: string): WeaponType {
  return charactersByID[id]?.weaponType ?? "Sword";
}
