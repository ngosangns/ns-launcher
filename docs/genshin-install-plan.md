# Genshin Install Plan

## Goal

`ns-launcher` targets a native macOS launcher workflow for Genshin Impact through
local game files and Wine. The current product flow is Sophon-only:

1. plan a fresh install or update from HoYoPlay Sophon metadata;
2. download and reconstruct missing or changed assets from Sophon chunks;
3. write install metadata after validation;
4. launch through Wine.

The project does not target cloud gaming and no longer exposes archive package,
local archive, import, generic manifest, or file-level streaming download paths.

## Current MVP State

The bundled `genshin-global` game definition uses the `sophon` strategy. The
expected Windows executable is:

```text
GenshinImpact.exe
```

Fresh install and update share the same Sophon backend. The launcher fetches
HoYoPlay branch/build metadata, selects the game resource manifest plus the
default `en-us` voice manifest, decodes zstd-compressed protobuf manifests, and
plans work by comparing local files with Sophon asset size plus MD5.

## Sophon Install and Update Source

`GenshinSophonInstaller` requests:

- `getGameBranches` for the live package id and branch password;
- Sophon `getBuild` for the selected branch/package;
- manifest download URLs and chunk base URLs for the selected categories.

The installer downloads zstd-compressed manifests, verifies compressed size,
decompresses them, verifies manifest MD5, and decodes asset/chunk metadata.

For each asset that is missing or mismatched locally, the installer:

1. creates a staging file under `.nslauncher-sophon-staging`;
2. downloads compressed chunks with bounded concurrency;
3. decompresses each chunk through `libzstd` when available, falling back to the
   `zstd` CLI;
4. verifies each decompressed chunk MD5;
5. writes chunks into the staging file at their declared offsets;
6. saves chunk resume state in batched sidecars;
7. verifies the final asset MD5;
8. atomically replaces the destination file.

Before applying the target asset set, the installer prunes files no longer
present in the selected Sophon manifests while preserving the Wine prefix,
launcher metadata, staging files, and resume sidecars.

The update flow exposes a dedicated log panel. It records source `sophon`,
install directory, executable, runtime requirements, installed/latest version,
changed/skipped asset counts, compressed download bytes, decompressed write
bytes, peak temporary bytes, representative changed assets, pause/stop requests,
coarse progress milestones, validation, metadata writes, and final success or
failure details.

## Settings and Runtime

The app persists:

- selected language;
- game definitions;
- selected game id;
- launch display mode.

Settings exposes:

- language;
- install root;
- executable path;
- launch display mode.

Settings intentionally does not expose download cache, temporary extraction,
archive package URLs, local archive install, or generic manifest controls.

The launcher starts the configured Windows executable through Wine with the
configured Wine prefix directory and game arguments. It defaults to windowed mode
so Genshin opens as a normal 1280x720 window; Settings exposes a `Display mode`
segmented control to switch between `Windowed` and `Fullscreen`.

The bundled Genshin definition requires DXMT. Before launch, `WineService`
downloads the pinned DXMT builtin release if needed, verifies the copied payload,
installs the Direct3D/Metal bridge into the Wine runtime and prefix system
directories, and clears prefix DLL overrides that would prevent Wine from using
the replaced builtin DLLs.

Wine on macOS cannot load Windows kernel drivers. If the game attempts to start a
driver such as `HoYoKProtect.sys`, the launcher surfaces a targeted Wine kernel
driver error instead of reporting a generic process failure.

## Product Labels

Recommended labels in the app:

- `Download & Install`: install from official Sophon chunks;
- `Update Game`: check the latest Sophon build and download changed assets;
- `Launch via Wine`: experimental.

## Remaining Work

### Sophon Coverage

- Add selectable voice language.
- Validate a full clean install against the current official Sophon build on real
  storage and Wine setup.
- Add a repair/validate-only view for existing files.

### Runtime Packaging

- Expand the current pinned DXMT bootstrap into configurable runtime profiles.
- Add signing, notarization, and app bundle packaging.

## Key Risks

- Official HoYoPlay/Sophon endpoints can change without notice.
- Genshin package structure can change between versions.
- Local Wine compatibility can break across macOS, Wine, or game updates.
- Current Genshin builds may require Windows kernel protection drivers that Wine
  cannot load.

## Guiding Decisions

- Prefer the current official Sophon metadata path over older file-level sources.
- Keep the app Sophon-only until the product needs another supported game.
- Keep local macOS launch labeled experimental until runtime compatibility is
  proven.
- Prefer a working vertical slice over deeper abstraction.
