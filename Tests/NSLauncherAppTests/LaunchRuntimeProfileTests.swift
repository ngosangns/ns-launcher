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

    private func makeSettings(useMsync: Bool = false, maxFrameRate: Int = 0) -> AppSettings {
        var settings = AppSettings.default
        settings.useMsync = useMsync
        settings.maxFrameRate = maxFrameRate
        return settings
    }

    func testDXMTBackendDefaultsToEsync() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings()
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
            settings: makeSettings(useMsync: true)
        )
        XCTAssertEqual(profile.environment["WINEMSYNC"], "1")
        XCTAssertNil(profile.environment["WINEESYNC"])
    }

    func testMaxFrameRateIsForwardedAsDXMTConfig() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(maxFrameRate: 120)
        )
        XCTAssertEqual(
            profile.environment["DXMT_CONFIG"]?.contains("d3d11.preferredMaxFrameRate=120;"),
            true
        )
    }

    func testDisabledMaxFrameRateOmitsDXMTConfig() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings(maxFrameRate: 0)
        )
        XCTAssertNil(profile.environment["DXMT_CONFIG"])
    }

    func testDXVKBackendAlwaysUsesEsyncEvenWhenMSyncRequested() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxvk]),
            settings: makeSettings(useMsync: true)
        )
        XCTAssertEqual(profile.backend, .dxvk)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        XCTAssertNil(profile.environment["WINEMSYNC"])
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
