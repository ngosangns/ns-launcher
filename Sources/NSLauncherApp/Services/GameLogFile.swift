// GameLogFile.swift
//
// Where a game session's Wine output goes.
//
// A session runs for hours and Wine writes the whole time. Streaming that through the launcher
// costs the main thread — the same thread the game is competing with — for output nobody reads
// while playing, so it goes straight to a file instead and the UI keeps showing only the
// launcher's own progress. YAAGL does the same thing with a shell redirect.

import Foundation

/// Per-launch log files under the standard macOS location, so Console.app can open them.
enum GameLogFile {
    /// How many previous sessions to keep before the oldest are removed.
    private static let retainedLogCount = 10

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/NSLauncher", isDirectory: true)
    }

    /// Returns the file this launch should write to, pruning older sessions first.
    ///
    /// Returns nil when the directory cannot be created; the caller then falls back to piping,
    /// which is slower but must not stop someone from playing.
    static func prepare(now: Date = Date()) -> URL? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        pruneOldLogs()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return directory.appendingPathComponent("game-\(formatter.string(from: now)).log")
    }

    /// Keeps the newest sessions and deletes the rest.
    private static func pruneOldLogs() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let logs = contents
            .filter { $0.lastPathComponent.hasPrefix("game-") && $0.pathExtension == "log" }
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return leftDate > rightDate
            }

        for log in logs.dropFirst(max(retainedLogCount - 1, 0)) {
            try? FileManager.default.removeItem(at: log)
        }
    }
}
