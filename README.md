# NS Launcher

Native macOS launcher prototype built with `Swift + SwiftUI`, designed for Windows games that run through `Wine`.

## Goals

- Native macOS app shell instead of a webview-based desktop wrapper.
- Installation pipeline that does not require keeping a fully downloaded archive plus a fully extracted game copy at the same time.
- Clear separation between:
  - UI
  - game definitions
  - install planning
  - Wine/runtime integration
  - process execution

## Current scope

This repository is a starter project, not a full production launcher yet.

It already includes:

- a native SwiftUI app
- install planning models
- a manifest-first installer strategy that downloads files directly into the final game directory using per-file `.partial` files
- process wrappers for `wine`, `aria2c`, and external sidecars
- editable game configuration and launch settings
- architecture docs for extending the launcher

## Why this install flow uses less disk

The intended default strategy is:

1. fetch a manifest
2. create the destination tree
3. download each game file to `filename.partial`
4. atomically move it into place
5. continue to the next file

This means the launcher only needs temporary space roughly equal to the largest file currently being written, not the full compressed payload plus the full decompressed payload.

Fallback archive installers can still exist, but they should be treated as compatibility mode rather than the primary path.

## Build

```bash
cd /Users/ngosangns/Github/ns-launcher
swift build
```

## Run

```bash
cd /Users/ngosangns/Github/ns-launcher
swift run
```

## Docs

- [Architecture](docs/architecture.md)
