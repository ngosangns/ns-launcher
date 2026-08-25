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
        XCTAssertEqual(RenderBridges.bridge(for: .dxmt)?.backend, .dxmt)
        XCTAssertEqual(RenderBridges.bridge(for: .dxvk)?.backend, .dxvk)
        XCTAssertNil(RenderBridges.bridge(for: .plainWine))
    }

    /// The shader cache is a runtime dependency of every launch, so it must not live anywhere
    /// macOS is free to delete.
    func testDXMTKeepsItsCacheOutOfPurgeableLocations() {
        XCTAssertFalse(DXMTBridge.shaderCacheDirectory.path.contains("/Library/Caches/"))
        XCTAssertFalse(RenderBridgePayload.root.path.contains("/Library/Caches/"))
    }
}
