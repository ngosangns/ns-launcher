// AbyssShowcaseStore.swift
//
// Persists the last showcase fetched from Enka, under
// `~/Library/Application Support/NSLauncher/abyss-showcase.json`.
//
// Deliberately *not* part of `abyss-roster.json`: that file is hand-entered by
// the player and is byte-compatible with the Python tool's `roster.json`, and
// this is fetched data with a shelf life. Keeping them apart means clearing one
// never touches the other, and an exported roster stays a plain roster.

import Foundation

protocol AbyssShowcaseStoring: Sendable {
    func load() throws -> AbyssShowcase?
    func save(_ showcase: AbyssShowcase) throws
    func clear() throws
}

struct AbyssShowcaseStore: AbyssShowcaseStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher", isDirectory: true)) {
        fileURL = baseDirectory.appendingPathComponent("abyss-showcase.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    /// A cached showcase is a convenience, not a record: if it cannot be read
    /// back — an older layout, a truncated write — the answer is "nothing
    /// cached", because re-fetching it costs one request.
    func load() throws -> AbyssShowcase? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try? decoder.decode(AbyssShowcase.self, from: Data(contentsOf: fileURL))
    }

    func save(_ showcase: AbyssShowcase) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try encoder.encode(showcase).write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
