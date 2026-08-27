// WineBinaryLocator.swift
//
// Finds usable Wine builds and ranks them newest first.
//
// Shared by the render bridges, which disagree about which builds they can run on — D3DMetal needs
// a build carrying Apple's Game Porting Toolkit payload, DXVK only needs a loader — but agree on
// where to look, on what counts as a usable binary, and on not letting Gatekeeper kill a launch
// mid-flight.
//
// A candidate is usable only if it answers `--version` with a `wine-<major>` string. That single
// rule replaces a pile of per-distribution special cases: CrossOver ships `bin/wine` as a Perl
// wrapper that reports CrossOver product info and dies when run directly, next to the real loader
// `bin/wineloader`. The wrapper fails the probe, the loader passes, and nothing here has to know
// the word "CrossOver".
//
// Ranking is by version, not by where a build was found. A hard-coded path must not let an old
// build beat a newer one turned up by scanning: Game Porting Toolkit 1.1 is wine-7.7 and sat ahead
// of CrossOver's wine-11.0 purely because its path was listed first.

import Foundation

/// A Wine build the launcher can run a game on.
struct WineBuild: Sendable {
    /// Executable to invoke.
    let binaryPath: String
    /// Root directory containing `bin/` and `lib/wine`.
    let root: URL
    /// Major version reported by `--version`, used to reject builds too old for a bridge's ABI.
    let majorVersion: Int
}

/// Outcome of a Wine search: what can be used, and what macOS is holding.
struct WineSearchResult: Sendable {
    /// Usable builds, newest first.
    var builds: [WineBuild] = []
    /// Paths skipped because they are quarantined.
    ///
    /// Surfaced only when no build works at all. A quarantined build the launcher was never going
    /// to pick must not abort a launch that had a working alternative — that sent people off to
    /// run `xattr` on an app the launcher does not even use.
    var quarantinedPaths: [String] = []
}

enum WineBinaryLocator {
    /// Executable names a Wine build uses for its loader.
    ///
    /// `wineloader` is CrossOver's real binary; its `bin/wine` is a Perl wrapper that cannot run a
    /// game directly. Both are probed and the version check picks the right one.
    private static let loaderNames = ["wine64", "wine", "wineloader"]

    /// App bundles known to carry a Wine build.
    private static let knownWineApplications = [
        "CrossOver.app",
        "Wine Devel.app",
        "Wine Stable.app",
        "Wine Staging.app",
        "Game Porting Toolkit.app"
    ]

    /// Upper bound on a `--version` probe. A candidate that hangs here would freeze the launch
    /// before the game ever starts, so the probe is abandoned rather than waited on.
    private static let versionProbeTimeoutNanoseconds: UInt64 = 5_000_000_000

    /// Resolves the Wine root directory that contains bin/wine and lib/wine.
    static func wineRootDirectory(forBinaryAtPath path: String) throws -> URL {
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let wineRoot = resolvedURL.deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: wineRoot.appendingPathComponent("lib/wine").path) else {
            throw WineServiceError.wineRootNotFound(path)
        }
        return wineRoot
    }

    /// Launcher-managed slot the resolver also scans, so a Wine build symlinked or unpacked here is
    /// picked up without any system-wide install or PATH change. Nothing populates it automatically.
    static var managedWineDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NSLauncher/wine", isDirectory: true)
    }

    /// CrossOver-derived builds locate their own DLLs and compatibility database relative to
    /// `CX_ROOT`; without it they log `prepend_cx_root_dll_path CX_ROOT not set` and skip that
    /// step. Returns nil for builds that do not need it.
    static func crossOverRoot(for build: WineBuild) -> URL? {
        let appleGPTK = build.root.appendingPathComponent("lib64/apple_gptk", isDirectory: true)
        return FileManager.default.fileExists(atPath: appleGPTK.path) ? build.root : nil
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

    /// One candidate that passed the cheap filesystem checks and is waiting on a `--version` probe.
    private struct VersionProbeCandidate: Sendable {
        let index: Int
        let path: String
        let root: URL
    }

    /// Probes every candidate and returns the usable builds, newest first.
    ///
    /// Nothing throws: a candidate that is missing, quarantined, rootless or silent about its
    /// version is reported and skipped. Deciding that the *set* is unusable belongs to the bridge,
    /// which is the only thing that knows what it additionally requires.
    static func search(
        preferredPath: String,
        processRunner: ProcessRunning,
        onDiagnostic: (String) -> Void
    ) async -> WineSearchResult {
        var result = WineSearchResult()

        // Filesystem checks are cheap stat calls; run them sequentially and keep only candidates
        // worth a version probe.
        var toProbe: [VersionProbeCandidate] = []
        for (index, candidate) in (await candidatePaths(preferredPath: preferredPath)).enumerated() {
            guard FileManager.default.isExecutableFile(atPath: candidate) else { continue }
            guard let root = try? wineRootDirectory(forBinaryAtPath: candidate) else {
                onDiagnostic("wine candidate skipped (no sibling lib/wine): \(candidate)")
                continue
            }
            if let quarantined = quarantinedPath(forExecutableAtPath: candidate) {
                onDiagnostic("wine candidate skipped (quarantined at \(quarantined)): \(candidate)")
                result.quarantinedPaths.append(quarantined)
                continue
            }
            toProbe.append(VersionProbeCandidate(index: index, path: candidate, root: root))
        }

        // `--version` is a whole process spawn per candidate, each bounded by its own 5s timeout.
        // Probing them one at a time meant a machine with several Wine installs paid every timeout
        // back to back before the game could even start loading; the candidates are independent of
        // each other, so they run concurrently instead.
        let probed = await withTaskGroup(of: (Int, WineBuild?).self) { group -> [Int: WineBuild] in
            for candidate in toProbe {
                group.addTask {
                    guard let major = await majorVersion(
                        ofBinaryAtPath: candidate.path,
                        processRunner: processRunner
                    ) else {
                        return (candidate.index, nil)
                    }
                    return (candidate.index, WineBuild(binaryPath: candidate.path, root: candidate.root, majorVersion: major))
                }
            }
            var results: [Int: WineBuild] = [:]
            for await (index, build) in group {
                if let build { results[index] = build }
            }
            return results
        }

        // Diagnostics and `found` are assembled back in discovery order, unaffected by which probe
        // finished first, so logs stay deterministic and the tie-break below still means what it says.
        var found: [WineBuild] = []
        for candidate in toProbe {
            if let build = probed[candidate.index] {
                onDiagnostic("wine candidate wine-\(build.majorVersion): \(candidate.path)")
                found.append(build)
            } else {
                onDiagnostic("wine candidate skipped (no wine version reported): \(candidate.path)")
            }
        }

        // Newest first. `sorted` is not stable, so discovery order is carried explicitly to break
        // ties — within one major version the managed build still wins over a scanned bundle.
        result.builds = found.enumerated()
            .sorted { left, right in
                left.element.majorVersion == right.element.majorVersion
                    ? left.offset < right.offset
                    : left.element.majorVersion > right.element.majorVersion
            }
            .map(\.element)
        return result
    }

    /// Candidate Wine binaries in discovery order: the launcher-managed build, then the preferred
    /// or PATH binary, then every known app bundle. Ordering here is not preference — `search`
    /// ranks by version.
    static func candidatePaths(preferredPath: String) async -> [String] {
        let preferredPath = preferredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitCandidates = [
            managedWineDirectory.appendingPathComponent("bin/wine64").path,
            managedWineDirectory.appendingPathComponent("bin/wine").path,
            preferredPath,
            BinaryLocator.resolveExecutable(
                preferredPath: preferredPath,
                candidateNames: BinaryLocator.candidateNames(forExecutable: preferredPath)
            )
        ].compactMap { $0 }.filter { !$0.isEmpty }

        var seen = Set<String>()
        var candidates = explicitCandidates.filter { seen.insert($0).inserted }

        candidates.append(contentsOf: wineExecutables(in: managedWineDirectory, seen: &seen))

        // Each known app bundle is an independent directory tree — CrossOver.app alone carries
        // thousands of files under lib/wine — and scanning them one after another on every launch
        // added their cost up serially. They share nothing until the results are merged below (each
        // scan gets its own local `seen`, only used to dedupe within that one bundle), so they scan
        // concurrently and are merged back in the original app/root order afterward.
        let bundleRoots = knownWineApplications.flatMap { appName in
            applicationSearchRoots().map { root in root.appendingPathComponent(appName, isDirectory: true) }
        }
        let scans = await withTaskGroup(of: (Int, [String]).self) { group -> [[String]] in
            for (index, appURL) in bundleRoots.enumerated() {
                group.addTask {
                    var localSeen = Set<String>()
                    return (index, wineExecutables(in: appURL, seen: &localSeen))
                }
            }
            var ordered = [[String]](repeating: [], count: bundleRoots.count)
            for await (index, paths) in group {
                ordered[index] = paths
            }
            return ordered
        }
        for paths in scans {
            for path in paths where seen.insert(path).inserted {
                candidates.append(path)
            }
        }

        return candidates
    }

    /// Reads the major version a Wine loader reports, or nil when it reports something else.
    ///
    /// A non-zero exit still gets its output read: what matters is whether the binary identifies
    /// itself as Wine, not how it terminated.
    private static func majorVersion(
        ofBinaryAtPath path: String,
        processRunner: ProcessRunning
    ) async -> Int? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                do {
                    let result = try await processRunner.run(
                        executable: path,
                        arguments: ["--version"],
                        environment: [:],
                        currentDirectory: nil
                    )
                    return result.stdout + result.stderr
                } catch let ProcessRunnerError.nonZeroExit(result) {
                    return result.stdout + result.stderr
                } catch {
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: versionProbeTimeoutNanoseconds)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first.flatMap(parseMajorVersion(from:))
        }
    }

    /// Extracts the major version from a `wine-11.0-8726-g2e2f5fca349` style version string.
    static func parseMajorVersion(from output: String) -> Int? {
        guard let range = output.range(of: #"wine-[0-9]+"#, options: .regularExpression) else {
            return nil
        }
        return Int(output[range].dropFirst("wine-".count))
    }

    /// Searches standard app locations without scanning the whole filesystem.
    private static func applicationSearchRoots() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    /// Finds Wine loader executables inside a known app bundle.
    ///
    /// A build is recognised by having a sibling `lib/wine`, the same test `wineRootDirectory`
    /// applies. The previous filter required a `bin` component in the path, which silently dropped
    /// CrossOver entirely: its `bin` is a symlink to `CrossOver-Hosted Application`, and
    /// `FileManager`'s enumerator reports the real directory rather than following the link, so the
    /// only path it ever produced had no `bin` in it.
    static func wineExecutables(in appURL: URL, seen: inout Set<String>) -> [String] {
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
            // `lib/wine` and `share/wine` are directories, and directories report as executable.
            let values = try? url.resourceValues(forKeys: [.isExecutableKey, .isRegularFileKey])
            guard loaderNames.contains(url.lastPathComponent),
                  values?.isRegularFile == true,
                  values?.isExecutable == true,
                  seen.insert(url.path).inserted,
                  (try? wineRootDirectory(forBinaryAtPath: url.path)) != nil else {
                continue
            }
            results.append(url.path)
        }
        return results
    }
}
