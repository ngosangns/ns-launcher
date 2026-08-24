import XCTest
@testable import NSLauncherApp

final class LaunchRuntimeProfileTests: XCTestCase {
    private func makeGame(requirements: [RuntimeRequirement]) -> GameDefinition {
        GameDefinition(
            id: "genshin-global",
            displayName: "Genshin Impact",
            installDirectory: URL(fileURLWithPath: "/tmp/game"),
            executableRelativePath: "GenshinImpact.exe",
            winePrefixDirectory: URL(fileURLWithPath: "/tmp/prefix"),
            installerStrategy: .sophon,
            runtimeRequirements: requirements,
            launchArguments: []
        )
    }

    private func makeSettings(
        useMsync: Bool = false,
        maxFrameRate: Int = 0,
        metalFXUpscaling: Bool = false,
        resolutionCustom: Bool = false,
        renderBackend: RenderBackendPreference = .dxmt
    ) -> AppSettings {
        var settings = AppSettings.default
        settings.useMsync = useMsync
        settings.maxFrameRate = maxFrameRate
        settings.metalFXUpscaling = metalFXUpscaling
        settings.resolutionCustom = resolutionCustom
        settings.renderBackend = renderBackend
        return settings
    }

    /// Pinned so the frame cap under test never depends on the display the tests run on.
    private static let refreshRate = 120

    func testDXMTBackendDefaultsToEsync() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.backend, .dxmt)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        XCTAssertNil(profile.environment["WINEMSYNC"])
        // The empty override list keeps the DXMT builtin D3D DLLs authoritative.
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "")
    }

    func testUseMsyncOptsIntoMSyncOnDXMT() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(useMsync: true),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.environment["WINEMSYNC"], "1")
        XCTAssertNil(profile.environment["WINEESYNC"])
    }

    func testMaxFrameRateIsForwardedAsDXMTConfig() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(maxFrameRate: 120),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(
            profile.environment["DXMT_CONFIG"]?.contains("d3d11.preferredMaxFrameRate=120;"),
            true
        )
    }

    func testDisabledMaxFrameRateOmitsDXMTConfig() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(maxFrameRate: 0),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertNil(profile.environment["DXMT_CONFIG"])
    }

    func testDXVKBackendAlwaysUsesEsyncEvenWhenMSyncRequested() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxvk]),
            settings: makeSettings(useMsync: true),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.backend, .dxvk)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        XCTAssertNil(profile.environment["WINEMSYNC"])
    }

    func testFrameCapSnapsDownToAFactorOfTheRefreshRate() {
        // 60 is not a factor of 144, which is what made a hardcoded 60 unsafe.
        XCTAssertEqual(AppSettings.supportedFrameCap(requested: 60, refreshRate: 144), 48)
        XCTAssertEqual(AppSettings.supportedFrameCap(requested: 60, refreshRate: 120), 60)
        XCTAssertEqual(AppSettings.supportedFrameCap(requested: 100, refreshRate: 60), 60)
        XCTAssertEqual(AppSettings.supportedFrameCap(requested: 0, refreshRate: 144), 0)
        XCTAssertEqual(AppSettings.supportedFrameCap(requested: 60, refreshRate: 0), 0)
    }

    func testFrameCapIsSnappedBeforeReachingDXMTConfig() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(maxFrameRate: 60),
            displayRefreshRate: 144
        )
        XCTAssertEqual(
            profile.environment["DXMT_CONFIG"]?.contains("d3d11.preferredMaxFrameRate=48;"),
            true
        )
    }

    /// MetalFX only upscales something when the game is told to render below the window size,
    /// which is what `resolutionCustom` sets up; otherwise the pass is pure GPU cost.
    func testMetalFXIsWithheldWithoutACustomRenderResolution() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(metalFXUpscaling: true, resolutionCustom: false),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertNil(profile.environment["DXMT_METALFX_SPATIAL_SWAPCHAIN"])
    }

    func testMetalFXIsAppliedWithACustomRenderResolution() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(metalFXUpscaling: true, resolutionCustom: true),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.environment["DXMT_METALFX_SPATIAL_SWAPCHAIN"], "1")
    }

    /// D3DMetal is selected purely through the DLL search path, so none of DXMT's knobs may leak
    /// into the launch; WineService fills in WINEDLLPATH once the Wine root is known.
    func testD3DMetalBackendCarriesNoDXMTEnvironment() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(renderBackend: .d3dMetal),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.backend, .d3dMetal)
        XCTAssertNil(profile.environment["DXMT_SHADER_CACHE"])
        XCTAssertNil(profile.environment["DXMT_LOG_PATH"])
        XCTAssertNil(profile.environment["DXMT_CONFIG"])
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
    }

    func testRenderBackendPreferenceOnlyAppliesToGamesNeedingABridge() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine]),
            settings: makeSettings(renderBackend: .d3dMetal),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.backend, .plainWine)
    }

    func testLegacySettingsWithoutRenderBackendDefaultToDXMT() throws {
        let encoded = try JSONEncoder().encode(makeSettings(renderBackend: .d3dMetal))
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        json.removeValue(forKey: "renderBackend")
        let stripped = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: stripped)
        XCTAssertEqual(decoded.renderBackend, .dxmt)
    }

    /// The persistent pipeline cache is what keeps a character swap from paying shader-compile
    /// cost again on every session; DXMT ships it off by default.
    func testPersistentShaderCacheIsEnabled() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.environment["DXMT_SHADER_CACHE"], "1")
        XCTAssertEqual(
            profile.environment["DXMT_SHADER_CACHE_PATH"],
            LaunchRuntimeProfile.dxmtShaderCacheDirectory.path
        )
    }

    /// The cache must not sit under `Library/Caches`, which macOS purges under disk pressure.
    func testShaderCacheSurvivesCachePurges() {
        XCTAssertFalse(LaunchRuntimeProfile.dxmtShaderCacheDirectory.path.contains("/Library/Caches/"))
    }

    /// DXMT appends `d3d11.log` to this path, so it has to name a directory.
    func testDXMTLogPathIsADirectory() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(),
            displayRefreshRate: Self.refreshRate
        )
        XCTAssertEqual(profile.environment["DXMT_LOG_PATH"]?.hasSuffix("/DXMT"), true)
        XCTAssertEqual(profile.environment["DXMT_CONFIG_FILE"]?.hasSuffix("/DXMT/dxmt.conf"), true)
    }

    func testSanitizedMaxFrameRateClampsOutOfRangeValues() {
        XCTAssertEqual(AppSettings.sanitizedMaxFrameRate(-5), 0)
        XCTAssertEqual(AppSettings.sanitizedMaxFrameRate(0), 0)
        XCTAssertEqual(AppSettings.sanitizedMaxFrameRate(60), 60)
        XCTAssertEqual(AppSettings.sanitizedMaxFrameRate(1000), 360)
    }

    func testSanitizedMetalFXScaleFactorClampsOutOfRangeValues() {
        XCTAssertEqual(AppSettings.sanitizedMetalFXScaleFactor(0.5), 1.0)
        XCTAssertEqual(AppSettings.sanitizedMetalFXScaleFactor(1.5), 1.5)
        XCTAssertEqual(AppSettings.sanitizedMetalFXScaleFactor(10.0), 4.0)
    }

    func testMetalFXRenderResolutionDividesOutputByFactor() {
        let resolution = AppSettings.metalFXRenderResolution(
            outputWidth: 1920,
            outputHeight: 1080,
            factor: 1.5
        )
        XCTAssertEqual(resolution.width, 1280)
        XCTAssertEqual(resolution.height, 720)
    }

    func testMetalFXRenderResolutionNeverReturnsZero() {
        let resolution = AppSettings.metalFXRenderResolution(
            outputWidth: 100,
            outputHeight: 100,
            factor: 4.0
        )
        XCTAssertGreaterThanOrEqual(resolution.width, 1)
        XCTAssertGreaterThanOrEqual(resolution.height, 1)
    }

    func testDecodingLegacySettingsWithoutMsyncKeyDefaultsItOff() throws {
        let original = makeSettings(maxFrameRate: 90)
        let data = try JSONEncoder().encode(original)

        // Simulate a legacy file by stripping the new key from the payload.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "useMsync")
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacyData)
        XCTAssertFalse(decoded.useMsync)
        XCTAssertEqual(decoded.maxFrameRate, 90)
    }
}
