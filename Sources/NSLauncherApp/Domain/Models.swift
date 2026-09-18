// Models.swift
//
// Domain models: everything the app reasons about, independent of UI and I/O.
//
// The domain is intentionally narrow and Sophon-only. Genshin is the single bundled
// game and its only install/update backend is HoYoPlay Sophon chunks
// (`InstallerStrategy.sophon`). Deprecated archive/manifest/package download
// surfaces were removed; `AppSettings` still decodes the old keys (ignored) so
// existing settings files keep loading.
//
// Notable pieces:
// - `VoiceLanguage`/`VoicePackage`: the four voice-over categories advertised by
//   Sophon (`en-us`, `zh-cn`, `ja-jp`, `ko-kr`) and the per-pack storage removal.
// - `AppSettings`: persisted config. The YAAGL-style launch workarounds (cloud
//   compatibility, AC patch, network block, timeout fix, steam parent) are not
//   settings — they always run; see `LaunchRuntimeProfile.build` and
//   `LauncherCoordinator.launchGame`.
// - Sophon models (`SophonBuild`, `SophonCategoryManifest`, `SophonAsset`,
//   `SophonChunk`): the decoded shape of the official chunk manifests.

import Foundation

/// Languages exposed by the launcher UI and by official metadata requests.
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case vietnamese

    var id: String { rawValue }

    /// Language code expected by HoYoPlay's official package metadata endpoint.
    var officialMetadataLanguageCode: String {
        switch self {
        case .english:
            return "en-us"
        case .vietnamese:
            return "vi-vn"
        }
    }

    /// This language's own name, spelled in that language rather than translated into whichever
    /// language is currently active — the language switcher always reads "English" / "Tiếng Việt".
    var nativeName: String {
        switch self {
        case .english:
            return "English"
        case .vietnamese:
            return "Tiếng Việt"
        }
    }
}

/// Player-selected Traveler gender. Informational only: NS Launcher has no reliable way to map
/// cutscene files to a gender variant (see `CutsceneFile`), so this is not used to filter or
/// auto-select anything — it's shown alongside the manual cutscene browser for the player's own
/// reference.
enum TravelerGender: String, Codable, CaseIterable, Identifiable {
    case aether
    case lumine

    var id: String { rawValue }
}

/// Voice-over language pack downloaded alongside game resources.
enum VoiceLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case chinese
    case japanese
    case korean

    var id: String { rawValue }

    /// Sophon `matching_field` for this voice pack, verified against the live `getBuild` response.
    var sophonMatchingField: String {
        switch self {
        case .english: return "en-us"
        case .chinese: return "zh-cn"
        case .japanese: return "ja-jp"
        case .korean: return "ko-kr"
        }
    }

    /// Maps a Sophon voice matching field back to a supported voice language.
    init?(sophonMatchingField: String) {
        switch sophonMatchingField.lowercased() {
        case "en-us": self = .english
        case "zh-cn": self = .chinese
        case "ja-jp": self = .japanese
        case "ko-kr": self = .korean
        default: return nil
        }
    }
}

/// One locally present voice-over category exposed by the Sophon build.
struct VoicePackage: Identifiable, Hashable {
    var matchingField: String
    var categoryName: String
    var localBytes: Int64
    var localFileCount: Int

    var id: String { matchingField }

    /// Known voice language for the matching field, when it maps to a supported voice language.
    var voiceLanguage: VoiceLanguage? {
        VoiceLanguage(sophonMatchingField: matchingField)
    }
}

/// A local game-content category derived from Sophon asset paths.
enum StorageContentKind: String, Hashable, Identifiable {
    case audio

    var id: String { rawValue }
}

/// Actual local storage and current Sophon availability for one content category.
struct StorageContentGroup: Hashable, Identifiable {
    var kind: StorageContentKind
    var localBytes: Int64
    var localFileCount: Int
    var availableBytes: Int64
    var availableFileCount: Int

    var id: StorageContentKind { kind }
}

/// Runtime container formats that can be measured locally without inferring quest ownership.
enum QuestAssetContainerKind: String, CaseIterable, Hashable, Identifiable {
    case encryptedBlock
    case cabBundle
    case assetBundle
    case assetIndex

    var id: String { rawValue }
}

/// Local totals for one runtime container format; these containers are not quest-specific.
struct QuestAssetContainerGroup: Hashable, Identifiable {
    var kind: QuestAssetContainerKind
    var localBytes: Int64
    var localFileCount: Int

    var id: QuestAssetContainerKind { kind }
}

/// Whether the launcher has verified evidence to associate runtime files with quests.
enum QuestAssetMappingStatus: Hashable {
    case unavailable
}

/// A read-only report of runtime containers; it never identifies removable quest data.
struct QuestAssetAnalysis: Hashable {
    var containerGroups: [QuestAssetContainerGroup] = []
    var mappingStatus: QuestAssetMappingStatus = .unavailable

    static let unavailable = QuestAssetAnalysis()
}

/// Local storage inventory for one selected game, computed from live Sophon manifests.
struct GameStorageInventory: Hashable {
    var voicePackages: [VoicePackage] = []
    var contentGroups: [StorageContentGroup] = []
    var questAssetAnalysis = QuestAssetAnalysis.unavailable

    static let empty = GameStorageInventory()
}

/// One category of removable on-disk cache for the selected game, with its current size.
///
/// None of these hold player-save or game-required data; each is regenerated or
/// re-downloaded on demand, so they are safe to clear to reclaim disk space.
struct RemovableCache: Identifiable, Hashable {
    /// Cache categories the launcher can measure and safely remove.
    enum Kind: String, CaseIterable, Identifiable, Hashable {
        /// Cutscene videos the client downloaded into `Persistent/VideoAssets` while they were
        /// missing from `StreamingAssets`. Now that Sophon installs them, this only holds a stale
        /// duplicate; clearing it is safe and does not trigger a re-download.
        case cutsceneVideos
        case gameWebCache
        case gameSDKCache
        /// `Persistent/AssetBundles`: the open-world block cache the client streams in on demand
        /// as you explore, and re-downloads incrementally rather than trusting what is already
        /// there. `GenshinSophonInstaller.gameOwnedRuntimeDirectories` protects this same
        /// directory from the *automatic* update prune (deleting it there would force a
        /// multi-gigabyte re-download on every single update); this is the separate, user-
        /// requested escape hatch for when the client's own version check on these blocks falls
        /// out of sync and stale terrain/props/lighting keep showing up after an update. Clearing
        /// it is the same fix HoYoverse's own support docs give for that symptom on Windows.
        ///
        /// Must also clear `Persistent`'s own revision/version-manifest files (see
        /// `LauncherCoordinator.gameWorldAssetCacheLocations`) — leaving them behind while wiping
        /// the block data they point to is worse than not clearing at all: the client believes it
        /// is already on the revision those counters name, finds no block data for it, and shows
        /// missing models or wrong textures instead of a clean re-download. Matched by name prefix,
        /// not a fixed list — a real install was observed switching from
        /// `res_revision`/`res_versions_persist` to `base_revision`/`res_versions_remote` between
        /// two ordinary launches, with an old-scheme file left uncleaned next to its replacement.
        case gameWorldAssetCache
        case winePrefixTemp
        case launcherDownloadArchives
        var id: String { rawValue }
    }

    let kind: Kind
    let sizeBytes: Int64

    var id: Kind { kind }
}

/// One cutscene video file found under `StreamingAssets/VideoAssets`.
///
/// NS Launcher does not know which quest or Traveler-gender variant this file belongs to — see
/// `QuestAssetAnalysis` above for why that mapping isn't available. This is a plain on-disk
/// listing for the player to review and open/delete themselves, not a classified one.
struct CutsceneFile: Identifiable, Hashable {
    let url: URL
    let relativePath: String
    let sizeBytes: Int64

    var id: URL { url }
}

/// Error from decrypting a cutscene through the user's own GI-cutscenes install.
enum CutsceneDecryptionError: LocalizedError {
    /// The tool exited successfully but left no `.mkv` in its output directory. `details` carries
    /// its captured stdout/stderr so the failure is diagnosable instead of a silent no-op.
    case decryptedFileNotProduced(details: String)

    var errorDescription: String? {
        switch self {
        case let .decryptedFileNotProduced(details):
            return "GI-cutscenes ran but did not produce a playable file.\(details.isEmpty ? "" : " \(details)")"
        }
    }
}

/// Installation backend selected for a game definition.
enum InstallerStrategy: String, Codable, CaseIterable, Identifiable {
    case sophon

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        _ = try? container.decode(String.self)
        self = .sophon
    }
}

/// Runtime components the launcher may need before a game can run correctly.
enum RuntimeRequirement: String, Codable, CaseIterable, Identifiable {
    case wine
    /// The DXVK backend was removed (see `RuntimeBackend`) and this requirement is no longer
    /// produced by any code path. The case stays only so existing settings.json files that still
    /// list it in `GameDefinition.runtimeRequirements` keep decoding instead of resetting to
    /// defaults (see `SettingsStore`).
    case dxvk
    /// CrossOver's bundled DXMT (`lib/dxmt`) — see `DXMTBridge`. Raw value is NOT `"dxmt"`: that
    /// string is aliased below to `.dxmt` for settings.json files predating this raw value's
    /// rename, and reusing it here would make old and new meanings collide.
    case dxmt = "dxmtBundled"

    var id: String { rawValue }

    /// `dxmt` is this case's own raw value before it was renamed to `dxmtBundled`, and `d3dMetal`
    /// is the raw value of the removed Apple D3DMetal backend requirement — existing settings.json
    /// files can still carry either in `GameDefinition.runtimeRequirements`, and a decode failure
    /// there resets the whole settings file to defaults (see `SettingsStore`), so both legacy
    /// values are aliased to the remaining Metal-native backend rather than left to fail.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "dxmt" || raw == "d3dMetal" {
            self = .dxmt
            return
        }
        guard let value = RuntimeRequirement(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown RuntimeRequirement '\(raw)'")
        }
        self = value
    }
}

/// A render size in the unit Wine's Mac driver reports display modes in.
///
/// Whether that unit is points or backing pixels depends on the `retina` flag passed to
/// `DisplayGeometry.mainDisplaySize(retina:)` — always `false` (Retina scaling is not offered as a
/// setting; see `LaunchRuntimeProfile.build`). Both the Unity `-screen-width`/`-screen-height`
/// arguments and the `Screenmanager Resolution *` registry values are expressed in it, so they can
/// never disagree with each other.
struct RenderSize: Equatable, Sendable {
    var width: Int
    var height: Int

}

/// User-selected display mode for games launched through Wine.
enum LaunchDisplayMode: String, Codable, CaseIterable, Identifiable {
    case windowed
    case fullscreen

    var id: String { rawValue }

    /// Unity-compatible launch arguments used by Genshin Impact and similar games.
    ///
    /// Fullscreen uses Wine's real Win32 exclusive fullscreen (`-screen-fullscreen 1`), not
    /// AppKit's Spaces-based fullscreen: Unity's player window never carries
    /// `NSWindowStyleMaskResizable`, and Wine's Mac driver only grants a window the
    /// `NSWindowCollectionBehaviorFullScreenPrimary` a Space-fullscreen toggle needs when the
    /// window is resizable (see `adjustFullScreenBehavior:` in macdrv's `cocoa_window.m`) — so
    /// `-toggleFullScreen:`/`AXFullScreen` can never succeed on it. Win32 exclusive fullscreen
    /// does not need that: once the window's frame covers the whole screen, macdrv's own
    /// `CaptureDisplaysForFullscreen` registry option (see `WineService`) makes it seize the
    /// display for real, independent of AppKit's resizable-window gate.
    var launchArguments: [String] {
        switch self {
        case .windowed:
            return ["-screen-fullscreen", "0"]
        case .fullscreen:
            return ["-screen-fullscreen", "1"]
        }
    }
}

/// Marker file written into an install directory after a successful Sophon install or update.
struct InstalledGameMetadata: Codable, Hashable {
    var gameID: String
    var installMode: InstallerStrategy
    var installedAt: Date
    var executableRelativePath: String
    var version: String?
}

/// Static configuration for one launchable game.
struct GameDefinition: Identifiable, Codable, Hashable {
    let id: String
    var displayName: String
    var installDirectory: URL
    var executableRelativePath: String
    var winePrefixDirectory: URL
    var installerStrategy: InstallerStrategy
    var runtimeRequirements: [RuntimeRequirement]
    var launchArguments: [String]
}

/// Delta plan for bringing an existing Sophon install up to the latest version.
struct GameUpdatePlan: Hashable {
    var sourceKind: UpdatePlanSourceKind = .sophon
    var installedVersion: String?
    var latestVersion: String
    var sophonTargetAssets: [SophonAsset] = []
    var sophonAssetsToWrite: [SophonAsset] = []
    var sophonSkippedAssets: Int = 0
    var bytesToDownload: Int64
    var decompressedBytesToWrite: Int64 = 0
    var peakTemporaryBytes: Int64
    var metadataNeedsUpdate: Bool

    var isUpToDate: Bool {
        sophonAssetsToWrite.isEmpty && !metadataNeedsUpdate
    }

    var changedItemCount: Int {
        sophonAssetsToWrite.count
    }

    var skippedItemCount: Int {
        sophonSkippedAssets
    }
}

/// Update backend selected for a plan.
enum UpdatePlanSourceKind: String, Hashable {
    case sophon
}

/// Parsed Sophon build metadata for HoYoPlay chunk-based installs.
struct SophonBuild: Hashable {
    var version: String
    var packageID: String
    var manifests: [SophonCategoryManifest]
}

/// One category manifest inside a Sophon build, such as game resources or one voice language.
struct SophonCategoryManifest: Hashable {
    var categoryID: String
    var matchingField: String
    var categoryName: String
    var manifestID: String
    var manifestMD5: String
    var manifestCompressedSize: Int64
    var manifestUncompressedSize: Int64
    var manifestBaseURL: URL
    var chunkBaseURL: URL
    var compressedBytes: Int64
    var decompressedBytes: Int64
    var fileCount: Int
    var chunkCount: Int
    var assets: [SophonAsset]
}

/// One final game asset described by a Sophon manifest.
struct SophonAsset: Hashable, Identifiable {
    var path: String
    var size: Int64
    var md5: String
    var chunks: [SophonChunk]
    var isDirectory: Bool
    var matchingField: String
    var categoryName: String

    var id: String { "\(matchingField):\(path)" }

    var compressedBytes: Int64 {
        chunks.reduce(Int64(0)) { $0 + $1.compressedSize }
    }
}

/// One compressed chunk used to reconstruct a Sophon asset.
struct SophonChunk: Hashable, Identifiable {
    var name: String
    var offset: Int64
    var compressedSize: Int64
    var decompressedSize: Int64
    var decompressedMD5: String
    var chunkBaseURL: URL

    var id: String { name }

    var resumeKey: String {
        "\(name)|\(offset)|\(decompressedSize)|\(decompressedMD5)"
    }

    var url: URL {
        chunkBaseURL.appendingPathComponent(name, isDirectory: false)
    }
}

/// User settings and bundled game defaults persisted to disk.
struct AppSettings: Codable, Equatable {
    private static let genshinGameID = "genshin-global"
    private static let genshinLegacyNestedExecutablePath = "Genshin Impact Game/GenshinImpact.exe"
    private static let genshinStreamingExecutablePath = "GenshinImpact.exe"

    var games: [GameDefinition] = []
    var selectedGameID: String?
    var language: AppLanguage = .english
    var launchDisplayMode: LaunchDisplayMode = .windowed
    /// Optional `cmd /c` batch wrapper that runs `cd /d <game_dir>` before launching the executable.
    var useBatchWrapper: Bool = false
    /// Hours after launch the Home screen's playtime countdown reaches zero. Advisory only — it
    /// never stops the game, only flags the reminder as due (see `LauncherViewModel`).
    var playtimeReminderHours: Double = 3
    /// Player-selected Traveler gender. See `TravelerGender` — informational only.
    var travelerGender: TravelerGender = .aether
    /// Path to a user-installed GI-cutscenes binary, used to decrypt a `.usm` cutscene before
    /// opening it. Empty by default: NS Launcher never bundles this tool or its decryption keys.
    var giCutscenesBinaryPath: String = ""
    /// Monotonic settings schema version used for one-time default migrations.
    var settingsVersion: Int = 0

    /// Resolved Wine executable path, falling back to a PATH lookup name.
    var wineBinaryPath: String {
        BinaryLocator.resolveManagedExecutable(.wine, preferredPath: "") ?? "wine64"
    }

    /// First-run settings used when no settings file exists yet.
    static var `default`: AppSettings {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home
            .appendingPathComponent("Games", isDirectory: true)
            .appendingPathComponent("Genshin Impact", isDirectory: true)
        return AppSettings(
            games: [
                GameDefinition(
                    id: genshinGameID,
                    displayName: "Genshin Impact",
                    installDirectory: root,
                    executableRelativePath: genshinStreamingExecutablePath,
                    winePrefixDirectory: root.appendingPathComponent(".wine", isDirectory: true),
                    installerStrategy: .sophon,
                    runtimeRequirements: [.wine, .dxmt],
                    launchArguments: []
                )
            ],
            selectedGameID: genshinGameID,
            language: .english,
            launchDisplayMode: .windowed,
            useBatchWrapper: false,
            playtimeReminderHours: 3,
            settingsVersion: 3
        )
    }

    /// Migrates older settings to the Sophon-only bundled Genshin strategy.
    ///
    /// settingsVersion 1 through 3 previously migrated launch toggles (cloud compatibility, AC
    /// patch, network block, timeout fix, steam parent) and Retina scaling that are now hardcoded
    /// rather than persisted settings — see `LaunchRuntimeProfile.build` and
    /// `LauncherCoordinator.launchGame`. No migration reads `settingsVersion` left; it stays only
    /// for a future one to gate against.
    func applyingBundledGenshinDefaultsIfNeeded() -> AppSettings {
        var copy = self

        guard let index = copy.games.firstIndex(where: { $0.id == Self.genshinGameID }) else {
            return copy
        }

        copy.games[index].installerStrategy = .sophon
        if !copy.games[index].runtimeRequirements.contains(.dxmt) {
            copy.games[index].runtimeRequirements.append(.dxmt)
        }
        if copy.games[index].executableRelativePath == Self.genshinLegacyNestedExecutablePath {
            copy.games[index].executableRelativePath = Self.genshinStreamingExecutablePath
        }

        return copy
    }

    /// The size the game is told to render at, in the unit Wine reports display modes in.
    ///
    /// Every launch names one. Leaving it to the game was the source of both reported rendering
    /// faults: Unity persists whatever resolution was last used into its `Screenmanager` PlayerPrefs
    /// (including changes made inside the game), and `LaunchDisplayMode.fullscreen` then asks
    /// macdrv — with `CaptureDisplaysForFullscreen` on — to seize the display for that stale size.
    /// When it does not match the display's own mode, macOS switches to a synthesised stretched
    /// mode: a 16:9 size on a 16:10 Mac panel is exactly the "models look stretched" symptom, and
    /// the captured mode change is also what shifts the colour rendition, because the display's
    /// profile no longer applies to the mode being scanned out. Naming the display's current mode
    /// keeps the aspect ratio honest and leaves the mode — and its colour profile — untouched.
    ///
    /// Returns nil only when fullscreen is selected and the display geometry could not be read;
    /// the launch then omits the arguments rather than inventing a size.
    func renderSize(displaySize: RenderSize?) -> RenderSize? {
        switch launchDisplayMode {
        case .fullscreen:
            // A window covering the whole screen at the screen's own mode: no mode switch, so
            // nothing to stretch and no profile change.
            return displaySize
        case .windowed:
            // Default windowed size. A window is drawn at its own size, so an aspect ratio
            // different from the display's costs nothing here.
            return RenderSize(width: 1280, height: 720)
        }
    }

    /// Builds launch arguments with display mode controlled by settings rather than stale game flags.
    func launchArguments(for game: GameDefinition, displaySize: RenderSize?) -> [String] {
        var arguments = Self.filteredUnityDisplayArguments(game.launchArguments) + launchDisplayMode.launchArguments
        if let size = renderSize(displaySize: displaySize) {
            arguments += ["-screen-width", String(size.width), "-screen-height", String(size.height)]
        }
        return arguments
    }

    /// Removes Unity screen flags that are now owned by launchDisplayMode.
    private static func filteredUnityDisplayArguments(_ arguments: [String]) -> [String] {
        var filtered: [String] = []
        var index = 0
        let keyedScreenArguments = Set(["-screen-fullscreen", "-screen-width", "-screen-height"])

        while index < arguments.count {
            let argument = arguments[index]
            if keyedScreenArguments.contains(argument) {
                index += 2
                continue
            }
            if argument == "-popupwindow" {
                index += 1
                continue
            }
            filtered.append(argument)
            index += 1
        }

        return filtered
    }
}

enum InstallProgressEvent: Equatable {
    case diagnostic(String)
    case preparing(String)
    case downloadingSophonAsset(
        path: String,
        overallReceived: Int64,
        overallTotal: Int64,
        fileReceived: Int64,
        fileTotal: Int64
    )
    case verifying(path: String)
    case validatingInstall(path: String)
    case finished(version: String)
}

/// Runtime backend used for DirectX translation on macOS.
///
/// DXMT requires a payload matched to a CrossOver-derived Wine build and translates directly to
/// Metal. `RenderBridges.resolveBackend` picks it when the selected game declares support for it,
/// falling back to plain Wine otherwise.
///
/// Apple's own D3DMetal backend and DXVK (D3D11 through Vulkan then MoltenVK) were both removed —
/// D3DMetal for a Wine payload issue with no lever to fix from here, DXVK because the extra
/// Vulkan/SPIRV-Cross hop made its shader translation the least reliable of the three on Apple
/// GPUs. Not persisted, so no settings.json migration is needed for either removal.
enum RuntimeBackend: String {
    case dxmt
    case plainWine
}

/// Describes the full runtime environment for a single game launch session.
struct LaunchRuntimeProfile {
    var wineBinaryPath: String
    var prefixDirectory: URL
    var executablePath: URL
    var currentDirectory: URL
    var arguments: [String]
    var backend: RuntimeBackend
    var environment: [String: String]
    var runtimeRequirements: [RuntimeRequirement]
    /// Size the launch arguments ask the game to render at, carried here so the registry values
    /// written before launch can be the same numbers rather than a second, independently derived
    /// set that can drift out of agreement with them.
    var renderSize: RenderSize?
    /// Whether this launch runs the game in Win32 exclusive fullscreen.
    var fullscreen: Bool

    /// Builds a profile from game definition and app settings.
    ///
    /// `displaySize` is the geometry of the display the game will run on; passing nil reads the
    /// main display's current mode, which is what production callers want. Tests pass an explicit
    /// value so the profile they build does not depend on the machine running them.
    static func build(
        game: GameDefinition,
        settings: AppSettings,
        displaySize: RenderSize? = nil
    ) -> LaunchRuntimeProfile {
        // Retina scaling is not offered as a setting: it is the single biggest render-side cost in
        // the whole pipeline and the main driver of stutter once the window fills the screen in
        // `LaunchDisplayMode.fullscreen`.
        let displaySize = displaySize ?? DisplayGeometry.mainDisplaySize(retina: false)
        let exe = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        // DXMT is the only Metal-native backend left (Apple D3DMetal was removed); `resolveBackend`
        // falls back to plain Wine on a game that does not declare support for it.
        let backend = RenderBridges.resolveBackend(requirements: game.runtimeRequirements, preferred: .dxmt)

        var env: [String: String] = [
            "WINEARCH": "win64",
            // Disable every debug class by default, then re-enable `err` (where the launcher's own
            // failure detection lives) except on `unwind`, whose err output is exception-unwinding
            // noise rather than an actionable failure. `fixme`/`warn`/`trace` stay off across every
            // channel: Wine's internal chatter on these was the bulk of what got formatted and
            // written per frame, none of it something the launcher reads.
            "WINEDEBUG": "-all,+err,err-unwind"
        ]

        // Everything specific to a translation layer — its variables, its cache, its quirks —
        // belongs to that layer's RenderBridge, so this stays generic launch environment.
        env.merge(
            RenderBridges.launchEnvironment(for: backend, settings: settings)
        ) { _, bridgeValue in bridgeValue }

        // YAAGL's network-timeout fix: prevents the macOS Wine socket timeout that drops the game
        // back to the title screen mid-session. Only effective on Wine builds carrying the patch
        // (the managed wine does); a harmless no-op elsewhere. Always on for Genshin.
        env["WINE_ENABLE_TIMEOUT_FIX"] = "1"

        // YAAGL-style cloud-gaming mode: the game skips the local anti-cheat requirement. DO NOT
        // remove these flags; without them the client aborts during the anti-cheat driver-load
        // phase (see LauncherCoordinator for the full bypass stack). Always on for Genshin.
        let launchArguments = settings.launchArguments(for: game, displaySize: displaySize)
            + ["-platform_type", "CLOUD_THIRD_PARTY_PC", "-is_cloud", "1"]

        return LaunchRuntimeProfile(
            wineBinaryPath: settings.wineBinaryPath,
            prefixDirectory: game.winePrefixDirectory,
            executablePath: exe,
            currentDirectory: game.installDirectory,
            arguments: launchArguments,
            backend: backend,
            environment: env,
            runtimeRequirements: game.runtimeRequirements,
            renderSize: settings.renderSize(displaySize: displaySize),
            fullscreen: settings.launchDisplayMode == .fullscreen
        )
    }
}

/// Preflight errors that block launch before Wine is invoked.
enum LaunchPreflightError: LocalizedError {
    case missingExecutable(String)
    case missingInstallMetadata
    case invalidInstallMetadata(String)
    case updateRequiredBeforeLaunch(String)
    /// The game is already running in this prefix, with the process IDs holding it.
    case gameAlreadyRunning([Int32])

    var errorDescription: String? {
        switch self {
        case let .missingExecutable(path):
            return "Game executable not found at \(path)."
        case .missingInstallMetadata:
            return "Install metadata (.nslauncher-install.json) is missing. Run Update Game first."
        case let .invalidInstallMetadata(detail):
            return "Install metadata is invalid: \(detail)."
        case let .updateRequiredBeforeLaunch(reason):
            return "Update Game is required before launch: \(reason)."
        case let .gameAlreadyRunning(pids):
            return "The game is already running (PID \(pids.map(String.init).joined(separator: ", ")))."
        }
    }
}
