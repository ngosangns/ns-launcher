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
| Abyss cycle override | `~/Library/Application Support/NSLauncher/abyss-cycles/*.json`   |
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

The Abyss tab ranks four-character teams for the current Spiral Abyss rotation
against the characters and weapons the player marks as owned.

Data lives in `Sources/NSLauncherApp/Resources/Abyss/` (bundled, see that
folder's README); the Markdown it was transcribed from and the JSON Schemas stay
in `toi-uu-doi-hinh/`. `toi-uu-doi-hinh/optimizer/` holds the Python reference
implementation the Swift engine was ported from — it reads the same data and the
same `tuning.json`, and it generates `Tests/NSLauncherAppTests/Fixtures/abyss-golden.json`,
which pins the Swift engine to the Python's numbers.

The search runs in two passes. The first ranks characters and gear on neutral
ground — level 95 enemies, baseline resistance, no team — because it has to
compare everyone against everyone before it knows which four end up together,
and then enumerates every 4-character combination. The second,
`AbyssArtifactAdvisor`, re-picks the artifacts of the teams that survived, this
time against the floor they will actually fight and the three characters they
will stand next to, and re-ranks on the result. It is a coordinate-ascent sweep
over the members, it only ever accepts a strict improvement, and it costs a few
hundred milliseconds because it runs over a shortlist rather than over every
team.

That second pass has **no counterpart in the Python**, which is why the golden
fixture runs with `refinesArtifacts: false`. Do not "fix" that flag to make the
fixture cover more: with it on, the fixture would stop pinning the port.

Adding it also forced a correction in `AbyssScorer.partyBuffs`: an artifact
set's party-wide buff is now counted once no matter how many members wear it.
The reference implementation sums them, which is invisible while gear is chosen
on solo damage — a party buff is then worth no more than a selfish one — and
becomes the highest-scoring build the moment anything optimises the *team*
score. The first thing the artifact pass recommended was Tenacity of the
Millelith on three characters for a fictional +60% party ATK. The golden fixture
is unchanged by the fix, so the two implementations still agree on every team it
pins; a future rotation where a top team does share such a set would diverge,
and the Python should be corrected then. Buffs from weapons and talents are
still summed, so two different weapons granting the same buff still
double-count — rarer, and it needs source tracking `AbyssStats` does not carry.

Most of the gain the tab reports for the artifact pass is not exotic: it is the
supports being handed sets that buff the party, which the neutral first pass
cannot value because it scores every character alone.

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

Two things to know before changing the engine:

- **The golden fixture is a baseline, not an expectation to update.** If a
  change makes `AbyssGoldenValueTests` red, that is the test doing its job: the
  stat-name mapping is a long switch and a misrouted name produces
  plausible-but-wrong numbers rather than a crash. Regenerate only when the
  model was deliberately changed, and change the Python at the same time.
- **Some Python quirks are reproduced on purpose** and are commented where they
  live (`AbyssTextParser`, `AbyssOptimizer.defaultRole`). Fixing one moves every
  score, so it has to be done in both implementations together with the fixture
  regenerated.

Scores are a ranking heuristic, not a damage simulation — no rotation, energy,
reaction cooldowns or constellations. That caveat is shown in the tab itself,
not just here.
