// AbyssSearchCacheStore.swift
//
// Persists the last search result, under
// `~/Library/Application Support/NSLauncher/abyss-search-cache.json`.
//
// Follows `AbyssShowcaseStore`'s shape exactly: a cached search is a
// convenience, not a record, so a file that cannot be read back — an older
// layout, a truncated write — degrades to "nothing cached" rather than an
// error the player has to do anything about. Re-running the search costs
// time, not correctness.

import Foundation

protocol AbyssSearchCacheStoring: Sendable {
    /// The most recent cached search, or `nil` when there is none or it has
    /// aged past `AbyssSearchCacheStore.maxAge`. Expiry is checked here rather
    /// than left to the caller, so every caller gets it for free.
    func load() -> AbyssSearchCache?
    func save(_ cache: AbyssSearchCache) throws
    func clear() throws
}

struct AbyssSearchCacheStore: AbyssSearchCacheStoring {
    /// How long a cached result answers for.
    ///
    /// The search itself never goes stale — see `AbyssSearchCache`'s doc on why
    /// a matching digest is always correct — so this bounds the one thing that
    /// is not in the digest (a bundled-data correction landing between app
    /// versions on an otherwise-unchanged rotation) rather than the computation
    /// itself. A week is long enough that a player planning the current
    /// rotation is not re-running the search on every visit, and short enough
    /// that the whole cycle turns over roughly once before an entry could be
    /// stale for a reason the digest cannot see.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher", isDirectory: true)) {
        fileURL = baseDirectory.appendingPathComponent("abyss-search-cache.json")
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> AbyssSearchCache? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let cache = try? decoder.decode(AbyssSearchCache.self, from: data),
              Date().timeIntervalSince(cache.computedAt) < Self.maxAge
        else { return nil }
        return cache
    }

    func save(_ cache: AbyssSearchCache) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try encoder.encode(cache).write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
