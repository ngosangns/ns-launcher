# Genshin Install Plan

## Goal

`ns-launcher` targets a native macOS launcher workflow for `Genshin Impact` through local game files and Wine. The current app supports these product flows:

1. official streaming-source install planning and install when a complete manifest is available
2. archive-package install when a package source is configured
3. local archive install from a user-selected file
4. import existing install
5. re-scan / relocate
6. launch through Wine

The project does not target cloud gaming.

## Current MVP State

The bundled `genshin-global` game definition uses `streamingManifest` by default. It points at the official HoYoPlay metadata path rather than a hardcoded archive package source. The expected Windows executable remains:

```text
Genshin Impact Game/GenshinImpact.exe
```

Fresh official streaming install depends on HoYoPlay exposing a complete `pkg_version` manifest. If the official metadata is unavailable or incomplete, the launcher reports that fresh install is unsupported instead of pretending the install can continue.

## Supported Install Sources

### Official Streaming Source

`GenshinStreamingMetadataService` requests HoYoPlay game package metadata for `hk4e_global`, using the selected app language to choose the official metadata language. It reads the returned resource-list base URL and parses `pkg_version` entries into `RemoteGameFile` values.

The manifest installer then downloads files directly into the install directory through `.partial` files. It can resume existing partial files, retries transient network failures, verifies final file sizes, optionally verifies SHA-256 values when a manifest file supplies them, and writes `.nslauncher-install.json` after the expected executable is present.

### Archive Packages

Archive package installation remains available for game definitions configured with `archivePackage`.

`PackageDownloadService` supports:

- single remote archive downloads
- multipart package downloads through explicit part URLs
- byte-range resume when supported by the server
- persisted paused-download state
- part-size validation from remote metadata
- transfer progress, speed, and ETA reporting

`ArchiveInstaller` extracts through a resolved `7zz`, `7z`, or `7za` binary into the configured temporary extraction directory. It then merges files into the install directory, validates the expected executable, writes install metadata, and lets the coordinator clean downloaded cache archives after successful extraction.

### Existing Installs

Import and re-scan validate an existing directory by checking the expected executable path. Import writes launcher metadata for the selected folder. Re-scan reports whether the current install directory still looks valid.

## Settings and Runtime

The app persists:

- selected language
- game definitions
- selected game id
- download cache directory
- temporary extraction directory

Managed runtime/tool paths are resolved dynamically. Wine candidates are `wine64` and `wine`; archive-tool candidates are `7zz`, `7z`, and `7za`; `aria2c` remains a managed candidate for future sidecar use.

The launcher currently starts the configured Windows executable through Wine with the configured Wine prefix directory and game arguments.

## Product Labels

Recommended labels in the app:

- `Download & Install`: official streaming source or configured remote package
- `Install From Local Archive`: configured archive-package games only
- `Import Existing Install`: supported
- `Re-scan`: supported
- `Launch via Wine`: experimental

## Remaining Work

### Fresh Install Reliability

- Confirm whether the official `pkg_version` resource list is complete enough for a clean Genshin install.
- Add clearer remediation when official metadata is incomplete.
- Add checksum support for hashes provided by official metadata.

### Repair and Validation

- Add repair mode for missing or corrupted files.
- Persist and compare installed version metadata.
- Expand import validation beyond the executable check.

### Runtime Packaging

- Add runtime downloader/updater for Wine and graphics layers.
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
