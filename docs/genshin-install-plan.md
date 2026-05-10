# Genshin Install Plan

## Goal

`ns-launcher` targets a native macOS launcher workflow for `Genshin Impact` through local game files and Wine. The current app supports these product flows:

1. official streaming-source install planning and install when a complete manifest is available
2. archive-package install when a package source is configured
3. local archive install from a user-selected file
4. update existing manifest-backed installs from the latest official resource list
5. launch through Wine

The project does not target cloud gaming.

## Current MVP State

The bundled `genshin-global` game definition uses `streamingManifest` by default. It points at the official HoYoPlay metadata path rather than a hardcoded archive package source. For this streaming layout, the expected Windows executable is:

```text
GenshinImpact.exe
```

Fresh official streaming install depends on HoYoPlay exposing a complete `pkg_version` manifest. The launcher accepts the manifest only when it contains the main executable, `GenshinImpact_Data/app.info`, required data folders, and a plausible full-install byte total. If the official metadata is unavailable or incomplete, the launcher reports that fresh install is unsupported instead of pretending the install can continue.

## Supported Install Sources

### Official Streaming Source

`GenshinStreamingMetadataService` requests HoYoPlay game package metadata for `hk4e_global`, using the selected app language to choose the official metadata language. It reads the returned resource-list base URL and parses `pkg_version` entries into `RemoteGameFile` values, including official MD5 hashes when the resource list provides them.

The manifest installer then downloads files directly into the install directory through `.partial` files. It can resume existing partial files, downloads large files through parallel HTTP byte ranges, retries transient network failures, verifies final file sizes, verifies MD5 or SHA-256 values when a manifest file supplies them, and writes `.nslauncher-install.json` after the expected executable is present.

Downloader implementation details, including current concurrency caps, segmented range state, Sophon chunk state, in-process zstd, and verification boundaries, are maintained in [Downloader Optimization](modules/downloader-optimization.md).

For updates, the launcher can fetch the latest official resource list without requiring it to pass the stricter fresh-install completeness check. It compares the existing install root against the latest list by file size and official hash, prunes files that no longer exist in the target version before downloading new delta files, downloads only the changed files, and rewrites `.nslauncher-install.json` with the latest version. A clean match reports that the game is already up to date.

The update path now uses Sophon metadata for current Genshin builds. If HoYoPlay `getGameBranches` reports a newer Sophon branch such as 6.5.0, the launcher fetches Sophon `getBuild`, selects the game resource manifest plus the default `en-us` voice manifest, decodes zstd-compressed protobuf manifests, resolves existing files by size and asset MD5, and only downloads chunks for assets that are missing or mismatched. The old `getGamePackages`/`pkg_version` path remains a legacy fallback instead of being trusted as latest when it still reports 5.5.0.

The Sophon MVP uses `libzstd` in-process for the main decompression path, with the local `zstd` command-line tool kept only as fallback. It prunes install-root files that are not present in the selected target manifests before downloading new chunks, writes changed assets into `.nslauncher-sophon-staging`, downloads chunks with high concurrency, batches resume state, verifies chunk and final asset MD5, and atomically replaces the final file. Patch/diff Sophon updates and selectable voice language remain follow-up work.

The update flow exposes a dedicated log panel. It records the chosen strategy, install directory, executable, installed/latest version comparison, delta file/byte counts, a bounded sample of changed files, pause/stop requests, coarse progress milestones, validation, metadata writes, and final success or failure details.

### Archive Packages

Archive package installation remains available for game definitions configured with `archivePackage`.

`PackageDownloadService` supports:

- single remote archive downloads
- multipart package downloads through explicit part URLs
- byte-range resume when supported by the server
- persisted paused-download state
- part-size validation from remote metadata
- transfer progress, speed, and ETA reporting

`ArchiveInstaller` extracts through a resolved `7zz`, `7z`, or `7za` binary into the configured temporary extraction directory. It then merges files into the install directory, prunes files not present in the extracted target set, validates the expected executable, writes install metadata, and lets the coordinator clean downloaded cache archives after successful extraction.

## Settings and Runtime

The app persists:

- selected language
- game definitions
- selected game id
- download cache directory
- temporary extraction directory
- launch display mode

Settings exposes directory pickers for storage paths and can open existing download cache, temporary extraction, and selected-game install directories in Finder.

Managed runtime/tool paths are resolved dynamically. Wine candidates are `wine64` and `wine`; archive-tool candidates are `7zz`, `7z`, and `7za`; `aria2c` remains a managed candidate for future sidecar use.

The launcher starts the configured Windows executable through Wine with the configured Wine prefix directory and game arguments. It defaults to windowed mode so Genshin opens as a normal 1280x720 window rather than taking over a fullscreen Space; Settings exposes a `Display mode` segmented control to switch between `Windowed` and `Fullscreen`. The launcher filters stale Unity screen flags from per-game arguments and injects the selected mode at launch time.

The bundled Genshin definition requires DXMT; before launch, `WineService` downloads the pinned DXMT builtin release if needed, verifies the copied payload, installs the Direct3D/Metal bridge into the Wine runtime's `lib/wine` directories and the prefix `system32` directories, and clears prefix DLL overrides that would prevent Wine from using the replaced builtin DLLs. If the selected Wine build cannot expose the macOS window symbols DXMT needs, the launcher reports that compatibility issue directly instead of surfacing the full MoltenVK diagnostic dump.

## Product Labels

Recommended labels in the app:

- `Download & Install`: official streaming source or configured remote package
- `Update Game`: check the latest manifest and download only changed files
- `Install From Local Archive`: configured archive-package games only
- `Launch via Wine`: experimental

## Remaining Work

### Fresh Install Reliability

- Add clearer remediation when official metadata is incomplete.
- Find or derive the current 6.x scattered-file metadata source for Genshin when HoYoPlay package metadata is stale.
- Validate a full clean install against the current official manifest on real storage and Wine setup.

### Repair and Validation

- Expand update reporting into a fuller repair/validation view.
- Expand import validation beyond the executable check.

### Runtime Packaging

- Expand the current pinned DXMT bootstrap into configurable runtime profiles.
- Add configurable runtime profiles after the install/import path is stable.
- Add signing, notarization, and app bundle packaging.

## Key Risks

- Official metadata endpoints can change without notice.
- Genshin package structure can change between versions.
- Local Wine compatibility can break across macOS, Wine, or game updates.
- Archive extraction can require large temporary disk usage for package-based installs.

## Guiding Decisions

- Prefer official streaming metadata when it provides a complete manifest.
- Keep archive install and existing-install import as practical fallback paths.
- Keep local macOS launch labeled experimental until runtime compatibility is proven.
- Prefer a working vertical slice over deeper abstraction.
