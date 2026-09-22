import { charactersByID, kitsByID, type ElementName } from "../abyss";
import { foldVi } from "../slug";
import {
  characterTalent,
  frameRow,
  gaugeTable,
  paramsAtTalentLevel,
  particleReading,
  ROTATION_SECONDS,
  tuningConstants,
  type PassiveEffect,
} from "./catalog";

export type Basis = "ATK" | "HP" | "DEF" | "EM";
export type HitKind = "combo" | "charged" | "skill" | "burst";

export type HitTemplate = {
  kind: HitKind;
  motion: number;
  basis: Basis;
  gauge: number;
  icdTag: string | null;
  icdHits: number | null;
  icdSeconds: number | null;
  element: "character" | "physical";
  label: string;
  aoe: boolean;
};

export type SustainedAttack = {
  ticks: HitTemplate[];
  duration: number;
  interval: number;
  onNormal: boolean;
};

type KitHit = {
  label?: string;
  param?: number;
  talent?: "normalAttack" | "elementalSkill" | "elementalBurst";
  count?: number;
  category?: "normal" | "charged" | "skill" | "burst";
  basis?: Basis;
  factor?: { talent: "normalAttack" | "elementalSkill" | "elementalBurst"; param: number };
};

type TalentKey = "normalAttack" | "elementalSkill" | "elementalBurst";

/** Extra talent levels from owned constellations (C3/C5-style "+3 level" entries). */
export type TalentBoost = Partial<Record<TalentKey, number>>;

const SLOT_TALENT: Record<HitKind, TalentKey> = {
  combo: "normalAttack",
  charged: "normalAttack",
  skill: "elementalSkill",
  burst: "elementalBurst",
};

export type CharacterProfile = {
  id: string;
  element: ElementName;
  weaponType: string;
  combo: HitTemplate[];
  charged: HitTemplate[];
  skill: HitTemplate[];
  burst: HitTemplate[];
  skillCooldown: number;
  burstCooldown: number;
  burstCost: number;
  burstDuration: number;
  particles: number;
  particlesToField: boolean;
  maxSkillCasts: number;
  comboFrames: number[];
  chargedFrames: number;
  skillFrames: number;
  burstFrames: number;
  framesEstimated: boolean;
  skillSustain: SustainedAttack | null;
  burstSustain: SustainedAttack | null;
  fallback: boolean;
  infused: boolean;
  loop: "combo" | "charged";
  partyBuff: { ratio: number; duration: number } | null;
  tags: string[];
};

const profiles = new Map<string, CharacterProfile>();

export function characterProfile(id: string, boost: TalentBoost = {}): CharacterProfile {
  const key = `${id}:${boost.normalAttack ?? 0},${boost.elementalSkill ?? 0},${boost.elementalBurst ?? 0}`;
  const cached = profiles.get(key);
  if (cached) return cached;
  const built = buildProfile(id, boost);
  profiles.set(key, built);
  return built;
}

/** Parses constellation entries like "Cấp kỹ năng <talent> +3" into per-talent level boosts. */
export function constellationBoosts(id: string, constellation: number): TalentBoost {
  const boost: Required<TalentBoost> = { normalAttack: 0, elementalSkill: 0, elementalBurst: 0 };
  const character = charactersByID[id];
  if (!character || constellation <= 0) return boost;
  const talents: Array<[TalentKey, string]> = [
    ["normalAttack", foldVi(character.normalAttack.name ?? "")],
    ["elementalSkill", foldVi(character.elementalSkill.name ?? "")],
    ["elementalBurst", foldVi(character.elementalBurst.name ?? "")],
  ];
  for (const entry of character.constellations) {
    if (entry.level > constellation) continue;
    const match = /cap ky nang\s+(.+?)\s*\+\s*(\d+)/i.exec(foldVi(entry.description));
    if (!match) continue;
    const named = match[1].trim();
    const target = talents.find(([, name]) => name && (name.includes(named) || named.includes(name)));
    if (target) boost[target[0]] += Number(match[2]);
  }
  return boost;
}

function buildProfile(id: string, boost: TalentBoost = {}): CharacterProfile {
  const character = charactersByID[id];
  const element = character?.element ?? "Pyro";
  const weaponType = character?.weaponType ?? "Sword";
  const kit = kitsByID[id] as {
    tags?: string[];
    hits?: { skill?: KitHit[]; burst?: KitHit[]; combo?: KitHit[]; charged?: KitHit[]; note?: string };
    energy?: {
      eventsPerCast?: number;
      particlesPerCast?: number;
      skillCastsPerRotation?: number;
      collectedBy?: string;
      note?: string;
    };
    attack?: { infused?: boolean; loop?: string };
    buffs?: Array<{ scope?: string; kind?: string; talent?: TalentKey; label?: string }>;
  } | undefined;
  const talent = characterTalent(id);
  const frames = frameRow(id);
  const reading = particleReading(id);
  const skillBlock = talent?.elementalSkill;
  const burstBlock = talent?.elementalBurst;
  const infused = kit?.attack?.infused === true || weaponType === "Catalyst";
  const attacksApply = infused || weaponType === "Bow";

  const skillAbility = resolveSlot(id, "skill", kit?.hits?.skill, true, boost, {
    count: kit?.hits?.skill ? 0 : eventCount(kit?.energy?.eventsPerCast),
    event: reading.event,
  });
  const burstAbility = resolveSlot(id, "burst", kit?.hits?.burst, true, boost);
  const skillText = character?.elementalSkill.description ?? "";
  const burstText = character?.elementalBurst.description ?? "";
  const skillSplit = skillAbility.ticks.length > 0 ? skillAbility : splitContinuous(skillAbility.cast, skillText);
  const burstSplit = burstAbility.ticks.length > 0 ? burstAbility : splitContinuous(burstAbility.cast, burstText);
  const slots = {
    combo: resolveSlot(id, "combo", kit?.hits?.combo, attacksApply && weaponType !== "Bow", boost).cast,
    charged: resolveSlot(id, "charged", kit?.hits?.charged, attacksApply, boost).cast,
    skill: markAoe(skillSplit.cast, skillText),
    burst: markAoe(burstSplit.cast, burstText),
  };
  const skillSustain = sustainOf(skillSplit.ticks, skillText, durationOf(skillBlock, boost.elementalSkill ?? 0), kit?.energy?.note ?? "", eventCount(kit?.energy?.eventsPerCast));
  const burstSustain = sustainOf(burstSplit.ticks, burstText, durationOf(burstBlock, boost.elementalBurst ?? 0), "", 0);

  const hasHitKit = Boolean(kit?.hits && (kit.hits.skill || kit.hits.burst || kit.hits.combo || kit.hits.charged));
  const particles =
    kit?.energy?.particlesPerCast ??
    (reading.perEvent > 0 ? reading.perEvent * (kit?.energy?.eventsPerCast ?? 1) : reading.press);
  const tuning = tuningConstants();
  const cooldown = skillBlock?.cooldown || 0;
  const naturalCasts = cooldown > 0 ? Math.floor(ROTATION_SECONDS / cooldown) : 1;
  const maxSkillCasts = kit?.energy?.skillCastsPerRotation ?? Math.min(tuning.energy.maxSkillCastsPerRotation, Math.max(1, naturalCasts));

  const chargedRate = slots.charged.reduce((sum, hit) => sum + hit.motion, 0) / Math.max(1, frames.chargedFrames);
  const comboRate = slots.combo.reduce((sum, hit) => sum + hit.motion, 0) / Math.max(1, frames.comboFrames.reduce((a, b) => a + b, 0));
  const chargedLoop = kit?.attack?.loop === "charged" || weaponType === "Bow" || weaponType === "Catalyst";
  const loop = chargedLoop && chargedRate > comboRate ? "charged" : "combo";

  return {
    id,
    element,
    weaponType,
    ...slots,
    skillCooldown: cooldown > 0 ? cooldown : ROTATION_SECONDS,
    burstCooldown: burstBlock?.cooldown || ROTATION_SECONDS,
    burstCost: burstBlock?.energyCost || 0,
    burstDuration: durationOf(burstBlock, boost.elementalBurst ?? 0),
    particles,
    particlesToField: kit?.energy?.collectedBy === "field",
    maxSkillCasts,
    comboFrames: frames.comboFrames,
    chargedFrames: frames.chargedFrames,
    skillFrames: frames.skillFrames,
    burstFrames: frames.burstFrames,
    framesEstimated: frames.estimated,
    skillSustain,
    burstSustain,
    fallback: !hasHitKit,
    infused,
    loop,
    partyBuff: partyBuffOf(id, kit?.buffs, boost),
    tags: kit?.tags ?? [],
  };
}

function partyBuffOf(
  id: string,
  buffs: Array<{ scope?: string; kind?: string; talent?: TalentKey; label?: string }> | undefined,
  boost: TalentBoost = {},
): { ratio: number; duration: number } | null {
  const buff = buffs?.find((item) => item.scope === "party" && item.kind === "flat-atk-from-base-atk" && item.label);
  if (!buff?.label || !buff.talent) return null;
  const block = characterTalent(id)?.[buff.talent];
  const line = block?.lines.find((row) => cleanLabel(row.split("|")[0] ?? "") === buff.label);
  if (!line) return null;
  const params = paramsAtTalentLevel(block, boost[buff.talent] ?? 0);
  const expr = line.split("|").slice(1).join("|");
  const ratio = firstParam(expr, params);
  return { ratio, duration: durationOf(block, boost[buff.talent] ?? 0) || 12 };
}

function durationOf(block: { lines: string[]; params: number[][] } | undefined, boost = 0): number {
  if (!block) return 0;
  const line = block.lines.find((row) => /^duration\|/i.test(cleanLabel(row).split("|")[0] ?? "") || row.startsWith("Duration|"));
  if (!line) return 0;
  const params = paramsAtTalentLevel(block, boost);
  const match = /\{param(\d+)/i.exec(line);
  if (!match) return 0;
  return params[Number(match[1]) - 1] ?? 0;
}

function resolveSlot(
  id: string,
  kind: HitKind,
  kitHits: KitHit[] | undefined,
  appliesElement: boolean,
  boost: TalentBoost,
  events?: { count: number; event: string },
): { cast: HitTemplate[]; ticks: HitTemplate[] } {
  if (kitHits) return { cast: kitHits.flatMap((hit) => hitFromKit(id, kind, hit, appliesElement, boost)), ticks: [] };
  return fallbackSlot(id, kind, appliesElement, boost, events);
}

function eventCount(value: number | undefined): number {
  if (value == null || !Number.isInteger(value) || value <= 1) return 0;
  return value;
}

function hitFromKit(id: string, kind: HitKind, hit: KitHit, appliesElement: boolean, boost: TalentBoost): HitTemplate[] {
  const talentKey = hit.talent ?? SLOT_TALENT[hit.category === "normal" ? "combo" : hit.category === "charged" ? "charged" : kind];
  const block = characterTalent(id)?.[talentKey];
  const params = paramsAtTalentLevel(block, boost[talentKey] ?? 0);
  const count = hit.count ?? 1;
  let motion = 0;
  let basis: Basis = hit.basis ?? "ATK";
  if (hit.factor) {
    const factorBlock = characterTalent(id)?.[hit.factor.talent];
    motion = (paramsAtTalentLevel(factorBlock, boost[hit.factor.talent] ?? 0)[hit.factor.param - 1] ?? 0) * (hit.param ? (params[hit.param - 1] ?? 1) : 1);
  } else if (hit.param) {
    motion = params[hit.param - 1] ?? 0;
  } else if (hit.label && block) {
    const line = block.lines.find((row) => cleanLabel(row.split("|")[0] ?? "") === hit.label);
    if (line) {
      const parsed = parseExpr(line.split("|").slice(1).join("|"), params);
      motion = parsed.reduce((sum, part) => sum + part.motion, 0) || parsed[0]?.motion || 0;
      basis = parsed[0]?.basis ?? basis;
    }
  }
  const gauge = gaugeFor(id, talentKey, hit.label ?? "");
  const element = appliesElement || kind === "skill" || kind === "burst" ? "character" : "physical";
  return Array.from({ length: count }, () => ({
    kind,
    motion,
    basis,
    gauge: gauge.units,
    icdTag: gauge.icdTag,
    icdHits: gauge.icdHits,
    icdSeconds: gauge.icdSeconds,
    element,
    label: hit.label ?? "",
    aoe: false,
  }));
}

function fallbackSlot(
  id: string,
  kind: HitKind,
  appliesElement: boolean,
  boost: TalentBoost,
  events?: { count: number; event: string },
): { cast: HitTemplate[]; ticks: HitTemplate[] } {
  const talentKey = SLOT_TALENT[kind];
  const block = characterTalent(id)?.[talentKey];
  if (!block) return { cast: [], ticks: [] };
  const params = paramsAtTalentLevel(block, boost[talentKey] ?? 0);
  let rows = block.lines
    .map((row) => ({ raw: row, label: cleanLabel(row.split("|")[0] ?? "") }))
    .filter((row) => isDamageLabel(row.label));
  if (kind === "combo") rows = rows.filter((row) => /hit/i.test(row.label) && !/charged/i.test(row.label));
  if (kind === "charged") rows = rows.filter((row) => /charged/i.test(row.label));
  if (kind === "skill" || kind === "burst") {
    const hasPress = rows.some((row) => /\b(press|tap)\b/i.test(row.label));
    if (hasPress) rows = rows.filter((row) => !/hold|charge level/i.test(row.label));
    rows = rows.filter((row) => {
      if (!/^low hp\b/i.test(row.label)) return true;
      const plain = row.label.replace(/^low hp\s+/i, "");
      return !rows.some((other) => other.label === plain);
    });
  }
  if (!events || events.count <= 1 || kind !== "skill") {
    return { cast: rows.flatMap((row) => lineHits(id, talentKey, kind, row, params, appliesElement)), ticks: [] };
  }
  const repeated = rows.filter((row) => repeatsWithEvent(row.label, events.event, rows.map((item) => item.label)));
  if (repeated.length === 0) {
    return { cast: rows.flatMap((row) => lineHits(id, talentKey, kind, row, params, appliesElement)), ticks: [] };
  }
  const once = rows.filter((row) => !repeated.includes(row));
  return {
    cast: once.flatMap((row) => lineHits(id, talentKey, kind, row, params, appliesElement)),
    ticks: repeated.flatMap((row) => lineHits(id, talentKey, kind, row, params, appliesElement)),
  };
}

function lineHits(
  id: string,
  talentKey: TalentKey,
  kind: HitKind,
  row: { raw: string; label: string },
  params: number[],
  appliesElement: boolean,
): HitTemplate[] {
  const parts = parseExpr(row.raw.split("|").slice(1).join("|"), params);
  const gauge = gaugeFor(id, talentKey, row.label);
  const element = kind === "skill" || kind === "burst" || appliesElement ? "character" : "physical";
  return parts.map((part) => ({
    kind,
    motion: part.motion,
    basis: part.basis,
    gauge: gauge.units,
    icdTag: gauge.icdTag,
    icdHits: gauge.icdHits,
    icdSeconds: gauge.icdSeconds,
    element,
    label: row.label,
    aoe: false,
  }));
}

function splitContinuous(cast: HitTemplate[], description: string): { cast: HitTemplate[]; ticks: HitTemplate[] } {
  const text = foldVi(description);
  const repeating = sustainedText(text) || /tan cong thuong/.test(text);
  if (!repeating || cast.length === 0) return { cast, ticks: [] };
  if (cast.length === 1 && /^skill dmg$/i.test(cast[0]?.label ?? "")) return { cast: [], ticks: cast };
  const ticks = cast.filter((hit) => !/swing|summoning|^skill dmg$|^total\b/i.test(hit.label));
  if (ticks.length === 0) return { cast, ticks: [] };
  if (ticks.length === cast.length) return { cast: [], ticks: cast };
  const ticking = new Set(ticks);
  return { cast: cast.filter((hit) => !ticking.has(hit)), ticks };
}

function sustainOf(
  ticks: HitTemplate[],
  description: string,
  duration: number,
  note: string,
  events: number,
): SustainedAttack | null {
  if (ticks.length === 0) return null;
  const text = foldVi(`${description} ${note}`);
  const onNormal = /don thuong|don danh trung/.test(text);
  const perSecond = /(\d+(?:[.,]\d+)?)\s*don\s*\/\s*s/u.exec(text);
  const everySeconds = /(\d+(?:[.,]\d+)?)\s*s\s*\/\s*lan/u.exec(text);
  const everyFrames = /moi\s+(\d+)\s*frame/u.exec(text);
  let interval = 1;
  if (perSecond) interval = 1 / Number(perSecond[1].replace(",", "."));
  else if (everySeconds) interval = Number(everySeconds[1].replace(",", "."));
  else if (everyFrames) interval = Number(everyFrames[1]) / 60;
  else if (events > 1 && duration > 0) interval = duration / events;
  const span = duration > 0 ? duration : interval * Math.max(events, 1);
  if (!onNormal && !sustainedText(text) && events <= 1) return null;
  if (span <= 0 || interval <= 0) return null;
  const aoe = /dien rong|pham vi|xung quanh|aoe|quanh|loc |vung/.test(text);
  return {
    ticks: ticks.map((tick) => ({ ...tick, aoe })),
    duration: span,
    interval,
    onNormal,
  };
}

function sustainedText(text: string): boolean {
  return /sat thuong lien tuc|tan cong lien tuc|tan cong thuong|khong ngung|thoi gian ton tai|dmg(?: [^.]{0,32})?lien tuc|lien tuc(?: [^.]{0,40})?(?:dmg|sat thuong|ban|phun)|dinh ky|chu ky|don\s*\/\s*s|s\s*\/\s*lan|xuc xac/.test(text);
}

function markAoe(hits: HitTemplate[], description: string): HitTemplate[] {
  const aoe = /dien rong|pham vi|xung quanh|aoe|quanh|loc |vung/.test(foldVi(description));
  if (!aoe) return hits;
  return hits.map((hit) => ({ ...hit, aoe: true }));
}

function repeatsWithEvent(label: string, event: string, labels: string[]): boolean {
  const words = event
    .toLowerCase()
    .split(/[^a-z]+/u)
    .filter((word) => word.length > 3 && !["each", "every", "dealt", "this", "skill", "with", "from", "that"].includes(word));
  const matched = labels.filter((item) => words.some((word) => item.toLowerCase().includes(word)));
  if (matched.length > 0) return matched.includes(label);
  if (labels.length === 1) return true;
  const casts = labels.filter((item) => /hold|press|tap|charge level/i.test(item));
  if (casts.length > 0 && casts.length < labels.length) return !/hold|press|tap|charge level/i.test(label);
  return false;
}

function isDamageLabel(label: string): boolean {
  if (!/dmg/i.test(label)) return false;
  if (/bonus|increase|decrease|regeneration|duration|reduction|cost|stamina|extension|absorption|healing|shield|chance/i.test(label)) return false;
  if (/plunge/i.test(label)) return false;
  return true;
}

export function cleanLabel(label: string): string {
  return label
    .replace(/#\{LAYOUT_MOBILE#[^}]*\}\{LAYOUT_PC#([^}]*)\}\{LAYOUT_PS#[^}]*\}/gu, "$1")
    .replace(/\{LAYOUT_[A-Z]+#([^}]*)\}/gu, "$1")
    .replace(/^#/u, "")
    .trim();
}

function firstParam(expr: string, params: number[]): number {
  const match = /\{param(\d+):([^}]+)\}/i.exec(expr);
  if (!match || !match[2].toUpperCase().endsWith("P")) return 0;
  return params[Number(match[1]) - 1] ?? 0;
}

function parseExpr(expr: string, params: number[]): Array<{ motion: number; basis: Basis }> {
  let basis: Basis = "ATK";
  if (/max hp/i.test(expr)) basis = "HP";
  else if (/elemental mastery/i.test(expr)) basis = "EM";
  else if (/\bdef\b/i.test(expr)) basis = "DEF";
  const text = expr.replace(/max hp|elemental mastery|\bdef\b|\batk\b/giu, "");
  const options = text.includes("/") ? text.split("/") : [text];
  let best: Array<{ motion: number; basis: Basis }> = [];
  let bestMotion = -1;
  for (const option of options) {
    const parts = option
      .split("+")
      .map((term) => term.trim())
      .filter(Boolean)
      .flatMap((term) => {
        const mult = /[*×]\s*(\d+(?:\.\d+)?)\s*$/u.exec(term);
        const count = mult ? Number(mult[1]) : 1;
        const core = mult ? term.slice(0, mult.index) : term;
        const motion = firstParam(core, params);
        return Array.from({ length: Number.isFinite(count) ? count : 1 }, () => ({ motion, basis }));
      });
    const total = parts.reduce((sum, part) => sum + part.motion, 0);
    if (total > bestMotion) {
      bestMotion = total;
      best = parts;
    }
  }
  return best.filter((part) => part.motion > 0);
}

function gaugeFor(id: string, talent: TalentKey, label: string): { units: number; icdTag: string | null; icdHits: number | null; icdSeconds: number | null } {
  const rows = gaugeTable(id)[talent] ?? [];
  const folded = label.toLowerCase();
  const found =
    rows.find((row) => row.name.toLowerCase() === folded) ??
    rows.find((row) => folded && (row.name.toLowerCase().includes(folded) || folded.includes(row.name.toLowerCase())));
  return {
    units: found?.units ?? 0,
    icdTag: found?.icdTag ?? null,
    icdHits: found?.icdHits ?? null,
    icdSeconds: found?.icdSeconds ?? null,
  };
}

export function triggersOf(effect: PassiveEffect): Array<{ kind: string; by?: string[]; reactions?: string[]; match?: string; atLeast?: number; percent?: number }> {
  if (!effect.trigger) return [];
  return Array.isArray(effect.trigger) ? effect.trigger : [effect.trigger];
}
