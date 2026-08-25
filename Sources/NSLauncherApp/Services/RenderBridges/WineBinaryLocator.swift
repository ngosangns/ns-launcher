// WineBinaryLocator.swift
//
// Finds a usable Wine binary and the root of the build it belongs to.
//
// Shared by the render bridges, which disagree about which builds they can run on — DXMT needs
// winemac's Metal symbols, D3DMetal needs the apple_gptk tree — but agree on where to look and on
// refusing a quarantined binary rather than letting Gatekeeper kill the launch mid-flight.

import Foundation

enum WineBinaryLocator {
    /// Resolves the Wine root directory that contains bin/wine and lib/wine.
    static func wineRootDirectory(forBinaryAtPath path: String) throws -> URL {
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let wineRoot = resolvedURL.deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: wineRoot.appendingPathComponent("lib/wine").path) else {
            throw WineServiceError.dxmtBootstrapFailed("Unable to locate Wine lib/wine directory for \(path).")
        }
        return wineRoot
    }

    static func quarantinedPath(forExecutableAtPath path: String) -> String? {
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let candidatePaths = [
            enclosingAppBundlePath(for: resolvedURL),
            resolvedURL.path,
            path
        ].compactMap(\.self)

        return candidatePaths.first(where: hasQuarantineAttribute)
    }

    /// Returns the enclosing .app bundle for a Wine executable nested inside one.
    private static func enclosingAppBundlePath(for url: URL) -> String? {
        let components = url.pathComponents
        guard let appIndex = components.lastIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }
        return NSString.path(withComponents: Array(components.prefix(appIndex + 1)))
    }

    private static func hasQuarantineAttribute(atPath path: String) -> Bool {
        path.withCString { fileSystemPath in
            getxattr(fileSystemPath, "com.apple.quarantine", nil, 0, 0, 0) >= 0
        }
    }


    /// Candidate Wine binaries: the launcher-managed DXMT-patched Wine first, then the preferred
    /// PATH binary and CrossOver/GPTK/WineHQ app bundles as fallbacks. PATH wine (e.g. Game Porting
    /// Toolkit) may export a `macdrv_functions` table with an incompatible struct layout and crash
    /// at load time, so the managed build must win.
    static func candidatePaths(preferredPath: String) -> [String] {
        let preferredPath = preferredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitCandidates = [
            managedWineDirectory.appendingPathComponent("bin/wine64").path,
            managedWineDirectory.appendingPathComponent("bin/wine").path,
            preferredPath,
            BinaryLocator.resolveExecutable(
                preferredPath: preferredPath,
                candidateNames: BinaryLocator.candidateNames(forExecutable: preferredPath)
            ),
            "/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine",
            "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine64",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64"
        ].compactMap { $0 }.filter { !$0.isEmpty }

        var seen = Set<String>()
        var candidates = explicitCandidates.filter { seen.insert($0).inserted }

        candidates.append(contentsOf: wineExecutables(in: managedWineDirectory, seen: &seen))

        for appName in ["CrossOver.app", "Game Porting Toolkit.app", "Wine Devel.app"] {
            for root in applicationSearchRoots() {
                let appURL = root.appendingPathComponent(appName, isDirectory: true)
                candidates.append(contentsOf: wineExecutables(in: appURL, seen: &seen))
            }
        }

        return candidates
    }

    /// Launcher-managed directory where a DXMT-patched Wine can be extracted so the resolver can
    /// pick it up without any system-wide install or PATH changes.
    private static var managedWineDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NSLauncher/wine", isDirectory: true)
    }

    /// Searches standard app locations without scanning the whole filesystem.
    private static func applicationSearchRoots() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    /// Finds wine/wine64 executables inside a known app bundle.
    private static func wineExecutables(in appURL: URL, seen: inout Set<String>) -> [String] {
        guard FileManager.default.fileExists(atPath: appURL.path),
              let enumerator = FileManager.default.enumerator(
                  at: appURL,
                  includingPropertiesForKeys: [.isExecutableKey, .isRegularFileKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var results: [String] = []
        for case let url as URL in enumerator {
            guard ["wine", "wine64"].contains(url.lastPathComponent),
                  url.pathComponents.contains("bin"),
                  seen.insert(url.path).inserted,
                  FileManager.default.isExecutableFile(atPath: url.path) else {
                continue
            }
            results.append(url.path)
        }
        return results
    }
}
