# Architecture

## Overview

`NS Launcher` is a native macOS launcher with a `SwiftUI` front-end and a service-oriented backend.

Main layers:

- `App`: application lifecycle and screen composition
- `Domain`: pure models for games, manifests, install plans, and settings
- `Services`: file system, networking, install pipeline, Wine integration, sidecars
- `ViewModels`: UI-facing state and commands

## Main components

### App shell

- `NSLauncherApp`
- `LauncherViewModel`
- `ContentView`

The app shell owns UI state and delegates all work to services.

### Game definitions

`GameDefinition` describes a game channel:

- stable identifier
- display name
- install root
- executable path
- Wine prefix path
- installer strategy
- runtime requirements

This keeps game-specific data declarative.

### Installer strategies

Two strategies are modeled:

- `manifest`
- `segmentedArchive`

The launcher is intentionally optimized around `manifest`.

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

#### Segmented archive strategy

Supported as a compatibility path for ecosystems that only ship split archives or patch blobs.

This project keeps the abstraction but treats it as secondary because it often requires extra temporary space.

### Wine integration

`WineService` is responsible for:

- locating a Wine binary
- preparing a prefix
- building launch commands
- launching a Windows executable with environment overrides

### Sidecars

`SidecarTooling` models external helpers such as:

- `aria2c`
- `7zz`
- patchers

These are configured by path rather than hardcoded into the app.

## Suggested next steps

1. add real manifest fetch/parsing for a target game
2. add checksum validation and repair mode
3. add import-detected-existing-install flow
4. add updater/runtime downloader for Wine, DXVK, DXMT, and shaders
5. add signing, notarization, and app bundle packaging
