// AbyssCycleHistoryStore.swift
//
// Persists a short local log of past cycles' best plan, under
// `~/Library/Application Support/NSLauncher/abyss-cycle-history.json`.
//
// Follows `AbyssSearchCacheStore`'s shape: a file that cannot be read back —
// an older layout, a truncated write — degrades to an empty log rather than
// an error the player has to do anything about, the same "convenience, not a
// record" philosophy. Unlike that store, this one is meant to accumulate
// across visits rather than be replaced by the latest run: `append` merges a
// new entry into what is already on disk instead of overwriting it.

import Foundation

protocol AbyssCycleHistoryStoring: Sendable {
    /// An empty log when there is nothing cached or the file cannot be read —
    /// see the file header on why that is the right degrade here.
    func load() -> AbyssCycleHistory
    /// Adds this cycle+floor's entry, replacing an earlier entry for the same
    /// cycle and floor (a re-run overwrites its own entry rather than
    /// duplicating it), then prunes to the newest
    /// `AbyssCycleHistoryStore.maxEntries`.
    func append(_ entry: AbyssCycleHistoryEntry) throws
    func clear() throws
}

struct AbyssCycleHistoryStore: AbyssCycleHistoryStoring {
    /// How many entries to keep. A handful answers "how did recent cycles go"
    /// without the file growing without bound — this is a log for context,
    /// not an archive.
    static let maxEntries = 6

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher", isDirectory: true)) {
        fileURL = baseDirectory.appendingPathComponent("abyss-cycle-history.json")
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> AbyssCycleHistory {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let history = try? decoder.decode(AbyssCycleHistory.self, from: data)
        else { return AbyssCycleHistory() }
        return history
    }

    func append(_ entry: AbyssCycleHistoryEntry) throws {
        var history = load()
        history.entries.removeAll { $0.cyclePeriodStart == entry.cyclePeriodStart && $0.floor == entry.floor }
        history.entries.append(entry)
        history.entries.sort { $0.computedAt > $1.computedAt }
        if history.entries.count > Self.maxEntries {
            history.entries.removeLast(history.entries.count - Self.maxEntries)
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try encoder.encode(history).write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
