# Quest System Overview

*Updated through Version 7.0 ("Everwinter Without Mercy", released 08/12/2026).*

Genshin Impact does not have a single quest line. Instead, the game splits
its content into several quest types with different roles: one main
storyline following the Traveler's search for their sibling, side branches
that dig deeper into individual characters, and countless errands tied to
each region. This document describes that framework — how quests are
tiered, how they unlock, their rewards, and the current scale — as the
foundation for the detailed listing files in the same directory.

## The hierarchy: Chapter → Act → Quest

The three quest types with long storylines (Archon Quests, Story Quests,
and part of the World Quests) all share the same three-tier structure:

- **Chapter** — the largest unit. For Archon Quests, each chapter
  corresponds to a nation or a standalone storyline. For Story Quests,
  each chapter corresponds to one character and is named after that
  character's constellation, e.g. Xiao's *Alatus Chapter*.
- **Act** — the unlockable unit. Each Act has its own requirements and is
  usually what the player sees in the quest menu. It is also the unit the
  game uses to mark progress.
- **Quest** — the individual steps inside an Act, played back to back.
  For example, Act I of the Prologue contains 11 sub-quests.

For Hangout Events, the "Chapter" is the character's name; for Tribal
Chronicles it is the tribe's name.

## Summary table of quest types

| Type | Role | Voiced | Unlocked by | Hallmarks |
|---|---|---|---|---|
| Archon Quest | Main storyline | Yes | Adventure Rank + previous Act | Split into Chapters/Acts; drives overall game progress |
| Story Quest | Per-character story | Yes | AR + Archon Quest + other quests | Lets you trial the character; some chapters gate Archon Quests and Weekly Bosses |
| Hangout Event | Branching dialogue with multiple endings | Yes | 2 Story Keys per Act | Replayable, has a Heartbeat meter, multiple endings |
| Tribal Chronicles | Story Quests of Natlan's tribes | Yes | AR 40 + Natlan Archon Quest | Costs no Story Keys; tied to Tribe Reputation |
| World Quest | Stories of regions and NPCs | Mostly no | Map exploration, talking to NPCs, AR, Archon Quests | Largest in number; many Series carry heavy lore |
| Event Quest | Time-limited event content | Varies | Event window | Mostly World Quests; flagship events include Story Quests |
| Commission | Daily quests | No | AR 12 + *Every Day a New Adventure* | 4 quests/day, the main source of Story Keys |
| Reputation Request | Regional reputation errands | No | AR 25 + the region's Reputation-unlocking quest | Claimed weekly from reputation NPCs |
| Random Event | Random open-world events | No | Walking past a spawn point | Despawns if you stray too far; rewards capped at 10/day |
| Ascension Quest | World Level gate | Yes | AR milestones 25/35/45/50 | Required to raise World Level |

## Each quest type

### Archon Quest

The main storyline. The Traveler and Paimon journey through each nation to
meet The Seven, following the trail of the lost sibling. All of it is
voiced, and enemy difficulty plus the level of trial characters (up to 90)
scales with the current World Level.

Unlock requirements are always an Adventure Rank milestone plus the
immediately preceding Act. Some Acts also require completing another
character's Story Quest — for example, Act IV of Chapter I needs Act I of
Razor's *Lupus Minor Chapter*. Full details are in `01-archon-quests.md`.

### Story Quest

Standalone stories for each playable character. Most let you trial the
character for the duration of the quest; if that character is already in
your party, the party copy is temporarily replaced by the trial version.

Since Version 5.4, character Story Quests **no longer cost Story Keys**.
A few chapters are mandatory prerequisites for continuing Archon Quests,
and a few others unlock Weekly Bosses.

Story Quests for Natlan characters are presented as Tribal Chronicles.
Story Quests for Nod-Krai characters released between Version 6.0 and 6.3
were folded directly into the *Song of the Welkin Moon* Archon Quest
chapter instead of being split out separately.

### Hangout Event

Also called Invitation Quests. These are branching Story Quests: dialogue
choices lead to different endings, and each quest has a Heartbeat value —
wrong answers drain it, and emptying it fails the quest. Branch points are
saved as checkpoints so players can return and unlock the remaining
endings.

Each Act costs **2 Story Keys**; replaying the same Act costs nothing
extra. Rewards scale with the number of endings unlocked and include
Primogems, Adventure EXP, Hero's Wit, upgrade materials, and the
character's specialty dish. Hangouts also award achievements in the
*Memories of the Heart* group.

### Tribal Chronicles

Also called Tribe Reputation Quests — Natlan's own flavor of Story Quest,
where each chapter revolves around a tribe rather than a single
character. They cost no Story Keys. The shared requirement is AR 40 plus
the corresponding Natlan Archon Quest progress.

### World Quest

The most numerous type. Some quests start automatically once conditions
are met (usually after an Archon Quest); others must be found by locating
an NPC or an object in the open world — such NPCs show a World Quest icon
when the player gets close.

**World Quest Series** are chains of consecutive World Quests, displayed
in the menu like Acts of Archon/Story Quests and always marked on the map.
This is where most of the heavy regional lore outside the main storyline
lives.

World Quests also have sub-branches:

- **Random Event** — random open-world events (see below).
- **Reputation Request** — errands that earn regional reputation points.
- **Ascension Quest** — World Level gates.
- **Crimson Wish** — a Dragonspine-exclusive chain, unlocked at level 8 of
  Frostbearing Tree's Gratitude and gone once the tree reaches level 12.
- **Intel Quest** — a Nod-Krai exclusive type.

World Quests that belong to events, or that unlock major features
(Serenitea Pot, Imaginarium Theater, the Reputation system), are marked
with a blue tag in the quest journal.

### Commission

Daily quests. At each reset, the player receives 4 commissions: 0–1 from
the **NPC Commission** group (with their own stories and requirements) and
3–4 from the basic group. Unfinished commissions expire at the end of the
day; they do not roll over.

Unlocked at AR 12 after completing *Every Day a New Adventure*. Initially
only Mondstadt commissions exist; other regions unlock gradually with
Archon Quest progress plus an accompanying World Quest (for example,
Inazuma requires *Ritou Escape Plan* and *Katheryne in Inazuma*; Snezhnaya
requires reaching the "Go to Zapolyarny" step in *Great Deeds on the
Tundra*). A preferred region can be set in the Adventurer Handbook,
applying from the next reset onward.

Only 4 commissions grant rewards per day, even when doing them for others
in Co-Op. Commissions are the sole source of Story Keys.

### Event Quest

Time-limited quests inside Events. Most are World Quests, but major
Flagship Events usually include their own Story Quests. Since Version
3.2, event Story Quests no longer require finishing the character's Story
Quest first — the game only recommends it to avoid spoilers. Some event
chapters are kept permanently and can be accessed from the quest menu.

### Random Event

Encountered at random while roaming. Stray too far or fail to interact in
time and the event disappears. Spawns can be forced by quitting the game
near a spawn point and logging back in. After 50 events within one reset
cycle no more spawn, and rewards only count for the first 10 each day
(Companionship EXP, Mora, enhancement ore). Random Events **do not occur**
in Fontaine, Natlan, or Nod-Krai.

### Reputation Request

Errands tied to each nation's Reputation system. Unlocking Reputation
requires AR 25 plus one Archon Quest and one World Quest of that region —
for example, Mondstadt needs *The Outlander Who Caught the Wind* and
*Knight of the Realm*; Fontaine needs *As Light Rain Falls Without Reason*
and *Steambird Interview*. Natlan skips the opening World Quest in favor
of the Tribe Reputation system. Reputation rewards include cooking
recipes, forging/crafting blueprints, namecards, and wind gliders.

### Ascension Quest

Five gate quests: *Adventure Rank Ascension 1–4* (at AR 25, 35, 45, 50)
and *World Level Ascension* (to World Level 9). If left undone, Adventure
EXP still accumulates but Adventure Rank stays frozen until they are
completed.

## Story Keys and unlock requirements

**Story Keys** are quest-unlocking items, earned from AR 26 onward: every
8 completed commissions (i.e. 2 days × 4 commissions) grants 1 key. Keys
do not go into the inventory automatically — they must be claimed in the
Story Quest screen. At most 3 keys can be held at once, but the counter
still runs up to 8, so spending one key lets you claim a new one
immediately.

Currently only **Hangout Events** still cost Story Keys (2 per Act).
Character Story Quests dropped the requirement in Version 5.4, and Tribal
Chronicles never needed them.

The remaining unlock requirements are usually a combination of: an
Adventure Rank milestone, completing the previous Act in the same
chapter, completing a specific Archon Quest Act, or completing another
character's Story Quest.

One secondary mechanic worth noting: if an NPC or a location is currently
"occupied" by another quest, the player cannot start a new quest that
needs that same NPC or location. The quest menu will indicate which quest
must be cleared first.

## Signature rewards

| Type | Main rewards |
|---|---|
| Archon Quest | Primogems, Adventure EXP, Mora, Hero's Wit, talent books, enhancement ore; regional Reputation |
| Story Quest | Primogems, Adventure EXP, upgrade materials; Weekly Boss unlocks (some chapters) |
| Hangout Event | Primogems, Adventure EXP, Hero's Wit, talent/ascension materials, the character's specialty dish, *Memories of the Heart* achievements |
| Tribal Chronicles | Natlan Tribe Reputation, plus regular Story Quest rewards |
| World Quest | Primogems, Mora, Adventure EXP, materials; many quests unlock features or areas |
| Commission | Primogems, Adventure EXP, Mora, Companionship EXP, enhancement ore; accumulates into Story Keys |
| Reputation Request | Reputation points, leading to recipes, blueprints, namecards, wind gliders |
| Random Event | Companionship EXP, Mora, enhancement ore (max 10/day) |
| Ascension Quest | Raises World Level, opens high-level content |

## Overall figures (through Version 7.0)

The figures below count pages in the corresponding wiki categories, so
they are approximate measures of scale, not official in-game numbers.

| Category | Count |
|---|---|
| Total quest pages (all types) | ~2,547 |
| Archon Quest — chapters | 11 (Prologue, I–V, *Song of the Welkin Moon*, VII, Chapter ??, Epilogue, Interlude Chapter) |
| Archon Quest — Acts | 48 |
| Archon Quest — sub-quests | 224 |
| Story Quest — character chapters | 53 |
| Hangout Event — chapters | 18 |
| Tribal Chronicles — chapters | 6 |
| Story Quest — total quests | ~570 |
| World Quest — total quests | ~1,376 |
| World Quest Series | 73 |
| Commissions | 248 (of which 186 are NPC Commissions) |
| Event Quests | ~639 |
| Reputation Requests | 57 |
| Random Events | 22 (+16 repeatable Random World Quests) |
| Crimson Wish (Dragonspine) | 5 |
| Intel Quests (Nod-Krai) | 8 |
| Ascension Quests | 5 |

Two Archon Quest chapters are named but not yet open: **Chapter ??: The
Dream Yet to Be Dreamed** (Khaenri'ah, tied to Dainsleif) and the
**Epilogue** — the wiki does not yet document the Act contents of either.
Additionally, the wiki's chapter overview page still labels Snezhnaya as
"Chapter VI", while the Archon Quest page and the chapter category both
use "Chapter VII"; this document follows the latter numbering.

## Sources

- Genshin Impact Wiki (Fandom): Quest, Quest/Menu
- Archon Quest, Story Quest, World Quest, Event Quest, Commission
- Hangout Event, Tribal Chronicles, Story Key, Random Event, Reputation
- Chapter, Adventure Rank, Version, Version/7.0
- Category:Quests, Category:Archon Quests, Category:Archon Quest Acts,
  Category:Archon Quest Chapters, Category:Story Quests,
  Category:Story Quest Chapters, Category:Hangout Event Chapters,
  Category:World Quests, Category:World Quest Series,
  Category:Commissions, Category:NPC Commissions, Category:Event Quests,
  Category:Reputation Requests, Category:Random Events,
  Category:Random World Quests, Category:Crimson Wish Quests,
  Category:Intel Quests, Category:Ascension Quests
