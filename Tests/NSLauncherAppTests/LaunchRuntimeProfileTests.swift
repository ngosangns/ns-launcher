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
        showMetalHUD: Bool = false,
        d3dMetalAsyncCommit: Bool = true,
        d3dMetalMultithreadedInterface: Bool = true,
        metalRenderBackend: RuntimeBackend = .d3dMetal
    ) -> AppSettings {
        var settings = AppSettings.default
        settings.metalFXUpscaling = metalFXUpscaling
        settings.resolutionCustom = resolutionCustom
        settings.showMetalHUD = showMetalHUD
        settings.d3dMetalAsyncCommit = d3dMetalAsyncCommit
        settings.d3dMetalMultithreadedInterface = d3dMetalMultithreadedInterface
        settings.metalRenderBackend = metalRenderBackend
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
        // D3DMetal's builtin D3D DLLs stay authoritative, and vulkan-1 is disabled outright so
        // Unity's Vulkan fallback (broken under D3DMetal) can never kick in even via CrossOver's
        // own system32 copy — see D3DMetalBridge.launchEnvironment for the crash signature this
        // prevents.
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "vulkan-1=")
    }

    /// Confirmed real `D3DM_*` variables (found in a real D3DMetal.framework binary's strings) that
    /// reduce Metal command-submission stalls — see `D3DMetalBridge.launchEnvironment`. Default on.
    func testD3DMetalEnablesAsyncCommitAndMultithreadingByDefault() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.environment["D3DM_ENABLE_ASYNC_COMMIT"], "1")
        XCTAssertEqual(profile.environment["D3DM_MULTITHREADED_INTERFACE_ENABLE"], "1")
    }

    /// Both flags are unproven (inferred from their names, not documented), so each must be
    /// independently switchable to isolate a stutter/instability report without a rebuild.
    func testD3DMetalAsyncCommitAndMultithreadingCanBeDisabledIndependently() {
        let asyncCommitOff = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings(d3dMetalAsyncCommit: false, d3dMetalMultithreadedInterface: true)
        )
        XCTAssertNil(asyncCommitOff.environment["D3DM_ENABLE_ASYNC_COMMIT"])
        XCTAssertEqual(asyncCommitOff.environment["D3DM_MULTITHREADED_INTERFACE_ENABLE"], "1")

        let multithreadedOff = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings(d3dMetalAsyncCommit: true, d3dMetalMultithreadedInterface: false)
        )
        XCTAssertEqual(multithreadedOff.environment["D3DM_ENABLE_ASYNC_COMMIT"], "1")
        XCTAssertNil(multithreadedOff.environment["D3DM_MULTITHREADED_INTERFACE_ENABLE"])
    }

    /// The user's DXMT preference only wins when the game actually declares support for it.
    func testDXMTIsUsedWhenPreferredAndSupported() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal, .dxmt]),
            settings: makeSettings(metalRenderBackend: .dxmt)
        )
        XCTAssertEqual(profile.backend, .dxmt)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        // Same Vulkan-fallback block as D3DMetal — Unity's broken Vulkan path is not specific to
        // one backend.
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "vulkan-1=")
    }

    /// A game that never declared DXMT support must not silently get it just because the user's
    /// global preference says DXMT — falls back to whatever the game does declare.
    func testDXMTPreferenceIsIgnoredWhenTheGameDoesNotDeclareSupportForIt() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: makeSettings(metalRenderBackend: .dxmt)
        )
        XCTAssertEqual(profile.backend, .d3dMetal)
    }

    /// Default preference stays D3DMetal even for a game that declares both, so existing users see
    /// no behavior change.
    func testD3DMetalStaysTheDefaultPreferenceWhenBothAreDeclared() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal, .dxmt]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.backend, .d3dMetal)
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
