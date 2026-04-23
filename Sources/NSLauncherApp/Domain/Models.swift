import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case vietnamese

    var id: String { rawValue }
}

enum InstallerStrategy: String, Codable, CaseIterable, Identifiable {
    case archivePackage
    case existingInstall
    case manifest

    var id: String { rawValue }
}

enum RuntimeRequirement: String, Codable, CaseIterable, Identifiable {
    case wine
    case dxvk
    case dxmt
    case reshade

    var id: String { rawValue }
}

enum ArchiveFormat: String, Codable, CaseIterable, Identifiable {
    case sevenZip
    case zip
    case multipartZip
    case tarGz

    var id: String { rawValue }

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

struct PackageSource: Codable, Hashable {
    var remoteURL: URL?
    var partURLs: [URL]?
    var archiveFileName: String
    var archiveFormat: ArchiveFormat
    var expectedArchiveSize: Int64?
}

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

struct InstalledGameMetadata: Codable, Hashable {
    var gameID: String
    var installMode: InstallerStrategy
    var installedAt: Date
    var sourceArchiveFileName: String?
    var executableRelativePath: String
    var version: String?
}

struct ImportValidationResult: Hashable {
    var isValid: Bool
    var message: String
}

enum InstallState: String, Codable {
    case notInstalled
    case packageReady
    case installed
    case imported
}

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

struct RemoteGameManifest: Codable, Hashable {
    var version: String
    var files: [RemoteGameFile]
}

struct RemoteGameFile: Codable, Hashable, Identifiable {
    var path: String
    var url: URL
    var size: Int64
    var sha256: String?

    var id: String { path }
}

struct InstallPlan: Hashable {
    var version: String
    var steps: [InstallStep]
    var estimatedBytesToDownload: Int64
    var peakTemporaryBytes: Int64
}

struct InstallStep: Hashable, Identifiable {
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

struct LaunchConfiguration: Codable, Hashable {
    var gameArguments: [String]
    var environment: [String: String]
}

struct AppSettings: Codable, Equatable {
    var games: [GameDefinition]
    var selectedGameID: String?
    var language: AppLanguage
    var wineBinaryPath: String
    var aria2BinaryPath: String
    var sevenZipBinaryPath: String
    var downloadCacheDirectory: String
    var temporaryExtractionDirectory: String

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

    static var `default`: AppSettings {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home
            .appendingPathComponent("Games", isDirectory: true)
            .appendingPathComponent("Genshin Impact", isDirectory: true)
        return AppSettings(
            games: [
                GameDefinition(
                    id: "genshin-global",
                    displayName: "Genshin Impact",
                    installDirectory: root,
                    executableRelativePath: "Genshin Impact Game/GenshinImpact.exe",
                    winePrefixDirectory: root.appendingPathComponent(".wine", isDirectory: true),
                    installerStrategy: .archivePackage,
                    runtimeRequirements: [.wine],
                    manifestURL: nil,
                    packageSource: defaultGenshinPackageSource,
                    launchArguments: []
                )
            ],
            selectedGameID: "genshin-global",
            language: .english,
            wineBinaryPath: "/opt/homebrew/bin/wine64",
            aria2BinaryPath: "/opt/homebrew/bin/aria2c",
            sevenZipBinaryPath: "/opt/homebrew/bin/7zz",
            downloadCacheDirectory: home
                .appendingPathComponent("Library/Caches/NSLauncher/Downloads", isDirectory: true)
                .path,
            temporaryExtractionDirectory: home
                .appendingPathComponent("Library/Caches/NSLauncher/Extraction", isDirectory: true)
                .path
        )
    }

    func applyingBundledGenshinDefaultsIfNeeded() -> AppSettings {
        var copy = self
        guard let index = copy.games.firstIndex(where: { $0.id == "genshin-global" }) else {
            return copy
        }

        let current = copy.games[index].packageSource
        let shouldBackfill =
            current == nil ||
            ((current?.remoteURL == nil) && (current?.partURLs?.isEmpty ?? true)) ||
            current?.archiveFileName == "GenshinImpact_latest.7z"

        if shouldBackfill {
            copy.games[index].packageSource = Self.defaultGenshinPackageSource
        }

        return copy
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
    case extracting(path: String)
    case verifying(path: String)
    case validatingInstall(path: String)
    case importing(path: String)
    case rescanning(path: String)
    case finished(version: String)
}
