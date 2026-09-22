export type ReactionKind = "amplifying" | "transformative" | "catalyze";

export type GaugeEvent = {
  reaction?: string;
  kind?: ReactionKind;
  coefficient?: number;
  swirled?: string;
};

type Aura = { element: string; gauge: number; decay: number };

const AMP: Record<string, { reaction: string; coefficient: number; consume: number }> = {
  "pyro>cryo": { reaction: "melt", coefficient: 2, consume: 2 },
  "cryo>pyro": { reaction: "melt", coefficient: 1.5, consume: 0.5 },
  "hydro>pyro": { reaction: "vaporize", coefficient: 2, consume: 2 },
  "pyro>hydro": { reaction: "vaporize", coefficient: 1.5, consume: 0.5 },
};

const TRANSFORM: Record<string, { reaction: string; coefficient: number }> = {
  "pyro>electro": { reaction: "overload", coefficient: 2.75 },
  "electro>pyro": { reaction: "overload", coefficient: 2.75 },
  "cryo>electro": { reaction: "superconduct", coefficient: 1.5 },
  "electro>cryo": { reaction: "superconduct", coefficient: 1.5 },
  "pyro>dendro": { reaction: "burning", coefficient: 0.25 },
  "dendro>pyro": { reaction: "burning", coefficient: 0.25 },
};

const SWIRLABLE = new Set(["pyro", "hydro", "electro", "cryo"]);

export class Gauge {
  private auras: Aura[] = [];
  private time = 0;
  private quicken = 0;
  private quickenDecay = 0;
  private seeds: number[] = [];
  private bloomStamp = -1;
  private bloomCount = 0;

  apply(element: string, units: number, time: number): GaugeEvent {
    const name = element.toLowerCase();
    this.advance(time);
    if (units <= 0 || name === "physical" || name === "geo") return {};
    if (name === "anemo") return this.swirl(units);
    const aura = this.strongest();
    if (this.seeds.length > 0 && (name === "electro" || name === "pyro")) {
      this.seeds.shift();
      this.attach(name, units);
      return {
        reaction: name === "electro" ? "hyperbloom" : "burgeon",
        kind: "transformative",
        coefficient: name === "electro" ? 3 : 3,
      };
    }
    if (aura) {
      const amp = AMP[`${name}>${aura.element}`];
      if (amp) {
        aura.gauge -= units * amp.consume;
        if (aura.gauge <= 0) this.remove(aura.element);
        return { reaction: amp.reaction, kind: "amplifying", coefficient: amp.coefficient };
      }
      const transform = TRANSFORM[`${name}>${aura.element}`];
      if (transform) {
        aura.gauge -= units * 0.5;
        if (aura.gauge <= 0) this.remove(aura.element);
        this.attach(name, units * 0.5);
        return { reaction: transform.reaction, kind: "transformative", coefficient: transform.coefficient };
      }
      if ((name === "hydro" && aura.element === "electro") || (name === "electro" && aura.element === "hydro")) {
        this.attach(name, units);
        return { reaction: "electro-charged", kind: "transformative", coefficient: 2 };
      }
      if ((name === "dendro" && aura.element === "hydro") || (name === "hydro" && aura.element === "dendro")) {
        this.spawnSeed(time);
        aura.gauge -= units * 0.5;
        if (aura.gauge <= 0) this.remove(aura.element);
        return { reaction: "bloom", kind: "transformative", coefficient: 2 };
      }
      if ((name === "dendro" && aura.element === "electro") || (name === "electro" && aura.element === "dendro")) {
        this.refreshQuicken(units);
        return this.catalyze(name);
      }
    }
    if (this.quicken > 0 && (name === "electro" || name === "dendro")) {
      this.attach(name, units);
      return this.catalyze(name);
    }
    this.attach(name, units);
    return {};
  }

  private catalyze(element: string): GaugeEvent {
    return {
      reaction: element === "electro" ? "aggravate" : "spread",
      kind: "catalyze",
      coefficient: element === "electro" ? 1.15 : 1.25,
    };
  }

  private swirl(units: number): GaugeEvent {
    const aura = this.auras
      .filter((item) => SWIRLABLE.has(item.element))
      .sort((a, b) => b.gauge - a.gauge)[0];
    if (!aura) return {};
    aura.gauge -= units * 0.5;
    const swirled = aura.element;
    if (aura.gauge <= 0) this.remove(aura.element);
    return { reaction: "swirl", kind: "transformative", coefficient: 0.6, swirled };
  }

  private spawnSeed(time: number): void {
    if (time - this.bloomStamp > 0.5) {
      this.bloomStamp = time;
      this.bloomCount = 0;
    }
    if (this.bloomCount >= 2) return;
    this.bloomCount += 1;
    this.seeds.push(time);
  }

  private attach(element: string, units: number): void {
    const tax = units * 0.8;
    const duration = 2.5 * units + 7;
    const existing = this.auras.find((item) => item.element === element);
    if (existing) {
      if (tax >= existing.gauge) {
        existing.gauge = tax;
        existing.decay = tax / duration;
      }
      return;
    }
    this.auras.push({ element, gauge: tax, decay: tax / duration });
  }

  private refreshQuicken(units: number): void {
    const tax = units * 0.8;
    const duration = 2.5 * units + 7;
    this.quicken = Math.max(this.quicken, tax);
    this.quickenDecay = this.quicken / duration;
  }

  private strongest(): Aura | undefined {
    return this.auras.slice().sort((a, b) => b.gauge - a.gauge)[0];
  }

  private remove(element: string): void {
    this.auras = this.auras.filter((item) => item.element !== element);
  }

  private advance(time: number): void {
    const dt = Math.max(0, time - this.time);
    this.time = time;
    if (dt === 0) return;
    for (const aura of this.auras) aura.gauge -= aura.decay * dt;
    this.auras = this.auras.filter((aura) => aura.gauge > 1e-4);
    this.quicken -= this.quickenDecay * dt;
    if (this.quicken <= 0) this.quicken = 0;
    this.seeds = this.seeds.filter((born) => time - born < 6);
  }
}

export function icdReady(
  state: Map<string, { hits: number; last: number }>,
  key: string,
  time: number,
  icdHits: number | null,
  icdSeconds: number | null,
): boolean {
  if (icdHits == null && icdSeconds == null) return true;
  const slot = state.get(key) ?? { hits: 0, last: Number.NEGATIVE_INFINITY };
  if (!Number.isFinite(slot.last)) {
    state.set(key, { hits: 0, last: time });
    return true;
  }
  const elapsed = time - slot.last;
  const hitsReady = icdHits != null && slot.hits + 1 >= icdHits;
  const timeReady = icdSeconds != null && icdSeconds > 0 && elapsed >= icdSeconds;
  if (hitsReady || timeReady) {
    state.set(key, { hits: 0, last: time });
    return true;
  }
  slot.hits += 1;
  state.set(key, slot);
  return false;
}
