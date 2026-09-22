import type { PlannerOutput } from "./planner";
import type { Roster } from "./roster";

const KEY = "ns-teyvat-plans";

export type PlansInput = {
  roster: Roster;
  fullCharacters: boolean;
  fullWeapons: boolean;
  cycleId: string;
  lang?: "vi" | "en";
};

export function plansInputKey(input: PlansInput): string {
  return JSON.stringify(input);
}

export function loadPlans(): { input: string; output: PlannerOutput } | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const data = JSON.parse(raw) as { input?: unknown; output?: unknown };
    const output = data.output as PlannerOutput | undefined;
    if (typeof data.input !== "string" || !output || !Array.isArray(output.plans)) return null;
    return { input: data.input, output };
  } catch {
    return null;
  }
}

export function savePlans(input: string, output: PlannerOutput): void {
  try {
    localStorage.setItem(KEY, JSON.stringify({ input, output }));
  } catch {
    /* private mode */
  }
}
