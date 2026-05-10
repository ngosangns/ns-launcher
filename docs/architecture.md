# Architecture

## Overview

`NS Launcher` is a native macOS launcher with a `SwiftUI` front-end and a service-oriented backend.

Main layers:

- `App`: application lifecycle and screen composition
- `Domain`: pure models for games, manifests, install plans, and settings
- `Services`: file system, networking, install pipeline, Wine integration, sidecars
- `ViewModels`: UI-facing state and commands

The launcher currently focuses on a single bundled Genshin Impact definition while keeping the domain model generic enough for other Windows games.

## Main components

### App shell

- `NSLauncherApp`
- `LauncherViewModel`
- `ContentView`

The app shell owns UI state and delegates all work to services.

`LauncherViewModel` coordinates long-running UI operations through `OperationController`, translates service progress events into localized status text, and preserves resumable package-download state when a user pauses a download.

### Game definitions

`GameDefinition` describes a game channel:

- stable identifier
- display name
- install root
- executable path
- Wine prefix path
- installer strategy
- manifest URL or package source
- runtime requirements
- launch arguments

This keeps game-specific data declarative.

`AppSettings.launchDisplayMode` owns Wine launch display behavior globally. The launcher defaults to windowed mode and injects Unity-compatible screen arguments at launch time. User-provided screen flags such as `-screen-fullscreen`, `-screen-width`, `-screen-height`, and `-popupwindow` are filtered from per-game arguments so the Settings toggle remains authoritative.

### Installer strategies

Four strategies are modeled:

- `streamingManifest`
- `manifest`
- `archivePackage`
- `existingInstall`

The bundled Genshin definition uses `streamingManifest` and the official streaming source. Archive-package and existing-install flows are supported when the game definition or user settings select those paths.

#### Streaming manifest strategy

`GenshinStreamingMetadataService` fetches HoYoPlay metadata for `hk4e_global`, derives the resource-list base URL, reads `pkg_version`, and maps each remote entry to a `RemoteGameFile`.

Downloader concurrency, range resume, Sophon chunk reconstruction, resume sidecars, and checksum boundaries are documented in [Downloader Optimization](modules/downloader-optimization.md).

The resulting manifest is installed by `ManifestInstaller`, so the disk usage and progress behavior match the normal manifest path. Before accepting the official file list, the service checks that the manifest looks complete enough for a fresh install: it must include the main executable, `GenshinImpact_Data/app.info`, key data folders, and a plausible total byte size. If the official metadata is unavailable or incomplete, the service reports a localized fresh-install unsupported error instead of silently falling back to stale package assumptions.

For Genshin specifically, update checks now prefer the newer HoYoPlay Sophon branch when the game uses `streamingManifest`. `GenshinSophonInstaller` reads `getGameBranches`, fetches Sophon `getBuild`, selects the game resource manifest plus the default `en-us` voice manifest, downloads zstd-compressed protobuf manifests, decodes assets and chunks, and plans changed assets by size plus MD5. Existing assets that already match the Sophon size and asset MD5 are counted as skipped and are not passed to the chunk downloader. The legacy `pkg_version` path remains available for old file-level manifests, but current Genshin 6.x updates use Sophon metadata instead of reporting the stale 5.5.0 source.

Sophon updates reconstruct files from chunks. Each changed asset is staged under `.nslauncher-sophon-staging`; chunks are downloaded from the Sophon chunk base URL through a high-concurrency URLSession and a global request limiter, decompressed in-process through `libzstd`, verified by decompressed chunk MD5, written at the declared file offset through an asset writer that keeps the staging file open, then the full asset is verified by MD5 before atomic replacement. Resume sidecar state is batched instead of rewritten after every chunk. The MVP keeps patch/diff Sophon support as follow-up work.

#### Manifest strategy

Best for low disk amplification.

Flow:

1. fetch remote manifest
2. compare with local install state
3. download missing or outdated files directly into final destination with `.partial`
4. rename on success

Disk usage characteristics:

- no full archive staging
- temporary space roughly bounded by the largest active file and a small metadata cache
- resumable per-file `.partial` downloads, including segment sidecar state for large files
- concurrent file downloads capped by the manifest installer
- large files are downloaded with parallel HTTP byte ranges when the server supports `206 Partial Content`
- official MD5 metadata is verified when available, with SHA-256 still supported for generic manifests

Manifest-backed games also support an update flow. The coordinator fetches the latest manifest, reads `.nslauncher-install.json`, and asks `ManifestInstaller` to compare each local file by size plus MD5 or SHA-256 when available. Before downloading the delta, files under the install root that are no longer present in the target manifest are pruned while launcher metadata, staging folders, resumable partials, and the Wine prefix are preserved. Only missing, truncated, oversized, or checksum-mismatched files are downloaded again. If every file matches and metadata is current, the UI reports that the game is already up to date; otherwise the same `.partial` and segmented download pipeline updates only the delta and rewrites install metadata for the latest version.

The update UI keeps a dedicated log panel separate from Wine diagnostics. It records the selected strategy, install root, executable path, local/latest versions, delta size, skipped file count, a bounded sample of changed files, pause/stop requests, coarse transfer milestones, validation, metadata writes, and final success or failure messages.

#### Archive package strategy

Supported for `.7z`, `.zip`, `.zip.001` multipart archives, and `.tar.gz` model declarations.

`PackageDownloadService` downloads single or multipart packages into the configured cache directory. It supports byte-range resume when the server exposes `Accept-Ranges: bytes`, stores persisted download checkpoints under the app support download-state directory, validates downloaded part sizes against server metadata, and retries transient connection-loss errors.

`ArchiveInstaller` extracts with a resolved `7zz`/`7z`/`7za` binary into the configured temporary extraction directory, merges extracted files into the install directory, prunes files not present in the extracted target set, validates the expected executable, and writes `.nslauncher-install.json`.

Downloaded archive cache files are removed after successful extraction when the launcher downloaded the archive itself. Locally selected archive files are left untouched.

### Wine integration

`WineService` is responsible for:

- locating a Wine binary, including DXMT-compatible CrossOver, Whisky, and Yaagl libraries under Application Support when a game requires DXMT
- preparing a prefix
- bootstrapping DXVK or DXMT into prefixes for game definitions that require a graphics bridge
- building launch commands
- launching a Windows executable with environment overrides
- streaming stdout and stderr chunks back to the app shell for live Wine diagnostics
- preflighting DXMT-required `x86_64-unix/winemac.so` exports and surfacing targeted launch errors instead of raw graphics backend dumps

Launch display mode is selected before the Wine request is built. Windowed mode passes `-screen-fullscreen 0 -screen-width 1280 -screen-height 720` so games open in a normal window instead of taking over a fullscreen Space. Fullscreen mode passes `-screen-fullscreen 1`.

`BinaryLocator` resolves managed tools from an explicit preferred path when present, then searches `PATH` and common macOS package-manager directories. Managed candidates currently cover Wine, `aria2c`, and 7-Zip binaries.

### Sidecars

`SidecarTooling` models external helpers such as:

- `aria2c`
- `7zz`
- patchers

These are configured by path rather than hardcoded into the app.

Current settings keep storage locations persisted, while managed binary paths are resolved at runtime and deprecated custom binary path values are ignored when older settings files are decoded.

### Progress and control flow

`InstallProgressEvent` carries the current installation stage, item path, byte counts, multipart part counts, and manifest file progress.

The UI presents:

- overall and current-part progress
- current manifest items for concurrent streaming downloads
- transfer speed and ETA once samples stabilize
- pause, resume, and stop controls for install operations
- a dedicated update log panel for manifest delta updates
- a Play/Stop toggle and filtered live log panel for Wine launches

Pause for package downloads stores resumable state. Stop clears persisted package-download state for the active game.

## Suggested next steps

1. add import-detected-existing-install discovery
2. make archive fallback disk estimates account for extraction staging
3. add configurable runtime profiles for Wine, DXVK, DXMT, and shaders
4. add signing, notarization, and app bundle packaging
