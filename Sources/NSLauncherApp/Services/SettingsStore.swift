// SettingsStore.swift
//
// JSON persistence for `AppSettings` under
// `~/Library/Application Support/NSLauncher/settings.json`. Writes are atomic so an
// interrupted save cannot corrupt the file; the decoder in `AppSettings` tolerates
// removed legacy keys so older files still load.

import Foundation

/// Persistence boundary for application settings.
protocol SettingsStoring: Sendable {
    /// Loads settings, creating defaults when needed.
    func load() throws -> AppSettings
    /// Atomically writes the latest settings to disk.
    func save(_ settings: AppSettings) throws
}

/// JSON-backed settings store under Application Support.
struct SettingsStore: SettingsStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Creates a store rooted at the default NSLauncher support directory.
    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher", isDirectory: true)) {
        self.fileURL = baseDirectory.appendingPathComponent("settings.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    /// Loads persisted settings or initializes the settings file with defaults.
    func load() throws -> AppSettings {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try save(.default)
            return .default
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppSettings.self, from: data)
    }

    /// Writes settings atomically so interrupted saves do not corrupt the file.
    func save(_ settings: AppSettings) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
