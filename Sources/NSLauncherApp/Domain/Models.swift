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
// - `AppSettings`: persisted config plus three YAAGL-style launch toggles
//   (`cloudCompatibilityMode`, `acPatchMode`, `blockNetMode`), enabled by default and
//   applied under Wine before launch. These are unsupported by HoYoverse and risk the
//   account; users can still turn each one off in Settings.
// - `LaunchRuntimeProfile.build`: computes Wine args/environment, appending the
//   cloud-gaming flags when `cloudCompatibilityMode` is on.
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
    case cutscene
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
    var excludedFromInstall: Bool

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
        case cutsceneVideos
        case gameWebCache
        case gameSDKCache
        case winePrefixTemp
        case launcherDownloadArchives

        var id: String { rawValue }
    }

    let kind: Kind
    let sizeBytes: Int64

    var id: Kind { kind }
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
    case dxvk
    case dxmt
    case reshade

    var id: String { rawValue }
}

/// User-selected display mode for games launched through Wine.
enum LaunchDisplayMode: String, Codable, CaseIterable, Identifiable {
    case windowed
    case fullscreen

    var id: String { rawValue }

    /// Unity-compatible launch arguments used by Genshin Impact and similar games.
    var launchArguments: [String] {
        switch self {
        case .windowed:
            return ["-screen-fullscreen", "0", "-screen-width", "1280", "-screen-height", "720"]
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

/// Coarse install state used by UI or future persistence.
enum InstallState: String, Codable {
    case notInstalled
    case installed
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

/// User-facing estimate of the operations required for an install.
struct InstallPlan: Hashable {
    var version: String
    var steps: [InstallStep]
    var estimatedBytesToDownload: Int64
    var peakTemporaryBytes: Int64
    /// Cutscene videos excluded from the plan; their chunk URLs are never downloaded.
    var cutsceneSkippedAssets: Int = 0
    var cutsceneSkippedBytes: Int64 = 0
}

/// Delta plan for bringing an existing Sophon install up to the latest version.
struct GameUpdatePlan: Hashable {
    var sourceKind: UpdatePlanSourceKind = .sophon
    var installedVersion: String?
    var latestVersion: String
    var sophonTargetAssets: [SophonAsset] = []
    var sophonAssetsToWrite: [SophonAsset] = []
    var sophonSkippedAssets: Int = 0
    /// Cutscene videos excluded from the target set, downloads, and every size total.
    var sophonCutsceneSkippedAssets: Int = 0
    var sophonCutsceneSkippedBytes: Int64 = 0
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

/// One planned install operation.
struct InstallStep: Hashable, Identifiable {
    /// Type of file-system or network action represented by this step.
    enum Kind: Hashable {
        case createDirectory
        case downloadFile
        case moveIntoPlace
        case verifyChecksum
        case writeMetadata
    }

    let id = UUID()
    var kind: Kind
    var relativePath: String
    var bytes: Int64
}

/// Launch-time arguments and environment that can be persisted or derived.
struct LaunchConfiguration: Codable, Hashable {
    var gameArguments: [String]
    var environment: [String: String]
}

/// User settings and bundled game defaults persisted to disk.
struct AppSettings: Codable, Equatable {
    private static let genshinGameID = "genshin-global"
    private static let genshinLegacyNestedExecutablePath = "Genshin Impact Game/GenshinImpact.exe"
    private static let genshinStreamingExecutablePath = "GenshinImpact.exe"

    var games: [GameDefinition]
    var selectedGameID: String?
    var language: AppLanguage
    /// Voice-over language pack selected for Sophon downloads.
    var voiceLanguage: VoiceLanguage
    var launchDisplayMode: LaunchDisplayMode
    /// Wine Mac Driver registry: enable Retina scaling for HiDPI displays.
    var macDriverRetina: Bool
    /// Wine Mac Driver registry: treat the left Command key as Ctrl for games that assume Windows bindings.
    var leftCommandIsCtrl: Bool
    /// Debug overlay: set `MTL_HUD_ENABLED=1` at launch to show the Metal performance HUD.
    var showMetalHUD: Bool
    /// Optional `cmd /c` batch wrapper that runs `cd /d <game_dir>` before launching the executable.
    var useBatchWrapper: Bool
    /// YAAGL-style cloud-gaming launch (enabled by default): adds `CLOUD_THIRD_PARTY_PC` flags and
    /// installs a protection-driver stub so the Windows client can start under Wine. Unsupported by
    /// HoYoverse and may risk the account.
    var cloudCompatibilityMode: Bool
    /// AC patch (enabled by default): temporarily hide the crash reporter and Vulkan fallback files
    /// during launch, then restore them afterwards (mirrors YAAGL's current Genshin behavior).
    var acPatchMode: Bool
    /// Launch network block (enabled by default): block the anti-cheat/telemetry hosts in the Wine
    /// prefix hosts file for the duration of the launch, then restore. The dispatch host is only
    /// blocked for the first 10 seconds (see `LauncherCoordinator.dispatchBlockHost`) so the game can
    /// still re-dispatch — blocking it for the whole launch causes a disconnect back to the title
    /// screen ~10 minutes after login.
    var blockNetMode: Bool
    /// Wine network-timeout fix (enabled by default): set `WINE_ENABLE_TIMEOUT_FIX=1` so YAAGL-patched
    /// Wine avoids the macOS socket timeout that drops the game back to the title screen mid-session.
    /// Harmless (ignored) on Wine builds without that patch.
    var timeoutFix: Bool
    /// Steam patch (enabled by default): launch through a real `steam.exe` + `lsteamclient.dll` parent
    /// so the anti-cheat skips loading its kernel driver.
    var steamPatch: Bool
    /// Apply a custom windowed resolution through the game's registry keys.
    var resolutionCustom: Bool
    var resolutionWidth: Int
    var resolutionHeight: Int
    /// Enable the game's HDR registry flag.
    var enableHDR: Bool
    /// Route the game through an HTTP/HTTPS proxy.
    var proxyEnabled: Bool
    var proxyHost: String
    /// Optional Metal frame-pacing cap for DXMT (0 = disabled). The value must be a factor of the
    /// display refresh rate (e.g. 60 on a 60/120 Hz display).
    var maxFrameRate: Int
    /// DXMT MetalFX spatial upscaling (DXMT only): renders at the game's own resolution and lets
    /// Metal upscale to the window size by `metalFXScaleFactor`. Only has a visible effect when the
    /// game itself renders below the window's native resolution (pair with `resolutionCustom`).
    var metalFXUpscaling: Bool
    /// Upscale factor applied when `metalFXUpscaling` is enabled (e.g. 1.5 = render at 2/3 scale).
    var metalFXScaleFactor: Double
    /// Monotonic settings schema version used for one-time default migrations.
    var settingsVersion: Int

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
            voiceLanguage: .english,
            launchDisplayMode: .windowed,
            macDriverRetina: true,
            leftCommandIsCtrl: false,
            showMetalHUD: false,
            useBatchWrapper: false,
            cloudCompatibilityMode: true,
            acPatchMode: true,
            blockNetMode: true,
            timeoutFix: true,
            steamPatch: true,
            resolutionCustom: false,
            resolutionWidth: 1920,
            resolutionHeight: 1080,
            enableHDR: false,
            proxyEnabled: false,
            proxyHost: "",
            maxFrameRate: 0,
            metalFXUpscaling: false,
            metalFXScaleFactor: 1.5,
            settingsVersion: 2
        )
    }

    /// Migrates older settings to the Sophon-only bundled Genshin strategy.
    func applyingBundledGenshinDefaultsIfNeeded() -> AppSettings {
        var copy = self

        // One-time migration: enable the YAAGL-style launch toggles for pre-existing settings that
        // predate the default-on change. `settingsVersion` guards this so users can still turn them
        // back off afterwards without the next launch re-enabling them.
        if copy.settingsVersion < 1 {
            copy.cloudCompatibilityMode = true
            copy.acPatchMode = true
            copy.blockNetMode = true
            copy.settingsVersion = 1
        }

        // One-time migration: enable the timeout fix and real steam.exe parent for settings that
        // predate these default-on toggles.
        if copy.settingsVersion < 2 {
            copy.timeoutFix = true
            copy.steamPatch = true
            copy.settingsVersion = 2
        }

        guard let index = copy.games.firstIndex(where: { $0.id == Self.genshinGameID }) else {
            return copy
        }

        copy.games[index].installerStrategy = .sophon
        copy.games[index].runtimeRequirements.removeAll { $0 == .dxvk }
        if !copy.games[index].runtimeRequirements.contains(.dxmt) {
            copy.games[index].runtimeRequirements.append(.dxmt)
        }
        if copy.games[index].executableRelativePath == Self.genshinLegacyNestedExecutablePath {
            copy.games[index].executableRelativePath = Self.genshinStreamingExecutablePath
        }

        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case games
        case selectedGameID
        case language
        case voiceLanguage
        case downloadCacheDirectory
        case temporaryExtractionDirectory
        case launchDisplayMode
        case wineBinaryPath
        case aria2BinaryPath
        case sevenZipBinaryPath
        case macDriverRetina
        case leftCommandIsCtrl
        case showMetalHUD
        case useBatchWrapper
        case cloudCompatibilityMode
        case acPatchMode
        case blockNetMode
        case timeoutFix
        case steamPatch
        case resolutionCustom
        case resolutionWidth
        case resolutionHeight
        case enableHDR
        case proxyEnabled
        case proxyHost
        case maxFrameRate
        case metalFXUpscaling
        case metalFXScaleFactor
        case settingsVersion
    }

    init(
        games: [GameDefinition],
        selectedGameID: String?,
        language: AppLanguage,
        voiceLanguage: VoiceLanguage = .english,
        launchDisplayMode: LaunchDisplayMode = .windowed,
        macDriverRetina: Bool = true,
        leftCommandIsCtrl: Bool = false,
        showMetalHUD: Bool = false,
        useBatchWrapper: Bool = false,
        cloudCompatibilityMode: Bool = false,
        acPatchMode: Bool = false,
        blockNetMode: Bool = false,
        timeoutFix: Bool = false,
        steamPatch: Bool = false,
        resolutionCustom: Bool = false,
        resolutionWidth: Int = 1920,
        resolutionHeight: Int = 1080,
        enableHDR: Bool = false,
        proxyEnabled: Bool = false,
        proxyHost: String = "",
        maxFrameRate: Int = 0,
        metalFXUpscaling: Bool = false,
        metalFXScaleFactor: Double = 1.5,
        settingsVersion: Int = 0
    ) {
        self.games = games
        self.selectedGameID = selectedGameID
        self.language = language
        self.voiceLanguage = voiceLanguage
        self.launchDisplayMode = launchDisplayMode
        self.macDriverRetina = macDriverRetina
        self.leftCommandIsCtrl = leftCommandIsCtrl
        self.showMetalHUD = showMetalHUD
        self.useBatchWrapper = useBatchWrapper
        self.cloudCompatibilityMode = cloudCompatibilityMode
        self.acPatchMode = acPatchMode
        self.blockNetMode = blockNetMode
        self.timeoutFix = timeoutFix
        self.steamPatch = steamPatch
        self.resolutionCustom = resolutionCustom
        self.resolutionWidth = resolutionWidth
        self.resolutionHeight = resolutionHeight
        self.enableHDR = enableHDR
        self.proxyEnabled = proxyEnabled
        self.proxyHost = proxyHost
        self.maxFrameRate = maxFrameRate
        self.metalFXUpscaling = metalFXUpscaling
        self.metalFXScaleFactor = metalFXScaleFactor
        self.settingsVersion = settingsVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.games = try container.decode([GameDefinition].self, forKey: .games)
        self.selectedGameID = try container.decodeIfPresent(String.self, forKey: .selectedGameID)
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
        self.voiceLanguage = try container.decodeIfPresent(VoiceLanguage.self, forKey: .voiceLanguage) ?? .english
        self.launchDisplayMode = try container.decodeIfPresent(LaunchDisplayMode.self, forKey: .launchDisplayMode) ?? .windowed
        self.macDriverRetina = try container.decodeIfPresent(Bool.self, forKey: .macDriverRetina) ?? true
        self.leftCommandIsCtrl = try container.decodeIfPresent(Bool.self, forKey: .leftCommandIsCtrl) ?? false
        self.showMetalHUD = try container.decodeIfPresent(Bool.self, forKey: .showMetalHUD) ?? false
        self.useBatchWrapper = try container.decodeIfPresent(Bool.self, forKey: .useBatchWrapper) ?? false
        self.cloudCompatibilityMode = try container.decodeIfPresent(Bool.self, forKey: .cloudCompatibilityMode) ?? false
        self.acPatchMode = try container.decodeIfPresent(Bool.self, forKey: .acPatchMode) ?? false
        self.blockNetMode = try container.decodeIfPresent(Bool.self, forKey: .blockNetMode) ?? false
        self.timeoutFix = try container.decodeIfPresent(Bool.self, forKey: .timeoutFix) ?? false
        self.steamPatch = try container.decodeIfPresent(Bool.self, forKey: .steamPatch) ?? false
        self.resolutionCustom = try container.decodeIfPresent(Bool.self, forKey: .resolutionCustom) ?? false
        self.resolutionWidth = try container.decodeIfPresent(Int.self, forKey: .resolutionWidth) ?? 1920
        self.resolutionHeight = try container.decodeIfPresent(Int.self, forKey: .resolutionHeight) ?? 1080
        self.enableHDR = try container.decodeIfPresent(Bool.self, forKey: .enableHDR) ?? false
        self.proxyEnabled = try container.decodeIfPresent(Bool.self, forKey: .proxyEnabled) ?? false
        self.proxyHost = try container.decodeIfPresent(String.self, forKey: .proxyHost) ?? ""
        self.maxFrameRate = try container.decodeIfPresent(Int.self, forKey: .maxFrameRate) ?? 0
        self.metalFXUpscaling = try container.decodeIfPresent(Bool.self, forKey: .metalFXUpscaling) ?? false
        self.metalFXScaleFactor = try container.decodeIfPresent(Double.self, forKey: .metalFXScaleFactor) ?? 1.5
        self.settingsVersion = try container.decodeIfPresent(Int.self, forKey: .settingsVersion) ?? 0

        // Ignore deprecated storage and custom binary paths while remaining decode-compatible with older settings files.
        _ = try container.decodeIfPresent(String.self, forKey: .downloadCacheDirectory)
        _ = try container.decodeIfPresent(String.self, forKey: .temporaryExtractionDirectory)
        _ = try container.decodeIfPresent(String.self, forKey: .wineBinaryPath)
        _ = try container.decodeIfPresent(String.self, forKey: .aria2BinaryPath)
        _ = try container.decodeIfPresent(String.self, forKey: .sevenZipBinaryPath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(games, forKey: .games)
        try container.encodeIfPresent(selectedGameID, forKey: .selectedGameID)
        try container.encode(language, forKey: .language)
        try container.encode(voiceLanguage, forKey: .voiceLanguage)
        try container.encode(launchDisplayMode, forKey: .launchDisplayMode)
        try container.encode(macDriverRetina, forKey: .macDriverRetina)
        try container.encode(leftCommandIsCtrl, forKey: .leftCommandIsCtrl)
        try container.encode(showMetalHUD, forKey: .showMetalHUD)
        try container.encode(useBatchWrapper, forKey: .useBatchWrapper)
        try container.encode(cloudCompatibilityMode, forKey: .cloudCompatibilityMode)
        try container.encode(acPatchMode, forKey: .acPatchMode)
        try container.encode(blockNetMode, forKey: .blockNetMode)
        try container.encode(timeoutFix, forKey: .timeoutFix)
        try container.encode(steamPatch, forKey: .steamPatch)
        try container.encode(resolutionCustom, forKey: .resolutionCustom)
        try container.encode(resolutionWidth, forKey: .resolutionWidth)
        try container.encode(resolutionHeight, forKey: .resolutionHeight)
        try container.encode(enableHDR, forKey: .enableHDR)
        try container.encode(proxyEnabled, forKey: .proxyEnabled)
        try container.encode(proxyHost, forKey: .proxyHost)
        try container.encode(maxFrameRate, forKey: .maxFrameRate)
        try container.encode(metalFXUpscaling, forKey: .metalFXUpscaling)
        try container.encode(metalFXScaleFactor, forKey: .metalFXScaleFactor)
        try container.encode(settingsVersion, forKey: .settingsVersion)
    }

    /// Builds launch arguments with display mode controlled by settings rather than stale game flags.
    func launchArguments(for game: GameDefinition) -> [String] {
        var arguments = Self.filteredUnityDisplayArguments(game.launchArguments) + launchDisplayMode.launchArguments
        if launchDisplayMode == .fullscreen, resolutionCustom {
            // Start fullscreen at the custom render size; DXMT/Metal upscales to the screen.
            arguments += ["-screen-width", String(resolutionWidth), "-screen-height", String(resolutionHeight)]
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
enum RuntimeBackend: String, Codable {
    case dxmt
    case dxvk
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

    /// Builds a profile from game definition and app settings.
    static func build(game: GameDefinition, settings: AppSettings) -> LaunchRuntimeProfile {
        let exe = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        let backend: RuntimeBackend = {
            if game.runtimeRequirements.contains(.dxmt) { return .dxmt }
            if game.runtimeRequirements.contains(.dxvk) { return .dxvk }
            return .plainWine
        }()

        var env: [String: String] = [
            "WINEARCH": "win64",
            "WINEDEBUG": "fixme-all,err-unwind,+timestamp"
        ]

        if backend == .dxmt {
            // DO NOT switch this back to msync (`WINEMSYNC=1`). On the DXMT-patched Wine build used
            // here, msync surfaced as `wine client error:308: partial wakeup read 0` immediately
            // followed by `err:virtual:virtual_setup_exception nested exception on signal stack` —
            // a hard render-path crash. esync is what YAAGL uses for DXMT.
            env["WINEESYNC"] = "1"
            // An empty override list keeps the DXMT builtin D3D10/D3D11/DXGI DLLs authoritative and
            // prevents any shell-level WINEDLLOVERRIDES from leaking into the launch. Keep it for
            // DXMT only; the DXVK path below relies on registry `DllOverrides` instead.
            env["WINEDLLOVERRIDES"] = ""
            let cacheDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/NSLauncher/DXMT", isDirectory: true)
            env["DXMT_LOG_PATH"] = cacheDir.appendingPathComponent("dxmt.log").path
            env["DXMT_CONFIG_FILE"] = cacheDir.appendingPathComponent("dxmt.conf").path
            // Optional Metal frame-pacing cap. DXMT requires the value to be a FACTOR of the display
            // refresh rate (e.g. 60 for 60/120 Hz, 120 for 120 Hz). It is off by default; a hardcoded
            // 60 was removed because it is invalid on non-60 Hz displays and contributed to the same
            // render crash above. Keep it opt-in and validate against the refresh rate.
            var dxmtConfig = ""
            if settings.maxFrameRate > 0 {
                dxmtConfig += "d3d11.preferredMaxFrameRate=\(settings.maxFrameRate);"
            }
            // MetalFX spatial upscaling: only has a visible effect when the game itself renders
            // below the window's native resolution (pair with `resolutionCustom`). Off by default.
            if settings.metalFXUpscaling {
                env["DXMT_METALFX_SPATIAL_SWAPCHAIN"] = "1"
                let factor = max(settings.metalFXScaleFactor, 1.0)
                dxmtConfig += "d3d11.metalSpatialUpscaleFactor=\(factor);"
            }
            if !dxmtConfig.isEmpty {
                env["DXMT_CONFIG"] = dxmtConfig
            }
            // Rank GStreamer's H.264 decoders (Apple AudioToolbox + FFmpeg) so in-game/cutscene video
            // never selects a broken decoder. Mirrors YAAGL's always-on DXMT launch config.
            env["GST_PLUGIN_FEATURE_RANK"] = "atdec:MAX,avdec_h264:MAX"
        } else if backend == .dxvk {
            env["WINEESYNC"] = "1"
        }

        // YAAGL's network-timeout fix: prevents the macOS Wine socket timeout that drops the game
        // back to the title screen mid-session. Only effective on Wine builds carrying the patch
        // (the managed wine does); a harmless no-op elsewhere. Keep it default-on for Genshin.
        if settings.timeoutFix {
            env["WINE_ENABLE_TIMEOUT_FIX"] = "1"
        }

        // Metal performance HUD (debug overlay). Off by default; enabling it floods the launch log
        // with `[libMTLHud]`/`NSEventModifierFlagFunction` noise and adds Metal pipeline overhead,
        // so it should stay off for normal play.
        if settings.showMetalHUD {
            env["MTL_HUD_ENABLED"] = "1"
        }

        // Optional HTTP/HTTPS proxy forwarded to the Windows client.
        if settings.proxyEnabled, !settings.proxyHost.isEmpty {
            env["HTTP_PROXY"] = settings.proxyHost
            env["HTTPS_PROXY"] = settings.proxyHost
        }

        var launchArguments = settings.launchArguments(for: game)
        if settings.cloudCompatibilityMode {
            // YAAGL-style cloud-gaming mode: the game skips the local anti-cheat requirement.
            // DO NOT remove these flags; without them the client aborts during the anti-cheat
            // driver-load phase (see LauncherCoordinator for the full bypass stack).
            launchArguments += ["-platform_type", "CLOUD_THIRD_PARTY_PC", "-is_cloud", "1"]
        }

        return LaunchRuntimeProfile(
            wineBinaryPath: settings.wineBinaryPath,
            prefixDirectory: game.winePrefixDirectory,
            executablePath: exe,
            currentDirectory: game.installDirectory,
            arguments: launchArguments,
            backend: backend,
            environment: env,
            runtimeRequirements: game.runtimeRequirements
        )
    }
}

/// Preflight errors that block launch before Wine is invoked.
enum LaunchPreflightError: LocalizedError {
    case missingExecutable(String)
    case missingInstallMetadata
    case invalidInstallMetadata(String)
    case updateRequiredBeforeLaunch(String)

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
        }
    }
}
