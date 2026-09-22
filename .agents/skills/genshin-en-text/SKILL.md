---
name: genshin-en-text
description: Fetch official English Genshin Impact text from authoritative sources — never hand-translate between Vietnamese and English. Use whenever adding or updating English names/prose in web content or web data (Resources/Abyss, Resources/Story, web/src), writing sync scripts, or when the user asks for bản tiếng Anh chuẩn, official EN text, or flags a translation as unofficial. Pairs with genshin-vi-text.
---

# English game text — authoritative sources only

**Rule: never self-translate game text in either direction.** VI→EN and EN→VI hand translations drift from what players see in-game. Every game term, quest name, blessing description, and Ley Line Disorder must come from an authoritative source. Authored prose (recommendations, summaries, analysis) may be written in either language, but every game term inside it must match the official text.

## Source hierarchy

1. **Game files via Yatta** — `https://gi.yatta.moe/api/v2/en` (same API as the VI skill, `en` locale). Characters, weapons, artifacts, monsters, quests: `name`, `chapterTitle`, `route`, etc. Fetch with curl + a User-Agent; plain urllib gets 403.
2. **Fandom wiki wikitext** — `https://genshin-impact.fandom.com/api.php?action=parse&page=<page>&prop=wikitext&format=json`. Carries official EN text the Yatta API doesn't expose:
   - Blessing of the Abyssal Moon: `Spiral Abyss/Blessing of the Abyssal Moon/<periodStart>` → `{{Blessing of the Abyssal Moon|details=...}}` (strip `{{Color|bp|...}}` markup).
   - Ley Line Disorder floors 11–12: `Spiral Abyss/Floors/<periodStart>` → `* '''Ley Line Disorder'''` bullets (`{{Color|menu|First Half}}` → `Half 1:`).
   - Monster names/counts: `Domain Enemies` template on the same page.
3. **Yatta `tower` endpoint** — `/api/v2/en/tower` covers floors 1–8 only (LLD `description` fields). Does NOT carry the current cycle's floors 9–12.

## Known gaps

- **Floors 9–10 Ley Line Disorder EN**: not published on the wiki's per-cycle page and absent from Yatta `tower`. No authoritative online source found — if needed, extract from game TextMap (`TowerFloorExcelConfigData`/`levelConfigName` → TextMapEN hash) or leave a marked unofficial translation.
- **Hangout events**: no Yatta quest entries (same gap as VI).
- **Traveler variants**: no Yatta avatar entry.

## Conventions in this repo

- EN fields are the `*EN` twins of VI fields (`descriptionEN`, `leyLineDisorderEN`, `countEN`, `sizeEN`, `mechanicsEN`, `resistanceNotesEN`, `summaryEN`, `displayNameEN`, `aliasesEN`, `homeHeadingEN`). See `abyss-cycle-update` skill.
- `leyLineDisorderEN` uses `Half 1: ... Half 2: ...` (the web's `splitDisorder` accepts both `Nửa` and `Half`).
- Join EN↔VI records by `id`/`route`/exact name — never by fuzzy matching.
- EN story markdown lives in `chapters/en/` and `quests/en/` mirroring the VI files; quest/act headings come from official EN names (Yatta `route`, wiki), not translation of the VI headings.
- When a field has no authoritative source, prefer leaving it absent (UI falls back) over inventing a translation; if a translation must ship, mark it clearly as unofficial in the commit/PR.

## Existing sync scripts

- `scripts/sync-abyss-vi-text.py`, `sync-abyss-artifact-text.py`, `sync-story-vi-text.py` — VI side; mirror their shape for EN syncs (curl + UA, match by id/route, print unmatched, idempotent).
- `scripts/sync-abyss-monster-hp.py` — already fetches wiki wikitext (`wikitext()` helper, `WIKI` constant); reuse its fetch pattern for EN text.
