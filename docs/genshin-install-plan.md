# Genshin Install Plan

## Goal

Adapt `ns-launcher` to support `Genshin Impact` on macOS with these primary flows:

1. `download + unzip/extract + install`
2. `import existing install`
3. `re-scan / relocate`

This MVP explicitly does **not** target cloud gaming, and does **not** treat `manifest-first` as the main installation path for Genshin.

## MVP Scope

- Download a game package to a local cache
- Extract the package into the final install directory
- Persist local install metadata
- Import an already existing game folder
- Re-scan an imported or installed game folder
- Launch the game through the current local runtime path

## Out of Scope

- Cloud support
- Full manifest-based install flow for Genshin
- Multiple runtime profiles in the first iteration
- Full repair mode with global checksum verification
- Over-engineered service splitting before the end-to-end flow works

## Product Direction

For Genshin, the practical MVP should focus on archive-based installation and existing-install import.

Recommended supported flows:

- `Download & Install`
- `Import Existing Install`
- `Re-scan`
- `Launch`

Recommended product labeling:

- `Install / Import`: supported
- `Local launch on macOS`: experimental

## Implementation Plan

### 1. Extend Domain Models

Update `Sources/NSLauncherApp/Domain/Models.swift`.

Add or revise:

- `InstallerStrategy`
- `PackageSource`
- `ArchiveFormat`
- `InstalledGameMetadata`
- `ImportValidationResult`
- `InstallState`

Recommended `InstallerStrategy` values:

- `archivePackage`
- `existingInstall`
- `manifest`

`manifest` can remain in the codebase for future research, but it should not drive the Genshin MVP.

### 2. Expand GameDefinition

Update `GameDefinition` so a game can declare:

- package URL
- downloaded archive filename
- archive format such as `.7z`, `.zip`, or `.tar.gz`
- expected executable path after extraction
- install root
- prefix root

### 3. Add PackageDownloadService

Create a download service responsible for:

- downloading package files into a cache directory
- resuming partial downloads where feasible
- reporting progress to the UI
- validating basic file presence and size

For MVP, `URLSession` is enough. `aria2c` can remain configurable for later acceleration.

### 4. Add ArchiveInstaller

Create an installer responsible for:

- extracting supported archives into the final install directory
- using temporary paths safely
- validating the expected executable after extraction
- writing install metadata

The first supported format should be whichever archive format is actually used by the real Genshin package flow.

### 5. Add ImportService

Create an import service responsible for:

- validating a selected folder
- checking for expected executable paths
- checking minimum directory structure
- writing launcher metadata for imported installs

### 6. Refactor LauncherCoordinator

Update `Sources/NSLauncherApp/Services/LauncherCoordinator.swift` to route by install strategy instead of assuming everything goes through `ManifestInstaller`.

Coordinator responsibilities should include:

- build install summary
- install from archive
- import install
- re-scan install
- launch game

### 7. Expand Progress Events

Update `InstallProgressEvent` to include archive-flow stages such as:

- `downloadingPackage`
- `extracting`
- `validatingInstall`
- `importing`
- `rescanning`

### 8. Update View Model

Update `Sources/NSLauncherApp/ViewModels/LauncherViewModel.swift` to expose commands for:

- `downloadAndInstallSelectedGame`
- `importSelectedGame`
- `rescanSelectedGame`
- `launchSelectedGame`

### 9. Update UI

Update the SwiftUI views to support:

- `Download & Install`
- `Import Existing Install`
- `Re-scan`
- `Launch`
- progress and status text for download and extraction

### 10. Expand Settings

Add settings for:

- download cache directory
- temporary extraction directory
- default install root
- `7zz` binary path
- runtime binary path

### 11. Standardize Install Metadata

Persist `.nslauncher-install.json` with at least:

- game id
- install mode
- install timestamp
- source archive name or imported folder marker
- executable path
- version if known

### 12. Keep Runtime Simple for MVP

Continue using the current runtime launch path first. Do not split into multiple runtime profiles until installation and import already work end to end.

## Suggested Milestones

### Milestone 1

- extend models
- add import flow
- validate imported installs
- launch imported game

### Milestone 2

- add package download
- add archive extraction
- install from package
- launch installed game

### Milestone 3

- add re-scan / relocate
- improve progress reporting
- improve error handling
- clean up metadata and settings UX

## Key Risks

- local runtime compatibility on macOS may break across Genshin updates
- real-world package structure may change
- archive extraction can require large temporary disk usage if handled poorly

## Guiding Decisions

- prioritize end-to-end archive install over manifest research
- prefer a working vertical slice over deep abstraction
- label local macOS launch as experimental until it proves stable

## Research Findings

### Current Packaging Direction

Research on 2026-04-23 suggests these practical conclusions for Genshin:

- prioritize `.7z` support
- support `.zip` next
- expect split archives such as `.zip.001` in some community-documented flows
- do not prioritize `.tar` for core game installation

### Executable Path

The commonly referenced Windows executable path for Genshin is:

- `Genshin Impact Game/GenshinImpact.exe`

This path appears consistently in community troubleshooting threads and is a reasonable default for import validation and post-install checks.

### Official and Ecosystem Signals

- HoYoPlay support documentation for related games shows a manual package flow based on downloading archives, extracting them manually, then using a relocate/find-game flow.
- HoYo ecosystem materials also show launcher-side distribution via `.zip`.
- Community launcher documentation for Genshin on macOS mentions split archive pieces in real-world install/update workflows.

### Product Implication

For this project, the most useful install order is:

1. local archive install
2. import existing install
3. optional direct package download once reliable URLs are available
