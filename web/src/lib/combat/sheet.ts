import {
  artifactSetsByID,
  charactersByID,
  weaponsByID,
  type ElementName,
} from "../abyss";
import {
  characterTalent,
  paramsAtTalentLevel,
  refinedValue,
  setPassive,
  tuningConstants,
  weaponPassive,
  type PassiveEffect,
} from "./catalog";
import { characterProfile, cleanLabel, triggersOf, type Basis } from "./talent";

export type TimedBuff = {
  stat: string;
  value: number;
  duration: number;
  cooldown: number;
  stacks: number;
  scope: string;
  on: string[] | null;
  kinds: string[];
  by: string[];
  reactions: string[];
  match: string | null;
};

export type Sheet = {
  id: string;
  element: ElementName;
  weaponType: string;
  baseAtk: number;
  hp: number;
  atk: number;
  def: number;
  em: number;
  er: number;
  critRate: number;
  critDmg: number;
  dmg: number;
  elementDmg: number;
  normalDmg: number;
  chargedDmg: number;
  skillDmg: number;
  burstDmg: number;
  reactionBonus: number;
  atkFromConversion: number;
  atkFromHp: number;
  timed: TimedBuff[];
  role: string;
};

export type SheetRequest = {
  characterId: string;
  weaponId: string | null;
  artifactSetId: string | null;
  refinement?: number;
  role?: string;
  energyRecharge?: number;
};

type Acc = {
  hpPct: number;
  atkPct: number;
  defPct: number;
  flatHp: number;
  flatAtk: number;
  flatDef: number;
  em: number;
  er: number;
  critRate: number;
  critDmg: number;
  dmg: number;
  elementDmg: number;
  normalDmg: number;
  chargedDmg: number;
  skillDmg: number;
  burstDmg: number;
  reactionBonus: number;
  atkFromHp: number;
  atkFromEm: number;
  atkFromDef: number;
  timed: TimedBuff[];
};

const cache = new Map<string, Sheet>();

export function buildSheet(request: SheetRequest): Sheet {
  const key = JSON.stringify([
    request.characterId,
    request.weaponId,
    request.artifactSetId,
    request.refinement ?? 1,
    request.role ?? "dps",
    request.energyRecharge ?? "",
  ]);
  const cached = cache.get(key);
  if (cached) return cached;
  const sheet = assemble(request);
  cache.set(key, sheet);
  return { ...sheet, timed: sheet.timed.slice() };
}

function emptyAcc(): Acc {
  return {
    hpPct: 0,
    atkPct: 0,
    defPct: 0,
    flatHp: 0,
    flatAtk: 0,
    flatDef: 0,
    em: 0,
    er: 0,
    critRate: 0.05,
    critDmg: 0.5,
    dmg: 0,
    elementDmg: 0,
    normalDmg: 0,
    chargedDmg: 0,
    skillDmg: 0,
    burstDmg: 0,
    reactionBonus: 0,
    atkFromHp: 0,
    atkFromEm: 0,
    atkFromDef: 0,
    timed: [],
  };
}

function assemble(request: SheetRequest): Sheet {
  const character = charactersByID[request.characterId];
  const weapon = request.weaponId ? weaponsByID[request.weaponId] : undefined;
  const profile = characterProfile(request.characterId);
  const role = request.role ?? "dps";
  const refinement = request.refinement ?? 1;
  const basis = scalingBasis(request.characterId);
  const acc = emptyAcc();
  const lv90 = character?.baseStats.lv90;
  const baseHp = lv90?.hp ?? 0;
  const baseAtk = (lv90?.atk ?? 0) + (weapon?.atkLv90 ?? 0);
  const baseDef = lv90?.def ?? 0;

  addNamed(acc, lv90?.ascensionStatType, lv90?.ascensionStatValue ?? 0);
  addNamed(acc, weapon?.subStat.type, weapon?.subStat.valueLv90 ?? 0);
  addArtifactMains(acc, role, basis, profile.burstCost > 0);
  addSubstats(acc, role, basis);
  for (const effect of request.weaponId ? weaponPassive(request.weaponId) : []) {
    applyEffect(acc, effect, refinement, request.weaponId ?? "", "weapons");
  }
  if (request.artifactSetId && artifactSetsByID[request.artifactSetId]) {
    const pieces = setPassive(request.artifactSetId);
    for (const effect of [...pieces.two, ...pieces.four]) {
      applyEffect(acc, effect, 1, request.artifactSetId, "sets");
    }
  }

  const hp = baseHp * (1 + acc.hpPct) + acc.flatHp;
  const def = baseDef * (1 + acc.defPct) + acc.flatDef;
  let conversion = 0;
  for (const row of character?.kit?.conversions ?? []) {
    const converted = conversionTerm(request.characterId, row.talent, row.label);
    const pool = converted.from === "HP" ? hp : def;
    conversion += pool * converted.rate * (row.uptime ?? 1);
  }
  const atkFromHp = hp * acc.atkFromHp;
  const atk =
    baseAtk * (1 + acc.atkPct) +
    acc.flatAtk +
    atkFromHp +
    acc.em * acc.atkFromEm +
    def * acc.atkFromDef +
    conversion;

  return {
    id: request.characterId,
    element: character?.element ?? profile.element,
    weaponType: character?.weaponType ?? profile.weaponType,
    baseAtk,
    hp,
    atk,
    def,
    em: acc.em,
    er: request.energyRecharge ?? 1 + acc.er,
    critRate: Math.min(1, acc.critRate),
    critDmg: acc.critDmg,
    dmg: acc.dmg,
    elementDmg: acc.elementDmg,
    normalDmg: acc.normalDmg,
    chargedDmg: acc.chargedDmg,
    skillDmg: acc.skillDmg,
    burstDmg: acc.burstDmg,
    reactionBonus: acc.reactionBonus,
    atkFromConversion: conversion,
    atkFromHp,
    timed: acc.timed,
    role,
  };
}

function conversionTerm(
  id: string,
  talent: string | undefined,
  label: string | undefined,
): { rate: number; from: "HP" | "DEF" } {
  if (!talent || !label) return { rate: 0, from: "ATK" as "DEF" };
  const key = talent === "elementalBurst" || talent === "normalAttack" ? talent : "elementalSkill";
  const data = characterTalent(id)?.[key];
  if (!data) return { rate: 0, from: "DEF" };
  const line = data.lines.find((row) => cleanLabel(row.split("|")[0] ?? "") === label);
  if (!line) return { rate: 0, from: "DEF" };
  const match = /\{param(\d+)/i.exec(line);
  const rate = match ? (paramsAtTalentLevel(data)[Number(match[1]) - 1] ?? 0) : 0;
  return { rate, from: /max hp/i.test(line) ? "HP" : "DEF" };
}

function scalingBasis(id: string): Basis {
  const notes = (charactersByID[id]?.kit?.conversions ?? []).map((row) => row.note ?? "").join(" ");
  if (/max hp/i.test(notes)) return "HP";
  if (/\bdef\b/i.test(notes)) return "DEF";
  const profile = characterProfile(id);
  const hits = [...profile.skill, ...profile.burst, ...profile.charged, ...profile.combo];
  const score = { ATK: 0, HP: 0, DEF: 0, EM: 0 };
  for (const hit of hits) score[hit.basis] += hit.motion;
  return (Object.entries(score).sort((a, b) => b[1] - a[1])[0]?.[0] as Basis) ?? "ATK";
}

function addArtifactMains(acc: Acc, role: string, basis: Basis, hasBurst: boolean): void {
  const mains = tuningConstants().artifactMainStats;
  acc.flatHp += mains.flat_hp;
  acc.flatAtk += mains.flat_atk;
  const sandsEr = role === "support" || role === "healer" || role === "shield";
  if (sandsEr && hasBurst) acc.er += mains.er;
  else addBasisMain(acc, basis, mains);
  if (role === "healer" || role === "shield") acc.hpPct += mains.hp_pct;
  else acc.elementDmg += mains.elemental_dmg;
  if (role !== "healer" && role !== "shield") acc.critRate += mains.crit_rate;
}

function addBasisMain(acc: Acc, basis: Basis, mains: Record<string, number>): void {
  if (basis === "HP") acc.hpPct += mains.hp_pct;
  else if (basis === "DEF") acc.defPct += mains.def_pct;
  else if (basis === "EM") acc.em += mains.em;
  else acc.atkPct += mains.atk_pct;
}

function addSubstats(acc: Acc, role: string, basis: Basis): void {
  const tuning = tuningConstants();
  const weights = tuning.substatPriority[role] ?? tuning.substatPriority["main-dps"];
  const swap = tuning.scalingBasisSwap[basis] ?? {};
  const budget = tuning.substatRollBudget;
  for (const [stat, weight] of Object.entries(weights)) {
    const key = swap[stat] ?? stat;
    const roll = tuning.substatRollValue[key] ?? 0;
    const amount = budget * weight * roll;
    if (key === "crit_rate") acc.critRate += amount;
    else if (key === "crit_dmg") acc.critDmg += amount;
    else if (key === "atk_pct") acc.atkPct += amount;
    else if (key === "hp_pct") acc.hpPct += amount;
    else if (key === "def_pct") acc.defPct += amount;
    else if (key === "em") acc.em += amount;
    else if (key === "er") acc.er += amount;
  }
}

function addNamed(acc: Acc, type: string | null | undefined, value: number): void {
  if (!type || !value) return;
  const name = type.toLowerCase();
  if (name.includes("crit") && name.includes("dmg")) acc.critDmg += value;
  else if (name.includes("crit")) acc.critRate += value;
  else if (name.includes("energy")) acc.er += value;
  else if (name.includes("mastery")) acc.em += value;
  else if (name.includes("hp")) acc.hpPct += value;
  else if (name.includes("def") && !name.includes("dmg")) acc.defPct += value;
  else if (name.includes("atk") && !name.includes("dmg")) acc.atkPct += value;
  else if (name.includes("dmg")) acc.elementDmg += name.includes("physical") ? 0 : value;
}

function applyEffect(
  acc: Acc,
  effect: PassiveEffect,
  refinement: number,
  sourceId: string,
  kind: "weapons" | "sets",
): void {
  const triggers = triggersOf(effect);
  if (triggers.some((trigger) => trigger.kind === "unmodelled")) return;
  const permanent = triggers.length === 0 && effect.duration == null;
  const teamStatic = triggers.length > 0 && triggers.every((trigger) => STATIC.has(trigger.kind)) && effect.duration == null;
  let value = effect.value ?? effect.tiers?.[0] ?? 0;
  if (effect.value != null) value = refinedValue(sourceId, effect.value, refinement, kind);
  if (effect.scale) value *= effect.scale;
  if (!permanent && !teamStatic) {
    if (effect.duration != null && effect.stat) {
      acc.timed.push(timedFrom(effect, value, triggers, effect.duration));
    }
    return;
  }
  if (teamStatic) {
    acc.timed.push(timedFrom(effect, value, triggers, 0));
    return;
  }
  addPassiveStat(acc, effect, value);
}

const STATIC = new Set(["party-members", "distinct-elements", "moonsign", "hexerei", "shield", "nightsoul", "weapon-type"]);

function timedFrom(
  effect: PassiveEffect,
  value: number,
  triggers: ReturnType<typeof triggersOf>,
  duration: number,
): TimedBuff {
  return {
    stat: effect.stat ?? "",
    value,
    duration,
    cooldown: effect.cooldown ?? 0,
    stacks: effect.stacks ?? 1,
    scope: effect.scope ?? "self",
    on: effect.on ?? null,
    kinds: triggers.map((trigger) => trigger.kind),
    by: triggers.flatMap((trigger) => trigger.by ?? []),
    reactions: triggers.flatMap((trigger) => trigger.reactions ?? []),
    match: triggers.find((trigger) => trigger.match)?.match ?? null,
  };
}

function addPassiveStat(acc: Acc, effect: PassiveEffect, value: number): void {
  const stat = effect.stat ?? "";
  const stacks = effect.stacks ?? 1;
  const amount = value * stacks;
  if (effect.on?.length) {
    for (const slot of effect.on) {
      if (slot === "normal") acc.normalDmg += amount;
      else if (slot === "charged") acc.chargedDmg += amount;
      else if (slot === "skill") acc.skillDmg += amount;
      else if (slot === "burst") acc.burstDmg += amount;
    }
    return;
  }
  if (effect.from === "hp" && stat === "flat-atk") {
    acc.atkFromHp += value;
    return;
  }
  if (effect.from === "em" && stat === "flat-atk") {
    acc.atkFromEm += value;
    return;
  }
  if (effect.from === "def" && stat === "flat-atk") {
    acc.atkFromDef += value;
    return;
  }
  if (stat === "atk%") acc.atkPct += amount;
  else if (stat === "hp%") acc.hpPct += amount;
  else if (stat === "def%") acc.defPct += amount;
  else if (stat === "flat-atk") acc.flatAtk += amount;
  else if (stat === "em") acc.em += amount;
  else if (stat === "er") acc.er += amount;
  else if (stat === "crit-rate") acc.critRate += amount;
  else if (stat === "crit-dmg") acc.critDmg += amount;
  else if (stat === "dmg") acc.dmg += amount;
  else if (stat === "own-element-dmg" || stat.endsWith("-dmg")) acc.elementDmg += amount;
  else if (stat === "normal") acc.normalDmg += amount;
}

export function statAmount(sheet: Sheet, basis: Basis): number {
  if (basis === "HP") return sheet.hp;
  if (basis === "DEF") return sheet.def;
  if (basis === "EM") return sheet.em;
  return sheet.atk;
}

export function dmgBonusFor(sheet: Sheet, kind: string, element: ElementName | "Physical"): number {
  let bonus = sheet.dmg + (element === sheet.element ? sheet.elementDmg : 0);
  if (kind === "combo") bonus += sheet.normalDmg;
  if (kind === "charged") bonus += sheet.chargedDmg;
  if (kind === "skill") bonus += sheet.skillDmg;
  if (kind === "burst") bonus += sheet.burstDmg;
  return bonus;
}

export function applyResonance(sheets: Sheet[]): void {
  const counts = new Map<ElementName, number>();
  for (const sheet of sheets) counts.set(sheet.element, (counts.get(sheet.element) ?? 0) + 1);
  if ((counts.get("Pyro") ?? 0) >= 2) {
    for (const sheet of sheets) sheet.atk += sheet.baseAtk * 0.25;
  }
  if ((counts.get("Hydro") ?? 0) >= 2) {
    for (const sheet of sheets) sheet.hp += sheet.hp * 0.25;
  }
  if ((counts.get("Dendro") ?? 0) >= 2) {
    for (const sheet of sheets) sheet.em += 50;
  }
}
