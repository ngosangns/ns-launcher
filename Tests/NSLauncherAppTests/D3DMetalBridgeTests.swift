import XCTest
@testable import NSLauncherApp

final class D3DMetalBridgeTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("D3DMetalBridgeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    /// The directory D3DMetal's own shader cache lives under, keyed by executable name — see
    /// `D3DMetalBridge.shaderCacheDirectory`. Confirmed against a real cache directory found on
    /// disk at `$(confstr DARWIN_USER_CACHE_DIR)/d3dm/GenshinImpact.exe/shaders.cache/`.
    func testShaderCacheDirectoryIsKeyedByExecutableNameUnderTheDarwinUserCacheDirectory() {
        guard let directory = D3DMetalBridge.shaderCacheDirectory(forExecutable: "GenshinImpact.exe") else {
            return XCTFail("Darwin user cache directory should always resolve on macOS")
        }
        XCTAssertEqual(directory.lastPathComponent, "GenshinImpact.exe")
        XCTAssertEqual(directory.deletingLastPathComponent().lastPathComponent, "d3dm")
    }

    func testShaderCacheDirectoryDiffersPerExecutable() {
        let genshin = D3DMetalBridge.shaderCacheDirectory(forExecutable: "GenshinImpact.exe")
        let other = D3DMetalBridge.shaderCacheDirectory(forExecutable: "ZFGameBrowser.exe")
        XCTAssertNotEqual(genshin, other)
    }

    func testCompatibleSnapshotRestoresAnEmptyLiveCache() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let build = try makeWineBuild(sourceVersion: "32047000000000")
        try write("compiled", to: live.appendingPathComponent("shaders.cache/pipeline_cache.bin"))

        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        try FileManager.default.removeItem(at: live)
        try FileManager.default.createDirectory(at: live, withIntermediateDirectories: true)

        try D3DMetalBridge.prepareShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        XCTAssertEqual(
            try String(contentsOf: live.appendingPathComponent("shaders.cache/pipeline_cache.bin"), encoding: .utf8),
            "compiled"
        )
    }

    func testPopulatedLiveCacheWinsAndReplacesTheOlderSnapshot() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let cacheFile = live.appendingPathComponent("shaders.cache/pipeline_cache.bin")
        let build = try makeWineBuild(sourceVersion: "32047000000000")
        try write("old", to: cacheFile)
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        try write("new-live-cache", to: cacheFile)
        try D3DMetalBridge.prepareShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        XCTAssertEqual(try String(contentsOf: cacheFile, encoding: .utf8), "new-live-cache")

        try FileManager.default.removeItem(at: live)
        try D3DMetalBridge.prepareShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        XCTAssertEqual(try String(contentsOf: cacheFile, encoding: .utf8), "new-live-cache")
    }

    func testSnapshotFromAnotherD3DMetalVersionIsNotRestored() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let cacheFile = live.appendingPathComponent("shaders.cache/pipeline_cache.bin")
        try write("compiled", to: cacheFile)
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: try makeWineBuild(sourceVersion: "1"),
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        try FileManager.default.removeItem(at: live)

        try D3DMetalBridge.prepareShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: try makeWineBuild(sourceVersion: "2"),
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
    }

    func testUnchangedCacheDoesNotRewriteItsSnapshot() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let build = try makeWineBuild(sourceVersion: "32047000000000")
        try write("compiled", to: live.appendingPathComponent("shaders.cache/pipeline_cache.bin"))
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        var diagnostics: [String] = []
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { diagnostics.append($0) }
        )

        XCTAssertTrue(diagnostics.contains { $0.contains("snapshot unchanged") })
    }

    func testPerFileManifestDetectsEqualAggregateMetadata() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let build = try makeWineBuild(sourceVersion: "32047000000000")
        let first = live.appendingPathComponent("shaders.cache/a.bin")
        let second = live.appendingPathComponent("shaders.cache/b.bin")
        try write("same-size", to: first)
        let modificationDate = try XCTUnwrap(
            first.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        try FileManager.default.removeItem(at: first)
        try write("same-size", to: second)
        try FileManager.default.setAttributes(
            [.modificationDate: modificationDate],
            ofItemAtPath: second.path
        )
        var diagnostics: [String] = []
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { diagnostics.append($0) }
        )

        XCTAssertTrue(diagnostics.contains { $0.contains("checkpointed") })
        try FileManager.default.removeItem(at: live)
        try D3DMetalBridge.prepareShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
    }

    func testClearRemovesLiveAndDurableCopiesTogether() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let cacheFile = live.appendingPathComponent("shaders.cache/pipeline_cache.bin")
        let build = try makeWineBuild(sourceVersion: "32047000000000")
        try write("compiled", to: cacheFile)
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        let freed = try D3DMetalBridge.clearShaderCaches(
            forExecutable: "GenshinImpact.exe",
            liveDirectory: live,
            durableRoot: snapshots
        )

        XCTAssertGreaterThan(freed, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
        XCTAssertTrue(
            D3DMetalBridge.durableCacheDirectories(
                forExecutable: "GenshinImpact.exe",
                durableRoot: snapshots
            ).isEmpty
        )
    }

    func testConcurrentRestoreAndClearLeaveNoCacheBehind() async throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let cacheFile = live.appendingPathComponent("shaders.cache/pipeline_cache.bin")
        let build = try makeWineBuild(sourceVersion: "32047000000000")

        for iteration in 0..<10 {
            try write("compiled-\(iteration)", to: cacheFile)
            try D3DMetalBridge.checkpointShaderCache(
                forExecutable: "GenshinImpact.exe",
                wineBuild: build,
                liveDirectory: live,
                durableRoot: snapshots,
                onDiagnostic: { _ in }
            )
            try FileManager.default.removeItem(at: live)

            async let restore: Void = Task.detached {
                try D3DMetalBridge.prepareShaderCache(
                    forExecutable: "GenshinImpact.exe",
                    wineBuild: build,
                    liveDirectory: live,
                    durableRoot: snapshots,
                    onDiagnostic: { _ in }
                )
            }.value
            async let clear: Int64 = Task.detached {
                try D3DMetalBridge.clearShaderCaches(
                    forExecutable: "GenshinImpact.exe",
                    liveDirectory: live,
                    durableRoot: snapshots
                )
            }.value
            _ = try await (restore, clear)

            XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))
            XCTAssertTrue(D3DMetalBridge.durableCacheDirectories(
                forExecutable: "GenshinImpact.exe",
                durableRoot: snapshots
            ).isEmpty)
        }
    }

    func testClearInvalidatesCheckpointFromAnActiveLaunch() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let build = try makeWineBuild(sourceVersion: "32047000000000")
        let generation = try XCTUnwrap(try D3DMetalBridge.prepareShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        ))

        _ = try D3DMetalBridge.clearShaderCaches(
            forExecutable: "GenshinImpact.exe",
            liveDirectory: live,
            durableRoot: snapshots
        )
        try write("compiled-after-clear", to: live.appendingPathComponent("shaders.cache/pipeline_cache.bin"))
        var diagnostics: [String] = []
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: build,
            expectedGeneration: generation,
            liveDirectory: live,
            durableRoot: snapshots,
            onDiagnostic: { diagnostics.append($0) }
        )

        XCTAssertTrue(diagnostics.contains { $0.contains("generation changed") })
        XCTAssertTrue(D3DMetalBridge.durableCacheDirectories(
            forExecutable: "GenshinImpact.exe",
            durableRoot: snapshots
        ).isEmpty)
    }

    func testSanitizedExecutableNameCollisionsRemainIsolated() throws {
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let build = try makeWineBuild(sourceVersion: "32047000000000")
        let firstLive = root.appendingPathComponent("first-live", isDirectory: true)
        let secondLive = root.appendingPathComponent("second-live", isDirectory: true)
        let relativeCachePath = "shaders.cache/pipeline_cache.bin"
        try write("first", to: firstLive.appendingPathComponent(relativeCachePath))
        try write("second", to: secondLive.appendingPathComponent(relativeCachePath))

        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "Game A.exe",
            wineBuild: build,
            liveDirectory: firstLive,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "Game_A.exe",
            wineBuild: build,
            liveDirectory: secondLive,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        try FileManager.default.removeItem(at: firstLive)
        try FileManager.default.removeItem(at: secondLive)

        _ = try D3DMetalBridge.prepareShaderCache(
            forExecutable: "Game A.exe",
            wineBuild: build,
            liveDirectory: firstLive,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )
        _ = try D3DMetalBridge.prepareShaderCache(
            forExecutable: "Game_A.exe",
            wineBuild: build,
            liveDirectory: secondLive,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        XCTAssertEqual(try String(contentsOf: firstLive.appendingPathComponent(relativeCachePath)), "first")
        XCTAssertEqual(try String(contentsOf: secondLive.appendingPathComponent(relativeCachePath)), "second")
    }

    func testPruningOneExecutableDoesNotRemoveAnotherExecutablesSnapshots() throws {
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let otherLive = root.appendingPathComponent("other-live", isDirectory: true)
        let gameLive = root.appendingPathComponent("game-live", isDirectory: true)
        let cachePath = "shaders.cache/pipeline_cache.bin"

        for version in ["1", "2"] {
            try write("other-\(version)", to: otherLive.appendingPathComponent(cachePath))
            try D3DMetalBridge.checkpointShaderCache(
                forExecutable: "Other.exe",
                wineBuild: try makeWineBuild(sourceVersion: version),
                liveDirectory: otherLive,
                durableRoot: snapshots,
                onDiagnostic: { _ in }
            )
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: TimeInterval(Int(version)!))],
                ofItemAtPath: snapshots.appendingPathComponent(version).path
            )
        }

        try write("game-3", to: gameLive.appendingPathComponent(cachePath))
        try D3DMetalBridge.checkpointShaderCache(
            forExecutable: "GenshinImpact.exe",
            wineBuild: try makeWineBuild(sourceVersion: "3"),
            liveDirectory: gameLive,
            durableRoot: snapshots,
            onDiagnostic: { _ in }
        )

        XCTAssertEqual(D3DMetalBridge.durableCacheDirectories(
            forExecutable: "Other.exe",
            durableRoot: snapshots
        ).count, 2)
    }

    func testOnlyTwoD3DMetalVersionsAreRetained() throws {
        let live = root.appendingPathComponent("live", isDirectory: true)
        let snapshots = root.appendingPathComponent("snapshots", isDirectory: true)
        let cacheFile = live.appendingPathComponent("shaders.cache/pipeline_cache.bin")

        for version in ["1", "2", "3"] {
            try write("compiled-\(version)", to: cacheFile)
            try D3DMetalBridge.checkpointShaderCache(
                forExecutable: "GenshinImpact.exe",
                wineBuild: try makeWineBuild(sourceVersion: version),
                liveDirectory: live,
                durableRoot: snapshots,
                onDiagnostic: { _ in }
            )
            if version != "3" {
                let snapshot = try XCTUnwrap(D3DMetalBridge.durableCacheDirectories(
                    forExecutable: "GenshinImpact.exe",
                    durableRoot: snapshots
                ).first { $0.deletingLastPathComponent().lastPathComponent == version })
                try FileManager.default.setAttributes(
                    [.modificationDate: Date(timeIntervalSince1970: TimeInterval(Int(version)!))],
                    ofItemAtPath: snapshot.path
                )
            }
        }

        let retained = Set(D3DMetalBridge.durableCacheDirectories(
            forExecutable: "GenshinImpact.exe",
            durableRoot: snapshots
        ).map { $0.deletingLastPathComponent().lastPathComponent })
        XCTAssertEqual(retained, ["2", "3"])
    }

    private func makeWineBuild(sourceVersion: String) throws -> WineBuild {
        let wineRoot = root.appendingPathComponent("wine-\(sourceVersion)-\(UUID().uuidString)", isDirectory: true)
        let resources = wineRoot.appendingPathComponent(
            "lib64/apple_gptk/external/D3DMetal.framework/Resources",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(
            fromPropertyList: ["SourceVersion": sourceVersion],
            format: .xml,
            options: 0
        )
        try plist.write(to: resources.appendingPathComponent("version.plist"))
        return WineBuild(
            binaryPath: wineRoot.appendingPathComponent("bin/wineloader").path,
            root: wineRoot,
            majorVersion: 11
        )
    }

    private func write(_ value: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(value.utf8).write(to: url, options: .atomic)
    }
}
