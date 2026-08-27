# NS Launcher

Native macOS launcher prototype built with `Swift + SwiftUI`, designed to install,
update, and launch Genshin Impact through Wine.

## Goals

- Native macOS app shell instead of a webview-based desktop wrapper.
- Sophon-only game download flow for current HoYoPlay Genshin builds.
- Clear separation between UI, game definitions, Sophon install planning, Wine
  runtime integration, and process execution.

## Current Scope

This repository is a starter project, not a full production launcher yet.

It already includes:

- a native SwiftUI app;
- a single bundled `genshin-global` definition;
- Sophon build discovery through HoYoPlay branch/build metadata;
- zstd-compressed Sophon manifest decoding;
- chunk download, decompression, chunk MD5 verification, asset reconstruction,
  final asset MD5 verification, and atomic replacement;
- `.nslauncher-sophon-staging` resume sidecars for interrupted Sophon assets;
- update planning that skips assets already matching size plus MD5;
- a full-manifest target set: nothing is withheld from the install, because the
  game re-downloads anything missing into `GenshinImpact_Data/Persistent` on its
  own, which saves no space and moves the bytes onto a slower path the launcher
  cannot observe;
- a Settings screen limited to language, install root, display mode, render
  backend, and cache management;
- Wine launch bootstrap that selects Apple D3DMetal or installs DXVK when
  required;
- filtered Wine diagnostics with targeted messages for D3DMetal availability
  and unsupported Windows kernel-driver failures.

## Sophon Install Flow

The launcher uses HoYoPlay Sophon metadata for both fresh install and update:

1. fetch `getGameBranches` and Sophon `getBuild`;
2. select the game resource manifest plus the user-selected voice manifest;
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
- Swift 6.2 or later.

## Production Build

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

Without Taskfile, run the raw release binary produced by SwiftPM:

```bash
swift build -c release
"$(swift build -c release --show-bin-path)/NSLauncherApp"
```

## Development

For a debug build and run loop during development:

```bash
swift run
```

