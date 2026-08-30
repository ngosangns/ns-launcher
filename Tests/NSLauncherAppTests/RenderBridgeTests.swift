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

    func testEveryBackendNeedingATranslationLayerHasABridge() {
        XCTAssertEqual(RenderBridges.bridge(for: .d3dMetal)?.backend, .d3dMetal)
        XCTAssertEqual(RenderBridges.bridge(for: .dxmt)?.backend, .dxmt)
        XCTAssertNil(RenderBridges.bridge(for: .plainWine))
    }

    // MARK: - CrossOver graphics-backend shadowing

    /// The regression this guards against: CX_ROOT used to be withheld from bridged launches, which
    /// disabled `cxcompatdb.so` — the only thing that actually selects a translation layer. The game
    /// then never ran on the chosen backend at all, reporting a MoltenVK Vulkan adapter
    /// (`Renderer: Apple M3, Vendor: Unknown (ID=106b)`) instead of D3DMetal's spoofed
    /// `AMD Compatibility Mode / ATI`.
    func testEveryCrossOverLaunchGetsCrossOverRoot() throws {
        let build = try makeCrossOverStyleBuild()

        XCTAssertEqual(WineService.crossOverRootToApply(for: build, bridge: D3DMetalBridge()), build.root)
        XCTAssertEqual(WineService.crossOverRootToApply(for: build, bridge: DXMTBridge()), build.root)
    }

    /// The backend has to be pinned explicitly, otherwise CX_ROOT lets the bottle's own configuration
    /// decide instead of the user's choice — and each id has to match what `cxcompatdb.so` recognises.
    func testEachBridgeNamesTheBackendCrossOverRecognises() {
        XCTAssertEqual(D3DMetalBridge().crossOverGraphicsBackend, "d3dmetal")
        XCTAssertEqual(DXMTBridge().crossOverGraphicsBackend, "dxmt")
    }

    /// A plain-Wine launch needs CX_ROOT to find its own compatibility database too.
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
    /// `prepare` proves the payload is there and exports the shared library CrossOver's own script
    /// exports; it must NOT touch `WINEDLLPATH`, which selects nothing (see
    /// `RenderBridge.crossOverGraphicsBackend`).
    func testD3DMetalPrepareExportsLibD3DSharedAndLeavesDLLPathAlone() async throws {
        let gptkWindows = wineRoot.appendingPathComponent("lib64/apple_gptk/wine/x86_64-windows", isDirectory: true)
        try FileManager.default.createDirectory(at: gptkWindows, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: gptkWindows.appendingPathComponent("d3d11.dll").path, contents: nil)
        let external = wineRoot.appendingPathComponent("lib64/apple_gptk/external", isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let libD3DShared = external.appendingPathComponent("libd3dshared.dylib")
        FileManager.default.createFile(atPath: libD3DShared.path, contents: nil)
        let build = WineBuild(binaryPath: wineRoot.appendingPathComponent("bin/wineloader").path, root: wineRoot, majorVersion: 11)

        var environment: [String: String] = [:]
        try await D3DMetalBridge().prepare(
            wineBuild: build,
            prefixDirectory: wineRoot,
            environment: &environment,
            processRunner: ProcessRunner(),
            onDiagnostic: { _ in }
        )

        XCTAssertNil(environment["WINEDLLPATH"])
        XCTAssertEqual(environment["CX_APPLEGPTK_LIBD3DSHARED_PATH"], libD3DShared.path)
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
    private func makeCrossOverStyleBuild() throws -> WineBuild {        try FileManager.default.createDirectory(
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
