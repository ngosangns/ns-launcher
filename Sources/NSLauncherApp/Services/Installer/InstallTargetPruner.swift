import Foundation

/// Removes files from an install root when they are no longer present in the target manifest.
enum InstallTargetPruner {
    private static let protectedRelativePaths: Set<String> = [
        ".nslauncher-install.json",
        ".nslauncher-sophon-staging",
        ".wine"
    ]

    /// Deletes non-target files and then removes empty non-target directories.
    static func prune(
        installDirectory: URL,
        targetRelativePaths: Set<String>,
        protectedURLs: [URL] = [],
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: installDirectory.path) else { return }

        let normalizedTargets = Set(targetRelativePaths.compactMap(normalizeRelativePath(_:)))
        let protectedPaths = protectedRelativePaths.union(
            protectedURLs.compactMap { relativePath(for: $0, under: installDirectory) }
        )

        guard let enumerator = fileManager.enumerator(
            at: installDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [],
            errorHandler: nil
        ) else {
            return
        }

        var directories: [String] = []

        for case let url as URL in enumerator {
            guard let relativePath = relativePath(for: url, under: installDirectory) else { continue }
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values.isDirectory == true

            if isProtected(relativePath, protectedPaths: protectedPaths) {
                if isDirectory {
                    enumerator.skipDescendants()
                }
                continue
            }

            if isDirectory {
                directories.append(relativePath)
            } else if isLauncherTemporaryFile(relativePath) {
                continue
            } else if !normalizedTargets.contains(relativePath) {
                try fileManager.removeItem(at: url)
            }
        }

        for relativePath in directories.sorted(by: { $0.count > $1.count }) {
            guard !isProtected(relativePath, protectedPaths: protectedPaths) else { continue }
            let directory = installDirectory.appendingPathComponent(relativePath, isDirectory: true)
            if (try? fileManager.contentsOfDirectory(atPath: directory.path).isEmpty) == true {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    /// Deletes non-target files early, before new target files are downloaded or merged.
    static func pruneBeforeApplyingTarget(
        installDirectory: URL,
        targetRelativePaths: Set<String>,
        protectedURLs: [URL] = [],
        fileManager: FileManager = .default
    ) throws {
        try prune(
            installDirectory: installDirectory,
            targetRelativePaths: targetRelativePaths,
            protectedURLs: protectedURLs,
            fileManager: fileManager
        )
    }

    private static func isProtected(_ relativePath: String, protectedPaths: Set<String>) -> Bool {
        protectedPaths.contains(where: { protected in
            relativePath == protected || relativePath.hasPrefix(protected + "/")
        })
    }

    private static func isLauncherTemporaryFile(_ relativePath: String) -> Bool {
        relativePath.hasSuffix(".partial")
            || relativePath.hasSuffix(".partial.segments.json")
            || relativePath.hasSuffix(".partial.chunks.json")
    }

    private static func relativePath(for url: URL, under root: URL) -> String? {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return nil }
        return normalizeRelativePath(String(path.dropFirst(rootPath.count + 1)))
    }

    private static func normalizeRelativePath(_ path: String) -> String? {
        let parts = path
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { !$0.isEmpty && $0 != "." }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "/")
    }
}
