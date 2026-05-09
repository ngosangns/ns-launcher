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

### Installer strategies

Four strategies are modeled:

- `streamingManifest`
- `manifest`
- `archivePackage`
- `existingInstall`

The bundled Genshin definition uses `streamingManifest` and the official streaming source. Archive-package and existing-install flows are supported when the game definition or user settings select those paths.

#### Streaming manifest strategy

`GenshinStreamingMetadataService` fetches HoYoPlay metadata for `hk4e_global`, derives the resource-list base URL, reads `pkg_version`, and maps each remote entry to a `RemoteGameFile`.

The resulting manifest is installed by `ManifestInstaller`, so the disk usage and progress behavior match the normal manifest path. If the official metadata is unavailable or incomplete, the service reports a localized fresh-install unsupported error instead of silently falling back to stale package assumptions.

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
- resumable per-file `.partial` downloads
- concurrent file downloads capped by the manifest installer

#### Archive package strategy

Supported for `.7z`, `.zip`, `.zip.001` multipart archives, and `.tar.gz` model declarations.

`PackageDownloadService` downloads single or multipart packages into the configured cache directory. It supports byte-range resume when the server exposes `Accept-Ranges: bytes`, stores persisted download checkpoints under the app support download-state directory, validates downloaded part sizes against server metadata, and retries transient connection-loss errors.

`ArchiveInstaller` extracts with a resolved `7zz`/`7z`/`7za` binary into the configured temporary extraction directory, merges extracted files into the install directory, validates the expected executable, and writes `.nslauncher-install.json`.

Downloaded archive cache files are removed after successful extraction when the launcher downloaded the archive itself. Locally selected archive files are left untouched.

#### Existing install strategy

`ImportService` validates a selected install directory by checking the expected executable path, then writes `.nslauncher-install.json` for imported installs. Re-scan reuses the same validation path without rewriting settings beyond the selected install directory changes made by the user.

### Wine integration

`WineService` is responsible for:

- locating a Wine binary
- preparing a prefix
- building launch commands
- launching a Windows executable with environment overrides

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
- pause, resume, and stop controls

Pause for package downloads stores resumable state. Stop clears persisted package-download state for the active game.

## Suggested next steps

1. harden the official streaming manifest path against incomplete upstream metadata
2. add checksum validation and repair mode for streaming and archive installs
3. add import-detected-existing-install discovery
4. add runtime downloader/updater for Wine, DXVK, DXMT, and shaders
5. add signing, notarization, and app bundle packaging
