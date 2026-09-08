// AbyssRosterStore.swift
//
// JSON persistence for the player's Abyss roster under
// `~/Library/Application Support/NSLauncher/abyss-roster.json`, alongside
// `settings.json` rather than inside it: it can reach several hundred entries,
// it belongs to one feature, and keeping it separate makes import/export a plain
// file copy — the same file the Python tool reads.
//
// Writes are atomic so an interrupted save cannot leave a half-written roster.

import Foundation

protocol AbyssRosterStoring: Sendable {
    func load() throws -> AbyssRoster
    func save(_ roster: AbyssRoster) throws
    /// Reads a roster the user picked from disk, for the Import button.
    func importRoster(from url: URL) throws -> AbyssRoster
    /// Writes a roster to a user-chosen location, for the Export button.
    func exportRoster(_ roster: AbyssRoster, to url: URL) throws
}

struct AbyssRosterStore: AbyssRosterStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher", isDirectory: true)) {
        fileURL = baseDirectory.appendingPathComponent("abyss-roster.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    /// An absent file means "nothing owned yet", which is a normal first-run
    /// state rather than an error. A malformed file *is* an error: silently
    /// replacing it would throw away a roster the user spent time entering.
    func load() throws -> AbyssRoster {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .empty }
        return try decoder.decode(AbyssRoster.self, from: Data(contentsOf: fileURL))
    }

    func save(_ roster: AbyssRoster) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(roster).write(to: fileURL, options: .atomic)
    }

    func importRoster(from url: URL) throws -> AbyssRoster {
        try decoder.decode(AbyssRoster.self, from: Data(contentsOf: url))
    }

    /// The output is exactly what `load` and the Python tool accept.
    func exportRoster(_ roster: AbyssRoster, to url: URL) throws {
        try encoder.encode(roster).write(to: url, options: .atomic)
    }
}
