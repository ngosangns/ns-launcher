import Foundation

/// Persistence boundary for resumable package download metadata.
protocol DownloadStateStoring: Sendable {
    /// Returns the saved resume state for a game, if one exists.
    func load(for gameID: String) throws -> PersistedDownloadState?
    /// Saves the latest resume checkpoint for a game download.
    func save(_ state: PersistedDownloadState) throws
    /// Deletes any saved checkpoint for a completed or stopped download.
    func clear(for gameID: String) throws
}

/// JSON-backed store for per-game download checkpoints.
struct DownloadStateStore: DownloadStateStoring {
    private let baseDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a store rooted at the default NSLauncher download-state directory.
    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher/DownloadState", isDirectory: true)) {
        self.baseDirectory = baseDirectory
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    /// Decodes a saved checkpoint without creating the directory eagerly.
    func load(for gameID: String) throws -> PersistedDownloadState? {
        let metadataURL = metadataURL(for: gameID)
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode(PersistedDownloadState.self, from: data)
    }

    /// Writes a checkpoint atomically to preserve resume data across crashes.
    func save(_ state: PersistedDownloadState) throws {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let metadataData = try encoder.encode(state)
        try metadataData.write(to: metadataURL(for: state.gameID), options: .atomic)
    }

    /// Removes stale or consumed checkpoint data for a game.
    func clear(for gameID: String) throws {
        let fileManager = FileManager.default
        let metadataURL = metadataURL(for: gameID)

        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
    }

    /// Maps a game identifier to a stable metadata file path.
    private func metadataURL(for gameID: String) -> URL {
        baseDirectory.appendingPathComponent("\(sanitizedFileComponent(for: gameID)).json")
    }

    /// Keeps arbitrary game IDs safe as single path components.
    private func sanitizedFileComponent(for value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
    }
}
