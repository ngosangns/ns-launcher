# Architecture

## Overview

`NS Launcher` is a native macOS launcher with a `SwiftUI` front-end and a
service-oriented backend. The app currently focuses on one bundled Genshin Impact
definition and one install/update backend: HoYoPlay Sophon chunks.

Main layers:

- `App`: application lifecycle and screen composition.
- `Domain`: game, Sophon asset, install plan, update plan, progress, and settings
  models.
- `Services`: settings persistence, Sophon install/update, Wine integration, and
  external process execution.
- `ViewModels`: UI-facing state, commands, logs, and progress mapping.

## App Shell

`NSLauncherApp`, `LauncherViewModel`, `ContentView`, and `SettingsView` form the
native app shell. The view model owns long-running tasks, pause/stop state,
transfer metrics, filtered Wine logs, and the update log. It delegates side
effects to `LauncherCoordinator`.

Settings is intentionally narrow in the Sophon-only product: language, install
root, executable path, and launch display mode. There are no package URL,
archive, cache, extraction, or generic manifest controls.

## Game Definition

`GameDefinition` describes the bundled game channel:

- stable identifier;
- display name;
- install root;
- executable path;
- Wine prefix path;
- single installer strategy, `sophon`;
- runtime requirements;
- launch arguments.

Older settings files may still contain deprecated package or manifest fields, but
the decoder ignores them and `AppSettings.applyingBundledGenshinDefaultsIfNeeded`
migrates the bundled Genshin definition to Sophon.

`AppSettings.launchDisplayMode` owns Wine launch display behavior globally. The
launcher defaults to windowed mode and injects Unity-compatible screen arguments
at launch time. User-provided screen flags such as `-screen-fullscreen`,
`-screen-width`, `-screen-height`, and `-popupwindow` are filtered from per-game
arguments so the Settings toggle remains authoritative.

## Sophon Installer

`LauncherCoordinator` uses `GenshinSophonInstaller` for both fresh install and
update. The coordinator no longer routes through archive, local import,
file-level manifest, or `pkg_version` services.

The Sophon pipeline:

1. fetches HoYoPlay `getGameBranches`;
2. fetches Sophon `getBuild`;
3. selects the game resource manifest and default `en-us` voice manifest;
4. downloads zstd-compressed protobuf manifests;
5. verifies compressed size, decompressed size, and manifest MD5;
6. decodes assets and chunks;
7. plans changed assets by comparing local file size and asset MD5;
8. prunes files outside the target asset set while protecting Wine and launcher
   metadata paths;
9. downloads missing chunks with bounded concurrency;
10. decompresses chunks through in-process `libzstd` when available, falling back
    to the local `zstd` CLI;
11. verifies decompressed chunk MD5;
12. writes chunk payloads by offset into `.nslauncher-sophon-staging`;
13. verifies the full asset MD5 and atomically replaces the final file;
14. writes `.nslauncher-install.json` after the expected executable exists.

`GameUpdatePlan` is now Sophon-specific. It reports latest version, installed
version, target assets, changed assets, skipped assets, compressed download
bytes, decompressed write bytes, peak temporary bytes, and whether metadata needs
rewrite.

## Progress and Control Flow

`InstallProgressEvent` carries the Sophon stages used by the UI:

- preparing an asset;
- downloading Sophon chunks with overall and current-asset byte counts;
- verifying an asset;
- validating install output;
- writing final metadata.

The UI presents:

- overall and current Sophon asset progress;
- a rolling list of active asset paths for concurrent downloads;
- transfer speed and ETA once samples stabilize;
- pause/resume/stop controls for install and update operations;
- a dedicated update log panel;
- a Play/Stop toggle and filtered live log panel for Wine launches.

Pause and stop are cooperative through `OperationController`. Sophon chunk state
is stored beside staging files, so interrupted assets can resume without a
separate package-download checkpoint store.

## Wine Integration

`WineService` is responsible for:

- locating the configured latest WineHQ Devel binary when a game requires Wine;
- preparing the selected prefix;
- bootstrapping DXVK or DXMT into the Wine runtime/prefix;
- building launch commands;
- launching the Windows executable with environment overrides;
- streaming stdout and stderr chunks back to the app shell;
- preflighting DXMT-required `x86_64-unix/winemac.so` exports;
- surfacing targeted launch errors for Wine quarantine, unsupported DXMT builds,
  and unsupported Windows kernel drivers such as `HoYoKProtect.sys`.

Launch display mode is selected before the Wine request is built. Windowed mode
passes `-screen-fullscreen 0 -screen-width 1280 -screen-height 720`; fullscreen
mode passes `-screen-fullscreen 1`.

`BinaryLocator` now manages Wine lookup only. Other sidecars are internal to the
runtime bootstrap or the Sophon decompressor fallback.

## Suggested Next Steps

1. Add selectable voice language for Sophon manifests.
2. Add a repair/validate-only view for already installed files.
3. Add configurable runtime profiles for Wine, DXVK, DXMT, and shaders.
4. Add signing, notarization, and app bundle packaging.
