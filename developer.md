# Developer Guide

This document covers the local development workflow, contribution process,
and the boundaries of the NS Launcher implementation. For an end-user
overview, see [README.md](README.md).

## Contributing

1. Fork the repository and branch off `main`. Use a descriptive branch name
   (e.g. `fix/launch-reliability`, `feat/launcher-ui-and-icon`).
2. Keep changes focused: one logical change per pull request.
3. Follow the existing architecture and naming conventions (see
   [Architecture](#architecture) below) instead of introducing new patterns
   for the same problem.
4. Run `swift test` before opening a pull request; add or update tests when
   you touch installer, Wine runtime, or persistence logic (see
   [Tests And Boundaries](#tests-and-boundaries)).
5. Write commit messages using
   [Conventional Commits](https://www.conventionalcommits.org/)
   (`fix(scope): ...`, `feat(scope): ...`, `chore: ...`), matching the
   existing git history.
6. Open a pull request against `main` describing what changed and why. Link
   any related issue.
7. Do not commit secrets, machine-specific paths, or generated build output
   (`.build/`, `.swiftpm/`, etc.). Only update `Screenshots/` when the UI
   actually changed, via `task screenshots`.

## Prerequisites

- macOS 14 or later;
- Swift 6.2 or later;
- `go-task` for `Taskfile.yml` commands;
- a compatible Wine runtime, usually CrossOver or Game Porting Toolkit;
- internet access for HoYoPlay metadata, CDN chunks, and optional Steam
  compatibility stubs;
- Homebrew `zstd` only if dynamic loading of the system zstd library fails.

The app can install CrossOver from its UI with:

```bash
brew install --cask crossover
```

Screenshot automation uses AppleScript and requires Accessibility/Automation
permission for the terminal running the script.

## Daily Workflow

Run the complete test suite:

```bash
swift test
```

Run the app directly (the package also builds the `IconGen` tool, so the
target must be named explicitly):

```bash
swift run NSLauncherApp
```

Use the Taskfile for common workflows:

```bash
task dev         # watch Swift sources and relaunch
task build       # release binary
task bundle      # ad-hoc-signed NSLauncher.app
task install     # copy the bundle to /Applications
task screenshots # capture launcher and game windows
```

The raw release binary is produced by SwiftPM at:

```bash
"$(swift build -c release --show-bin-path)/NSLauncherApp"
```

## Architecture

| Area                    | Location                                                                         | Responsibility                                                                  |
| ----------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| App and UI              | `Sources/NSLauncherApp/NSLauncherApp.swift`, `Views/`                            | SwiftUI lifecycle, screens, theme, and input behavior                           |
| Domain                  | `Sources/NSLauncherApp/Domain/Models.swift`                                      | Game definitions, launch settings, profiles, and shared models                  |
| UI state                | `ViewModels/LauncherViewModel.swift`                                             | Observable state exposed to the views                                           |
| Orchestration           | `Services/LauncherCoordinator.swift`                                             | Coordinates install, update, launch, and cache operations                       |
| Persistence             | `Services/SettingsStore.swift`                                                   | Settings migration and JSON persistence                                         |
| Sophon installer        | `Services/Installer/`                                                            | Manifest decoding, planning, downloads, verification, staging, and pruning      |
| Wine runtime            | `Services/WineService.swift`, `Services/RenderBridges/`                          | Runtime discovery, render backend setup, launch arguments, and registry changes |
| Process and diagnostics | `ProcessRunner.swift`, `GameProcess*.swift`, `RunLog.swift`, `GameLogFile.swift` | Process execution, monitoring, bounded output, and logs                         |
| Abyss team planner      | `Domain/Abyss/`, `Services/Abyss/`, `Views/Abyss/`                               | Spiral Abyss data, damage model, team search, artifact advice, roster editing   |
| Localization            | `Localization/AppText.swift`                                                     | User-facing localized strings                                                   |

`Package.swift` defines the `NSLauncherApp` executable target, the
`AppIconKit` library shared between the app and icon tooling, the `IconGen`
executable that renders `AppIconKit`'s icon into `AppIcon.icns` for `task
bundle`, and the `NSLauncherAppTests` test target.

## Install And Update Flow

1. Fetch HoYoPlay branch metadata and the Sophon build descriptor.
2. Download and decode zstd-compressed protobuf manifests.
3. Compare local files by size and MD5.
4. Prune files outside the target game asset set while preserving the Wine
   prefix, launcher metadata, staging files, and
   `GenshinImpact_Data/Persistent`.
5. Download missing or mismatched chunks with bounded concurrency.
6. Decompress and verify chunks, then reconstruct assets in staging files.
7. Verify the final asset MD5 and atomically replace the destination.
8. Write `.nslauncher-install.json` only after the expected executable exists.

Voice manifests are used to report installed voice packs and support removal.
They are not an install source.

## Wine And Rendering

Wine discovery scans managed and known CrossOver/Game Porting Toolkit locations.
The launch path resolves DXMT or plain Wine based on the payloads available in
the selected runtime. HDR and Retina scaling are hardcoded off (Wine's HDR
path renders wrong colour; Retina is the single biggest render-side cost),
alongside the always-on YAAGL-style launch workarounds: cloud compatibility,
Steam-parent mode, AC patching, network blocking, and the network timeout fix.
None of these are user-configurable — they run on every launch.

These workarounds are not supported by HoYoverse and may carry account or
stability risks. Runtime behavior depends on the installed Wine build.

## Runtime Data

| Data                 | Path                                                             |
| -------------------- | ---------------------------------------------------------------- |
| Settings             | `~/Library/Application Support/NSLauncher/settings.json`         |
| Abyss roster         | `~/Library/Application Support/NSLauncher/abyss-roster.json`     |
| Abyss showcase cache | `~/Library/Application Support/NSLauncher/abyss-showcase.json`   |
| Abyss search cache   | `~/Library/Application Support/NSLauncher/abyss-search-cache.json` |
| Abyss cycle override | `~/Library/Application Support/NSLauncher/abyss-cycles/*.json`   |
| HoYoLAB credentials  | `~/Library/Application Support/NSLauncher/abyss-hoyolab.json` (mode 0600) |
| Managed Wine         | `~/Library/Application Support/NSLauncher/wine`                  |
| Game logs            | `~/Library/Logs/NSLauncher`                                      |
| Download/cache data  | `~/Library/Caches/NSLauncher`                                    |
| Default game install | `~/Games/Genshin Impact`                                         |
| Wine prefix          | `<install root>/.wine`                                           |
| Install metadata     | `<install root>/.nslauncher-install.json`                        |
| Sophon staging       | `<install root>/.nslauncher-sophon-staging`                      |

## Tests And Boundaries

The test suite covers settings migration, launch profiles, render backend
selection, Wine discovery, process inspection and monitoring, registry
rendering, logging, transfer metrics, protobuf decoding, pruning, and Sophon
concurrency.

There are no end-to-end tests for live HoYoPlay downloads, real Wine launches,
CrossOver installation, Steam stub downloads, or actual Genshin startup.

The current product scope is limited to global Genshin. Quest-to-file mapping is
not available, and runtime container sizes are reporting-only. Sophon APIs,
manifest schemas, CDN layout, and live category names are external dependencies
that can change independently of this repository.

## Release

The GitHub Actions workflow in `.github/workflows/release.yml` runs on tags
matching `v*.*.*` using `macos-15`. It builds the app, creates an ad-hoc-signed
bundle, archives it as `.tar.gz`, and publishes a GitHub release.

Both the workflow and `task bundle` assemble the `.app` through
`scripts/bundle-app.sh` — they must not spell those steps out separately. They
previously did, and drifted: the workflow never copied SwiftPM's
`ns-launcher_NSLauncherApp.bundle`, so every released build shipped without
`Resources/Story` and the Story tab came up empty even though local `task
bundle` builds were fine. The script now fails the build if any directory in
its `REQUIRED_RESOURCE_DIRS` list is missing from the assembled bundle; extend
that list whenever `Package.swift` gains a new `resources:` entry.

There is currently no notarized or DMG distribution path.

## Screenshot Capture

After the game is installed, run:

```bash
task screenshots
```

The script builds and launches the app, captures the launcher window, starts the
game through the Play button, waits for a Genshin window, and captures the
pre-login screen. It writes generated captures to `Screenshots/` and skips the
game image if the timeout is reached.

## Abyss Team Planner

The Abyss tab ranks four-character teams for **floor 12** of the current Spiral
Abyss rotation against the characters and weapons the player marks as owned. Only
floor 12: anything that clears it clears the floors below, so ranking teams for
9-11 spent three quarters of the search on an answer nobody acts on. Artifacts
are not part of the roster at all — sets are farmable, so the useful answer is
the best set that exists, and the search always covers all 46 five-star sets.

A floor is planned as the two fights it actually is. Every chamber is cleared
twice, by two teams that cannot share a character, and the rotation can pay the
two halves for different things — this one does: floor 12's first half gives
+200% Superconduct and +75% Stellar-Conduct, its second +75% to Pyro normal
attacks. Read as one sentence, which is how the model read it, every team
collected both bonuses and neither ranking meant anything. So `AbyssTextParser`
slices a disorder at its "Nửa 1"/"Nửa 2" markers (a text that merely mentions
halves — floor 11 says a bonus applies "không tách theo nửa" — is not a split),
`AbyssFloorContext` takes a `half` and reads only that half's enemies, which the
data records as the chamber's two waves, and the optimiser enumerates each half
separately and then pairs the two rankings.

Pairing is the part worth knowing about. The two halves rank the same
characters, so their favourite teams want the same people and the answer is
never "each half's own best": `AbyssOptimizer.pair` finds the best *legal* pair
by branch and bound, then the best pair among the teams no higher-ranked plan
used, so five plans are five different answers rather than one shuffled five
ways. A plan's score is the harmonic mean of its two halves — both have to be
cleared inside one timer, time goes as 1/damage, so ranking on the harmonic mean
ranks on how long the floor takes; adding the two would let a crushing first
half pay for a second half that cannot clear. That treats the two halves as
holding similar enemy HP, which the data does not record, and it is what makes
two very different score scales comparable at all. How deep the two rankings go
matters more than it looks: at 400 teams per half both lists were drawn from
about twelve characters and the search found exactly one legal plan, which is
why `pairingCandidates` is in the thousands.

`AbyssOptimizerRequest.splitsHalves` turns this off. The golden fixture runs
unsplit — its subject is the damage model, and splitting changes which teams come
back — and so does any test whose subject is how a single team is scored rather
than how two are chosen.

Data lives in `Sources/NSLauncherApp/Resources/Abyss/` (bundled, see that
folder's README); the Markdown it was transcribed from and the JSON Schemas stay
in `toi-uu-doi-hinh/`.

### Where a fact belongs

The data files are split by **what kind of claim** they make, not by which part
of the engine reads them. Four homes, and the boundary between them is the thing
worth remembering, because it is the one that went wrong:

| File | Holds | Test of membership |
|---|---|---|
| `characters/`, `weapons/`, `artifact-sets.json`, `abyss-monsters/` | Transcribed game data | Someone could read it off the wiki |
| `damage-formula.json`, `team-bonus.json` | Game **rules** | Changes with a game version |
| `character-kits.json` | Everything true of **one named character** that no game file states: how the kit is played | The sentence names a character |
| `tuning.json` | The planner's **assumptions** about every character | Changes because we changed our minds |

`character-kits.json` (as `character-traits.json`, until Phase 2 of
`docs/redesign.md` renamed and widened it on 2026-09-15) was added on
2026-09-12 and is the reason this table exists. Forty-eight facts about individual characters had accumulated across the
other three files in seven shapes — `tuning.json` held four tables,
`team-bonus.json` two flat id lists, `damage-formula.json` one more — so each new
character meant editing three files in three different ways. The split had been
made along "which subsystem reads this", and characters are not a subsystem: they
are the axis that grows every six weeks.

The part that actually cost something was quieter. **Six of the seven tables were
read without checking that the id existed.** A typo in `stellarJubileeCharacterIds`
did not crash and did not warn; it removed the mechanic, and a roster where
nobody has Stellar Jubilee looks exactly the same from the inside. One of the
seven columns was worse than untyped — `reactionBaseDmgBonusSources.reactionType`
was free text (`"Lunar-Charged/Bloom/Crystallize"`) that the engine decoded and
then ignored, so every source raised every Lunar and Stellar reaction: Lauma,
who raises Lunar-Bloom, was paying for other teams' Stellar-Conduct. The same
column mixed two id conventions — nine display names and one slug
(`traveler-cryo`) — against a lookup that was by slug, which worked only because
every name in it happened to be one word.

Now: one entry per character, `characterId` always the slug from
`characters/*.json`, `reactions` an explicit array, and every unresolved id,
reaction name or duplicate lands in `AbyssParseDiagnostics.unknownTraitCharacterIDs`.
`AbyssCharacterTraitsTests` pins that set empty, so a typo is a red test.

Two `resistanceShred` entries stayed in `tuning.json`, and they are the clearest
illustration of the boundary: they are artifact sets, gated on an element the
team has, standing in for "an Anemo support probably wears Viridescent Venerer".
That is an assumption about who wears what. Faruzan's and Shenhe's are gated on
the character being present, which is a fact, and they moved.

### One spelling for a stat

`AbyssStatField.tuningKey` is the only place a stat's snake_case name is written.
It used to be three: a `substatField(_:)` switch, a `tuningKey(for:)` switch, and
twenty hand-written lines in the fixture dumper. Every one of those fed a
dictionary subscript whose miss is `nil`, which the callers read as zero — so a
mistyped `crit_dmg` built every character without CRIT DMG and still produced a
confident recommendation. `AbyssStatVocabularyTests` walks `tuning.json` and
requires each key to land on a slot, in both directions; that is what turned up
`artifactMainStats.physical_dmg`, a main stat no search had offered since the
goblet candidates were cut down.

The engine began as a port of a Python implementation that lived in
`toi-uu-doi-hinh/optimizer/`. That Python is **deleted** as of 2026-09-09: it had
stopped being a second opinion and become a second thing to keep in step — every
model change had to be made twice, and the half-splitting above is the first
change that was simply not worth porting back. What it leaves behind is
`Tests/NSLauncherAppTests/Fixtures/abyss-golden.json`, which it generated and
which the Swift engine matched to the last digit. The fixture stays; it is now
written by `Tests/NSLauncherAppTests/AbyssGoldenDump.swift` — the same values,
from the engine itself — so it went from "what another implementation computes"
to "what this engine computed the day someone checked it". That is a regression
baseline, and regenerating it is a decision rather than a repair:

```bash
ABYSS_DUMP_GOLDEN=Tests/NSLauncherAppTests/Fixtures/abyss-golden.json \
    swift test --filter testRegenerateGoldenFixture
```

Scores are **damage per second**, not damage per rotation: the engine
accumulates a rotation's worth of damage — that is the unit the multipliers are
written in, `normalCombosPerRotation` attacks, a burst once — and divides by
`tuning.rotationSeconds` on the way out. Be clear about what that did and did
not do: every team's rotation is assumed to take the same 20 seconds, so the
division is by a constant and **reordered nothing**; regenerating the fixture
after the change moved all 325 scores by exactly ÷20 and left every team, every
stat sheet and every floor untouched. What it bought is a number that means
something, and a plan score (the harmonic mean of two halves) that is now
literally "how long this floor takes". Making a shorter rotation count as the
strength it is would need per-character cast and cooldown data the model does
not have.

Enemy resistance, enemy DEF and enemy element are all priced, but they came from
different places and only two of them came from data. DEF is the standard level
formula against the floor's mean monster level (`AbyssDamageMath.defMultiplier`,
with `defReduction`/`defIgnore` at zero — nothing in the model shreds DEF).
Resistance is `resMultiplier` on whatever the floor context holds. The floor
context, though, used to hold only what a monster's `resistanceNotes` prose
said, and **floor 12 has no such notes at all this rotation** — every monster is
`null` or "chưa xác nhận", so every element was priced at the 10% baseline and
bringing Cryo against a Cryo Abyss Mage cost a team exactly nothing. The
`elements` field was sitting there unread. It is now read: an enemy is taken to
resist the element it attacks or shields with at
`tuning.enemyOwnElementResistance`, for elements its own note did not already
price. That number is an inference and is labelled as one — 0.30 is anchored on
the only two monsters in the whole file whose own-element resistance was
transcribed, both of which say +20~30% over the baseline — and setting it to
0.10 switches the rule off. It moved floor 10's ranking completely, left floor
11's and floor 12's top ten in the same order, and took about 22% off every
floor-12 score.

Who gets to audition is decided in a team, not alone. The pool trim has to cut
somebody — C(n,4) grows fast enough that keeping a whole account is pure cost —
but it used to rank on a *solo* score, and a character alone triggers no
reaction, gets no resonance, receives no party buff and collects no floor bonus.
That is most of the reasons a support is worth a slot, invisible to the thing
deciding whether the support is looked at. On a real 49-character roster it cut
Bennett. Each candidate now auditions alongside four fixed anchors of four
different elements, scored against each fight being planned.

**The parser is where the quiet damage lives.** A misread row does not crash; it
lands in the profile as a multiplier of ATK and is wrong forever. Five families
have been found and each is now pinned by a test in `AbyssTextParserTests`:

- A **stat bonus** is not a hit. The non-damage filter listed ATK/DEF/HP/EM Bonus
  and not *DMG* Bonus, so "DMG Bonus (Omen) 60%" was 60% of Mona's ATK, and
  Lauma's burst — whose only two rows are Bloom bonuses of 499% and 400% — was
  nine times her ATK of damage that does not exist (-29% once it stopped).
- A **rate** is not a hit: per point, per stack, per 100 EM. Nine such rows, worth
  up to -6% each.
- A **percentage of another hit** is not a hit ("% ST đòn thường").
- **Alternatives are not additive.** Lisa's Hold DMG at 0 and at 3 stacks were
  summed for 14.5× ATK on a cast worth 8.8×; Hu Tao's burst was scored above
  *and* below 50% HP. Narrowly scoped: Tighnari's two waves and Columbina's three
  reactions are additive and keep their sum.
- **The basis is sometimes only in the label.** "Equitable Judgment (%MaxHP)"
  over a bare "14.47%" read as ATK scaling was Neuvillette's damage divided by
  about twenty-seven; reading the label more than doubled him (+140%), Sigewinne
  +93%, Furina +42%, and moved Gorou and Yun Jin onto the DEF they really scale
  on. Tight on purpose: Hu Tao's charged attack *costs* HP and must not be read
  as scaling on it.

Three mechanics the model did without for a long time, each a channel that
existed with nothing feeding it. All three are data now, in `tuning.json` and
`damage-formula.json`, not constants in code.

**Enemy resistance reduction** (`tuning.resistanceShred`). `resMultiplier` has
always had a negative branch — below zero the resistance is only halved, so
stripping keeps paying where a DMG bonus saturates — and nothing could push it
there. That is most of what Kazuha, Venti, Sucrose, Faruzan and Shenhe are, and
without it they were close to invisible: none of them appeared in a single
recommended team on a 49-character account. Four sources, each with its note and
its uptime: Viridescent Venerer and Deepwood Memories (conditioned on the team
having the element, because at team-context time the model does not know who
wears what, and in practice the Anemo support wears VV), Faruzan's burst and
Shenhe's burst (numbers that match their own scaling rows). The strongest source
per element, not the sum — two shreds on one element do not stack. Deepwood's
`setEffectApprox` %DMG went to zero and Viridescent Venerer's dropped, because
that stand-in was the shred and it is now real. Turning it on put an Anemo
character in every plan and Kazuha at 22% of a team's damage.

**Lunar and Stellar reactions** (`damage-formula.json`'s `lunarStellar`). A whole
block nothing read: five coefficients, a flatter EM curve (`6·EM/(EM+2000)`
against the transformative `16·EM/(EM+2000)`, so the same EM is worth far less to
them), and ten characters who raise a reaction's base damage by being present.
A team that qualifies now unlocks the Lunar/Stellar variant *alongside* the plain
one rather than instead of it, and the pricing picks whichever the floor pays
more for — this rotation triples Superconduct, so a Stellar Jubilee team's plain
Superconduct can still win. Stellar-Conduct is a range in the data (its
coefficient climbs with the Cryo/Electro hits before it) and sits on that range
at `tuning.stellarConductRamp`. The `indirect` branch — one reaction split across
four contributors weighted 0.6/0.3/0.05/0.05 — is still not modelled; it needs
per-character CRIT the transformative path does not carry, and the `direct`
coefficients are both the honest reading and the larger of the two.

**Charged attacks the vocabulary cannot see** (`tuning.chargedAttackLabels`). The
parser recognises "trọng kích", "charged", "aimed"; the data sometimes names the
attack after the skill instead, and those rows matched no bucket at all and were
dropped. Ganyu lost every point of Frostflake Arrow, Tighnari his Wreath Arrow,
Neuvillette his Equitable Judgment. Listed per character rather than by a wider
regex, because whether "Frostflake Arrow" is a charged attack or a normal one is
knowledge about the game and not a rule about words. Worth +15% to Ganyu, +24% to
Itto, +28% to Neuvillette, +35% to Lyney. Whatever still falls through is
reported in `AbyssParseDiagnostics.normalAttackRowsUnclassified`, so the table
getting longer is visible progress rather than an invisible gap.

A floor buff goes where its text says it goes. A clause naming a reaction —
"Sát thương Superconduct +200%" — multiplies that reaction; a clause naming an
element or normal attacks multiplies direct damage. The two used to share one
route: `floorBonus` added *any* buff to every hit the team made, gated only on
the team being able to trigger the named reaction. On this rotation's floor 12
that was worth +85% to a team's score for a reaction worth 5% of its damage, and
it picked the whole first-half team. `AbyssScorer.transformative` now takes the
floor's buffs into its pricing, which also fixes the second half of the same bug:
ranking reactions on the bare coefficient priced Overloaded (2.75) over a
Superconduct (1.5) the floor was tripling, so the team was chosen for a reaction
it was then not paid for. Vaporize and Melt clauses reach
`amplifyingMultiplier`'s `reactionBonus`, a parameter that had existed unused
since the port. A clause naming a reaction the model prices nowhere — the Stellar
and Lunar variants — reaches nothing and is reported in
`AbyssParseDiagnostics.floorBuffsNotPriced`, because the alternative is what used
to happen and silence was the worse half of it.

Pairing two halves requires disjoint **weapons** as well as disjoint characters.
Both halves are fought in one run and a weapon is one item; the first version
checked characters only, and all five plans it produced put the same Wolf's
Gravestone in both teams. Nothing re-arms a team to dodge a clash — the
alternative, re-picking the second half's weapons after the pair was chosen,
would rank pairs on scores that then change underneath the ranking.

The search runs in two passes. The first ranks characters and gear on neutral
ground — level 95 enemies, baseline resistance, no team — because it has to
compare everyone against everyone before it knows which four end up together,
and then enumerates every 4-character combination. The second,
`AbyssArtifactAdvisor`, re-picks the artifacts of the teams that survived, this
time against the floor they will actually fight and the three characters they
will stand next to, and re-ranks on the result. It is a coordinate-ascent sweep
over the members, exhaustive within each member — every set as a 4-piece and
every pair as 2+2, each scored on what the whole team does with it — and it only
ever accepts a strict improvement. It is affordable because it runs over a
shortlist of teams rather than every team, because the teams are refined
concurrently, and because everything a swap cannot change (`DamageContext`,
`TeamDamageContext` in `AbyssScorer`) is computed once per team instead of once
per candidate. Those two types are pure caching: the golden fixture still
matches to 1e-9 with them in place, which is what says so.

Constants come from `damage-formula.json`, not from the code: the EM curves, the
amplifying coefficients, the transformative coefficients and the level-90
multiplier are all read at load into `AbyssDamageConstants`, with the port's own
values as a fallback and anything unread reported in `AbyssParseDiagnostics`.
What stays written in `AbyssDamageMath` is the *shape* of the formulas — the
three-branch resistance curve, the defence formula — which the file expresses as
prose, plus the level-90 assumption; a test holds those against the file.

Talent levels follow constellations. C3 and C5 each raise one talent by three,
and the data carries a `lv13` column for the characters transcribed that far, so
`AbyssDataLibrary` precomputes a profile per reachable talent-level combination
and the optimiser picks one per character from the roster (or the showcase, which
knows the constellation for certain). Which talent a constellation raises is
resolved by counting how many words of each talent's *name* appear in its text —
counting rather than first-match, because several characters have two talents
sharing a prefix.

Transformative reactions are scored once for the team rather than per hit. They
ignore ATK, DMG bonus, CRIT and enemy DEF entirely and depend only on the
triggering character's Elemental Mastery, so `AbyssScorer` prices the strongest
reaction the team unlocks — one, not the sum, since a rotation's elemental
applications compete for the same aura — and credits it to whoever has the most
EM. Frequency is the modelling assumption, not the formula:
`tuning.transformativeReactionsPerRotation` is the most subjective number in the
file and is what decides where reaction teams rank. Catalyze (Aggravate, Spread)
and the Lunar/Stellar block are **not** modelled: catalyze is an additive base
DMG bonus that would need the damage loop restructured, and the Lunar block has
its own four-way aggregation rule.

Normal and charged attacks are separate categories in a damage profile and are
counted with separate per-rotation constants; plunging attacks are deliberately
in neither, since no rotation the model assumes uses them. A charged attack is
read as the *strongest* charged row rather than the sum, because the data does
not say which rows are alternatives (a bow's plain and fully-charged aimed shot)
and which are sequential (a claymore's spin and finisher).

Two classes of buff reach the model through hand-written interpretation rather
than a parser rule, because the prose does not distinguish them. `setEffectApprox`
in `tuning.json` credits an effective %DMG to the 4-piece set effects that are
too conditional to read mechanically. `character-kits.json`'s `buffs` name the
talent rows that buff the party — Bennett's ATK share, Kujou Sara's, Faruzan's
Anemo bonus — or the caster alone (Xiao's burst), which the damage filter drops
because they are not damage instances. In both cases the numbers still come
from the data (a buff reads its value out of `talent-params.json` by label) and
only the reading is written down; a label that drifts is reported in
`AbyssParseDiagnostics` and fails a test rather than quietly contributing
nothing.

The same file carries the two other things a talent table cannot say. `hits`
lists, per slot, which rows one cast actually deals — Bennett's press is one
row of a table that holds four, Raiden's Musou Isshin strikes are her attack
string and are priced as burst damage, Xilonen cannot charge in Blade Roller —
and a slot a kit names replaces the reader's inference for that slot outright.
`conversions` name the row that turns HP or DEF into ATK (Hu Tao, Noelle); the
rate lands on `AbyssStats` as a rate, not a number, so the substat search sees
for itself that HP% is a damage stat on Hu Tao. Every reference is checked at
load (`diagnostics.kitReferencesUnresolved`, pinned empty by
`AbyssCharacterKitTests`); a character without an entry reads by the general
rules, so the file can grow one character at a time.

The golden fixture runs with `refinesArtifacts: false`. Do not "fix" that flag
to make the fixture cover more: this pass re-picks gear per floor and per team,
so with it on the fixture would move for reasons that have nothing to do with
the damage model it exists to pin.

Adding it also forced a correction in `AbyssScorer.partyBuffs`: an artifact
set's party-wide buff is now counted once no matter how many members wear it.
It used to sum them, which is invisible while gear is chosen on solo damage — a
party buff is then worth no more than a selfish one — and becomes the
highest-scoring build the moment anything optimises the *team* score. The first
thing the artifact pass recommended was Tenacity of the Millelith on three
characters for a fictional +60% party ATK. The golden fixture is unchanged by the
fix, because no team it pins happens to share such a set. Buffs from weapons and talents are
still summed, so two different weapons granting the same buff still
double-count — rarer, and it needs source tracking `AbyssStats` does not carry.

Most of the gain the tab reports for the artifact pass is not exotic: it is the
supports being handed sets that buff the party, which the neutral first pass
cannot value because it scores every character alone.

The set named on a member's row opens a popover on hover
(`AbyssSetEffectPopover.swift`) carrying the game's effect text and, under it,
what the model made of that text — because the two often differ. Three cases,
decided by `AbyssSetPricing`: the data's own parsed bonuses went in; the effect
was too conditional to read and `tuning.json` credits a hand-written %DMG
estimate, which the popover labels as an estimate and quotes the reasoning for;
or nothing was priced and the set was ranked on its 2-piece alone, which the
popover says outright. That last line is the point of the whole thing — it is a
recommendation admitting what it did not measure. Only effects actually in force
are drawn: one set is a 4-piece and shows both bonuses, two sets are 2+2 and
show one each.

Main stats are searched, not ruled. Sands, goblet and circlet used to come from
a fixed rule — scaling stat, own element, CRIT DMG — which was defensible for a
damage dealer and wrong for anyone whose damage is a reaction: transformative
damage ignores ATK, DMG bonus and CRIT entirely and scales on Elemental Mastery
alone, so a Bloom carry was handed a goblet and a circlet worth nothing to the
damage the model was crediting them with. `AbyssBuildAssembler.mainStatCandidates`
now says what each slot may hold and the search picks. It runs in both passes,
and it has to: a character scored *alone* triggers no reaction at all, so
Elemental Mastery is worth exactly zero in gear selection and only the team pass
can discover the build. It does — Nahida in a Bloom team comes back with EM in
all three slots and ~836 EM, which the old rule could not express anywhere.

Two slots stay pinned, and not out of laziness: the score is damage and has no
term for a heal landing or a burst being up, so Energy Recharge and Healing Bonus
are worth nothing to it. A free search sells both for a few percent and calls it
an improvement — a better number and a worse team. So a healer keeps the Healing
Bonus circlet and a support or shielder the Energy Recharge sands. Model those
two objectives properly and the constraints go away.

Weapon, sets and main stats are not separable — a CRIT Rate circlet wins on a
weapon that has none and loses on one that does, and a set that hands out CRIT
Rate turns that circlet into a wasted slot — so gear selection walks them in
rounds and keeps the best complete build any round produced. The opening ranking
compares weapons with the three slots *empty*, which is the one comparison the
slots cannot bias, and each revision asks the slots again across the whole weapon
shortlist rather than just the winner. That last detail is worth keeping: without
it, coordinate ascent parked seven characters below where the old fixed rule had
them. With it, the switch moved 81 of 125 characters up and 2 down (both under
0.7%), median +5.1%.

Substats are still a rule (`tuning.json`'s `substatPriority`, by role). They are
a budget split rather than a discrete choice, so the same argument does not
carry over unchanged.

### Redesign in progress

`docs/redesign.md` tracks a larger, multi-phase rewrite of the damage model:
the search and the per-hit formula are sound, but the model has no notion of
*time* — every rotation-dependent quantity (uptime, reaction frequency, ER,
stack count) is a flat constant in `tuning.json` shared by every character,
rather than something computed from an actual timeline. Phase 0 (real
per-monster resistance from the game's own files) and Phase 1 (talent
multipliers from the game's own tables, `talent-params.json` read by
`AbyssTalentReader`, replacing the regex parse of transcribed prose for
118 of 125 characters) are done; read that file before touching
`AbyssScorer`, `AbyssFloorContext`, `AbyssTextParser`, or `tuning.json`'s
uptime-shaped constants, so a change lands as part of the plan rather than
beside it.

One consequence worth knowing before editing data: `characters/*.json`'s
`scaling` tables no longer drive anyone's damage except the seven Travelers.
Correcting a multiplier there changes nothing for the other 118 — the number
comes from `talent-params.json`, which is regenerated from the game and must
not be hand-edited. If the game's own number looks wrong, the reader's
reading of it is what to look at (`AbyssTalentReaderTests`).

### Search result cache

`AbyssSearchCacheStore` persists the last `AbyssOptimizerOutput` to
`abyss-search-cache.json` for up to `AbyssSearchCacheStore.maxAge` (a week), so
opening the tab a second time — or relaunching the app — does not re-run the
search over the same question. `AbyssViewModel.search()` checks it first and, on
a hit, applies the saved reports synchronously with no `isSearching` state at
all; there is no separate "force refresh" action, because the search has no
randomness in it — the same inputs always produce the same teams, so a matching
cache key *is* a fresh result, not a stand-in for one.

The key (`AbyssSearchCacheKey`) is a SHA-256 digest of everything the output
depends on: the roster (sorted by id — the search reads it as a set, so order
must not cause a miss), both pool toggles, the showcase, the request's
floors/topN/poolSize/refinesArtifacts/splitsHalves, the loaded cycle's
`periodStart`, and `AbyssDataLibrary.dataDigest` — a hash of the bytes of every
data file the library read, override cycles included. That last one is what
makes a data change invalidate the cache even when nothing the player did
changed; the first draft left it out as an "accepted gap", and the very next
change to the data (real monster resistances, same `periodStart`) was exactly
the case it would have missed. The week-long expiry remains for the one thing
no digest sees: this app's own code changing what it computes from the same
bytes.

The cache is a single slot, not a history: every entry `AbyssOptimizerOutput`'s
type graph carries had to grow `Codable` for this (`AbyssStats`'s `SIMD8<Double>`
included — the standard library already conforms it, no encoding written by
hand), and `AbyssSearchCacheTests` round-trips a real search result through
`JSONEncoder`/`JSONDecoder` to pin that synthesis dropped nothing, rather than
trusting the compiler accepted it.

### Roster grid sorting

`AbyssViewModel.RosterSort` only reorders what the grid shows — it is applied to
a copy on the way out to the view. Never sort `library.characters` or
`library.weapons` themselves: `AbyssOptimizer` breaks pool ties on that array's
own order, so resorting it would silently change which characters make the
search's candidate pool.

Each sort key has its own "interesting end" — names open on A, stars open on
5★, a release date opens on the newest — so picking a sort snaps
`sortDescending` to that key's `startsDescending`, not to a shared default.
Every ordering falls through to the name and then the id so it is total; Swift's
`sort` is not stable, and a comparator that stopped at "same rarity" would leave
equal-rarity characters in whatever order the algorithm's internals happened to
produce, which looks like the grid rearranging itself between renders.

### Showcase import

`AbyssEnkaClient` reads a player's Character Showcase from Enka.Network given
only their UID — no login, and no server picker, because the UID's first digit
is the region and the response says which. Enka's terms are honoured in the
client: an identifying `User-Agent`, no UID enumeration, and the response's
`ttl` respected (`AbyssViewModel.importFromUID` refuses to re-fetch a UID whose
data cannot have changed yet).

Two limits are structural, not implementation gaps. The showcase is **at most
eight characters**, and only exists if the player enabled "Show Character
Details" in game. A full roster is not available to anyone without the account's
own login session, and putting a HoYoLAB session cookie in a launcher is not a
trade this app makes.

What the import is worth is the *stats*. Enka returns `fightPropMap`, the
character screen's own numbers, already split into base, percentage and flat
parts — the same shape `AbyssStats` uses, so the conversion is a rename and
`base × (1 + percent) + flat` reproduces the totals the game displays (a test
asserts it). An imported character is therefore scored on the artifacts they
actually rolled rather than on `tuning.json`'s standardised build, and the
artifact advice becomes "this beats what you are wearing, by this much".

The delicate part is `AbyssBuildAssembler.showcaseStats`. A measured sheet
already contains the player's set bonuses, so comparing it against a candidate
set would double-count one side; the worn set's *unconditional* bonuses are
subtracted first, leaving their real main stats and substats, and `applySets`
then puts a full set effect back for any candidate. The split between
conditional and unconditional matters in both directions: the game's character
screen shows the always-on bonuses and not the qualified ones, which is also why
only conditional and stacking weapon passives are added on top.

Because a measured build and a modelled one are different kinds of claim,
`AbyssGearOption.statSource` carries which, the tab badges every character, and
a team that mixes the two gets an `.mixedStatSources` note. Do not remove that:
a well-built imported character and an assumed one are not comparable, and the
score does not know the difference.

`Resources/Abyss/game-ids.json` maps the game's numeric ids to the data's slugs.
Regenerate it with `scripts/generate-abyss-game-ids.py` whenever characters,
weapons or artifact sets are added — a stale table makes an import quietly
return fewer characters. The script refuses to write a table that lost entries,
and `AbyssShowcaseImportTests` pins it to the data set.

### Full roster import (HoYoLAB)

`AbyssHoyolabClient` reads a player's *complete* character list — not capped at
eight like the Showcase — from HoYoLAB's Battle Chronicle, on the *overseas*
Game Record host (`sg-public-api.hoyolab.com/event/game_record/genshin/api/character/list`)
— not `api-takumi-record.mihoyo.com/game_record/app/genshin/api/...`, which is
the mainland-China host in `genshin.py`'s own routing table and rejects an
overseas `ltuid_v2`/`ltoken_v2` session outright (an early version of this
client used that host by mistake and every real import failed with "invalid
cookies" until the mixup was found). It trades Enka's "no login"
property for a much wider one: the request needs the player's own HoYoLAB
session (`ltuid_v2`/`ltoken_v2`, pasted in by hand from their browser's
cookies), and only returns anything if they separately turned on "Character
Details" under their HoYoLAB privacy settings — a toggle most players have
never touched, unlike Enka's in-game one.

This is not an endpoint HoYoverse documents. The request shape, the app-version/
client-type header pair, and the Dynamic Secret salt come from the
actively-maintained open-source `genshin.py` client
(`github.com/thesadru/genshin.py`) — arrived at by the same kind of reverse
engineering this whole feature already leans on for Enka and Yatta, and just as
liable to stop working the day HoYoverse changes it, with no notice. The `ds`
header (`AbyssHoyolabClient.dynamicSecret`) is `"{t},{r},{md5("salt=...&t=...&r=...")}"`;
`computeDynamicSecret` is the pure half, pinned in
`AbyssHoyolabClientTests.testDynamicSecretMatchesTheReferenceImplementation`
against a value computed independently in Python from the same formula, so a
typo in the salt or the field order fails a test instead of a silent 401. What
that test *cannot* do is confirm the whole pipeline against a real account —
nobody's live login credentials belong in this repository or in a chat with an
AI assistant, so the network path is unverified pending the first real run.
`HoyolabCharacter.weapon.affix_level` is passed straight through as the
refinement (1-5) rather than offset by one the way Enka's `affixMap` is —
`genshin.py`'s model applies no such offset for this field, which is the best
evidence available without a live account; if imported weapons come back one
refinement short, that assumption is the first thing to check.

Because HoYoLAB's character list carries no artifact detail, an import from it
marks characters and their equipped weapon owned (with real constellation and
refinement) but never sets `.measured` — those characters are scored on the
same standardised build as anyone else marked owned by hand. Only a Showcase
import produces `.measured` stats. The two imports share the UID field (it
names the same account either way) but are otherwise independent: running one
does not touch the other's data, and both follow the same "only ever adds,
never removes what the player ticked by hand" rule the original Showcase
import established.

The credentials themselves live in `abyss-hoyolab.json`
(`AbyssHoyolabCredentialStore`), alongside the roster and the showcase cache.
They are saved only when the player actually presses import, not on every
keystroke, and reload automatically on the next launch.

They were a Keychain item first, and that did not survive contact with how this
app is built. The probe behind the original decision tested one binary against
an item that same binary had created, and concluded ad-hoc builds get at
`kSecClassGenericPassword` with no prompt. What it missed is that the ACL macOS
puts on a keychain item names the *creating* app by its code identity, and an
ad-hoc signature's identity is a cdhash that changes on every build. So the
first launch after any `task install` was a different program as far as the
Keychain was concerned, reaching for the previous build's secret — and since
`AbyssViewModel` loads these in `init`, the dialog landed on app launch, before
the player had touched the Abyss tab. "Always Allow" bought exactly one build's
peace.

A plain file has no such identity check, which is the point and also the cost:
this is a live session token that anything running as the player can now read
without being asked. `save` chmods it to 0600 so it is at least not readable
from another account on the same Mac, and a test asserts that rather than
trusting the comment. Nothing migrates the old keychain item — reading it is
precisely the prompt being removed — so an upgrading player re-pastes once and
can clear the leftover with
`security delete-generic-password -s com.ns-launcher.abyss.hoyolab`.

### Character and weapon portraits

`Resources/Abyss/icons/{characters,weapons}/<id>.png` are fetched once by
`scripts/fetch-abyss-icons.py`, matched by name against `gi.yatta.moe` the same
way `generate-abyss-game-ids.py` matches its ids, then saved under our own
slugs. That means the runtime side never needs Yatta's icon codenames — it is
the same `Resources/Abyss/<kind>/<id>` convention the rest of the data already
uses, just for a `.png`. Regenerate it whenever characters or weapons are
added; it skips files that already exist, so a re-run only fetches the new
ones (`--force` to refetch everything). `AbyssIconLibraryTests` pins full
coverage against the current data set.

`AbyssIconLibrary` resolves ids to file URLs, checking presence once at load —
built as a `Set` of filenames on disk, not a `FileManager.fileExists` call per
lookup — because `RosterCard`'s grid asks for an icon on every redraw while
scrolling. `AbyssPortraitImage` is the rendering half: it shows the portrait
when there is one and a tinted SF Symbol glyph when there is not, so a
character or weapon added without a matching icon degrades to what the tab
looked like before this feature, not to a blank tile. Decoded images go through
`AbyssPortraitCache` (an `NSCache`, `@MainActor`-isolated because only SwiftUI
view bodies touch it) rather than being held resident — 371 icons at 256×256
would be roughly 100MB of decoded bitmap data if kept around all at once, and
the grid only ever shows a few dozen.

`RosterCard` takes its leading glyph as a `@ViewBuilder icon: () -> Icon`
closure rather than a fixed `systemImage`/`accent` pair, specifically so it
did not have to hard-code a dependency on the Abyss-specific portrait types —
see the type's own doc comment about staying reusable for the next grid
picker.

The Traveler shares one portrait across all seven element variants — the game
has no per-element art for them, only per-gender — and the script picks
Aether's icon for every `traveler-*` slug. That is documented as an arbitrary
but consistent choice in the script, not a claim about which twin is "the"
Traveler.

Two things to know before changing the engine:

- **The golden fixture is a baseline, not an expectation to update.** If a
  change makes `AbyssGoldenValueTests` red, that is the test doing its job: the
  stat-name mapping is a long switch and a misrouted name produces
  plausible-but-wrong numbers rather than a crash. Regenerate only when the model
  was deliberately changed — and then read the diff, because a change meant for
  one character that moves three hundred numbers is the diff telling you
  something.
- **Some inherited quirks are kept on purpose** and are commented where they live
  (`AbyssTextParser`, `AbyssOptimizer.defaultRole`). Fixing one moves every score
  and every number in the fixture, so it is a deliberate change with the fixture
  regenerated, not a drive-by.

Scores are a ranking heuristic, not a damage simulation — no rotation, energy,
reaction cooldowns or constellations. That caveat is shown in the tab itself,
not just here.
