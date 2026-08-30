// LauncherCoordinator.swift
//
// Facade the view model talks to: it owns the settings store, the Sophon installer,
// and the Wine service, and coordinates install/update/launch.
//
// ============================================================================
// Anti-cheat bypass stack (Genshin Impact global, mirrors YAAGL's hk4e handling)
// ============================================================================
// Genshin cannot run under Wine without several coordinated workarounds. Each step
// below fixes a DIFFERENT, independently-observed failure, so none of them is
// redundant and none may be removed without re-introducing that specific failure.
// They are all unsupported by HoYoverse and risk the account; they are isolated
// here and gated by settings flags that can be turned off.
//
// Launch path, in order:
//   1. Build the runtime profile and run preflight checks (executable exists, valid
//      `.nslauncher-install.json` with matching game id, no partial staging).
//   2. Cloud compatibility (default-on): install a `HoYoKProtect.sys` stub into the
//      Wine prefix AND launch with `-platform_type CLOUD_THIRD_PARTY_PC -is_cloud 1`
//      (the flags are appended in `LaunchRuntimeProfile.build`). Without this the
//      Windows client aborts early because Wine cannot load the real kernel driver.
//   3. AC patch (default-on): temporarily move the crash reporter and Vulkan fallback
//      files to `.bak` for the launch, restored via `defer`. Mirrors YAAGL's current
//      Genshin-global `removed[]` list (its binary xdelta3 `patched[]` list is empty,
//      so no binary diff is applied here).
//   4. Network block (default-on): write anti-cheat/telemetry hosts into the Wine
//      prefix hosts file, removed via `defer` after the game exits. CRITICAL DETAIL:
//      the dispatch host is blocked for only 10 seconds (see `dispatchBlockHost`),
//      NOT for the whole launch — see the warning on `blockedHosts` below.
//
// Known failure signatures each step prevents (kept here so future edits know what
// breaks if a step is removed):
//   - Missing cloud flags / driver stub  -> game aborts at launch (anti-cheat driver
//     load, `initDriver Failed` / `HoYoKProtect.sys` abort).
//   - Missing steam.exe parent (see WineService) -> HoYoKProtect loads and aborts.
//   - Blocking the dispatch host for the WHOLE launch -> game disconnects ~10 minutes
//     after login ("ClearOnDisconnect" then kicked back to the title/waiting screen),
//     because the client cannot re-dispatch to a game server. YAAGL only blocks it
//     for the anti-cheat init window, then unblocks it.
//   - msync (`WINEMSYNC`) crashed twice on this stack — once as `wine client error:308:
//     partial wakeup read 0` + `err:virtual:virtual_setup_exception` (render-path crash)
//     on an earlier Wine pin, and once again after being re-tried unconditionally, killing
//     the game with exit code 5 during shader translation. Both render bridges therefore
//     stay on esync (`WINEESYNC`); see `D3DMetalBridge.launchEnvironment`.

import Foundation

import Darwin

/// Facade that coordinates persistence, the Sophon installer, and Wine launching.
struct LauncherCoordinator: Sendable {
    private let settingsStore: SettingsStoring
    private let sophonInstaller: SophonInstalling
    private let wineService: WineServicing
    /// Used by launch preflight to see whether the game is already running.
    private let processRunner: ProcessRunning

    /// Injects every side-effecting service so the view model stays UI-focused.
    init(
        settingsStore: SettingsStoring,
        sophonInstaller: SophonInstalling,
        wineService: WineServicing,
        processRunner: ProcessRunning
    ) {
        self.settingsStore = settingsStore
        self.sophonInstaller = sophonInstaller
        self.wineService = wineService
        self.processRunner = processRunner
    }

    /// Loads persisted application settings.
    func loadSettings() throws -> AppSettings {
        try settingsStore.load()
    }

    /// Saves application settings after UI changes.
    func saveSettings(_ settings: AppSettings) throws {
        try settingsStore.save(settings)
    }

    /// Builds a Sophon delta update plan for an existing game install.
    func fetchUpdatePlan(
        for game: GameDefinition,
        settings: AppSettings,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> GameUpdatePlan {
        let build = try await sophonInstaller.fetchBuild(
            language: settings.language,
            onEvent: onEvent
        )
        return try await sophonInstaller.planUpdate(
            for: game,
            build: build,
            installedMetadata: installedMetadata(for: game),
            onEvent: onEvent
        )
    }

    /// Builds locally present content inventory using live Sophon manifests.
    func fetchStorageInventory(
        for game: GameDefinition,
        settings: AppSettings,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> GameStorageInventory {
        try await sophonInstaller.fetchStorageInventory(game: game, language: settings.language, onEvent: onEvent)
    }

    /// Removes the local files of one non-selected voice pack.
    func removeVoicePack(
        matchingField: String,
        game: GameDefinition,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> Int64 {
        try await sophonInstaller.removeVoicePack(matchingField: matchingField, game: game, onEvent: onEvent)
    }

    /// Scans removable cache categories for the selected game and returns their on-disk sizes.
    func fetchCacheReport(for game: GameDefinition) -> [RemovableCache] {
        RemovableCache.Kind.allCases.map { kind in
            RemovableCache(
                kind: kind,
                sizeBytes: Self.cacheLocations(for: kind, game: game)
                    .reduce(0) { $0 + Self.sizeBytes(of: $1) }
            )
        }
    }

    /// Removes one removable cache category and returns the number of bytes freed.
    func clearCache(_ kind: RemovableCache.Kind, for game: GameDefinition) throws -> Int64 {
        if kind == .d3dMetalShaderCache {
            let executableName = URL(fileURLWithPath: game.executableRelativePath).lastPathComponent
            return try D3DMetalBridge.clearShaderCaches(forExecutable: executableName)
        }

        let locations = Self.cacheLocations(for: kind, game: game)
        let freed = locations.reduce(0) { $0 + Self.sizeBytes(of: $1) }
        for location in locations {
            try Self.remove(location)
        }
        return freed
    }

    /// Installs CrossOver via Homebrew so `D3DMetalBridge` has a build to select. Only ever called
    /// from an explicit user action — see `CrossOverInstaller` for why this must never run on its
    /// own (a paid trial and, if Homebrew is missing, a system-level installer this launcher will
    /// not run on the user's behalf).
    func installCrossOverViaHomebrew(onDiagnostic: @escaping @Sendable (String) -> Void) async throws {
        try await CrossOverInstaller.install(processRunner: processRunner, onDiagnostic: onDiagnostic)
    }

    /// A cache target: either everything inside a directory, or a single archive file.
    private enum CacheLocation {
        case directoryContents(URL)
        case file(URL)
    }

    /// Maps each cache kind to the concrete paths that hold it.
    private static func cacheLocations(for kind: RemovableCache.Kind, game: GameDefinition) -> [CacheLocation] {
        let dataDir = game.installDirectory.appendingPathComponent("GenshinImpact_Data", isDirectory: true)
        switch kind {
        case .cutsceneVideos:
            return [.directoryContents(dataDir.appendingPathComponent("Persistent/VideoAssets", isDirectory: true))]
        case .gameWebCache:
            return [.directoryContents(dataDir.appendingPathComponent("webCaches", isDirectory: true))]
        case .gameSDKCache:
            return [.directoryContents(dataDir.appendingPathComponent("SDKCaches", isDirectory: true))]
        case .gameWorldAssetCache:
            return gameWorldAssetCacheLocations(dataDir: dataDir)
        case .winePrefixTemp:
            return winePrefixTempLocations(prefixDirectory: game.winePrefixDirectory)
        case .launcherDownloadArchives:
            return launcherDownloadArchiveLocations()
        case .d3dMetalShaderCache:
            let executableName = URL(fileURLWithPath: game.executableRelativePath).lastPathComponent
            guard let directory = D3DMetalBridge.shaderCacheDirectory(forExecutable: executableName) else { return [] }
            return [.directoryContents(directory)]
                + D3DMetalBridge.durableCacheDirectories(forExecutable: executableName)
                    .map(CacheLocation.directoryContents)
        }
    }

    /// Everything that tracks the version of `Persistent/AssetBundles`, alongside the block data
    /// itself.
    ///
    /// The client keeps its own revision/version-manifest files in `Persistent/` that say which
    /// revision of world-block data it believes it already has cached — separate from (and
    /// normally ahead of) the counters baked into `StreamingAssets/AssetBundles` at install time.
    /// Deleting only the block data while leaving these counters behind is worse than not clearing
    /// at all: the client still believes it is on the newer revision the counters name, tries to
    /// use block data for that revision, and finds none — producing missing models and wrong
    /// textures instead of a clean re-download. Every location here must be cleared together so
    /// the client falls back to a consistent state (matching `StreamingAssets`) and re-derives
    /// everything from there, rather than a state no revision ever actually had.
    ///
    /// The exact file names are not stable: a real prefix (`ngosangns`) install was observed to
    /// rename `res_revision`/`data_revision`/`res_versions_persist`/`data_versions_persist` to
    /// `base_revision`/`res_versions_remote`/`data_versions_remote`/`cache_versions_<revision>`
    /// between two launches a couple hours apart, with the old-scheme `silence_data_versions_persist`
    /// left behind uncleaned next to the new `silence_data_versions_remote` — the client's own
    /// migration between schemes is not itself reliably clean. Matching by name prefix rather than
    /// a fixed list is what survives a scheme the client switches to next.
    private static func gameWorldAssetCacheLocations(dataDir: URL) -> [CacheLocation] {
        let persistent = dataDir.appendingPathComponent("Persistent", isDirectory: true)
        let versionFilePrefixes = [
            "res_revision", "data_revision", "silence_revision", "base_revision", "base_res_version_hash",
            "res_versions_", "data_versions_", "silence_data_versions_", "cache_versions_", "ctable.dat"
        ]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: persistent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let versionFileLocations = entries.compactMap { url -> CacheLocation? in
            let name = url.lastPathComponent
            guard versionFilePrefixes.contains(where: { name.hasPrefix($0) }) else { return nil }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else { return nil }
            return .file(url)
        }
        return [.directoryContents(persistent.appendingPathComponent("AssetBundles", isDirectory: true))] + versionFileLocations
    }

    /// Temporary files inside the Wine prefix: the Windows temp dir plus each user's Temp dir.
    private static func winePrefixTempLocations(prefixDirectory: URL) -> [CacheLocation] {
        let driveC = prefixDirectory.appendingPathComponent("drive_c", isDirectory: true)
        var locations: [CacheLocation] = [
            .directoryContents(driveC.appendingPathComponent("windows/temp", isDirectory: true))
        ]
        let users = driveC.appendingPathComponent("users", isDirectory: true)
        let userDirectories = (try? FileManager.default.contentsOfDirectory(
            at: users,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for userDirectory in userDirectories {
            locations.append(.directoryContents(userDirectory.appendingPathComponent("Temp", isDirectory: true)))
        }
        return locations
    }

    /// Compressed archives the launcher downloaded but no longer needs after extraction.
    private static func launcherDownloadArchiveLocations() -> [CacheLocation] {
        let cacheRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/NSLauncher", isDirectory: true)
        let directories = ["DXVK", "Wine"].map { cacheRoot.appendingPathComponent($0, isDirectory: true) }
        var locations: [CacheLocation] = []
        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { continue }
            for case let fileURL as URL in enumerator {
                let name = fileURL.lastPathComponent
                if name.hasSuffix(".tar.gz") || name.hasSuffix(".tar.xz") {
                    locations.append(.file(fileURL))
                }
            }
        }
        return locations
    }

    /// Returns the total byte size of one cache location.
    private static func sizeBytes(of location: CacheLocation) -> Int64 {
        switch location {
        case let .file(url):
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { return 0 }
            return Int64(values.fileSize ?? 0)
        case let .directoryContents(url):
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
            ) else { return 0 }
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if values?.isRegularFile == true {
                    total += Int64(values?.fileSize ?? 0)
                }
            }
            return total
        }
    }

    /// Removes one cache location. Directory contents are emptied without removing the
    /// directory itself, so the game can keep writing to the same path.
    private static func remove(_ location: CacheLocation) throws {
        let fileManager = FileManager.default
        switch location {
        case let .file(url):
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        case let .directoryContents(url):
            let entries = (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []
            for entry in entries {
                try? fileManager.removeItem(at: entry)
            }
        }
    }

    /// Applies a previously computed Sophon update plan.
    func updateGame(
        _ game: GameDefinition,
        settings: AppSettings,
        plan: GameUpdatePlan,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await applySophonPlan(game, plan: plan, operationController: operationController, onEvent: onEvent)
    }

    /// Builds a launch profile, runs preflight checks, then launches through Wine.
    func launchGame(
        _ game: GameDefinition,
        settings: AppSettings,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)? = nil
    ) async throws -> ProcessResult {
        let profile = LaunchRuntimeProfile.build(game: game, settings: settings)

        // Preflight: executable must exist
        guard FileManager.default.fileExists(atPath: profile.executablePath.path) else {
            throw LaunchPreflightError.missingExecutable(profile.executablePath.path)
        }

        // Preflight: install metadata must exist and be valid
        let metadataURL = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        guard let metadataData = try? Data(contentsOf: metadataURL) else {
            throw LaunchPreflightError.missingInstallMetadata
        }
        let metadata: InstalledGameMetadata
        do {
            metadata = try JSONDecoder().decode(InstalledGameMetadata.self, from: metadataData)
        } catch {
            throw LaunchPreflightError.invalidInstallMetadata(error.localizedDescription)
        }
        if metadata.gameID != game.id {
            throw LaunchPreflightError.invalidInstallMetadata("gameID mismatch: expected \(game.id), got \(metadata.gameID)")
        }

        // Preflight: staging must not hold leftover partial work (update in progress).
        // Empty directories left after a completed update are not in-progress work.
        let stagingURL = game.installDirectory.appendingPathComponent(".nslauncher-sophon-staging")
        if hasLeftoverStagingWork(at: stagingURL) {
            throw LaunchPreflightError.updateRequiredBeforeLaunch("Partial update staging detected. Run Update Game to complete.")
        }

        // Preflight: the prefix must not already have this game in it.
        //
        // A Wine prefix is single-tenant. A second client attaching to the running wineserver
        // deadlocks inside the loader rather than failing, so both sessions sit at 0% CPU with no
        // error — which is indistinguishable from "still loading" and was the reported symptom.
        // Rather than surface that as an error, Play kills the leftover instance itself — an old
        // session (crashed wrapper, force-quit launcher, force-quit game) commonly leaves the game
        // executable running with nothing left to stop it from the UI. This check only covers the
        // game's own executable; a stale wineserver from a *previous* session left running by an
        // old build (see `WineService.waitForWineserver`, now `-k` instead of `-w`) still gets
        // silently reused by this launch. If a prefix somehow still carries one from before that
        // fix, its leftover `winedevice.exe`/`services.exe` should be killed by hand once
        // (`pkill -f winedevice.exe`) — the prefix does not self-heal.
        let runningPIDs = await GameProcessInspector.runningProcessIDs(forExecutable: profile.executablePath)
        if !runningPIDs.isEmpty {
            await Self.terminate(pids: runningPIDs, executable: profile.executablePath)
            let survivors = await GameProcessInspector.runningProcessIDs(forExecutable: profile.executablePath)
            if !survivors.isEmpty {
                throw LaunchPreflightError.gameAlreadyRunning(survivors.sorted())
            }
        }

        if settings.cloudCompatibilityMode {
            try installProtectionDriverStub(for: game, prefixDirectory: profile.prefixDirectory)
        }

        if settings.acPatchMode {
            try applyACPatch(for: game, apply: true)
        }
        defer {
            if settings.acPatchMode {
                try? applyACPatch(for: game, apply: false)
            }
        }

        if settings.blockNetMode {
            try installHostsBlock(in: profile.prefixDirectory)
            // YAAGL blocks the dispatch host only during the anti-cheat init window, then unblocks it
            // so the game can re-dispatch without being kicked back to the title screen. The telemetry
            // hosts stay blocked for the whole launch.
            let prefixDirectory = profile.prefixDirectory
            Task.detached {
                try? await Task.sleep(nanoseconds: Self.dispatchBlockDurationNanoseconds)
                try? Self.unblockDispatchHost(in: prefixDirectory)
            }
        }
        defer {
            if settings.blockNetMode {
                try? removeHostsBlock(in: profile.prefixDirectory)
            }
        }

        let request = WineLaunchRequest(
            wineBinaryPath: profile.wineBinaryPath,
            prefixDirectory: profile.prefixDirectory,
            executablePath: profile.executablePath,
            arguments: profile.arguments,
            environment: profile.environment,
            currentDirectory: profile.currentDirectory,
            runtimeRequirements: profile.runtimeRequirements,
            renderBackend: profile.backend,
            useSteamLauncher: settings.steamPatch,
            macDriverRetina: settings.macDriverRetina,
            leftCommandIsCtrl: settings.leftCommandIsCtrl,
            // Same size the launch arguments carry, so the registry cannot contradict them.
            renderSize: profile.renderSize,
            enableHDR: settings.enableHDR,
            fullscreen: profile.fullscreen,
            onOutput: onOutput
        )
        return try await wineService.launch(request)
    }

    /// Terminates every running instance of the game executable so a stopped
    /// launcher really means stopped. Cancelling the launch only SIGTERMs the
    /// Wine wrapper, which does not reliably tear down the Windows process tree
    /// under wineserver; signal the game processes themselves — SIGTERM first,
    /// SIGKILL the survivors after a grace period.
    func terminateRunningGame(_ game: GameDefinition) async {
        let executable = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        let pids = await GameProcessInspector.runningProcessIDs(forExecutable: executable)
        await Self.terminate(pids: pids, executable: executable)
    }

    /// SIGTERMs the given PIDs, then SIGKILLs whatever of `executable` is still running after a
    /// grace period. Shared by the explicit Stop action and the launch preflight below.
    private static func terminate(pids: Set<Int32>, executable: URL) async {
        guard !pids.isEmpty else { return }

        for pid in pids { kill(pid, SIGTERM) }
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let survivors = await GameProcessInspector.runningProcessIDs(forExecutable: executable)
        for pid in survivors { kill(pid, SIGKILL) }
    }

    /// Copies the game's protection driver into the Wine prefix system32 so the driver-load step does
    /// not abort the process.
    ///
    /// Wine cannot load real Windows kernel drivers, but the client still tries to load
    /// `HoYoKProtect.sys` during startup. Placing the file in system32 lets that load step succeed
    /// (it is then inert under Wine). Combined with the cloud-gaming flags and the steam.exe parent
    /// process (see WineService), this is what lets the client start at all. DO NOT REMOVE without a
    /// replacement bypass; without it the client aborts during the anti-cheat driver-load phase.
    private func installProtectionDriverStub(for game: GameDefinition, prefixDirectory: URL) throws {
        let source = game.installDirectory.appendingPathComponent("HoYoKProtect.sys")
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let destinationDirectory = prefixDirectory
            .appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let destination = destinationDirectory.appendingPathComponent("HoYoKProtect.sys")
        if FileManager.default.fileExists(atPath: destination.path) {
            if FileManager.default.contentsEqual(atPath: source.path, andPath: destination.path) { return }
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    /// Files YAAGL hides for Genshin global during launch (crash reporter and Vulkan fallback).
    ///
    /// These are moved to `.bak` for the launch and restored afterwards. The crash reporters would
    /// otherwise fire (and their upload would fail) when the game hits the benign Wine/D3DMetal
    /// errors; hiding `vulkan-1.dll` keeps Unity from trying its Vulkan fallback path, which does
    /// not work through D3DMetal. This list matches YAAGL's `removed[]` for hk4e_global exactly. DO NOT remove
    /// entries from here without checking YAAGL's current `server.removed` — the set is deliberate.
    private static let acPatchRemovedFiles = [
        "GenshinImpact_Data/upload_crash.exe",
        "GenshinImpact_Data/Plugins/crashreport.exe",
        "GenshinImpact_Data/Plugins/vulkan-1.dll"
    ]

    /// Temporarily moves the AC-patch "removed" files to `.bak` before launch, or restores them after.
    ///
    /// Note: the `.bak` files live in the install root and are NOT protected by
    /// `InstallTargetPruner`. If the app crashes mid-launch they can linger; recover
    /// manually by removing the `.bak` suffix.
    private func applyACPatch(for game: GameDefinition, apply: Bool) throws {
        let fileManager = FileManager.default
        for relativePath in Self.acPatchRemovedFiles {
            let url = game.installDirectory.appendingPathComponent(relativePath)
            let backupURL = URL(fileURLWithPath: url.path + ".bak")
            if apply {
                if fileManager.fileExists(atPath: url.path), !fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.moveItem(at: url, to: backupURL)
                }
            } else {
                guard fileManager.fileExists(atPath: backupURL.path) else { continue }
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
                try fileManager.moveItem(at: backupURL, to: url)
            }
        }
    }

    /// Telemetry/anti-cheat hosts blocked in the Wine prefix for the whole launch. Mirrors YAAGL's
    /// Genshin-global `OS_CUSTOM_HOSTS`.
    ///
    /// DO NOT ADD `dispatchosglobal.yuanshen.com` BACK TO THIS LIST.
    /// `dispatchosglobal` is the game's *dispatch/region-routing* server, not a telemetry host.
    /// Blocking it for the entire launch makes the client unable to re-dispatch once its initial
    /// dispatch expires, which surfaces ~10 minutes after login as a disconnect back to the title
    /// screen (`BeyondLevelEditModule ClearOnDisconnect` in the game's output_log.txt). YAAGL only
    /// blocks it for the 10-second anti-cheat init window and then unblocks it — that behaviour is
    /// implemented via `dispatchBlockHost` + `unblockDispatchHost` below. Do not "simplify" the two
    /// lists back into one; the different lifetimes are load-bearing.
    ///
    /// DO NOT ADD `overseauspider.yuanshen.com` BACK TO THIS LIST either. Despite the name reading
    /// like a telemetry crawler, blocking it for the whole launch reproduced a real symptom: login
    /// and scene-init succeed, but `MonoLevelMap.ShowLevelMiniMap`'s `SyncLoadFromBundle` call times
    /// out ("HK4EUpload: case t u w timeout") and the client sits on the loading screen forever —
    /// confirmed live by clearing the block from a stuck session's prefix hosts file, which let
    /// loading immediately continue. It is evidently consulted for in-world resource loading too,
    /// not only telemetry.
    private static let blockedHosts = [
        "log-upload-os.hoyoverse.com",
        "sg-public-data-api.hoyoverse.com"
    ]

    /// Dispatch host blocked only during the anti-cheat init window, then unblocked so the game can
    /// re-dispatch without disconnecting. Mirrors YAAGL's `OS_BLOCK_URL`.
    ///
    /// DO NOT REMOVE the timed unblock. This host must NOT stay blocked for the whole launch (see
    /// the warning on `blockedHosts`). The 10-second window is long enough for the anti-cheat to
    /// give up initialising against the dispatch endpoint, but short enough that the game's normal
    /// re-dispatch still succeeds.
    private static let dispatchBlockHost = "dispatchosglobal.yuanshen.com"

    /// How long the dispatch host stays blocked at launch before being unblocked.
    private static let dispatchBlockDurationNanoseconds: UInt64 = 10_000_000_000

    /// Writes the block section into the Wine prefix hosts file so name resolution under Wine maps
    /// the blocked hosts to 0.0.0.0. No admin privileges are needed because the prefix is user-owned.
    private func installHostsBlock(in prefixDirectory: URL) throws {
        try Self.writeHostsBlock(in: prefixDirectory, hosts: Self.blockedHosts + [Self.dispatchBlockHost])
    }

    /// Rewrites the block with only the persistent telemetry hosts, unblocking the dispatch host.
    private static func unblockDispatchHost(in prefixDirectory: URL) throws {
        try writeHostsBlock(in: prefixDirectory, hosts: blockedHosts)
    }

    /// Writes the NSLauncher block section into the Wine prefix hosts file.
    private static func writeHostsBlock(in prefixDirectory: URL, hosts: [String]) throws {
        let hostsURL = prefixHostsURL(in: prefixDirectory)
        try FileManager.default.createDirectory(at: hostsURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        var lines = prefixHostsLines(excludingBlock: true, at: hostsURL)
        if !lines.isEmpty, lines.last?.isEmpty == false {
            lines.append("")
        }
        lines.append("# Added by NSLauncher")
        for host in hosts {
            lines.append("0.0.0.0 \(host)")
        }
        lines.append("# End of NSLauncher section")
        try (lines.joined(separator: "\n") + "\n").write(to: hostsURL, atomically: true, encoding: .utf8)
    }

    /// Removes the NSLauncher block section from the Wine prefix hosts file.
    private func removeHostsBlock(in prefixDirectory: URL) throws {
        let hostsURL = Self.prefixHostsURL(in: prefixDirectory)
        guard FileManager.default.fileExists(atPath: hostsURL.path) else { return }
        let lines = Self.prefixHostsLines(excludingBlock: true, at: hostsURL)
        let content = lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
        try content.write(to: hostsURL, atomically: true, encoding: .utf8)
    }

    /// Path to the Windows hosts file inside the Wine prefix.
    private static func prefixHostsURL(in prefixDirectory: URL) -> URL {
        prefixDirectory
            .appendingPathComponent("drive_c/windows/system32/drivers/etc", isDirectory: true)
            .appendingPathComponent("hosts", isDirectory: false)
    }

    /// Reads the prefix hosts file lines with any prior NSLauncher block section removed.
    private static func prefixHostsLines(excludingBlock: Bool, at hostsURL: URL) -> [String] {
        let existing: [String] = (try? String(contentsOf: hostsURL, encoding: .utf8))?
            .components(separatedBy: .newlines) ?? []
        guard excludingBlock else { return existing }

        var result: [String] = []
        var inBlock = false
        for line in existing {
            if line.hasPrefix("# Added by NSLauncher") {
                inBlock = true
                continue
            }
            if inBlock, line.hasPrefix("# End of NSLauncher section") {
                inBlock = false
                continue
            }
            if !inBlock {
                result.append(line)
            }
        }
        // Drop trailing empty lines left by the removed block.
        while result.last?.isEmpty == true {
            result.removeLast()
        }
        return result
    }

    /// Reads the marker metadata written by successful Sophon installs and updates.
    private func installedMetadata(for game: GameDefinition) -> InstalledGameMetadata? {
        let metadataURL = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(InstalledGameMetadata.self, from: data)
    }

    /// Returns true when the staging tree still holds partial files (`.partial` or
    /// `.chunks.json`). Empty leftover directories left behind by a completed
    /// update do not count as in-progress work and must not block launch.
    private func hasLeftoverStagingWork(at directory: URL) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return false }
        for case let url as URL in enumerator {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if !isDirectory.boolValue { return true }
        }
        return false
    }

    /// Applies the Sophon asset plan through the installer.
    private func applySophonPlan(
        _ game: GameDefinition,
        plan: GameUpdatePlan,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await sophonInstaller.update(
            game: game,
            version: plan.latestVersion,
            targetAssets: plan.sophonTargetAssets.isEmpty ? plan.sophonAssetsToWrite : plan.sophonTargetAssets,
            assets: plan.sophonAssetsToWrite,
            operationController: operationController,
            onEvent: onEvent
        )
    }
}
