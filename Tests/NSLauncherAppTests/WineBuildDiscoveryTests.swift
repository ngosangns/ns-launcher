import XCTest
@testable import NSLauncherApp

/// Guards the two decisions that once let a Direct3D-to-Metal layer load into an old, incompatible
/// Wine and deadlock the game at startup: reading a build's version, and recognising a build's
/// loader at all.
final class WineBuildDiscoveryTests: XCTestCase {

    // MARK: - Version parsing

    func testReadsTheMajorVersionFromEachBuildsOwnVersionString() {
        // Exact strings the three builds on a real machine print.
        XCTAssertEqual(WineBinaryLocator.parseMajorVersion(from: "wine-11.0-8726-g2e2f5fca349"), 11)
        XCTAssertEqual(WineBinaryLocator.parseMajorVersion(from: "wine-11.15"), 11)
        XCTAssertEqual(WineBinaryLocator.parseMajorVersion(from: "wine-7.7 (Game Porting Toolkit 1.1)"), 7)
    }

    /// CrossOver's `bin/wine` is a Perl wrapper that answers `--version` with product info and
    /// cannot run a game. Rejecting anything that fails to identify itself as Wine is what keeps
    /// the wrapper out of the candidate list without naming CrossOver anywhere in the locator.
    func testABuildThatDoesNotIdentifyItselfAsWineIsRejected() {
        let crossOverWrapper = """
            Product Name: CrossOver
            Public Version: 26.3.0
            Product Version: 26.3.0.39832
            """
        XCTAssertNil(WineBinaryLocator.parseMajorVersion(from: crossOverWrapper))
        XCTAssertNil(WineBinaryLocator.parseMajorVersion(from: ""))
        XCTAssertNil(WineBinaryLocator.parseMajorVersion(from: "wine-"))
    }

    // MARK: - Loader discovery

    /// CrossOver's `bin` is a symlink to `CrossOver-Hosted Application`, and FileManager's
    /// enumerator reports the real directory rather than following the link — so the only path it
    /// ever yields has no `bin` component. Requiring one made CrossOver undiscoverable entirely.
    func testALoaderIsFoundWhenBinIsASymlinkToAnotherDirectory() throws {
        let bundle = try makeTemporaryDirectory()
        let real = bundle.appendingPathComponent("Hosted Application", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("lib/wine", isDirectory: true),
            withIntermediateDirectories: true
        )
        let loader = real.appendingPathComponent("wineloader")
        try makeExecutable(at: loader)
        try FileManager.default.createSymbolicLink(
            at: bundle.appendingPathComponent("bin"),
            withDestinationURL: real
        )

        var seen: Set<String> = []
        let found = WineBinaryLocator.wineExecutables(in: bundle, seen: &seen)
        XCTAssertEqual(found.map(normalizingPrivatePrefix), [normalizingPrivatePrefix(loader.path)])
    }

    /// `lib/wine` and `share/wine` are directories, and directories report as executable — so the
    /// discovery rule cannot be "named wine and executable" alone.
    func testADirectoryNamedWineIsNotMistakenForALoader() throws {
        let bundle = try makeTemporaryDirectory()
        let libWine = bundle.appendingPathComponent("lib/wine", isDirectory: true)
        try FileManager.default.createDirectory(at: libWine, withIntermediateDirectories: true)

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: libWine.path))
        var seen: Set<String> = []
        XCTAssertEqual(WineBinaryLocator.wineExecutables(in: bundle, seen: &seen), [])
    }

    /// A loader with no sibling `lib/wine` cannot run a game; it is the same test
    /// `wineRootDirectory` applies, and discovery must not surface one.
    func testALoaderWithoutASiblingLibWineIsSkipped() throws {
        let bundle = try makeTemporaryDirectory()
        let bin = bundle.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try makeExecutable(at: bin.appendingPathComponent("wine64"))

        var seen: Set<String> = []
        XCTAssertEqual(WineBinaryLocator.wineExecutables(in: bundle, seen: &seen), [])
        XCTAssertThrowsError(
            try WineBinaryLocator.wineRootDirectory(forBinaryAtPath: bin.appendingPathComponent("wine64").path)
        )
    }

    /// The managed slot's contract is "a usable Wine lives here", so a symlink into a Wine
    /// installed elsewhere counts and must not trigger a redundant several-hundred-megabyte
    /// download.
    func testTheManagedSlotAcceptsASymlinkIntoAnotherInstallation() throws {
        let root = try makeTemporaryDirectory()
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("lib/wine", isDirectory: true),
            withIntermediateDirectories: true
        )
        let realLoader = root.appendingPathComponent("bin/wine64")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("bin", isDirectory: true),
            withIntermediateDirectories: true
        )
        try makeExecutable(at: realLoader)

        let slot = try makeTemporaryDirectory().appendingPathComponent("wine/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: slot, withIntermediateDirectories: true)
        let link = slot.appendingPathComponent("wine64")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: realLoader)

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: link.path))
        XCTAssertEqual(
            try WineBinaryLocator.wineRootDirectory(forBinaryAtPath: link.path).standardizedFileURL,
            root.standardizedFileURL
        )
    }

    // MARK: - Release resolution

    /// The exact shape the real API returns today. If this stops parsing, every install silently
    /// drops back to the pinned release and nobody finds out until the pin goes stale.
    func testParsesTheReleasePayloadGitHubActuallyReturns() throws {
        let payload = """
            {
              "tag_name": "wine-11.0-signed",
              "assets": [
                {
                  "name": "wine-devel-11.0-osx64-signed.tar.xz",
                  "browser_download_url": "https://github.com/yaagl/anime-game-wine/releases/download/wine-11.0-signed/wine-devel-11.0-osx64-signed.tar.xz"
                }
              ]
            }
            """
        let release = try XCTUnwrap(WineDistribution.parseRelease(from: Data(payload.utf8)))
        XCTAssertEqual(release, WineDistribution.pinnedFallback)
    }

    /// An unsigned build is quarantined by Gatekeeper, and `search` then skips the very build just
    /// installed — a download of several hundred megabytes that leaves the launcher no better off.
    func testASignedArchiveWinsOverAnUnsignedOne() throws {
        let payload = """
            {
              "tag_name": "wine-12.0",
              "assets": [
                {"name": "wine-devel-12.0-osx64.tar.xz", "browser_download_url": "https://example.invalid/plain.tar.xz"},
                {"name": "wine-devel-12.0-osx64-signed.tar.xz", "browser_download_url": "https://example.invalid/signed.tar.xz"}
              ]
            }
            """
        let release = try XCTUnwrap(WineDistribution.parseRelease(from: Data(payload.utf8)))
        XCTAssertEqual(release.assetName, "wine-devel-12.0-osx64-signed.tar.xz")
        XCTAssertEqual(release.tag, "wine-12.0")
    }

    /// Releases carry checksums, source tarballs and Linux builds alongside the macOS archive.
    func testAssetsThatAreNotAMacOSArchiveAreIgnored() throws {
        let payload = """
            {
              "tag_name": "wine-12.0",
              "assets": [
                {"name": "SHA256SUMS", "browser_download_url": "https://example.invalid/sums"},
                {"name": "wine-devel-12.0-linux.tar.xz", "browser_download_url": "https://example.invalid/linux.tar.xz"},
                {"name": "wine-devel-12.0-macos.tar.gz", "browser_download_url": "https://example.invalid/mac.tar.gz"}
              ]
            }
            """
        let release = try XCTUnwrap(WineDistribution.parseRelease(from: Data(payload.utf8)))
        XCTAssertEqual(release.assetName, "wine-devel-12.0-macos.tar.gz")
    }

    /// Returning nil is what sends the caller to the pinned release, so a payload with nothing
    /// installable in it must not produce a `Release` pointing at the wrong file.
    func testAReleaseWithNoMacOSArchiveResolvesToNothing() {
        let noArchive = """
            {"tag_name": "wine-12.0", "assets": [{"name": "SHA256SUMS", "browser_download_url": "https://example.invalid/sums"}]}
            """
        XCTAssertNil(WineDistribution.parseRelease(from: Data(noArchive.utf8)))
        XCTAssertNil(WineDistribution.parseRelease(from: Data("not json".utf8)))
        XCTAssertNil(WineDistribution.parseRelease(from: Data("{}".utf8)))
    }

    // MARK: - Release resolution against a stubbed network

    /// The contract is "never throws": a launch must not fail because GitHub did. Each of these is
    /// a way the call can go wrong, and all of them have to land on the pinned release.
    func testEveryNetworkFailureFallsBackToThePin() async {
        let failures: [StubHTTPFetcher.Outcome] = [
            .failure(URLError(.notConnectedToInternet)),
            .failure(URLError(.timedOut)),
            .response(status: 403, body: #"{"message": "API rate limit exceeded"}"#), // unauthenticated GitHub
            .response(status: 404, body: "{}"),
            .response(status: 500, body: ""),
            .response(status: 200, body: "not json at all"),
            .response(status: 200, body: #"{"tag_name": "wine-12.0", "assets": []}"#),
            .response(status: 200, body: #"{"tag_name": "wine-12.0", "assets": [{"name": "SHA256SUMS", "browser_download_url": "https://e.invalid/s"}]}"#)
        ]

        for outcome in failures {
            let diagnostics = DiagnosticCollector()
            let release = await WineDistribution.latestRelease(
                fetcher: StubHTTPFetcher(outcome: outcome),
                onDiagnostic: { diagnostics.append($0) }
            )
            XCTAssertEqual(release, WineDistribution.pinnedFallback, "\(outcome) did not fall back")
            // Silence here would mean a stale Wine with nothing in the log to explain it.
            XCTAssertTrue(
                diagnostics.lines.contains { $0.contains(WineDistribution.pinnedFallback.tag) },
                "\(outcome) fell back without saying so"
            )
        }
    }

    func testASuccessfulLookupUsesTheResolvedRelease() async {
        let body = """
            {
              "tag_name": "wine-12.0-signed",
              "assets": [
                {"name": "wine-devel-12.0-osx64-signed.tar.xz", "browser_download_url": "https://example.invalid/w.tar.xz"}
              ]
            }
            """
        let diagnostics = DiagnosticCollector()
        let release = await WineDistribution.latestRelease(
            fetcher: StubHTTPFetcher(outcome: .response(status: 200, body: body)),
            onDiagnostic: { diagnostics.append($0) }
        )

        XCTAssertEqual(release.tag, "wine-12.0-signed")
        XCTAssertEqual(release.assetName, "wine-devel-12.0-osx64-signed.tar.xz")
        XCTAssertNotEqual(release, WineDistribution.pinnedFallback)
        XCTAssertTrue(diagnostics.lines.contains { $0.contains("wine-12.0-signed") })
    }

    /// GitHub serves a different representation without it, which `parseRelease` is not written
    /// against.
    func testTheLookupAsksForTheDocumentedRepresentation() async {
        let fetcher = StubHTTPFetcher(outcome: .response(status: 200, body: "{}"))
        _ = await WineDistribution.latestRelease(fetcher: fetcher, onDiagnostic: { _ in })
        let accept = await fetcher.lastRequest?.value(forHTTPHeaderField: "Accept")
        XCTAssertEqual(accept, "application/vnd.github+json")
    }

    /// The lookup sits in front of a several-hundred-megabyte download on the launch path, so it
    /// must not be what stalls a launch.
    func testTheLookupCarriesATimeout() async {
        let fetcher = StubHTTPFetcher(outcome: .response(status: 200, body: "{}"))
        _ = await WineDistribution.latestRelease(fetcher: fetcher, onDiagnostic: { _ in })
        let timeout = await fetcher.lastRequest?.timeoutInterval
        XCTAssertNotNil(timeout)
        XCTAssertLessThanOrEqual(try XCTUnwrap(timeout), 30)
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("WineBuildDiscoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// The temporary directory is reached through `/var`, a symlink to `/private/var`, and the
    /// enumerator reports the real path while `URL` normalizes it back. Neither spelling is wrong,
    /// so comparisons go through one of them.
    private func normalizingPrivatePrefix(_ path: String) -> String {
        path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
    }

    private func makeExecutable(at url: URL) throws {
        try Data("#!/bin/sh\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}

/// Answers every fetch the same way and remembers what it was asked.
private actor StubHTTPFetcher: HTTPDataFetching {
    enum Outcome {
        case response(status: Int, body: String)
        case failure(any Error)
    }

    private let outcome: Outcome
    private(set) var lastRequest: URLRequest?

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        switch outcome {
        case let .failure(error):
            throw error
        case let .response(status, body):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
    }
}

/// Collects diagnostics from the `@Sendable` callback the resolver reports through.
private final class DiagnosticCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var lines: [String] { lock.withLock { storage } }

    func append(_ line: String) {
        lock.withLock { storage.append(line) }
    }
}
