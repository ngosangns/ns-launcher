export type OwnedCharacter = { id: string; constellation: number };
export type OwnedWeapon = { id: string; refinement: number };
export type Roster = { characters: OwnedCharacter[]; weapons: OwnedWeapon[] };

export const emptyRoster = (): Roster => ({ characters: [], weapons: [] });

const KEY = "ns-teyvat-roster";

export function loadRoster(): Roster {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return emptyRoster();
    return parseRoster(JSON.parse(raw));
  } catch {
    return emptyRoster();
  }
}

export function saveRoster(roster: Roster): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(roster));
  } catch {
    /* private mode */
  }
}

export function parseRoster(raw: unknown): Roster {
  if (!raw || typeof raw !== "object") return emptyRoster();
  const data = raw as { characters?: unknown; weapons?: unknown };
  const characters = Array.isArray(data.characters)
    ? data.characters.flatMap((item) => {
        if (!item || typeof item !== "object") return [];
        const row = item as { id?: unknown; constellation?: unknown };
        if (typeof row.id !== "string") return [];
        const constellation = clamp(Number(row.constellation ?? 0), 0, 6);
        return [{ id: row.id, constellation }];
      })
    : [];
  const weapons = Array.isArray(data.weapons)
    ? data.weapons.flatMap((item) => {
        if (!item || typeof item !== "object") return [];
        const row = item as { id?: unknown; refinement?: unknown };
        if (typeof row.id !== "string") return [];
        return [{ id: row.id, refinement: clamp(Number(row.refinement ?? 1), 1, 5) }];
      })
    : [];
  return { characters, weapons };
}

export function exportRoster(roster: Roster): string {
  return JSON.stringify(
    {
      characters: roster.characters,
      weapons: roster.weapons,
    },
    null,
    2,
  );
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(max, Math.max(min, Math.round(value)));
}

export function toggleCharacter(roster: Roster, id: string): Roster {
  if (roster.characters.some((item) => item.id === id)) {
    return { ...roster, characters: roster.characters.filter((item) => item.id !== id) };
  }
  return { ...roster, characters: [...roster.characters, { id, constellation: 0 }] };
}

export function toggleWeapon(roster: Roster, id: string): Roster {
  if (roster.weapons.some((item) => item.id === id)) {
    return { ...roster, weapons: roster.weapons.filter((item) => item.id !== id) };
  }
  return { ...roster, weapons: [...roster.weapons, { id, refinement: 1 }] };
}

export function setConstellation(roster: Roster, id: string, constellation: number): Roster {
  return {
    ...roster,
    characters: roster.characters.map((item) =>
      item.id === id ? { ...item, constellation: clamp(constellation, 0, 6) } : item,
    ),
  };
}

export function setRefinement(roster: Roster, id: string, refinement: number): Roster {
  return {
    ...roster,
    weapons: roster.weapons.map((item) =>
      item.id === id ? { ...item, refinement: clamp(refinement, 1, 5) } : item,
    ),
  };
}

export function mergeImported(
  roster: Roster,
  extra: { characters: Array<{ id: string; constellation?: number }>; weapons: Array<{ id: string; refinement?: number }> },
): Roster {
  const characters = [...roster.characters];
  for (const item of extra.characters) {
    if (!characters.some((owned) => owned.id === item.id)) {
      characters.push({ id: item.id, constellation: clamp(item.constellation ?? 0, 0, 6) });
    }
  }
  const weapons = [...roster.weapons];
  for (const item of extra.weapons) {
    if (!weapons.some((owned) => owned.id === item.id)) {
      weapons.push({ id: item.id, refinement: clamp(item.refinement ?? 1, 1, 5) });
    }
  }
  return { characters, weapons };
}
