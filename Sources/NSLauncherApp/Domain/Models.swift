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
    var launchDisplayMode: LaunchDisplayMode
    /// Wine Mac Driver registry: enable Retina scaling for HiDPI displays.
    var macDriverRetina: Bool
    /// Wine Mac Driver registry: treat the left Command key as Ctrl for games that assume Windows bindings.
    var leftCommandIsCtrl: Bool
    /// Debug overlay: set `MTL_HUD_ENABLED=1` at launch to show the Metal performance HUD.
    var showMetalHUD: Bool
    /// Optional `cmd /c` batch wrapper that runs `cd /d <game_dir>` before launching the executable.
    var useBatchWrapper: Bool

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
            macDriverRetina: true,
            leftCommandIsCtrl: false,
            showMetalHUD: false,
            useBatchWrapper: false
        )
    }

    /// Migrates older settings to the Sophon-only bundled Genshin strategy.
    func applyingBundledGenshinDefaultsIfNeeded() -> AppSettings {
        var copy = self

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
    }

    init(
        games: [GameDefinition],
        selectedGameID: String?,
        language: AppLanguage,
        launchDisplayMode: LaunchDisplayMode = .windowed,
        macDriverRetina: Bool = true,
        leftCommandIsCtrl: Bool = false,
        showMetalHUD: Bool = false,
        useBatchWrapper: Bool = false
    ) {
        self.games = games
        self.selectedGameID = selectedGameID
        self.language = language
        self.launchDisplayMode = launchDisplayMode
        self.macDriverRetina = macDriverRetina
        self.leftCommandIsCtrl = leftCommandIsCtrl
        self.showMetalHUD = showMetalHUD
        self.useBatchWrapper = useBatchWrapper
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.games = try container.decode([GameDefinition].self, forKey: .games)
        self.selectedGameID = try container.decodeIfPresent(String.self, forKey: .selectedGameID)
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
        self.launchDisplayMode = try container.decodeIfPresent(LaunchDisplayMode.self, forKey: .launchDisplayMode) ?? .windowed
        self.macDriverRetina = try container.decodeIfPresent(Bool.self, forKey: .macDriverRetina) ?? true
        self.leftCommandIsCtrl = try container.decodeIfPresent(Bool.self, forKey: .leftCommandIsCtrl) ?? false
        self.showMetalHUD = try container.decodeIfPresent(Bool.self, forKey: .showMetalHUD) ?? false
        self.useBatchWrapper = try container.decodeIfPresent(Bool.self, forKey: .useBatchWrapper) ?? false

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
        try container.encode(launchDisplayMode, forKey: .launchDisplayMode)
        try container.encode(macDriverRetina, forKey: .macDriverRetina)
        try container.encode(leftCommandIsCtrl, forKey: .leftCommandIsCtrl)
        try container.encode(showMetalHUD, forKey: .showMetalHUD)
        try container.encode(useBatchWrapper, forKey: .useBatchWrapper)
    }

    /// Builds launch arguments with display mode controlled by settings rather than stale game flags.
    func launchArguments(for game: GameDefinition) -> [String] {
        Self.filteredUnityDisplayArguments(game.launchArguments) + launchDisplayMode.launchArguments
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
            "WINEDEBUG": "fixme-all,err-unwind"
        ]

        if backend == .dxmt {
            env["WINEMSYNC"] = "1"
            let cacheDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/NSLauncher/DXMT", isDirectory: true)
            env["DXMT_LOG_PATH"] = cacheDir.appendingPathComponent("dxmt.log").path
            env["DXMT_CONFIG_FILE"] = cacheDir.appendingPathComponent("dxmt.conf").path
        } else if backend == .dxvk {
            env["WINEESYNC"] = "1"
        }

        return LaunchRuntimeProfile(
            wineBinaryPath: settings.wineBinaryPath,
            prefixDirectory: game.winePrefixDirectory,
            executablePath: exe,
            currentDirectory: game.installDirectory,
            arguments: settings.launchArguments(for: game),
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
