import Foundation

/// Failures specific to HoYoPlay streaming metadata discovery.
enum GenshinStreamingMetadataError: LocalizedError {
    case officialStreamingMetadataUnavailable
    case streamingManifestIncomplete
    case freshInstallUnsupported
    case packageManifestStale(currentVersion: String, evidence: String)
    case sophonUpdateRequired(currentVersion: String, latestVersion: String, evidence: String)

    var errorDescription: String? {
        switch self {
        case .officialStreamingMetadataUnavailable:
            return "Official streaming metadata is unavailable for Genshin Impact."
        case .streamingManifestIncomplete:
            return "Official metadata does not expose a complete file manifest for Genshin Impact."
        case .freshInstallUnsupported:
            return "Fresh install is currently unsupported because the official streaming manifest is incomplete."
        case let .packageManifestStale(currentVersion, evidence):
            return "Official package manifest is stale at \(currentVersion). Evidence: \(evidence)"
        case let .sophonUpdateRequired(currentVersion, latestVersion, evidence):
            return "Genshin Impact \(latestVersion) uses Sophon chunk metadata; legacy package manifest is still \(currentVersion). Evidence: \(evidence)"
        }
    }
}

/// Boundary for converting official HoYoPlay metadata into the launcher's manifest shape.
protocol GenshinStreamingMetadataProviding: Sendable {
    func fetchManifest(for game: GameDefinition, language: AppLanguage) async throws -> RemoteGameManifest
    func fetchUpdateManifest(for game: GameDefinition, language: AppLanguage) async throws -> RemoteGameManifest
}

/// Reads Genshin Impact package metadata from HoYoPlay's public launcher endpoints.
struct GenshinStreamingMetadataService: GenshinStreamingMetadataProviding {
    private static let gamePackagesURL = "https://sg-hyp-api.hoyoverse.com/hyp/hyp-connect/api/getGamePackages"
    private static let gameBranchesURL = "https://sg-hyp-api.hoyoverse.com/hyp/hyp-connect/api/getGameBranches"
    private static let latestInstallerURL = "https://sg-public-api.hoyoverse.com/event/download_porter/time_link/ys_global/genshinimpactpc/default"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches the official package list and turns its resource list into RemoteGameFile entries.
    func fetchManifest(for game: GameDefinition, language: AppLanguage) async throws -> RemoteGameManifest {
        guard game.id == "genshin-global" else {
            throw GenshinStreamingMetadataError.freshInstallUnsupported
        }

        let manifest = try await fetchUpdateManifest(for: game, language: language)
        let files = manifest.files
        guard isCompleteFreshInstallManifest(files) else {
            throw GenshinStreamingMetadataError.streamingManifestIncomplete
        }

        return manifest
    }

    /// Fetches the official resource list for updating an existing install root.
    func fetchUpdateManifest(for game: GameDefinition, language: AppLanguage) async throws -> RemoteGameManifest {
        guard game.id == "genshin-global" else {
            throw GenshinStreamingMetadataError.freshInstallUnsupported
        }

        let metadata = try await fetchOfficialMetadata(language: language)
        if let branchEvidence = try? await fetchLiveBranchEvidence(language: language),
           isPackageManifestBehindLiveBranch(metadata: metadata, evidence: branchEvidence) {
            throw GenshinStreamingMetadataError.sophonUpdateRequired(
                currentVersion: metadata.version,
                latestVersion: branchEvidence.tag,
                evidence: branchEvidence.summary
            )
        }
        if let staleEvidence = try? await fetchLiveInstallerEvidence(),
           isPackageManifestStale(metadata: metadata, evidence: staleEvidence) {
            throw GenshinStreamingMetadataError.packageManifestStale(
                currentVersion: metadata.version,
                evidence: staleEvidence.summary
            )
        }
        guard !metadata.resListURL.absoluteString.isEmpty else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }
        let files = try await fetchManifestEntries(baseURL: metadata.resListURL)
        return RemoteGameManifest(version: metadata.version, files: files)
    }

    /// Calls HoYoPlay's package endpoint for the selected UI language.
    private func fetchOfficialMetadata(language: AppLanguage) async throws -> GenshinOfficialMetadata {
        var components = URLComponents(string: Self.gamePackagesURL)
        components?.queryItems = [
            URLQueryItem(name: "launcher_id", value: "VYTpXlbWo8"),
            URLQueryItem(name: "language", value: language.officialMetadataLanguageCode)
        ]

        guard let url = components?.url else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        let decoded = try JSONDecoder().decode(GenshinOfficialPackagesResponse.self, from: data)
        guard let package = decoded.data.gamePackages.first(where: { $0.game.biz == "hk4e_global" }),
              let resListURL = URL(string: package.main.major.resListURL),
              !package.main.major.version.isEmpty else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        return GenshinOfficialMetadata(
            version: package.main.major.version,
            resListURL: resListURL
        )
    }

    /// Reads HoYoPlay branch metadata, which moved newer Genshin builds to Sophon chunks.
    private func fetchLiveBranchEvidence(language: AppLanguage) async throws -> GenshinLiveBranchEvidence {
        var components = URLComponents(string: Self.gameBranchesURL)
        components?.queryItems = [
            URLQueryItem(name: "game_ids[]", value: "gopR6Cufr3"),
            URLQueryItem(name: "launcher_id", value: "VYTpXlbWo8"),
            URLQueryItem(name: "language", value: language.officialMetadataLanguageCode)
        ]

        guard let url = components?.url else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        let decoded = try JSONDecoder().decode(GenshinOfficialBranchesResponse.self, from: data)
        guard let branch = decoded.data.gameBranches.first(where: { $0.game.biz == "hk4e_global" }),
              !branch.main.tag.isEmpty else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        return GenshinLiveBranchEvidence(
            tag: branch.main.tag,
            packageID: branch.main.packageID,
            password: branch.main.password
        )
    }

    /// Reads a lightweight official installer link as a freshness signal for the package manifest.
    private func fetchLiveInstallerEvidence() async throws -> GenshinLiveInstallerEvidence {
        guard let url = URL(string: Self.latestInstallerURL) else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        let decoded = try JSONDecoder().decode(GenshinDownloadPorterResponse.self, from: data)
        guard decoded.retcode == 0, let link = URL(string: decoded.data.link) else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }

        return GenshinLiveInstallerEvidence(installerURL: link)
    }

    /// Detects the post-5.5 Genshin branch where update metadata is Sophon, not pkg_version.
    private func isPackageManifestBehindLiveBranch(metadata: GenshinOfficialMetadata, evidence: GenshinLiveBranchEvidence) -> Bool {
        compareVersions(metadata.version, evidence.tag) == .orderedAscending
    }

    /// Prevents reporting up-to-date when the package manifest is a known stale Genshin source.
    private func isPackageManifestStale(metadata: GenshinOfficialMetadata, evidence: GenshinLiveInstallerEvidence) -> Bool {
        guard let majorVersion = Int(metadata.version.split(separator: ".").first ?? "") else {
            return false
        }

        // The current HoYoPlay package endpoint can still return 5.5.0 while the official
        // download-porter installer link has moved to 2026-era packages. That combination is
        // stale enough to block "up to date" instead of trusting the old ScatteredFiles list.
        return majorVersion < 6 && evidence.installerURL.absoluteString.contains("/2026/")
    }

    /// Numeric semver-ish comparison for HoYoPlay tags such as 5.5.0 and 6.5.0.
    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftPart = index < left.count ? left[index] : 0
            let rightPart = index < right.count ? right[index] : 0
            if leftPart < rightPart { return .orderedAscending }
            if leftPart > rightPart { return .orderedDescending }
        }

        return .orderedSame
    }

    /// Reads the newline-delimited pkg_version resource list.
    private func fetchManifestEntries(baseURL: URL) async throws -> [RemoteGameFile] {
        let manifestURL = baseURL.appendingPathComponent("pkg_version", isDirectory: false)
        let (data, response) = try await session.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw GenshinStreamingMetadataError.streamingManifestIncomplete
        }

        guard let contents = String(data: data, encoding: .utf8) else {
            throw GenshinStreamingMetadataError.streamingManifestIncomplete
        }

        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw GenshinStreamingMetadataError.streamingManifestIncomplete
        }

        let decoder = JSONDecoder()
        return try lines.map { line in
            // Each line is an independent JSON object describing one resource file.
            let entry = try decoder.decode(GenshinPkgVersionEntry.self, from: Data(line.utf8))
            guard !entry.remoteName.isEmpty, entry.fileSize > 0 else {
                throw GenshinStreamingMetadataError.streamingManifestIncomplete
            }

            let fileURL = fileURL(for: entry.remoteName, baseURL: baseURL)
            return RemoteGameFile(
                path: entry.remoteName,
                url: fileURL,
                size: entry.fileSize,
                md5: entry.md5,
                sha256: nil
            )
        }
    }

    /// Builds a URL by appending every remote path component safely.
    private func fileURL(for remoteName: String, baseURL: URL) -> URL {
        remoteName
            .split(separator: "/")
            .map(String.init)
            .reduce(baseURL) { partialURL, component in
                partialURL.appendingPathComponent(component, isDirectory: false)
            }
    }

    /// Checks for the minimum file set needed to trust the official list for a fresh install.
    private func isCompleteFreshInstallManifest(_ files: [RemoteGameFile]) -> Bool {
        let paths = Set(files.map(\.path))
        guard paths.contains("GenshinImpact.exe"),
              paths.contains("GenshinImpact_Data/app.info") else {
            return false
        }

        let hasPlugins = paths.contains { $0.hasPrefix("GenshinImpact_Data/Plugins/") }
        let hasStreamingAssets = paths.contains { $0.hasPrefix("GenshinImpact_Data/StreamingAssets/") }
        let hasManagedOrNativeData = paths.contains { $0.hasPrefix("GenshinImpact_Data/Managed/") }
            || paths.contains { $0.hasPrefix("GenshinImpact_Data/Native/") }
        let totalBytes = files.reduce(Int64(0)) { $0 + $1.size }

        return hasPlugins
            && hasStreamingAssets
            && hasManagedOrNativeData
            && totalBytes > 50 * 1024 * 1024 * 1024
    }
}

/// Minimal official metadata needed by the launcher.
private struct GenshinOfficialMetadata {
    var version: String
    var resListURL: URL
}

/// Lightweight freshness signal from HoYoverse's public download porter.
private struct GenshinLiveInstallerEvidence {
    var installerURL: URL

    var summary: String {
        "download_porter=\(installerURL.absoluteString)"
    }
}

/// Live branch metadata from HoYoPlay's newer Sophon package flow.
private struct GenshinLiveBranchEvidence {
    var tag: String
    var packageID: String
    var password: String

    var summary: String {
        "getGameBranches tag=\(tag), package_id=\(packageID), branch=main"
    }
}

/// Decodable shape for the public latest installer endpoint.
private struct GenshinDownloadPorterResponse: Decodable {
    var retcode: Int
    var data: DataPayload

    struct DataPayload: Decodable {
        var link: String
    }
}

/// Decodable shape for HoYoPlay branch metadata.
private struct GenshinOfficialBranchesResponse: Decodable {
    var data: DataPayload

    struct DataPayload: Decodable {
        var gameBranches: [GameBranch]

        private enum CodingKeys: String, CodingKey {
            case gameBranches = "game_branches"
        }
    }

    struct GameBranch: Decodable {
        var game: Game
        var main: MainBranch
    }

    struct Game: Decodable {
        var biz: String
    }

    struct MainBranch: Decodable {
        var packageID: String
        var password: String
        var tag: String

        private enum CodingKeys: String, CodingKey {
            case packageID = "package_id"
            case password
            case tag
        }
    }
}

/// One line from HoYoPlay's pkg_version file.
private struct GenshinPkgVersionEntry: Decodable {
    var remoteName: String
    var md5: String
    var hash: String
    var fileSize: Int64
}

/// Decodable shape for the HoYoPlay game-packages response.
private struct GenshinOfficialPackagesResponse: Decodable {
    var data: DataPayload

    struct DataPayload: Decodable {
        var gamePackages: [GamePackage]

        private enum CodingKeys: String, CodingKey {
            case gamePackages = "game_packages"
        }
    }

    struct GamePackage: Decodable {
        var game: Game
        var main: MainPackage
    }

    struct Game: Decodable {
        var biz: String
    }

    struct MainPackage: Decodable {
        var major: MajorPackage
    }

    struct MajorPackage: Decodable {
        var version: String
        var resListURL: String

        private enum CodingKeys: String, CodingKey {
            case version
            case resListURL = "res_list_url"
        }
    }
}
