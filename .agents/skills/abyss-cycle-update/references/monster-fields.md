# Monster object fields

Each entry in `floors[].chambers[].waves[].monsters` is a single-line JSON object.
The sync scripts patch by line — `"name"` through `"hpRatio"` must be on one line.

## Fields you write by hand

| Field | Type | Notes |
|---|---|---|
| `name` | string | Exact game/wiki name (e.g. `"Battle-Hardened Chimeric Burrowbeast"`). The sync scripts resolve by this — spelling matters. |
| `count` | string | Prose count, e.g. `"1"`, `"2→10 (hồi thêm)"`, `"1 (boss)"`. The real spawn count is re-derived from the wiki by the HP sync into `spawns`. |
| `size` | string | e.g. `"Vừa"`, `"Vừa/Lớn (Elite)"`, `"Lớn (máy Fatui)"`. |
| `elements` | string[] | Elements the monster attacks/shields with, e.g. `["Electro"]`, `["Anemo","Cryo"]`. |
| `resistanceNotes` | string \| null | Wiki resistance note when unusual, e.g. `"kháng Anemo +20%"`. `null` when none — real numbers come from the sync. |
| `weakpoint` | bool \| null | Has a weakpoint for aimed shots. |
| `mechanics` | string \| null | Special mechanic worth knowing, e.g. paralyze conditions. |
| `hpRatio` | string \| null | Optional prose note, e.g. `"hp_ratio 7, atk_ratio 6 — rất trâu"`. The structured value is written by the HP sync. |

## Fields the sync scripts write (leave absent or null)

| Field | Written by |
|---|---|
| `gameId` | resistance sync (Yatta monster id) |
| `resistances` | resistance sync — all 7 elements, real values |
| `physicalResistance` | resistance sync |
| `nameVI` | resistance sync (official VI name) |
| `spawns` | HP sync (from wiki `Domain Enemies` count) |
| `hp` | HP sync — `{page, variant, ratio, type}` |

## One-line example


```json
{"name": "Battle-Hardened Chimeric Burrowbeast", "count": "1", "size": "Vừa/Lớn (Elite)", "elements": ["Electro"], "resistanceNotes": null, "weakpoint": null, "mechanics": null, "hpRatio": null}
```

After `sync` the same line becomes:

```json
{"name": "Battle-Hardened Chimeric Burrowbeast", "count": "1", "size": "Vừa/Lớn (Elite)", "elements": ["Electro"], "resistanceNotes": null, "weakpoint": null, "mechanics": null, "hpRatio": null, "gameId": 26120101, "resistances": {...}, "physicalResistance": 0.1, "spawns": 1, "hp": {"page": "Chimeric Burrowbeast", "variant": "Battle-Hardened", "ratio": 17.48, "type": "2"}, "nameVI": "..."}
```


## Floor-level fields

- `enemyHPMultiplier` — copied from the previous cycle by `new`; the HP sync refreshes it from the wiki ("Floor 12: HP 250% vs open world").
- `leyLineDisorder` — per floor; write both halves when they differ (`"Nửa 1: … Nửa 2: …"`).
- `recommendation` — team-direction prose (elements/roles to bring), not specific teams.

## Bilingual fields

Every hand-written VI field has an `*EN` twin written on the same line: `countEN`, `sizeEN`, `resistanceNotesEN`, `mechanicsEN`. Floor level: `leyLineDisorderEN` (use `Half 1: ... Half 2: ...`), `recommendationEN`. Blessing level: `descriptionEN`, `relatedMechanicEN`. The web falls back to the VI field when EN is absent — write both for new cycles.
