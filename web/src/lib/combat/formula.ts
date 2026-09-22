/** Damage identities from damage-formula.json. Pure functions, no characters. */

export function resMultiplier(res: number): number {
  if (res < 0) return 1 - res / 2;
  if (res < 0.75) return 1 - res;
  return 1 / (4 * res + 1);
}

export function defMultiplier(
  characterLevel: number,
  enemyLevel: number,
  defReduction = 0,
  defIgnore = 0,
): number {
  const k = (1 - defReduction) * (1 - defIgnore);
  const attacker = characterLevel + 100;
  return attacker / (k * (enemyLevel + 100) + attacker);
}

export function critHitMultiplier(critDmg: number): number {
  return 1 + critDmg;
}

export function expectedCrit(critRate: number, critDmg: number): number {
  const rate = Math.min(1, Math.max(0, critRate));
  return 1 + rate * critDmg;
}

export function amplifyingEmBonus(em: number): number {
  return (2.78 * em) / (em + 1400);
}

export function amplifyingMultiplier(coefficient: number, em: number, reactionBonus = 0): number {
  return coefficient * (1 + amplifyingEmBonus(em) + reactionBonus);
}

export function catalyzeEmBonus(em: number): number {
  return (5 * em) / (em + 1200);
}

export function transformativeEmBonus(em: number): number {
  return (16 * em) / (em + 2000);
}

export function lunarEmBonus(em: number): number {
  return (6 * em) / (em + 2000);
}

/** Character level-90 transformative/catalyze base from damage-formula.json. */
export const LEVEL_90_MULTIPLIER = 1446.853458;

export function catalyzeBonus(coefficient: number, em: number, reactionBonus = 0): number {
  return coefficient * LEVEL_90_MULTIPLIER * (1 + catalyzeEmBonus(em) + reactionBonus);
}

export function transformativeDamage(options: {
  coefficient: number;
  em: number;
  res: number;
  reactionBonus?: number;
  additive?: number;
  crit?: number;
}): number {
  const emTerm = 1 + transformativeEmBonus(options.em) + (options.reactionBonus ?? 0);
  const base = options.coefficient * LEVEL_90_MULTIPLIER * emTerm + (options.additive ?? 0);
  return base * resMultiplier(options.res) * (options.crit ?? 1);
}

const INDIRECT_WEIGHTS = [0.6, 0.3, 0.05, 0.05];

/** Lunar/Stellar indirect: keep the weights of whoever is present, drop the missing shares. */
export function aggregateIndirect(personal: number[]): number {
  const ranked = personal.filter((value) => value > 0).sort((a, b) => b - a);
  let total = 0;
  const n = Math.min(4, ranked.length);
  for (let i = 0; i < n; i++) total += ranked[i] * INDIRECT_WEIGHTS[i];
  return total;
}

export function directHit(options: {
  motion: number;
  stat: number;
  dmgBonus: number;
  critRate: number;
  critDmg: number;
  characterLevel: number;
  enemyLevel: number;
  res: number;
  defReduction?: number;
  additive?: number;
  amplifying?: { coefficient: number; em: number; reactionBonus?: number };
  guaranteedCrit?: boolean;
}): number {
  const base = options.motion * options.stat + (options.additive ?? 0);
  const crit = options.guaranteedCrit
    ? critHitMultiplier(options.critDmg)
    : expectedCrit(options.critRate, options.critDmg);
  const def = defMultiplier(options.characterLevel, options.enemyLevel, options.defReduction ?? 0);
  const amp = options.amplifying
    ? amplifyingMultiplier(
        options.amplifying.coefficient,
        options.amplifying.em,
        options.amplifying.reactionBonus ?? 0,
      )
    : 1;
  return base * (1 + options.dmgBonus) * crit * def * resMultiplier(options.res) * amp;
}
