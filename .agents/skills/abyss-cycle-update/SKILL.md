---
name: abyss-cycle-update
description: Update the Spiral Abyss (La Hoàn / Trầm Thủy) cycle data in this repo when a new cycle starts (reset on the 16th of each month) or when the user asks to add/refresh abyss monsters, the Blessing of the Abyssal Moon (Uyên Nguyệt Chúc Phúc), or Ley Line Disorder. Covers the full new → fill → sync → publish → deploy flow. Use whenever the user mentions a new abyss cycle, new floor 12 lineup, new blessing, or asks to update abyss data — even if they don't name the script.
---

# Abyss cycle update

The cycle data lives in `Sources/NSLauncherApp/Resources/Abyss/abyss-monsters/<start>-den-<end>.json` and expires monthly (reset on the 16th). `scripts/update-abyss-cycle.py` standardizes everything mechanical; the only genuinely manual step is transcribing the new cycle's monsters and blessing text.

## Flow

```bash
python3 scripts/update-abyss-cycle.py new       # scaffold next cycle
# ... fill in monsters / blessing / Ley Line Disorder by hand ...
python3 scripts/update-abyss-cycle.py sync      # resistance + HP + schema + npm test
python3 scripts/update-abyss-cycle.py publish   # copy into abyss-monsters/
task web:deploy                                 # ship to teyvat.gnas.dev
```

### 1. `new`

Computes the next period from the newest bundled cycle (16th → 15th of next month; monthly since 2025-09) and writes two files:

- `~/Library/Application Support/NSLauncher/abyss-cycles/<range>.json` — schema-shaped draft with every monster list emptied and per-cycle text set to `"TODO"`. This directory is **not** served by the site, so a half-filled cycle stays off the web until `publish`.
- `toi-uu-doi-hinh/quai-vat-la-hoan/<range>.md` — human-readable stub with a TODO checklist.

Both refuse to overwrite existing files. Pass `--start/--end` only if the computed period is wrong.

### 2. Fill the draft (manual)

Edit the JSON in the override directory. Required before `sync`:

- `blessingOfTheAbyssalMoon`: `name`, `nameVI`, `description` — from `TowerScheduleExcelConfigData`/`TextMap{EN,VI}` or the wiki. Do not self-translate; use the game's own VI text.
- `floors[].leyLineDisorder` — per floor (and per half if they differ).
- `floors[].chambers[].waves[].monsters` — one object per monster. `name` must match the game/wiki name exactly — the sync scripts resolve monsters **by name**.
- `floors[].recommendation` — team-direction note per floor.
- `gameVersion` if the version changed.

**Critical: keep each monster object on ONE line.** `sync-abyss-monster-resistance.py` and `sync-abyss-monster-hp.py` patch the file by line, anchored on a regex expecting `"name"` through `"hpRatio"` on a single line. A pretty-printed monster object makes both scripts silently write nothing. See `references/monster-fields.md` for the exact field list and a one-line example.

### 3. `sync`

Runs in order, stopping at first failure:

1. `sync-abyss-monster-resistance.py` — writes `gameId`, `resistances` (all 7 elements), `physicalResistance`, `nameVI` per monster from gi.yatta.moe. Unresolvable names are printed, never guessed — add an alias in that script or fix the name.
2. `sync-abyss-monster-hp.py` — writes `spawns`, `hp` (wiki `Enemy Stats` ratio/type), floor `enemyHPMultiplier`, and refreshes `enemy-hp.json`. Refuses on ambiguous variants or >1% Yatta disagreement.
3. JSON Schema validation (`toi-uu-doi-hinh/data-model/schema/abyss-cycle.schema.json`).
4. `npm test` in `web/` — regression check on published data only; it does not see the override file.
- Bilingual: every hand-written VI text field has an `*EN` twin (`descriptionEN`, `leyLineDisorderEN` — use `Half 1: ... Half 2: ...`, `recommendationEN`, `countEN`, `sizeEN`, `mechanicsEN`, `resistanceNotesEN`). Write both when filling a cycle; the web falls back to VI when EN is absent. Game text must come from official sources — blessing/LLD EN from the wiki (`genshin-en-text` skill), VI from Yatta (`genshin-vi-text` skill); never self-translate.

Needs network (gi.yatta.moe + Fandom wiki).

### 4. `publish`

Copies the finished file into `Resources/Abyss/abyss-monsters/` — the step that ships it. Refuses to overwrite. After this, `npm test` sees the new cycle.

### 5. Deploy

`task web:deploy` (needs `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ZONE_ID`). Then commit + push `main` per repo rules.

## Sources

- Monster names/counts/waves: Fandom `Spiral Abyss/Floors/<periodStart>` (`Domain Enemies` template, `Name*count`, sub-waves split by `//`).
- Blessing + Ley Line Disorder text: game TextMap via Yatta (`gi.yatta.moe/api/v2/vi`) — never hand-translate.
- Resistances/HP: fetched by the sync scripts; do not fill by hand.
- Vietnamese text conventions: see the `genshin-vi-text` skill if present.

## Notes

- A monster the resistance script can't resolve is left untouched and printed — check the output, don't assume silence means success.
- `hpRatio`/`resistanceNotes`/`mechanics`/`weakpoint` are optional prose fields; `null` is fine when unknown.
- The `.md` doc file is for humans; keep it in sync with the JSON when filling.
