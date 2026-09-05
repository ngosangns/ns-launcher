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
        XCTAssertEqual(RenderBridges.bridge(for: .dxmt)?.backend, .dxmt)
        XCTAssertNil(RenderBridges.bridge(for: .plainWine))
    }

    // MARK: - CrossOver graphics-backend shadowing

    /// The regression this guards against: CX_ROOT used to be withheld from bridged launches, which
    /// disabled `cxcompatdb.so` — the only thing that actually selects a translation layer. The game
    /// then never ran on the chosen backend at all, reporting a MoltenVK Vulkan adapter
    /// (`Renderer: Apple M3, Vendor: Unknown (ID=106b)`) instead of the render bridge's own adapter.
    func testEveryCrossOverLaunchGetsCrossOverRoot() throws {
        let build = try makeCrossOverStyleBuild()

        XCTAssertEqual(WineService.crossOverRootToApply(for: build, bridge: DXMTBridge()), build.root)
    }

    /// The backend has to be pinned explicitly, otherwise CX_ROOT lets the bottle's own configuration
    /// decide instead of the resolved backend — and the id has to match what `cxcompatdb.so` recognises.
    func testEachBridgeNamesTheBackendCrossOverRecognises() {
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
        XCTAssertNil(WineService.crossOverRootToApply(for: build, bridge: DXMTBridge()))
    }

    /// `lib64/apple_gptk` is what marks a build as CrossOver-derived, whether or not the launch uses
    /// Apple's own D3DMetal backend it belongs to.
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
