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
        /// D3DMetal's on-disk compiled-shader cache (pipeline/bytecode/root-signature/stage
        /// `.bin` files under `$(confstr DARWIN_USER_CACHE_DIR)/d3dm/<exe>/shaders.cache/` — see
        /// `D3DMetalBridge.shaderCacheDirectory`). Regenerated automatically the next time each
        /// shader is used, so clearing it is safe; the trade-off is a fresh round of
        /// compile-on-first-use stutter, which is worth it if the cache itself is stale or
        /// corrupted (D3DMetal falls back to disabling its disk cache entirely when it can't
        /// parse an entry, which is worse for stutter than a clean cache).
        case d3dMetalShaderCache

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
    case d3dMetal
    /// CrossOver's bundled DXMT (`lib/dxmt`), reintroduced as a second Metal-native backend
    /// alongside D3DMetal — see `DXMTBridge`. Raw value is NOT `"dxmt"`: that string is already
    /// hard-aliased to `.d3dMetal` below for pre-rename settings.json files, and reusing it here
    /// would make old and new meanings collide.
    case dxmt = "dxmtBundled"

    var id: String { rawValue }

    /// `dxmt` is this case's raw value before the DXMT-to-D3DMetal switch. Existing settings files
    /// still carry it in `GameDefinition.runtimeRequirements`, and a decode failure there resets
    /// the whole settings file to defaults (see `SettingsStore`), so the legacy value is aliased
    /// rather than left to fail.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw == "dxmt" {
            self = .d3dMetal
            return
        }
        guard let value = RuntimeRequirement(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown RuntimeRequirement '\(raw)'")
        }
        self = value
    }
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
    /// Wine Mac Driver registry: enable Retina scaling for HiDPI displays.
    ///
    /// Off by default: on a Retina display this makes the render backend draw at the full physical pixel
    /// count (2x the logical size in each dimension, ~4x the pixels), which is the single
    /// biggest render-side cost in the whole pipeline and the main driver of stutter once the
    /// window fills the screen in `LaunchDisplayMode.fullscreen`. Users on capable hardware can
    /// turn it back on for sharper output.
    var macDriverRetina: Bool = false
    /// Wine Mac Driver registry: treat the left Command key as Ctrl for games that assume Windows bindings.
    var leftCommandIsCtrl: Bool = false
    /// Debug overlay: set `MTL_HUD_ENABLED=1` at launch to show the Metal performance HUD.
    var showMetalHUD: Bool = false
    /// Optional `cmd /c` batch wrapper that runs `cd /d <game_dir>` before launching the executable.
    var useBatchWrapper: Bool = false
    /// YAAGL-style cloud-gaming launch (enabled by default): adds `CLOUD_THIRD_PARTY_PC` flags and
    /// installs a protection-driver stub so the Windows client can start under Wine. Unsupported by
    /// HoYoverse and may risk the account.
    var cloudCompatibilityMode: Bool = false
    /// AC patch (enabled by default): temporarily hide the crash reporter and Vulkan fallback files
    /// during launch, then restore them afterwards (mirrors YAAGL's current Genshin behavior).
    var acPatchMode: Bool = false
    /// Launch network block (enabled by default): block the anti-cheat/telemetry hosts in the Wine
    /// prefix hosts file for the duration of the launch, then restore. The dispatch host is only
    /// blocked for the first 10 seconds (see `LauncherCoordinator.dispatchBlockHost`) so the game can
    /// still re-dispatch — blocking it for the whole launch causes a disconnect back to the title
    /// screen ~10 minutes after login.
    var blockNetMode: Bool = false
    /// Wine network-timeout fix (enabled by default): set `WINE_ENABLE_TIMEOUT_FIX=1` so YAAGL-patched
    /// Wine avoids the macOS socket timeout that drops the game back to the title screen mid-session.
    /// Harmless (ignored) on Wine builds without that patch.
    var timeoutFix: Bool = false
    /// Steam patch (enabled by default): launch through a real `steam.exe` + `lsteamclient.dll` parent
    /// so the anti-cheat skips loading its kernel driver.
    var steamPatch: Bool = false
    /// Apply a custom windowed resolution through the game's registry keys.
    var resolutionCustom: Bool = false
    var resolutionWidth: Int = 1920
    var resolutionHeight: Int = 1080
    /// Enable the game's HDR registry flag.
    var enableHDR: Bool = false
    /// Route the game through an HTTP/HTTPS proxy.
    var proxyEnabled: Bool = false
    var proxyHost: String = ""
    /// Apple D3DMetal's MetalFX spatial upscaling toggle (`D3DM_ENABLE_METALFX`): renders at the
    /// game's own resolution and lets Metal upscale to the window size. Only has a visible effect
    /// when the game itself renders below the window's native resolution (pair with
    /// `resolutionCustom`). Unlike DXMT, D3DMetal exposes no upscale factor to tune — Metal picks it.
    var metalFXUpscaling: Bool = false
    /// Apple D3DMetal's async command-buffer commit (`D3DM_ENABLE_ASYNC_COMMIT`, experimental):
    /// expected to overlap encoding the next Metal command buffer with submitting the previous
    /// one instead of stalling the CPU thread on each submit. Confirmed to exist in a real
    /// D3DMetal.framework binary; its exact effect is not — see `D3DMetalBridge`. Default on, but
    /// toggleable so a stutter/instability report can be isolated to this flag without a rebuild.
    var d3dMetalAsyncCommit: Bool = true
    /// Apple D3DMetal's multithreaded D3D11 interface (`D3DM_MULTITHREADED_INTERFACE_ENABLE`,
    /// experimental): expected to stop D3DMetal serializing D3D11 context access more
    /// conservatively than the game's own threading needs. Same caveat and reason for being
    /// toggleable as `d3dMetalAsyncCommit` — see `D3DMetalBridge`.
    var d3dMetalMultithreadedInterface: Bool = true
    /// Which D3D translation backend to prefer when a game declares more than one supported
    /// option. D3DMetal remains the default; DXMT and DXVK are compatibility fallbacks for
    /// backend-specific rendering bugs.
    ///
    /// The persisted property name predates DXVK becoming selectable. Keep it stable so existing
    /// settings retain their chosen backend.
    var metalRenderBackend: RuntimeBackend = .d3dMetal
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
                    runtimeRequirements: [.wine, .d3dMetal, .dxmt, .dxvk],
                    launchArguments: []
                )
            ],
            selectedGameID: genshinGameID,
            language: .english,
            launchDisplayMode: .windowed,
            macDriverRetina: false,
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
            metalFXUpscaling: false,
            d3dMetalAsyncCommit: true,
            d3dMetalMultithreadedInterface: true,
            metalRenderBackend: .d3dMetal,
            settingsVersion: 3
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

        // One-time migration: turn off Retina scaling for settings that predate this performance
        // default. It was previously on and produced stutter once the game window filled the
        // screen (uncapped, full physical pixel count on a Retina display); see the property
        // comment above. Guarded the same way so users who want the old behavior can turn it
        // back on.
        if copy.settingsVersion < 3 {
            copy.macDriverRetina = false
            copy.settingsVersion = 3
        }

        guard let index = copy.games.firstIndex(where: { $0.id == Self.genshinGameID }) else {
            return copy
        }

        copy.games[index].installerStrategy = .sophon
        if !copy.games[index].runtimeRequirements.contains(.d3dMetal) {
            copy.games[index].runtimeRequirements.append(.d3dMetal)
        }
        if !copy.games[index].runtimeRequirements.contains(.dxmt) {
            copy.games[index].runtimeRequirements.append(.dxmt)
        }
        if !copy.games[index].runtimeRequirements.contains(.dxvk) {
            copy.games[index].runtimeRequirements.append(.dxvk)
        }
        if copy.games[index].executableRelativePath == Self.genshinLegacyNestedExecutablePath {
            copy.games[index].executableRelativePath = Self.genshinStreamingExecutablePath
        }

        return copy
    }

    /// Builds launch arguments with display mode controlled by settings rather than stale game flags.
    func launchArguments(for game: GameDefinition) -> [String] {
        var arguments = Self.filteredUnityDisplayArguments(game.launchArguments) + launchDisplayMode.launchArguments
        if resolutionCustom {
            // Start windowed at the custom render size in either display mode; in fullscreen,
            // native fullscreen scaling happens at the AppKit level after launch and D3DMetal
            // upscales to the screen.
            arguments += ["-screen-width", String(resolutionWidth), "-screen-height", String(resolutionHeight)]
        } else if launchDisplayMode == .windowed {
            // Default windowed size when no custom resolution is set.
            arguments += ["-screen-width", "1280", "-screen-height", "720"]
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
/// D3DMetal, DXMT and DXVK all require payloads matched to a CrossOver-derived Wine build.
/// D3DMetal and DXMT translate directly to Metal; DXVK translates through Vulkan and MoltenVK.
/// `AppSettings.metalRenderBackend` stores the user's preference; `RenderBridges.resolveBackend`
/// validates it against the backends declared by the selected game.
enum RuntimeBackend: String, Codable {
    case d3dMetal
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
    static func build(
        game: GameDefinition,
        settings: AppSettings
    ) -> LaunchRuntimeProfile {
        let exe = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        let backend = RenderBridges.resolveBackend(
            requirements: game.runtimeRequirements,
            preferred: settings.metalRenderBackend
        )

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
