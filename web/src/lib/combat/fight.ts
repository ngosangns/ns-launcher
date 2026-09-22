import { charactersByID, monsterHP, type CycleFloor } from "../abyss";
import { foldVi } from "../slug";
import { tuningConstants } from "./catalog";
import {
  catalyzeBonus,
  directHit,
  expectedCrit,
  lunarEmBonus,
  LEVEL_90_MULTIPLIER,
  resMultiplier,
  transformativeDamage,
} from "./formula";
import { Gauge, icdReady, type GaugeEvent } from "./gauge";
import { scheduleTeam, type RotationAction } from "./rotation";
import { applyResonance, buildSheet, dmgBonusFor, scalingBasis, statAmount, type Sheet, type TimedBuff } from "./sheet";
import { characterProfile, constellationBoosts, type HitKind, type HitTemplate } from "./talent";

export type FightMember = {
  characterId: string;
  weaponId: string | null;
  artifactSetId: string | null;
  refinement?: number;
  role?: string;
  energyRecharge?: number;
  constellation?: number;
};

export type FightHit = {
  time: number;
  owner: string;
  kind: HitKind;
  motion: number;
  damage: number;
  reaction?: string;
};

export type FightResult = {
  damage: number;
  dps: number;
  reactions: Array<{ id: string; count: number }>;
  rotation: Array<{ characterId: string; casts: Array<"E" | "Q"> }>;
  onFieldId: string;
  confidence: "kit" | "fallback";
  fallbackIds: string[];
  shockwaves: number;
  hits: FightHit[];
};

export type FightOptions = {
  onFieldId?: string;
  enemyLevel?: number;
  res?: Partial<Record<string, number>>;
  reactionBonus?: Record<string, number>;
  extraResShred?: number;
  shockwave?: boolean;
  /** Simultaneous enemies an area hit reaches. 1 keeps every hit single-target. */
  targets?: number;
  hp?: number;
  groups?: number;
  clearParticles?: number;
  refine?: boolean;
};

const REACTION_RES: Record<string, string> = {
  swirl: "anemo",
  overload: "pyro",
  superconduct: "cryo",
  "electro-charged": "electro",
  bloom: "dendro",
  hyperbloom: "dendro",
  burgeon: "pyro",
  burning: "pyro",
};

export function fightTeam(members: FightMember[], options: FightOptions = {}): FightResult {
  const profiles = new Map(
    members.map((member) => [
      member.characterId,
      characterProfile(member.characterId, constellationBoosts(member.characterId, member.constellation ?? 0)),
    ]),
  );
  const sheets = members.map((member) => buildSheet(member));
  applyResonance(sheets);
  applyStaticBuffs(sheets);
  const byId = new Map(sheets.map((sheet) => [sheet.id, sheet]));
  const onFieldId = options.onFieldId ?? pickOnField(members, sheets);
  const er: Record<string, number> = {};
  for (const member of members) {
    er[member.characterId] = member.energyRecharge ?? byId.get(member.characterId)?.er ?? 1;
  }
  const skillResets: Record<string, number> = {};
  const flatEnergy: Record<string, number> = {};
  for (const member of members) {
    if (member.weaponId?.startsWith("sacrificial-")) skillResets[member.characterId] = 1;
    // Favonius restores 6 energy to the wielder, at most once per 12s.
    if (member.weaponId?.startsWith("favonius-")) flatEnergy[member.characterId] = 6;
  }
  const rotation = scheduleTeam(
    members.map((member) => member.characterId),
    onFieldId,
    er,
    options.clearParticles ?? 0,
    skillResets,
    flatEnergy,
  );
  const gauge = new Gauge();
  const icd = new Map<string, { hits: number; last: number }>();
  const counts = new Map<string, number>();
  const hits: FightHit[] = [];
  const windows: Array<{ start: number; end: number; owner: string; flatAtk?: number; buff?: TimedBuff }> = [];
  const shreds: Array<{ start: number; end: number; element: string; amount: number }> = [];
  let damage = 0;
  let shockwaves = 0;
  let lastShock = -10;
  const stellar = members.some((member) => profiles.get(member.characterId)?.tags.includes("stellar-jubilee"));
  const moonsign = members.some((member) => profiles.get(member.characterId)?.tags.includes("moonsign"));
  const wearsVV = members.some((member) => member.artifactSetId === "viridescent-venerer");
  const wearsDeepwood = members.some((member) => member.artifactSetId === "deepwood-memories");
  const level = options.enemyLevel ?? 90;
  const bonus = options.reactionBonus ?? {};

  const resolve = (owner: string, template: HitTemplate, time: number) => {
    const sheet = byId.get(owner);
    if (!sheet) return;
    const mods = modifiersAt(windows, owner, onFieldId, time, template.kind);
    const atk = sheet.atk * (1 + mods.atkPct) + mods.flatAtk;
    const stat = template.basis === "ATK" ? atk : statAmount({ ...sheet, atk }, template.basis);
    const element = template.element === "physical" ? "Physical" : sheet.element;
    let event: GaugeEvent = {};
    if (template.element === "character" && template.gauge > 0) {
      const key = `${owner}:${template.icdTag ?? template.kind}`;
      if (icdReady(icd, key, time, template.icdHits, template.icdSeconds)) {
        event = gauge.apply(sheet.element.toLowerCase(), template.gauge, time);
      }
    }
    const reactionId = event.reaction;
    const stellarSwirl = reactionId === "swirl" && event.swirled === "cryo" && stellar;
    if (reactionId) counts.set(reactionId, (counts.get(reactionId) ?? 0) + 1);
    if (stellarSwirl) counts.set("stellar-swirl", (counts.get("stellar-swirl") ?? 0) + 1);
    if (wearsVV && reactionId === "swirl" && event.swirled) {
      shreds.push({ start: time, end: time + 10, element: event.swirled, amount: 0.4 });
    }
    if (wearsDeepwood && sheet.element === "Dendro" && template.element === "character") {
      shreds.push({ start: time, end: time + 8, element: "dendro", amount: 0.3 });
    }
    const res = resistanceAt(options, shreds, element, time);
    const amp = event.kind === "amplifying" && event.coefficient
      ? { coefficient: event.coefficient, em: sheet.em + mods.em }
      : undefined;
    const additive = event.kind === "catalyze" && event.coefficient ? catalyzeBonus(event.coefficient, sheet.em + mods.em) : 0;
    let hitDamage = directHit({
      motion: template.motion,
      stat,
      dmgBonus: dmgBonusFor(sheet, template.kind, element) + mods.dmg,
      critRate: Math.min(1, sheet.critRate + mods.critRate),
      critDmg: sheet.critDmg + mods.critDmg,
      characterLevel: 90,
      enemyLevel: level,
      res,
      additive,
      amplifying: amp,
    });
    if (event.kind === "amplifying" && reactionId && bonus[reactionId]) hitDamage *= 1 + bonus[reactionId];
    if (event.kind === "transformative" && event.coefficient) {
      const reactionRes = resistanceAt(options, shreds, event.swirled ?? REACTION_RES[reactionId ?? ""] ?? element, time);
      let extra = transformativeDamage({
        coefficient: event.coefficient,
        em: sheet.em + mods.em,
        res: reactionRes,
        reactionBonus: sheet.reactionBonus,
      });
      if (reactionId && bonus[reactionId]) extra *= 1 + bonus[reactionId];
      if (stellarSwirl && bonus["stellar-swirl"]) extra *= 1 + bonus["stellar-swirl"];
      hitDamage += extra;
      if (reactionId === "electro-charged" && moonsign) {
        hitDamage += lunarCharged(members, byId, reactionRes, bonus["lunar-charged"] ?? 0);
      }
    }
    const targets = template.aoe ? Math.max(1, options.targets ?? 1) : 1;
    if (options.shockwave && (reactionId === "swirl" || stellarSwirl) && time - lastShock >= 4) {
      shockwaves += 1;
      lastShock = time;
      // Ley-line shockwave is true damage hitting everything nearby.
      damage += tuningConstants().shockwaveDamage * Math.max(1, options.targets ?? 1);
    }
    damage += hitDamage * targets;
    hits.push({ time, owner, kind: template.kind, motion: template.motion, damage: hitDamage, reaction: reactionId });
  };

  const queue: Array<{ time: number; owner: string; template: HitTemplate; order: number }> = [];
  let order = 0;
  const normalProcs: Array<{ owner: string; start: number; end: number; ticks: HitTemplate[] }> = [];
  const push = (time: number, owner: string, template: HitTemplate) => {
    queue.push({ time, owner, template, order: order++ });
  };
  for (const action of rotation.actions) {
    const profile = profiles.get(action.owner) ?? characterProfile(action.owner);
    const time = action.start / 60;
    if (action.kind === "burst") {
      const sheet = byId.get(action.owner);
      const buff = profile.partyBuff;
      if (sheet && buff) {
        windows.push({
          start: time,
          end: time + buff.duration,
          owner: action.owner,
          flatAtk: sheet.baseAtk * buff.ratio,
        });
      }
    }
    if (action.kind === "skill" || action.kind === "burst") {
      openCastWindows(windows, byId.get(action.owner), action, time);
      const sustain = action.kind === "skill" ? profile.skillSustain : profile.burstSustain;
      const cast = action.kind === "skill" ? profile.skill : profile.burst;
      for (const template of cast) push(time, action.owner, template);
      if (sustain) {
        if (sustain.onNormal) {
          normalProcs.push({ owner: action.owner, start: time, end: time + sustain.duration, ticks: sustain.ticks });
        }
        else {
          for (let at = time; at < time + sustain.duration && at < tuningConstants().rotationSeconds; at += sustain.interval) {
            for (const tick of sustain.ticks) push(at, action.owner, tick);
          }
        }
      }
      continue;
    }
    const templates = templatesFor(profile, action.kind);
    const step = templates.length > 0 ? action.frames / templates.length / 60 : 0;
    templates.forEach((template, index) => {
      const at = time + index * step;
      push(at, action.owner, template);
      for (const proc of normalProcs) {
        if (at < proc.start || at >= proc.end) continue;
        for (const tick of proc.ticks) push(at, proc.owner, tick);
      }
    });
  }
  queue.sort((a, b) => a.time - b.time || a.order - b.order);
  for (const hit of queue) resolve(hit.owner, hit.template, hit.time);

  // Teams fielding an element the enemy is weak to exploit it (stagger windows, exposed states).
  const teamElements = new Set(sheets.map((sheet) => sheet.element));
  const exploitsWeakness = Object.entries(options.res ?? {}).some(
    ([element, res]) => (res ?? 0) < 0 && teamElements.has(element as Sheet["element"]),
  );
  if (exploitsWeakness) damage *= tuningConstants().weaknessExploitBonus;
  const sustain = members.some((member) => member.role === "healer" || member.role === "shield");
  if (!sustain) damage *= tuningConstants().noSustainPenalty;
  const seconds = tuningConstants().rotationSeconds;
  const dps = damage / seconds;
  if (options.refine !== false && (options.groups ?? 0) > 0 && (options.hp ?? 0) > 0 && dps > 0) {
    const clear = (options.hp ?? 0) / dps;
    const particles = (options.groups ?? 0) * (seconds / Math.max(seconds, clear));
    if (particles >= 0.25) return fightTeam(members, { ...options, clearParticles: particles, refine: false });
  }
  const fallbackIds = members
    .map((member) => member.characterId)
    .filter((id) => profiles.get(id)?.fallback ?? characterProfile(id).fallback);
  return {
    damage,
    dps,
    reactions: [...counts.entries()].map(([id, count]) => ({ id, count })).sort((a, b) => b.count - a.count),
    rotation: rotationLine(rotation.actions),
    onFieldId,
    confidence: fallbackIds.length === 0 ? "kit" : "fallback",
    fallbackIds,
    shockwaves,
    hits,
  };
}

function lunarCharged(
  members: FightMember[],
  sheets: Map<string, Sheet>,
  res: number,
  reactionBonus: number,
): number {
  const personal: number[] = [];
  for (const member of members) {
    const sheet = sheets.get(member.characterId);
    const element = sheet?.element;
    if (!sheet || (element !== "Electro" && element !== "Hydro")) continue;
    const kitBonus = (charactersByID[member.characterId]?.kit?.reactionBaseDamageBonus ?? [])
      .filter((row) => row.reactions.some((name) => /lunar-charged/i.test(name)))
      .reduce((sum, row) => sum + row.value, 0);
    const amount =
      3 *
      LEVEL_90_MULTIPLIER *
      (1 + kitBonus) *
      (1 + lunarEmBonus(sheet.em) + reactionBonus) *
      resMultiplier(res) *
      expectedCrit(sheet.critRate, sheet.critDmg);
    personal.push(amount);
  }
  const weights = [0.6, 0.3, 0.05, 0.05];
  return personal
    .sort((a, b) => b - a)
    .slice(0, 4)
    .reduce((sum, value, index) => sum + value * weights[index], 0);
}

function templatesFor(profile: ReturnType<typeof characterProfile>, kind: RotationAction["kind"]): HitTemplate[] {
  if (kind === "skill") return profile.skill;
  if (kind === "burst") return profile.burst;
  if (kind === "charged") return profile.charged;
  return profile.combo;
}

function pickOnField(members: FightMember[], sheets: Sheet[]): string {
  const dps = members.filter((member) => member.role === "dps");
  const pool = dps.length > 0 ? dps : members;
  const power = (id: string) => {
    const sheet = sheets.find((item) => item.id === id);
    return sheet ? statAmount(sheet, scalingBasis(id)) : 0;
  };
  return pool.slice().sort((a, b) => power(b.characterId) - power(a.characterId))[0]
    ?.characterId ?? members[0]?.characterId ?? "";
}

function modifiersAt(
  windows: Array<{ start: number; end: number; owner: string; flatAtk?: number; buff?: TimedBuff }>,
  owner: string,
  onFieldId: string,
  time: number,
  kind: HitKind,
): { flatAtk: number; atkPct: number; dmg: number; em: number; critRate: number; critDmg: number } {
  const mods = { flatAtk: 0, atkPct: 0, dmg: 0, em: 0, critRate: 0, critDmg: 0 };
  const slot = kind === "combo" ? "normal" : kind;
  for (const window of windows) {
    if (time < window.start || time >= window.end) continue;
    if (window.flatAtk) {
      mods.flatAtk += window.flatAtk;
      continue;
    }
    const buff = window.buff;
    if (!buff) continue;
    if (buff.scope === "self" && window.owner !== owner) continue;
    if (buff.scope === "others" && window.owner === owner) continue;
    if (buff.scope === "active" && owner !== onFieldId) continue;
    if (buff.on && !buff.on.includes(slot)) continue;
    const amount = buff.value * buff.stacks;
    if (buff.stat === "atk%") mods.atkPct += amount;
    else if (buff.stat === "dmg" || buff.stat.endsWith("-dmg") || buff.stat === "own-element-dmg") mods.dmg += amount;
    else if (buff.stat === "em") mods.em += amount;
    else if (buff.stat === "crit-rate") mods.critRate += amount;
    else if (buff.stat === "crit-dmg") mods.critDmg += amount;
    else if (buff.stat === "flat-atk") mods.flatAtk += amount;
  }
  return mods;
}

function openCastWindows(
  windows: Array<{ start: number; end: number; owner: string; buff?: TimedBuff }>,
  sheet: Sheet | undefined,
  action: RotationAction,
  time: number,
): void {
  if (!sheet) return;
  const by = action.kind === "skill" ? "skill" : "burst";
  for (const buff of sheet.timed) {
    if (buff.duration <= 0) continue;
    if (!buff.kinds.includes("cast")) continue;
    if (buff.by.length > 0 && !buff.by.includes(by)) continue;
    windows.push({ start: time, end: time + buff.duration, owner: sheet.id, buff });
  }
}

function applyStaticBuffs(sheets: Sheet[]): void {
  for (const sheet of sheets) {
    for (const buff of sheet.timed) {
      if (buff.duration !== 0 || !buff.stat) continue;
      if (!staticGate(buff, sheet, sheets)) continue;
      const stacks = Math.min(buff.stacks, staticStacks(buff, sheet, sheets));
      const amount = buff.value * Math.max(1, stacks);
      if (buff.stat === "atk%") sheet.atk *= 1 + amount;
      else if (buff.stat === "hp%") sheet.hp *= 1 + amount;
      else if (buff.stat === "em") sheet.em += amount;
      else if (buff.stat === "dmg" || buff.stat.endsWith("-dmg")) sheet.dmg += amount;
      else if (buff.stat === "er") sheet.er += amount;
      else if (buff.stat === "crit-rate") sheet.critRate += amount;
      else if (buff.stat === "crit-dmg") sheet.critDmg += amount;
    }
  }
}

function staticGate(buff: TimedBuff, sheet: Sheet, sheets: Sheet[]): boolean {
  if (buff.kinds.includes("shield") && !sheets.some((item) => item.role === "shield")) return false;
  if (buff.kinds.includes("hexerei")) {
    const count = sheets.filter((item) => characterProfile(item.id).tags.includes("hexerei")).length;
    if (count < 2) return false;
  }
  if (buff.kinds.includes("moonsign")) {
    const count = sheets.filter((item) => characterProfile(item.id).tags.includes("moonsign")).length;
    if (count < 1) return false;
  }
  if (buff.kinds.includes("party-members") && staticStacks(buff, sheet, sheets) <= 0 && buff.match) return false;
  return true;
}

function staticStacks(buff: TimedBuff, sheet: Sheet, sheets: Sheet[]): number {
  if (buff.match === "same-element") return sheets.filter((item) => item.id !== sheet.id && item.element === sheet.element).length;
  if (buff.match === "other-element") return sheets.filter((item) => item.id !== sheet.id && item.element !== sheet.element).length;
  return buff.stacks;
}

function resistanceAt(options: FightOptions, shreds: Array<{ start: number; end: number; element: string; amount: number }>, element: string, time: number): number {
  const key = element.toLowerCase() === "physical" ? "Physical" : element[0]?.toUpperCase() + element.slice(1).toLowerCase();
  const table = options.res ?? {};
  let res = table[key] ?? table[element] ?? table[element.toLowerCase()] ?? 0.1;
  res -= options.extraResShred ?? 0;
  for (const shred of shreds) {
    if (time < shred.start || time >= shred.end) continue;
    if (shred.element.toLowerCase() === element.toLowerCase()) res -= shred.amount;
  }
  return res;
}

function rotationLine(actions: RotationAction[]): Array<{ characterId: string; casts: Array<"E" | "Q"> }> {
  const line: Array<{ characterId: string; casts: Array<"E" | "Q"> }> = [];
  for (const action of actions) {
    if (action.kind !== "skill" && action.kind !== "burst") continue;
    const cast = action.kind === "skill" ? "E" : "Q";
    const last = line[line.length - 1];
    if (last?.characterId === action.owner) last.casts.push(cast);
    else line.push({ characterId: action.owner, casts: [cast] });
  }
  return line;
}

const REACTION_NAMES: Array<[RegExp, string]> = [
  [/tinh[-\s]?khuech|stellar swirl/, "stellar-swirl"],
  [/nguyet[-\s]?dien|lunar[-\s]?charged/, "lunar-charged"],
  [/khuech tan|(?<!stellar )swirl/, "swirl"],
  [/dien cam|electro[-\s]?charged/, "electro-charged"],
  [/boc hoi|vaporize/, "vaporize"],
  [/tan chay|melt/, "melt"],
  [/qua tai|overload/, "overload"],
  [/sieu dan|superconduct/, "superconduct"],
  [/bung toa|hyperbloom/, "hyperbloom"],
  [/no ro|burgeon/, "burgeon"],
  [/bao hoa|bloom/, "bloom"],
  [/tang cuong|aggravate/, "aggravate"],
  [/lan tran|spread/, "spread"],
];

export function reactionBonusFromText(text: string): Record<string, number> {
  const bonuses: Record<string, number> = {};
  const pattern = /tăng\s+(\d+(?:[.,]\d+)?)\s*%\s+sát thương(?:\s+phản ứng)?\s+([^,.;]+)/giu;
  for (const match of text.matchAll(pattern)) {
    const pct = Number(match[1].replace(",", ".")) / 100;
    const folded = foldVi(match[2]);
    const found = REACTION_NAMES.find(([rule]) => rule.test(folded));
    if (!found || !Number.isFinite(pct)) continue;
    bonuses[found[1]] = (bonuses[found[1]] ?? 0) + pct;
  }
  return bonuses;
}

export function enemyOfHalf(floor: CycleFloor, half: 1 | 2): {
  level: number;
  hp: number;
  res: Record<string, number>;
  targets: number;
  groups: number;
} {
  let hp = 0;
  let levelSum = 0;
  let targetSum = 0;
  let groups = 0;
  const resSum = new Map<string, { value: number; weight: number }>();
  for (const chamber of floor.chambers) {
    for (const wave of chamber.waves) {
      if (wave.wave !== half) continue;
      for (const monster of wave.monsters) {
        const weight = monsterHP(monster, chamber.monsterLevel, floor.enemyHPMultiplier ?? 1) ?? 1;
        const concurrent = Math.min(5, Number(/^(\d+)/u.exec(monster.count)?.[1] ?? 1) || 1);
        hp += weight;
        groups += 1;
        targetSum += concurrent * weight;
        levelSum += chamber.monsterLevel * weight;
        const table = monster.resistances ?? {};
        const elements = ["Pyro", "Hydro", "Electro", "Cryo", "Anemo", "Geo", "Dendro", "Physical"];
        for (const element of elements) {
          const value = element === "Physical" ? (monster.physicalResistance ?? table.Physical ?? 0.1) : (table[element] ?? 0.1);
          const bucket = resSum.get(element) ?? { value: 0, weight: 0 };
          bucket.value += value * weight;
          bucket.weight += weight;
          resSum.set(element, bucket);
        }
      }
    }
  }
  const res: Record<string, number> = {};
  for (const [element, bucket] of resSum) res[element] = bucket.weight > 0 ? bucket.value / bucket.weight : 0.1;
  return {
    level: hp > 0 ? levelSum / hp : 90,
    hp,
    res,
    targets: hp > 0 ? targetSum / hp : 1,
    groups,
  };
}
