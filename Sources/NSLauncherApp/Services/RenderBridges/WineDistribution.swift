// WineDistribution.swift
//
// Installs the Wine build the launcher runs games on, into the slot `WineBinaryLocator` has always
// looked in first.
//
// Until now that slot was only ever read. With nothing to fill it, DXMT fell through to whatever
// Wine happened to be on the machine, and on a machine with Game Porting Toolkit that meant DXMT
// v0.80 loaded into wine-7.7 — a combination that faults inside the loader while holding ntdll's
// loader lock, so the game deadlocks at startup and never reports an error. YAAGL avoids this by
// shipping its own Wine and pinning it to a DXMT version; this does the same thing.
//
// The build is whatever `yaagl/anime-game-wine` currently publishes as its latest release, resolved
// at install time rather than pinned. That is a deliberate trade: a pinned tag guarantees DXMT runs
// against a Wine it was released with, and resolving latest gives that up in exchange for picking
// up new Wine builds without a launcher update. The version floor in `DXMTBridge` is the only thing
// still checking the pairing, and it is a compile-time constant — so a future Wine that breaks DXMT
// would get installed here and rejected there, surfacing as `dxmtWineTooOld` rather than a hang.
//
// `pinnedFallback` is the last known-good release. It is used when GitHub cannot be reached or
// answers with something unusable, so a launch never fails purely because an API call did.
//
// Non-destructive: an existing usable build in the slot is left alone, including a symlink into a
// Wine installed elsewhere. The slot's contract is "a usable Wine lives here", not "the launcher
// downloaded this".

import Foundation

enum WineDistribution {
    /// Human-readable name used in progress messages and error text.
    ///
    /// Deliberately version-free: which release this installs is only known after the API call, so
    /// naming a version here would be a lie half the time.
    static let displayName = "the latest signed Wine build"

    /// Release the launcher falls back to when the latest one cannot be resolved.
    static let pinnedFallback = Release(
        tag: "wine-11.0-signed",
        assetName: "wine-devel-11.0-osx64-signed.tar.xz",
        downloadURL: URL(
            string: "https://github.com/yaagl/anime-game-wine/releases/download/wine-11.0-signed/wine-devel-11.0-osx64-signed.tar.xz"
        )!
    )

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/yaagl/anime-game-wine/releases/latest"
    )!

    /// Upper bound on the release lookup. The download that follows is far longer, but this call
    /// sits in front of it on the launch path and must not be what stalls a launch.
    private static let releaseLookupTimeout: TimeInterval = 10

    /// One installable Wine release.
    struct Release: Sendable, Equatable {
        let tag: String
        let assetName: String
        let downloadURL: URL
    }

    /// Where the archive is downloaded and unpacked before the finished tree is moved into place.
    ///
    /// A sibling of the destination so the move is a rename on the same volume rather than a copy
    /// of several hundred megabytes.
    private static var stagingDirectory: URL {
        WineBinaryLocator.managedWineDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("wine-staging", isDirectory: true)
    }

    /// Downloads and installs the managed build unless the slot already holds a usable one.
    static func ensureInstalled(
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        if WineBinaryLocator.managedBuildIsPresent() {
            onDiagnostic("managed Wine already present at \(WineBinaryLocator.managedWineDirectory.path)")
            return
        }

        do {
            let release = await latestRelease(onDiagnostic: onDiagnostic)
            let staging = stagingDirectory
            try? FileManager.default.removeItem(at: staging)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging) }

            let archive = staging.appendingPathComponent(release.assetName)
            onDiagnostic("downloading \(release.tag) — this happens once")
            try await download(from: release.downloadURL, to: archive, onDiagnostic: onDiagnostic)

            onDiagnostic("extracting \(release.assetName)")
            _ = try await processRunner.run(
                executable: "/usr/bin/tar",
                arguments: ["-xf", archive.path, "-C", staging.path],
                environment: [:],
                currentDirectory: nil
            )
            try FileManager.default.removeItem(at: archive)

            guard let extractedRoot = wineRoot(under: staging) else {
                throw WineServiceError.wineDistributionFailed(
                    "\(release.assetName) did not contain a Wine build with bin/ and lib/wine."
                )
            }

            let destination = WineBinaryLocator.managedWineDirectory
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: extractedRoot, to: destination)

            guard WineBinaryLocator.managedBuildIsPresent() else {
                throw WineServiceError.wineDistributionFailed(
                    "Installed \(release.tag) but no usable loader was found at \(destination.path)."
                )
            }
            onDiagnostic("installed \(release.tag) at \(destination.path)")
        } catch let wineError as WineServiceError {
            throw wineError
        } catch {
            throw WineServiceError.wineDistributionFailed(error.localizedDescription)
        }
    }

    /// Resolves the newest published release, falling back to the last known-good pin.
    ///
    /// Never throws. A GitHub outage, a rate limit or a release published without a macOS archive
    /// must not be the reason a game cannot start, and the pinned release is known to work.
    static func latestRelease(onDiagnostic: @Sendable (String) -> Void) async -> Release {
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = releaseLookupTimeout
        // Without this GitHub may answer with a different representation; the documented one is
        // what `parseRelease` is written against.
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                onDiagnostic("wine release lookup returned HTTP \(status); using \(pinnedFallback.tag)")
                return pinnedFallback
            }
            guard let release = parseRelease(from: data) else {
                onDiagnostic("wine release lookup had no usable macOS archive; using \(pinnedFallback.tag)")
                return pinnedFallback
            }
            onDiagnostic("latest wine release: \(release.tag) (\(release.assetName))")
            return release
        } catch {
            onDiagnostic("wine release lookup failed (\(error.localizedDescription)); using \(pinnedFallback.tag)")
            return pinnedFallback
        }
    }

    /// Picks the macOS Wine archive out of a GitHub release payload.
    ///
    /// A release carries several assets and the set changes between releases, so the archive is
    /// chosen by shape — a tarball whose name says osx/macos — rather than by an exact filename
    /// that would break on the next publish. Signed builds win: an unsigned Wine is quarantined by
    /// Gatekeeper and `search` would then skip the very build just installed.
    static func parseRelease(from data: Data) -> Release? {
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = payload["tag_name"] as? String,
              let assets = payload["assets"] as? [[String: Any]] else {
            return nil
        }

        let archives = assets.compactMap { asset -> (name: String, url: URL)? in
            guard let name = asset["name"] as? String,
                  let urlString = asset["browser_download_url"] as? String,
                  let url = URL(string: urlString) else {
                return nil
            }
            let lowercased = name.lowercased()
            guard lowercased.hasSuffix(".tar.xz") || lowercased.hasSuffix(".tar.gz"),
                  lowercased.contains("osx") || lowercased.contains("macos") else {
                return nil
            }
            return (name, url)
        }

        guard let chosen = archives.first(where: { $0.name.lowercased().contains("signed") }) ?? archives.first else {
            return nil
        }
        return Release(tag: tag, assetName: chosen.name, downloadURL: chosen.url)
    }

    /// Finds the Wine root inside an extracted archive.
    ///
    /// Distributions disagree about their layout — some unpack a bare `wine/`, some an app bundle
    /// with the tree at `Contents/Resources/wine` — so the tree is located by its shape (a `lib/wine`
    /// next to a loader) rather than by a hard-coded path that silently breaks on the next release.
    private static func wineRoot(under directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var candidates: [URL] = [directory]
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            candidates.append(url)
        }

        return candidates.first { root in
            guard FileManager.default.fileExists(atPath: root.appendingPathComponent("lib/wine").path) else {
                return false
            }
            return ["wine64", "wine", "wineloader"].contains { name in
                FileManager.default.isExecutableFile(atPath: root.appendingPathComponent("bin/\(name)").path)
            }
        }
    }

    /// Downloads to a file, reporting progress at most once a second.
    ///
    /// Progress matters here specifically: this is several hundred megabytes on the launch path,
    /// and a launcher that goes silent for minutes is the exact symptom this whole change set is
    /// meant to remove.
    private static func download(
        from url: URL,
        to destination: URL,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        let observer = DownloadProgressObserver { written, expected in
            guard expected > 0 else {
                onDiagnostic("downloading \(displayName): \(megabytes(written)) MB")
                return
            }
            let percent = Int((Double(written) / Double(expected)) * 100)
            onDiagnostic("downloading \(displayName): \(megabytes(written))/\(megabytes(expected)) MB (\(percent)%)")
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: url, delegate: observer)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw WineServiceError.wineDistributionFailed("Unable to download \(url.lastPathComponent).")
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private static func megabytes(_ bytes: Int64) -> Int {
        Int(bytes / 1_048_576)
    }
}

/// Reports download progress, throttled so a long transfer does not flood the launch log.
private final class DownloadProgressObserver: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let report: @Sendable (Int64, Int64) -> Void
    private let lock = NSLock()
    private var lastReport = Date.distantPast

    init(report: @escaping @Sendable (Int64, Int64) -> Void) {
        self.report = report
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let shouldReport = lock.withLock {
            guard Date().timeIntervalSince(lastReport) >= 1 else { return false }
            lastReport = Date()
            return true
        }
        if shouldReport {
            report(totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    /// Required by the protocol; the async `download(from:delegate:)` API hands back the file itself.
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {}
}
