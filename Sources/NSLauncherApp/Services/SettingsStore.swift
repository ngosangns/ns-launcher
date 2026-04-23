import Foundation

protocol SettingsStoring: Sendable {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}

struct SettingsStore: SettingsStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher", isDirectory: true)) {
        self.fileURL = baseDirectory.appendingPathComponent("settings.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() throws -> AppSettings {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try save(.default)
            return .default
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppSettings.self, from: data)
    }

    func save(_ settings: AppSettings) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
