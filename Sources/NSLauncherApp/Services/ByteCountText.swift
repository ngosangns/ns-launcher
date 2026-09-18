// ByteCountText.swift
//
// One shared `ByteCountFormatter` for the whole app.
//
// `ByteCountFormatter.string(fromByteCount:countStyle:)` builds a formatter for
// every call, and the call sites are the ones that can least afford it: five per
// download progress event, and one per row in the cutscene list. Every caller
// wants the same `.file` style, so they can share a single instance.

import Foundation

extension ByteCountFormatter {
    // `ByteCountFormatter` is not `Sendable` and the callers are not all on the
    // same actor — the installer formats from its own task — so the shared
    // instance is guarded. The lock is held only for the formatting call itself,
    // which is far cheaper than the allocation it replaces.
    nonisolated(unsafe) private static let file: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
    private static let fileLock = NSLock()

    /// A byte count in `.file` style — "1,2 GB".
    static func fileSize(_ bytes: Int64) -> String {
        fileLock.lock()
        defer { fileLock.unlock() }
        return file.string(fromByteCount: bytes)
    }
}
