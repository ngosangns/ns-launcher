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
        metalFXUpscaling: Bool = false,
        resolutionCustom: Bool = false,
        showMetalHUD: Bool = false
    ) -> AppSettings {
        var settings = AppSettings.default
        settings.metalFXUpscaling = metalFXUpscaling
        settings.resolutionCustom = resolutionCustom
        settings.showMetalHUD = showMetalHUD
        return settings
    }

    func testD3DMetalBackendDefaultsToEsync() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.backend, .d3dMetal)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        XCTAssertNil(profile.environment["WINEMSYNC"])
        // The empty override list keeps D3DMetal's builtin D3D DLLs authoritative.
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "")
    }

    func testDXVKBackendAlsoDefaultsToEsync() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxvk]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.backend, .dxvk)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        XCTAssertNil(profile.environment["WINEMSYNC"])
    }

    /// MetalFX only upscales something when the game is told to render below the window size,
    /// which is what `resolutionCustom` sets up; otherwise the pass is pure GPU cost.
    func testMetalFXIsWithheldWithoutACustomRenderResolution() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings(metalFXUpscaling: true, resolutionCustom: false)
        )
        XCTAssertNil(profile.environment["D3DM_ENABLE_METALFX"])
    }

    func testMetalFXIsAppliedWithACustomRenderResolution() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings(metalFXUpscaling: true, resolutionCustom: true)
        )
        XCTAssertEqual(profile.environment["D3DM_ENABLE_METALFX"], "1")
    }

    func testMetalHUDStatsFollowTheShowMetalHUDSetting() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings(showMetalHUD: true)
        )
        XCTAssertEqual(profile.environment["D3DM_SHOW_HUD_STATS"], "1")
    }

    /// D3DMetal is not applied to a game that never asked for a translation layer; its environment
    /// would otherwise follow every plain-Wine launch around.
    func testAGameNeedingNoBridgeRunsOnPlainWine() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.backend, .plainWine)
        XCTAssertNil(profile.environment["D3DM_ENABLE_METALFX"])
        XCTAssertNil(profile.environment["WINEDLLOVERRIDES"])
    }

    /// Every game that needs a Direct3D-to-Metal layer gets D3DMetal; there is no second choice to
    /// fall to, so a game requiring one must never resolve to plain Wine.
    func testEveryGameNeedingADirect3DLayerGetsD3DMetal() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.backend, .d3dMetal)
    }

    /// Everything but `err` is off by default; the kernel-driver names the launcher scans for rely
    /// on Wine's err-class output surviving.
    func testWineDebugKeepsErrEnabledEverywhereExceptUnwind() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.environment["WINEDEBUG"], "-all,+err,err-unwind")
    }

    func testWindowedModeDefaultsTo1280x720WithoutACustomResolution() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .windowed
        settings.resolutionCustom = false

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]))

        XCTAssertEqual(arguments, ["-screen-fullscreen", "0", "-screen-width", "1280", "-screen-height", "720"])
    }

    /// The bug this guards against: a custom resolution only ever applied in fullscreen mode,
    /// so choosing Windowed silently locked the game to 1280x720 no matter what was configured.
    func testWindowedModeAppliesACustomResolutionWhenSet() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .windowed
        settings.resolutionCustom = true
        settings.resolutionWidth = 2560
        settings.resolutionHeight = 1440

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]))

        XCTAssertEqual(arguments, ["-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1440"])
    }

    func testFullscreenModeOmitsResolutionFlagsWithoutACustomResolution() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen
        settings.resolutionCustom = false

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]))

        XCTAssertEqual(arguments, ["-screen-fullscreen", "1"])
    }

    func testFullscreenModeAppliesACustomResolutionWhenSet() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen
        settings.resolutionCustom = true
        settings.resolutionWidth = 3440
        settings.resolutionHeight = 1440

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]))

        XCTAssertEqual(arguments, ["-screen-fullscreen", "1", "-screen-width", "3440", "-screen-height", "1440"])
    }
}
