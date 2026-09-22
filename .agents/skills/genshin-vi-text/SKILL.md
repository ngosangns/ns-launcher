---
name: genshin-vi-text
description: Fetch official Vietnamese Genshin Impact text (character names, weapon/artifact names, quest titles, act names, blessing text, monster names) from gi.yatta.moe — the game's own localisation, not fan translation. Use whenever adding or updating Vietnamese names/prose anywhere in web content or web data (Resources/Abyss, Resources/Story, web/src), writing sync scripts, or when the user asks for tên tiếng Việt, bản dịch chuẩn, or official VI text. Never hand-translate game terms when this source exists.
---

# Vietnamese game text from Yatta

Genshin ships an official Vietnamese localisation. `gi.yatta.moe/api/v2/vi` serves it straight from the game files — this is the repo's canonical source for VI names and prose. Hand-translating produces names that don't match what players see in-game.

**Rule: never self-translate game text in either direction.** VI fields come from this API or TextMapVI; EN fields come from the sources in the `genshin-en-text` skill. Authored prose may be written in either language, but game terms inside it must match the official text.

## API

Base: `https://gi.yatta.moe/api/v2/vi` (also `/en`, and other langs).

| Endpoint | Contents |
|---|---|
| `avatar` / `avatar/{id}` | Characters: `name`, `element`, `weaponType`, `region`, talents, constellations |
| `weapon` / `weapon/{id}` | Weapons: `name`, `type`, `rank`, passive text |
| `reliquary` | Artifact sets + pieces: `name`, `affixList` |
| `monster` / `monster/{id}` | Monsters: `name`, `type`, resistances |
| `material` | Materials: `name`, `type` |
| `quest` / `quest/{id}` | Quests: `type` (`aq` archon, `lq` story/legend, `wq` world, `eq` event, `iq` tutorial-ish), `chapterNum` (e.g. `"Chương 1 Màn 2"`, `"Chương Tiểu Thố - Màn 1"`), `chapterTitle` (VI act title), `chapterImageTitle` (VI character/region name), `route` (EN act title — the join key to English sources) |
| `food`, `furniture`, `namecard`, `achievement` | Also available |

List responses: `{response, data: {items: {<id>: {...}}}}`. Detail responses: `{response, data: {...}}`.

**Fetch with curl + a User-Agent** — plain `urllib` gets 403:

```python
subprocess.run(["curl", "-sS", "--max-time", "60",
    "-A", "ns-launcher/vi-text (github.com/ngosangns/ns-launcher)", url], ...)
```

## Conventions in this repo

- Field naming: VI variants are `nameVI`, `descriptionVI`, etc., alongside the EN field.
- Join EN↔VI through `route` (EN title) or numeric `id` — never by fuzzy name matching.
- `chapterNum` carries both chapter and act: strip the trailing `Màn N` / `Mở Đầu` / `Phần Đệm` / `Giới Thiệu` token for the chapter name; the token itself is the act label.
- Story-quest `chapterImageTitle` is the VI character name; for tribal chronicles it's the VI tribe name (quoted, e.g. `"Cư Dân Suối Nước"`).
- Hangout events are NOT in the quest API — no official VI source exists for them here.
- Traveler variants have no Yatta avatar entry.

## Existing sync scripts (follow their shape for new ones)

- `scripts/sync-abyss-vi-text.py` — character/weapon/monster VI names + prose into `Resources/Abyss/`.
- `scripts/sync-abyss-artifact-text.py` — artifact set names en+vi.
- `scripts/sync-story-vi-text.py` — quest/act headings in `Resources/Story/quests/` (archon `Màn N — <VI>`, story `Chương <VI> — <char>`).

New sync scripts should: fetch via curl with the UA above, match records by id/route, write only the fields the source owns, print unmatched entries instead of guessing, and be idempotent.
