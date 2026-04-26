import Foundation

enum GenshinStreamingMetadataError: LocalizedError {
    case officialStreamingMetadataUnavailable
    case streamingManifestIncomplete
    case freshInstallUnsupported

    var errorDescription: String? {
        switch self {
        case .officialStreamingMetadataUnavailable:
            return "Official streaming metadata is unavailable for Genshin Impact."
        case .streamingManifestIncomplete:
            return "Official metadata does not expose a complete file manifest for Genshin Impact."
        case .freshInstallUnsupported:
            return "Fresh install is currently unsupported because the official streaming manifest is incomplete."
        }
    }
}

protocol GenshinStreamingMetadataProviding: Sendable {
    func fetchManifest(for game: GameDefinition, language: AppLanguage) async throws -> RemoteGameManifest
}

struct GenshinStreamingMetadataService: GenshinStreamingMetadataProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchManifest(for game: GameDefinition, language: AppLanguage) async throws -> RemoteGameManifest {
        guard game.id == "genshin-global" else {
            throw GenshinStreamingMetadataError.freshInstallUnsupported
        }

        let metadata = try await fetchOfficialMetadata(language: language)
        guard !metadata.resListURL.absoluteString.isEmpty else {
            throw GenshinStreamingMetadataError.officialStreamingMetadataUnavailable
        }
        let files = try await fetchManifestEntries(baseURL: metadata.resListURL)
        guard !files.isEmpty else {
            throw GenshinStreamingMetadataError.streamingManifestIncomplete
        }

        return RemoteGameManifest(version: metadata.version, files: files)
    }

    private func fetchOfficialMetadata(language: AppLanguage) async throws -> GenshinOfficialMetadata {
        var components = URLComponents(string: "https://sg-hyp-api.hoyoverse.com/hyp/hyp-connect/api/getGamePackages")
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
            let entry = try decoder.decode(GenshinPkgVersionEntry.self, from: Data(line.utf8))
            guard !entry.remoteName.isEmpty, entry.fileSize > 0 else {
                throw GenshinStreamingMetadataError.streamingManifestIncomplete
            }

            let fileURL = fileURL(for: entry.remoteName, baseURL: baseURL)
            return RemoteGameFile(
                path: entry.remoteName,
                url: fileURL,
                size: entry.fileSize,
                sha256: nil
            )
        }
    }

    private func fileURL(for remoteName: String, baseURL: URL) -> URL {
        remoteName
            .split(separator: "/")
            .map(String.init)
            .reduce(baseURL) { partialURL, component in
                partialURL.appendingPathComponent(component, isDirectory: false)
            }
    }
}

private struct GenshinOfficialMetadata {
    var version: String
    var resListURL: URL
}

private struct GenshinPkgVersionEntry: Decodable {
    var remoteName: String
    var md5: String
    var hash: String
    var fileSize: Int64
}

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
