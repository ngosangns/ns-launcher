# NS Launcher

Native macOS launcher built with `Swift + SwiftUI` for installing, updating, and
launching the global version of Genshin Impact through Wine.

## Screenshots

![NS Launcher](Screenshots/launcher.jpg)

![In-game](Screenshots/in-game.jpg)

## What It Does

- Discovers current HoYoPlay branches and Sophon builds.
- Installs and updates assets with chunk verification, resumable staging, and
  atomic replacement.
- Finds CrossOver or Game Porting Toolkit Wine runtimes and configures D3DMetal,
  DXMT, DXVK, or plain Wine when available.
- Monitors the actual game process and captures filtered Wine diagnostics.
- Manages launcher settings, selected caches, logs, render snapshots, and
  runtime/container size information.

## Current Status

This is an early-stage launcher for one bundled game definition,
`genshin-global`. It is not a general-purpose game catalog.

The installer uses the game resource manifest for installation and update
planning. Voice manifests are inspected for installed voice-pack inventory and
removal, but voice packs are not downloaded by the launcher.

See [developer.md](developer.md) for setup details, architecture, test commands,
runtime paths, and release workflows.

## Sophon Install Flow

The launcher uses HoYoPlay Sophon metadata for both fresh install and update:

1. fetch `getGameBranches` and Sophon `getBuild`;
2. select the game resource manifest and inspect the user-selected voice manifest;
3. download and decode zstd-compressed protobuf manifests;
4. compare local assets by size and MD5;
5. prune files outside the target Sophon asset set while protecting the Wine
   prefix, launcher metadata, and `GenshinImpact_Data/Persistent` (the client's
   own resource downloads and version bookkeeping);
6. download missing or mismatched chunks;
7. decompress and verify each chunk;
8. write chunks into staging files by offset;
9. verify the final asset MD5 and atomically replace the destination;
10. write `.nslauncher-install.json` only after the expected executable exists.

Archive packages, local archive install, generic JSON manifests, and the old
`pkg_version`/file-level streaming path are no longer product paths.

## Requirements

- macOS 14 or later;
- Swift 6.2 or later;
- a compatible Wine build, normally from CrossOver or Game Porting Toolkit;
- internet access for HoYoPlay metadata and game chunks;
- `go-task` for the Taskfile commands.

`zstd` is an optional Homebrew fallback when the system zstd library cannot be
loaded. Screenshot automation also requires Accessibility/Automation permission.

## Build And Run

Run the test suite:

```bash
swift test
```

Run a debug build:

```bash
swift run
```

For an automatic rebuild and relaunch loop, use `task dev`.

Build the optimized release binary:

```bash
task build
```

Assemble a signed `NSLauncher.app` bundle (release build + Info.plist +
ad-hoc codesign) into the SwiftPM release binary directory:

```bash
task bundle
```

Build and move `NSLauncher.app` into `/Applications` (replaces any existing
copy):

```bash
task install
```

`task install` replaces `/Applications/NSLauncher.app`. The bundle is ad-hoc
signed and is assembled in SwiftPM's release binary directory.

Without Taskfile, run the raw release binary produced by SwiftPM:

```bash
swift build -c release
"$(swift build -c release --show-bin-path)/NSLauncherApp"
```
