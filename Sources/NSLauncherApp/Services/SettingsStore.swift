// SettingsStore.swift
//
// JSON persistence for `AppSettings` under
// `~/Library/Application Support/NSLauncher/settings.json`. Writes are atomic so an
// interrupted save cannot corrupt the file.
//
// `AppSettings` uses synthesized Codable, which requires every key to be present. Rather than
// hand-writing a decoder that spells out a fallback per property — six edit points for every new
// setting — the stored JSON is merged onto the encoded defaults here, in one place. Keys the file
// does not carry keep their default, and keys it carries that no longer exist are dropped.

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
        return try decoder.decode(AppSettings.self, from: Self.merged(storedJSON: data))
    }

    /// Overlays the stored settings JSON onto the encoded defaults.
    ///
    /// Falls back to the stored bytes when either side is not a JSON object, so a corrupt file
    /// surfaces as a decoding error naming the real problem instead of being silently replaced.
    private static func merged(storedJSON: Data) throws -> Data {
        let defaultsEncoder = JSONEncoder()
        guard
            var object = try JSONSerialization.jsonObject(with: defaultsEncoder.encode(AppSettings.default)) as? [String: Any],
            let stored = try? JSONSerialization.jsonObject(with: storedJSON) as? [String: Any]
        else {
            return storedJSON
        }
        object.merge(stored) { _, storedValue in storedValue }
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// Writes settings atomically so interrupted saves do not corrupt the file.
    func save(_ settings: AppSettings) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
