import { FPS, ROTATION_FRAMES, SWAP_FRAMES, tuningConstants } from "./catalog";
import { characterProfile, type CharacterProfile } from "./talent";

export type CastKind = "skill" | "burst" | "combo" | "charged";

export type RotationAction = {
  owner: string;
  kind: CastKind;
  start: number;
  frames: number;
};

export type Rotation = {
  actions: RotationAction[];
  onFieldId: string;
  attackFrames: number;
  busyFrames: number;
};

export function scheduleTeam(
  ids: string[],
  onFieldId: string,
  energyRecharge: Record<string, number>,
  clearParticles = 0,
  skillResets: Record<string, number> = {},
  flatEnergy: Record<string, number> = {},
): Rotation {
  const profiles = ids.map((id) => characterProfile(id));
  const naturalCasts = new Map(profiles.map((profile) => [profile.id, profile.maxSkillCasts]));
  const casts = new Map(
    profiles.map((profile) => [profile.id, profile.maxSkillCasts + (skillResets[profile.id] ?? 0)]),
  );
  const gained = energyGain(profiles, casts, onFieldId, clearParticles, flatEnergy);
  const bursts = new Set<string>();
  for (const profile of profiles) {
    const energy = (gained.get(profile.id) ?? 0) * (energyRecharge[profile.id] ?? 1);
    if (profile.burstCost > 0 && energy >= profile.burstCost) bursts.add(profile.id);
  }

  const desired: Array<{ owner: string; kind: "skill" | "burst"; at: number; reset?: boolean }> = [];
  for (const profile of profiles) {
    const count = naturalCasts.get(profile.id) ?? 0;
    const resets = skillResets[profile.id] ?? 0;
    for (let i = 0; i < count; i++) {
      const at = i * profile.skillCooldown * FPS;
      if (at < ROTATION_FRAMES) desired.push({ owner: profile.id, kind: "skill", at });
    }
    for (let i = 0; i < resets; i++) {
      const at = Math.max(0, count - 1) * profile.skillCooldown * FPS + FPS;
      if (at < ROTATION_FRAMES) desired.push({ owner: profile.id, kind: "skill", at, reset: true });
    }
    if (bursts.has(profile.id)) {
      const afterSkills = Math.max(0, (count - 1) * profile.skillCooldown * FPS);
      desired.push({ owner: profile.id, kind: "burst", at: afterSkills });
    }
  }
  desired.sort((a, b) => {
    if (a.at !== b.at) return a.at - b.at;
    const anemo = (id: string) => (characterProfile(id).element === "Anemo" ? 1 : 0);
    const elementOrder = anemo(a.owner) - anemo(b.owner);
    if (elementOrder !== 0) return elementOrder;
    return ids.indexOf(a.owner) - ids.indexOf(b.owner);
  });

  const actions: RotationAction[] = [];
  const lastSkill = new Map<string, number>();
  let cursor = 0;
  for (const item of desired) {
    const profile = profiles.find((row) => row.id === item.owner);
    if (!profile) continue;
    const castFrames = item.kind === "skill" ? profile.skillFrames : profile.burstFrames;
    const swap = item.owner === onFieldId ? 0 : SWAP_FRAMES * 2;
    const frames = Math.round(castFrames + swap);
    let start = Math.max(cursor, Math.round(item.at));
    if (item.kind === "skill" && !item.reset) {
      const previous = lastSkill.get(item.owner);
      if (previous != null) start = Math.max(start, previous + Math.round(profile.skillCooldown * FPS));
    }
    if (start + frames > ROTATION_FRAMES) continue;
    actions.push({ owner: item.owner, kind: item.kind, start, frames });
    if (item.kind === "skill") lastSkill.set(item.owner, start);
    cursor = start + frames;
  }

  const gaps = idleGaps(actions);
  const onField = profiles.find((row) => row.id === onFieldId) ?? profiles[0];
  let attackFrames = 0;
  if (onField) {
    for (const gap of gaps) {
      let time = gap.start;
      while (time < gap.end) {
        const loop = onField.loop === "charged" ? [onField.chargedFrames] : onField.comboFrames;
        const span = Math.max(1, Math.round(loop.reduce((sum, frame) => sum + frame, 0)));
        if (time + span > gap.end) break;
        actions.push({
          owner: onField.id,
          kind: onField.loop === "charged" ? "charged" : "combo",
          start: time,
          frames: span,
        });
        attackFrames += span;
        time += span;
      }
    }
  }
  actions.sort((a, b) => a.start - b.start);
  const busyFrames = actions.filter((action) => action.kind === "skill" || action.kind === "burst").reduce((sum, action) => sum + action.frames, 0);
  return { actions, onFieldId, attackFrames, busyFrames };
}

function energyGain(
  profiles: CharacterProfile[],
  casts: Map<string, number>,
  onFieldId: string,
  clearParticles: number,
  flatEnergy: Record<string, number>,
): Map<string, number> {
  const tuning = tuningConstants().energy;
  const gain = new Map(profiles.map((profile) => [profile.id, 0]));
  for (const profile of profiles) {
    const count = casts.get(profile.id) ?? 0;
    const particles = profile.particles * count;
    if (particles <= 0) continue;
    for (const receiver of profiles) {
      const each = profile.element === receiver.element ? tuning.sameElementParticle : tuning.otherElementParticle;
      let share = 1;
      if (profile.particlesToField) share = receiver.id === onFieldId ? 1 : tuning.offFieldShare;
      else if (receiver.id !== profile.id) share = tuning.offFieldShare;
      gain.set(receiver.id, (gain.get(receiver.id) ?? 0) + particles * each * share);
    }
  }
  for (const [id, amount] of Object.entries(flatEnergy)) {
    gain.set(id, (gain.get(id) ?? 0) + amount);
  }
  if (clearParticles > 0) {
    for (const receiver of profiles) {
      const share = receiver.id === onFieldId ? 1 : tuning.offFieldShare;
      gain.set(receiver.id, (gain.get(receiver.id) ?? 0) + clearParticles * tuning.clearParticle * share);
    }
  }
  return gain;
}

function idleGaps(actions: RotationAction[]): Array<{ start: number; end: number }> {
  const busy = actions.slice().sort((a, b) => a.start - b.start);
  const gaps: Array<{ start: number; end: number }> = [];
  let cursor = 0;
  for (const action of busy) {
    if (action.start > cursor) gaps.push({ start: cursor, end: action.start });
    cursor = Math.max(cursor, action.start + action.frames);
  }
  if (cursor < ROTATION_FRAMES) gaps.push({ start: cursor, end: ROTATION_FRAMES });
  return gaps;
}
