# Developer Guide

This document covers the local development workflow and the boundaries of the
NS Launcher implementation.

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
| Localization            | `Localization/AppText.swift`                                                     | User-facing localized strings                                                   |

`Package.swift` defines the `NSLauncherApp` executable target, the
`AppIconKit` library shared between the app and icon tooling, the `IconGen`
executable that renders `AppIconKit`'s icon into `AppIcon.icns` for `task
bundle`, and the `NSLauncherAppTests` test target. `Vendor/yaagl` is a
separate submodule and is not compiled by this Swift package.

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
The launch path can configure Apple D3DMetal, DXMT, DXVK, or plain Wine based on
the selected render backend and the payloads available in the selected runtime.
The launch profile also carries optional compatibility settings such as cloud
compatibility, Steam-parent mode, AC patching, network blocking, proxy, HDR,
Retina, Metal HUD, resolution, and timeout fixes.

These workarounds are not supported by HoYoverse and may carry account or
stability risks. Runtime behavior depends on the installed Wine build.

## Runtime Data

| Data                 | Path                                                             |
| -------------------- | ---------------------------------------------------------------- |
| Settings             | `~/Library/Application Support/NSLauncher/settings.json`         |
| Managed Wine         | `~/Library/Application Support/NSLauncher/wine`                  |
| Game logs            | `~/Library/Logs/NSLauncher`                                      |
| Download/cache data  | `~/Library/Caches/NSLauncher`                                    |
| D3DMetal snapshots   | `~/Library/Application Support/NSLauncher/RenderCaches/D3DMetal` |
| Default game install | `~/Games/Genshin Impact`                                         |
| Wine prefix          | `<install root>/.wine`                                           |
| Install metadata     | `<install root>/.nslauncher-install.json`                        |
| Sophon staging       | `<install root>/.nslauncher-sophon-staging`                      |

## Tests And Boundaries

The test suite covers settings migration, launch profiles, render backend
selection, D3DMetal cache locking and snapshots, Wine discovery, process
inspection and monitoring, registry rendering, logging, transfer metrics,
protobuf decoding, pruning, and Sophon concurrency.

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
