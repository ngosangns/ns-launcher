import XCTest
@testable import NSLauncherApp

final class RenderBridgeTests: XCTestCase {
    private var wineRoot: URL!

    override func setUpWithError() throws {
        wineRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RenderBridgeTests-\(UUID().uuidString)", isDirectory: true)
        for suffix in ["lib/wine/x86_64-windows", "lib/wine/i386-windows"] {
            try FileManager.default.createDirectory(
                at: wineRoot.appendingPathComponent(suffix, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: wineRoot)
    }

    /// The bridge's own directory has to win over the Wine build's builtins; that ordering is what
    /// replaces overwriting the build's DLLs.
    func testBridgeDirectoriesComeBeforeTheWineBuildsOwn() {
        var environment: [String: String] = [:]
        let bridgeDirectory = URL(fileURLWithPath: "/payload/x86_64-windows", isDirectory: true)

        RenderBridgePayload.prependToDLLPath([bridgeDirectory], wineRoot: wineRoot, environment: &environment)

        let entries = try? XCTUnwrap(environment["WINEDLLPATH"]).split(separator: ":").map(String.init)
        XCTAssertEqual(entries?.first, "/payload/x86_64-windows")
        XCTAssertEqual(entries?.contains(wineRoot.appendingPathComponent("lib/wine/x86_64-windows").path), true)
        XCTAssertLessThan(
            try XCTUnwrap(entries?.firstIndex(of: "/payload/x86_64-windows")),
            try XCTUnwrap(entries?.firstIndex(of: wineRoot.appendingPathComponent("lib/wine/x86_64-windows").path))
        )
    }

    func testDirectoriesMissingFromTheWineBuildAreNotAddedToThePath() {
        var environment: [String: String] = [:]
        RenderBridgePayload.prependToDLLPath([], wineRoot: wineRoot, environment: &environment)

        // `lib/wine` and both arch directories exist; nothing else should appear.
        let entries = environment["WINEDLLPATH"]?.split(separator: ":").map(String.init) ?? []
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries.allSatisfy { FileManager.default.fileExists(atPath: $0) })
    }

    func testExistingDLLPathIsKeptAfterTheNewEntries() {
        var environment = ["WINEDLLPATH": "/preexisting"]
        RenderBridgePayload.prependToDLLPath(
            [URL(fileURLWithPath: "/payload/x86_64-windows", isDirectory: true)],
            wineRoot: wineRoot,
            environment: &environment
        )

        let entries = environment["WINEDLLPATH"]?.split(separator: ":").map(String.init) ?? []
        XCTAssertEqual(entries.first, "/payload/x86_64-windows")
        XCTAssertEqual(entries.last, "/preexisting")
    }

    func testDuplicateDirectoriesAppearOnce() {
        var environment: [String: String] = [:]
        let shared = wineRoot.appendingPathComponent("lib/wine/x86_64-windows", isDirectory: true)
        RenderBridgePayload.prependToDLLPath([shared, shared], wineRoot: wineRoot, environment: &environment)

        let entries = environment["WINEDLLPATH"]?.split(separator: ":").map(String.init) ?? []
        XCTAssertEqual(entries.filter { $0 == shared.path }.count, 1)
    }

    func testEveryBackendNeedingATranslationLayerHasABridge() {
        XCTAssertEqual(RenderBridges.bridge(for: .d3dMetal)?.backend, .d3dMetal)
        XCTAssertEqual(RenderBridges.bridge(for: .dxvk)?.backend, .dxvk)
        XCTAssertNil(RenderBridges.bridge(for: .plainWine))
    }

    /// The payload root is a runtime dependency of every bridged launch, so it must not live
    /// anywhere macOS is free to delete.
    func testRenderBridgePayloadRootIsOutOfPurgeableLocations() {
        XCTAssertFalse(RenderBridgePayload.root.path.contains("/Library/Caches/"))
    }

    // MARK: - CrossOver graphics-backend shadowing

    /// CrossOver's compatibility database uses CX_ROOT to prepend whichever Direct3D layer the
    /// bottle is configured for (`lib64/apple_gptk/wine` for D3DMetal, or its bundled dxvk) ahead of
    /// the bridge's own WINEDLLPATH. That made the game render on CrossOver's bottle config instead
    /// of the backend this launch resolved, with nothing in the launch output saying so.
    func testCrossOverRootIsWithheldFromABridgedLaunch() throws {
        let build = try makeCrossOverStyleBuild()

        XCTAssertNil(WineService.crossOverRootToApply(for: build, bridge: D3DMetalBridge()))
        XCTAssertNil(WineService.crossOverRootToApply(for: build, bridge: DXVKBridge()))
    }

    /// A plain-Wine launch installs no D3D payload, so there is nothing for CrossOver to shadow and
    /// it still needs CX_ROOT to find its own compatibility database.
    func testPlainWineLaunchStillGetsCrossOverRoot() throws {
        let build = try makeCrossOverStyleBuild()

        XCTAssertEqual(WineService.crossOverRootToApply(for: build, bridge: nil), build.root)
    }

    /// A build without CrossOver's `lib64/apple_gptk` has no root to expose either way.
    func testANonCrossOverBuildHasNoRootToApply() {
        let build = WineBuild(
            binaryPath: wineRoot.appendingPathComponent("bin/wine64").path,
            root: wineRoot,
            majorVersion: 11
        )

        XCTAssertNil(WineService.crossOverRootToApply(for: build, bridge: nil))
        XCTAssertNil(WineService.crossOverRootToApply(for: build, bridge: D3DMetalBridge()))
    }

    // MARK: - D3DMetalBridge payload detection

    /// D3DMetal's DLLs live under `lib64/apple_gptk/wine/x86_64-windows`; `prepare` has to put that
    /// directory ahead of the build's own `lib/wine` builtins on `WINEDLLPATH`.
    func testD3DMetalPreparePrependsTheGPTKDirectoryToWINEDLLPATH() async throws {
        let gptkWindows = wineRoot.appendingPathComponent("lib64/apple_gptk/wine/x86_64-windows", isDirectory: true)
        try FileManager.default.createDirectory(at: gptkWindows, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gptkWindows.appendingPathComponent("d3d11.dll").path, contents: nil)
        let build = WineBuild(binaryPath: wineRoot.appendingPathComponent("bin/wineloader").path, root: wineRoot, majorVersion: 11)

        var environment: [String: String] = [:]
        try await D3DMetalBridge().prepare(
            wineBuild: build,
            prefixDirectory: wineRoot,
            environment: &environment,
            processRunner: ProcessRunner(),
            onDiagnostic: { _ in }
        )

        let entries = environment["WINEDLLPATH"]?.split(separator: ":").map(String.init) ?? []
        XCTAssertEqual(entries.first, gptkWindows.path)
    }

    /// A Wine build with no Apple Game Porting Toolkit payload cannot run D3DMetal at all — this is
    /// the "install CrossOver or Game Porting Toolkit" error, not a generic launch failure.
    func testD3DMetalPrepareThrowsWhenTheGPTKPayloadIsMissing() async {
        let build = WineBuild(binaryPath: wineRoot.appendingPathComponent("bin/wineloader").path, root: wineRoot, majorVersion: 11)
        var environment: [String: String] = [:]

        do {
            try await D3DMetalBridge().prepare(
                wineBuild: build,
                prefixDirectory: wineRoot,
                environment: &environment,
                processRunner: ProcessRunner(),
                onDiagnostic: { _ in }
            )
            XCTFail("expected d3dMetalUnavailable")
        } catch WineServiceError.d3dMetalUnavailable {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// `lib64/apple_gptk` is what marks a build as CrossOver-derived.
    private func makeCrossOverStyleBuild() throws -> WineBuild {
        try FileManager.default.createDirectory(
            at: wineRoot.appendingPathComponent("lib64/apple_gptk", isDirectory: true),
            withIntermediateDirectories: true
        )
        return WineBuild(
            binaryPath: wineRoot.appendingPathComponent("bin/wineloader").path,
            root: wineRoot,
            majorVersion: 11
        )
    }
}
