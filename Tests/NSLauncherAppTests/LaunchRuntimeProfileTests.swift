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
        // The regression this guards against: without a builtin override, Wine loaded a stale native
        // DXVK left in the prefix instead of D3DMetal, and the game rendered through MoltenVK — 16154
        // [mvk-error] lines in 120s of play, versus zero with the override.
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "d3d10,d3d10_1,d3d10core,d3d11,dxgi=b")
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
        // Same builtin override as D3DMetal: the stale native DXVK shadows either one.
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "d3d10,d3d10_1,d3d10core,d3d11,dxgi=b")
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

    func testBundledGenshinDefaultsIncludeDXVKForNewAndExistingSettings() {
        XCTAssertEqual(AppSettings.default.games.first?.runtimeRequirements.contains(.dxvk), true)

        var existing = AppSettings.default
        existing.games[0].runtimeRequirements.removeAll { $0 == .dxvk }

        let migrated = existing.applyingBundledGenshinDefaultsIfNeeded()
        XCTAssertEqual(migrated.games.first?.runtimeRequirements.contains(.dxvk), true)
    }

    func testDXMTOnlyRequirementFallsBackToDXMT() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: makeSettings()
        )
        XCTAssertEqual(profile.backend, .dxmt)
    }

    func testDXVKIsUsedWhenPreferredAndSupported() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal, .dxmt, .dxvk]),
            settings: makeSettings(metalRenderBackend: .dxvk)
        )
        XCTAssertEqual(profile.backend, .dxvk)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        XCTAssertNil(profile.environment["D3DM_ENABLE_METALFX"])
        XCTAssertEqual(
            profile.environment["WINEDLLOVERRIDES"],
            "d3d10,d3d10_1,d3d10core,d3d11,dxgi=b"
        )
    }

    func testDXVKPreferenceIsIgnoredWhenTheGameDoesNotDeclareSupportForIt() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal, .dxmt]),
            settings: makeSettings(metalRenderBackend: .dxvk)
        )
        XCTAssertEqual(profile.backend, .d3dMetal)
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "d3d10,d3d10_1,d3d10core,d3d11,dxgi=b")
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

    private let display = RenderSize(width: 1512, height: 982)

    func testWindowedModeDefaultsTo1280x720WithoutACustomResolution() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .windowed
        settings.resolutionCustom = false

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]), displaySize: display)

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

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]), displaySize: display)

        XCTAssertEqual(arguments, ["-screen-fullscreen", "0", "-screen-width", "2560", "-screen-height", "1440"])
    }

    /// The stretched-image bug: with no size on the command line, Unity started fullscreen at
    /// whatever resolution it had last persisted, and macdrv — holding the captured display —
    /// scanned that out over a display whose mode has a different aspect ratio. Naming the
    /// display's own mode is what keeps the launch on a mode macOS does not have to synthesise.
    func testFullscreenModeWithoutACustomResolutionAsksForTheDisplaysOwnMode() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen
        settings.resolutionCustom = false

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]), displaySize: display)

        XCTAssertEqual(arguments, ["-screen-fullscreen", "1", "-screen-width", "1512", "-screen-height", "982"])
    }

    /// Nothing is invented when the display geometry cannot be read: the game keeps its own size
    /// rather than being sent to a resolution nobody measured.
    func testFullscreenModeOmitsResolutionFlagsWhenTheDisplaySizeIsUnknown() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen
        settings.resolutionCustom = false

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]), displaySize: nil)

        XCTAssertEqual(arguments, ["-screen-fullscreen", "1"])
    }

    func testFullscreenModeAppliesACustomResolutionWhenSet() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen
        settings.resolutionCustom = true
        settings.resolutionWidth = 3440
        settings.resolutionHeight = 1440

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .d3dMetal]), displaySize: display)

        XCTAssertEqual(arguments, ["-screen-fullscreen", "1", "-screen-width", "3440", "-screen-height", "1440"])
    }

    /// The registry values written before launch have to be the same numbers the command line
    /// carries; the profile is where both come from.
    func testProfileCarriesTheSameRenderSizeItPutsOnTheCommandLine() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen
        settings.resolutionCustom = false

        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal]),
            settings: settings,
            displaySize: display
        )

        XCTAssertEqual(profile.renderSize, display)
        XCTAssertTrue(profile.fullscreen)
        XCTAssertTrue(profile.arguments.contains("1512"))
    }

    /// Guards the tolerance: real display modes are not exact ratios (1512x982 is not exactly
    /// 16:10), but a 16:9 size on that panel has to count as stretched.
    func testStretchDetectionAcceptsModeRoundingAndRejectsADifferentShape() {
        XCTAssertFalse(RenderSize(width: 1512, height: 982).isStretched(onto: display))
        XCTAssertFalse(RenderSize(width: 756, height: 491).isStretched(onto: display))
        XCTAssertTrue(RenderSize(width: 1920, height: 1080).isStretched(onto: display))
    }

    /// The shader-compatibility switches are diagnostic: off unless asked for, because each one
    /// changes numeric behaviour for every shader in the game, and each isolatable on its own so a
    /// wrongly shaded model can be attributed to exactly one of them.
    func testD3DMetalShaderCompatibilityFlagsAreOffByDefaultAndSetIndependently() {
        let game = makeGame(requirements: [.wine, .d3dMetal])
        let names = [
            "D3DM_SAMPLE_NAN_TO_ZERO",
            "D3DM_FLUSH_POS_INF_TO_NAN",
            "D3DM_FORCE_RTZ_TEXWRITE",
            "D3DM_POSITION_INVARIANCE"
        ]

        let defaults = LaunchRuntimeProfile.build(game: game, settings: makeSettings(), displaySize: display)
        for name in names {
            XCTAssertNil(defaults.environment[name], "\(name) must stay off until it is asked for")
        }

        var settings = makeSettings()
        settings.d3dMetalSampleNaNToZero = true
        let nanToZero = LaunchRuntimeProfile.build(game: game, settings: settings, displaySize: display)
        XCTAssertEqual(nanToZero.environment["D3DM_SAMPLE_NAN_TO_ZERO"], "1")
        for name in names.dropFirst() {
            XCTAssertNil(nanToZero.environment[name])
        }

        var all = makeSettings()
        all.d3dMetalSampleNaNToZero = true
        all.d3dMetalFlushPositiveInfinityToNaN = true
        all.d3dMetalForceRTZTextureWrite = true
        all.d3dMetalPositionInvariance = true
        let everything = LaunchRuntimeProfile.build(game: game, settings: all, displaySize: display)
        for name in names {
            XCTAssertEqual(everything.environment[name], "1")
        }
    }

    /// A backend that is not D3DMetal must not inherit its private variables.
    func testShaderCompatibilityFlagsAreNotSetOnOtherBackends() {
        var settings = makeSettings(metalRenderBackend: .dxmt)
        settings.d3dMetalSampleNaNToZero = true

        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .d3dMetal, .dxmt]),
            settings: settings,
            displaySize: display
        )

        XCTAssertEqual(profile.backend, .dxmt)
        XCTAssertNil(profile.environment["D3DM_SAMPLE_NAN_TO_ZERO"])
    }
}
