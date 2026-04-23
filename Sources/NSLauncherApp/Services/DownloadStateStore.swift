import Foundation

protocol DownloadStateStoring: Sendable {
    func load(for gameID: String) throws -> PersistedDownloadState?
    func save(_ state: PersistedDownloadState) throws
    func clear(for gameID: String) throws
}

struct DownloadStateStore: DownloadStateStoring {
    private let baseDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher/DownloadState", isDirectory: true)) {
        self.baseDirectory = baseDirectory
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load(for gameID: String) throws -> PersistedDownloadState? {
        let metadataURL = metadataURL(for: gameID)
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode(PersistedDownloadState.self, from: data)
    }

    func save(_ state: PersistedDownloadState) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let metadataData = try encoder.encode(state)
        try metadataData.write(to: metadataURL(for: state.gameID), options: .atomic)
    }

    func clear(for gameID: String) throws {
        let fileManager = FileManager.default
        let metadataURL = metadataURL(for: gameID)

        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
    }

    private func metadataURL(for gameID: String) -> URL {
        baseDirectory.appendingPathComponent("\(sanitizedFileComponent(for: gameID)).json")
    }
    private func sanitizedFileComponent(for value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
    }
}
