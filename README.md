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
- official streaming-manifest plumbing for Genshin Impact metadata
- manifest installs that download files directly into the final game directory using per-file `.partial` files
- resumable archive package downloads, including multipart `.zip.001` package flows
- archive extraction through `7zz`/`7z`/`7za`
- import, re-scan, and launch flows for existing installs
- process wrappers for Wine, archive tooling, and other external sidecars
- editable game configuration, language, storage, package, and launch settings
- architecture docs for extending the launcher

## Why this install flow uses less disk

The lowest-amplification strategy is:

1. fetch a manifest
2. create the destination tree
3. download each game file to `filename.partial`
4. atomically move it into place
5. continue to the next file

This means the launcher only needs temporary space roughly equal to the largest file currently being written, not the full compressed payload plus the full decompressed payload.

Archive installers are also supported for package-based ecosystems. They download into the configured cache, extract through the configured temporary extraction directory, merge into the install directory, then remove downloaded cache archives after successful extraction when the launcher downloaded them itself.

## Current Genshin Direction

The bundled `genshin-global` definition uses the official streaming source path. The launcher queries HoYoPlay package metadata, reads the `pkg_version` resource list, and plans or installs those files through the manifest installer when a complete manifest is available.

Fresh streaming installs can still fail if the official metadata endpoint does not expose a complete file manifest. Archive-package install and existing-install import remain available paths when the game definition is configured for them.

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
- [Genshin Install Plan](docs/genshin-install-plan.md)
- [Docs Index](docs/_index.md)
