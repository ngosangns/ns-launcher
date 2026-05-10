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
    case archivePackage
    case existingInstall
    case manifest
    case streamingManifest

    var id: String { rawValue }
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

/// Archive formats supported by the package installer.
enum ArchiveFormat: String, Codable, CaseIterable, Identifiable {
    case sevenZip
    case zip
    case multipartZip
    case tarGz

    var id: String { rawValue }

    /// Human-readable extension hint shown in Settings and used for default names.
    var fileExtensionHint: String {
        switch self {
        case .sevenZip:
            return "7z"
        case .zip:
            return "zip"
        case .multipartZip:
            return "zip.001"
        case .tarGz:
            return "tar.gz"
        }
    }
}

/// Remote archive description for single-file or multipart package downloads.
struct PackageSource: Codable, Hashable {
    var remoteURL: URL?
    var partURLs: [URL]?
    var archiveFileName: String
    var archiveFormat: ArchiveFormat
    var expectedArchiveSize: Int64?
}

/// Resume metadata written beside partial package downloads.
struct PersistedDownloadState: Codable, Equatable {
    var gameID: String
    var archiveFileName: String
    var archiveFormat: ArchiveFormat
    var totalExpectedBytes: Int64?
    var downloadedBytes: Int64
    var currentPart: Int?
    var totalParts: Int?
    var currentPartURL: URL
    var currentPartFileName: String
    var currentPartReceivedBytes: Int64
    var currentPartExpectedBytes: Int64?
    var supportsByteRanges: Bool
    var etag: String?
    var lastModified: String?
    var savedAt: Date
}

/// Marker file written into an install directory after a successful install/import.
struct InstalledGameMetadata: Codable, Hashable {
    var gameID: String
    var installMode: InstallerStrategy
    var installedAt: Date
    var sourceArchiveFileName: String?
    var executableRelativePath: String
    var version: String?
}

/// Result returned by import and re-scan validation.
struct ImportValidationResult: Hashable {
    var isValid: Bool
    var message: String
}

/// Coarse install state used by UI or future persistence.
enum InstallState: String, Codable {
    case notInstalled
    case packageReady
    case installed
    case imported
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
    var manifestURL: URL?
    var packageSource: PackageSource?
    var launchArguments: [String]
}

/// File manifest format used by the manifest installer.
struct RemoteGameManifest: Codable, Hashable {
    var version: String
    var files: [RemoteGameFile]
}

/// One downloadable file in a remote manifest.
struct RemoteGameFile: Codable, Hashable, Identifiable {
    var path: String
    var url: URL
    var size: Int64
    var md5: String?
    var sha256: String?

    var id: String { path }
}

/// User-facing estimate of the operations required for an install.
struct InstallPlan: Hashable {
    var version: String
    var steps: [InstallStep]
    var estimatedBytesToDownload: Int64
    var peakTemporaryBytes: Int64
}

/// Delta plan for bringing an existing manifest install up to the latest version.
struct GameUpdatePlan: Hashable {
    var sourceKind: UpdatePlanSourceKind = .manifest
    var installedVersion: String?
    var latestVersion: String
    var targetFiles: [RemoteGameFile] = []
    var filesToDownload: [RemoteGameFile]
    var sophonTargetAssets: [SophonAsset] = []
    var sophonAssetsToWrite: [SophonAsset] = []
    var skippedFiles: Int
    var sophonSkippedAssets: Int = 0
    var bytesToDownload: Int64
    var decompressedBytesToWrite: Int64 = 0
    var peakTemporaryBytes: Int64
    var metadataNeedsUpdate: Bool

    var isUpToDate: Bool {
        filesToDownload.isEmpty && sophonAssetsToWrite.isEmpty && !metadataNeedsUpdate
    }

    var changedItemCount: Int {
        switch sourceKind {
        case .manifest:
            return filesToDownload.count
        case .sophon:
            return sophonAssetsToWrite.count
        }
    }

    var skippedItemCount: Int {
        switch sourceKind {
        case .manifest:
            return skippedFiles
        case .sophon:
            return sophonSkippedAssets
        }
    }
}

/// Update backend selected for a plan.
enum UpdatePlanSourceKind: String, Hashable {
    case manifest
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
    private static let genshinArchiveExecutablePath = "Genshin Impact Game/GenshinImpact.exe"
    private static let genshinStreamingExecutablePath = "GenshinImpact.exe"

    var games: [GameDefinition]
    var selectedGameID: String?
    var language: AppLanguage
    var downloadCacheDirectory: String
    var temporaryExtractionDirectory: String
    var launchDisplayMode: LaunchDisplayMode

    /// Resolved Wine executable path, falling back to a PATH lookup name.
    var wineBinaryPath: String {
        BinaryLocator.resolveManagedExecutable(.wine, preferredPath: "") ?? "wine64"
    }

    /// Resolved aria2 executable path reserved for future downloader integrations.
    var aria2BinaryPath: String {
        BinaryLocator.resolveManagedExecutable(.aria2, preferredPath: "") ?? "aria2c"
    }

    /// Resolved 7-Zip executable path used by archive extraction.
    var sevenZipBinaryPath: String {
        BinaryLocator.resolveManagedExecutable(.sevenZip, preferredPath: "") ?? "7zz"
    }

    /// Bundled multipart package metadata for the default Genshin Impact entry.
    static var defaultGenshinPackageSource: PackageSource {
        let genshinPackageParts = [
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.001",
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.002",
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.003",
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.004",
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.005",
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.006",
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.007",
            "https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20250314110016_HcIQuDGRmsbByeAE/GenshinImpact_5.5.0.zip.008"
        ].compactMap(URL.init(string:))

        return PackageSource(
            remoteURL: genshinPackageParts.first,
            partURLs: genshinPackageParts,
            archiveFileName: "GenshinImpact_5.5.0.zip.001",
            archiveFormat: .multipartZip,
            expectedArchiveSize: 80030274036
        )
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
                    installerStrategy: .streamingManifest,
                    runtimeRequirements: [.wine, .dxmt],
                    manifestURL: nil,
                    packageSource: nil,
                    launchArguments: []
                )
            ],
            selectedGameID: genshinGameID,
            language: .english,
            downloadCacheDirectory: home
                .appendingPathComponent("Library/Caches/NSLauncher/Downloads", isDirectory: true)
                .path,
            temporaryExtractionDirectory: home
                .appendingPathComponent("Library/Caches/NSLauncher/Extraction", isDirectory: true)
                .path,
            launchDisplayMode: .windowed
        )
    }

    /// Migrates older settings to the current bundled Genshin streaming strategy.
    func applyingBundledGenshinDefaultsIfNeeded() -> AppSettings {
        var copy = self

        guard let index = copy.games.firstIndex(where: { $0.id == Self.genshinGameID }) else {
            return copy
        }

        copy.games[index].installerStrategy = .streamingManifest
        copy.games[index].manifestURL = nil
        copy.games[index].runtimeRequirements.removeAll { $0 == .dxvk }
        if !copy.games[index].runtimeRequirements.contains(.dxmt) {
            copy.games[index].runtimeRequirements.append(.dxmt)
        }
        if copy.games[index].executableRelativePath == Self.genshinArchiveExecutablePath {
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
    }

    init(
        games: [GameDefinition],
        selectedGameID: String?,
        language: AppLanguage,
        downloadCacheDirectory: String,
        temporaryExtractionDirectory: String,
        launchDisplayMode: LaunchDisplayMode = .windowed
    ) {
        self.games = games
        self.selectedGameID = selectedGameID
        self.language = language
        self.downloadCacheDirectory = downloadCacheDirectory
        self.temporaryExtractionDirectory = temporaryExtractionDirectory
        self.launchDisplayMode = launchDisplayMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.games = try container.decode([GameDefinition].self, forKey: .games)
        self.selectedGameID = try container.decodeIfPresent(String.self, forKey: .selectedGameID)
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
        self.downloadCacheDirectory = try container.decode(String.self, forKey: .downloadCacheDirectory)
        self.temporaryExtractionDirectory = try container.decode(String.self, forKey: .temporaryExtractionDirectory)
        self.launchDisplayMode = try container.decodeIfPresent(LaunchDisplayMode.self, forKey: .launchDisplayMode) ?? .windowed

        // Ignore deprecated custom binary paths while remaining decode-compatible with older settings files.
        _ = try container.decodeIfPresent(String.self, forKey: .wineBinaryPath)
        _ = try container.decodeIfPresent(String.self, forKey: .aria2BinaryPath)
        _ = try container.decodeIfPresent(String.self, forKey: .sevenZipBinaryPath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(games, forKey: .games)
        try container.encodeIfPresent(selectedGameID, forKey: .selectedGameID)
        try container.encode(language, forKey: .language)
        try container.encode(downloadCacheDirectory, forKey: .downloadCacheDirectory)
        try container.encode(temporaryExtractionDirectory, forKey: .temporaryExtractionDirectory)
        try container.encode(launchDisplayMode, forKey: .launchDisplayMode)
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
    case preparing(String)
    case readyToExtract(downloadedParts: Int, totalParts: Int)
    case downloadingPackage(
        path: String,
        received: Int64,
        total: Int64,
        currentPart: Int?,
        totalParts: Int?,
        currentPartReceived: Int64?,
        currentPartTotal: Int64?,
        speedBytesPerSecond: Int64?
    )
    case downloading(path: String, received: Int64, total: Int64)
    case downloadingManifest(
        path: String,
        overallReceived: Int64,
        overallTotal: Int64,
        fileReceived: Int64,
        fileTotal: Int64
    )
    case extracting(path: String)
    case verifying(path: String)
    case validatingInstall(path: String)
    case cleaningDownloadedArchives(path: String)
    case importing(path: String)
    case finished(version: String)
}
