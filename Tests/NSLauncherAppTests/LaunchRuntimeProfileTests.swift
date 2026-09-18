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

    /// DXMT is the only Metal-native backend; a game that declares it always gets it.
    func testDXMTIsUsedWhenDeclared() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: .default
        )
        XCTAssertEqual(profile.backend, .dxmt)
        XCTAssertEqual(profile.environment["WINEESYNC"], "1")
        // The regression this guards against: without a builtin override, Wine loaded a stale native
        // DXVK left in the prefix instead of the render bridge, and the game rendered through
        // MoltenVK — 16154 [mvk-error] lines in 120s of play, versus zero with the override.
        XCTAssertEqual(profile.environment["WINEDLLOVERRIDES"], "d3d10,d3d10_1,d3d10core,d3d11,dxgi=b")
    }

    func testDXMTOnlyRequirementFallsBackToDXMT() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: .default
        )
        XCTAssertEqual(profile.backend, .dxmt)
    }

    /// The render bridge is not applied to a game that never asked for a translation layer; its
    /// environment would otherwise follow every plain-Wine launch around.
    func testAGameNeedingNoBridgeRunsOnPlainWine() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine]),
            settings: .default
        )
        XCTAssertEqual(profile.backend, .plainWine)
        XCTAssertNil(profile.environment["WINEDLLOVERRIDES"])
    }

    /// Everything but `err` is off by default; the kernel-driver names the launcher scans for rely
    /// on Wine's err-class output surviving.
    func testWineDebugKeepsErrEnabledEverywhereExceptUnwind() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: .default
        )
        XCTAssertEqual(profile.environment["WINEDEBUG"], "-all,+err,err-unwind")
    }

    /// The YAAGL launch workarounds are not settings — they always run. This guards against one
    /// silently becoming conditional again.
    func testCloudCompatibilityAndTimeoutFixAlwaysApply() {
        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine]),
            settings: .default
        )
        XCTAssertEqual(profile.environment["WINE_ENABLE_TIMEOUT_FIX"], "1")
        XCTAssertTrue(profile.arguments.contains("-platform_type"))
        XCTAssertTrue(profile.arguments.contains("CLOUD_THIRD_PARTY_PC"))
        XCTAssertTrue(profile.arguments.contains("-is_cloud"))
    }

    private let display = RenderSize(width: 1512, height: 982)

    func testWindowedModeDefaultsTo1280x720() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .windowed

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .dxmt]), displaySize: display)

        XCTAssertEqual(arguments, ["-screen-fullscreen", "0", "-screen-width", "1280", "-screen-height", "720"])
    }

    /// The stretched-image bug: with no size on the command line, Unity started fullscreen at
    /// whatever resolution it had last persisted, and macdrv — holding the captured display —
    /// scanned that out over a display whose mode has a different aspect ratio. Naming the
    /// display's own mode is what keeps the launch on a mode macOS does not have to synthesise.
    func testFullscreenModeAsksForTheDisplaysOwnMode() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .dxmt]), displaySize: display)

        XCTAssertEqual(arguments, ["-screen-fullscreen", "1", "-screen-width", "1512", "-screen-height", "982"])
    }

    /// Nothing is invented when the display geometry cannot be read: the game keeps its own size
    /// rather than being sent to a resolution nobody measured.
    func testFullscreenModeOmitsResolutionFlagsWhenTheDisplaySizeIsUnknown() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen

        let arguments = settings.launchArguments(for: makeGame(requirements: [.wine, .dxmt]), displaySize: nil)

        XCTAssertEqual(arguments, ["-screen-fullscreen", "1"])
    }

    /// The registry values written before launch have to be the same numbers the command line
    /// carries; the profile is where both come from.
    func testProfileCarriesTheSameRenderSizeItPutsOnTheCommandLine() {
        var settings = AppSettings.default
        settings.launchDisplayMode = .fullscreen

        let profile = LaunchRuntimeProfile.build(
            game: makeGame(requirements: [.wine, .dxmt]),
            settings: settings,
            displaySize: display
        )

        XCTAssertEqual(profile.renderSize, display)
        XCTAssertTrue(profile.fullscreen)
        XCTAssertTrue(profile.arguments.contains("1512"))
    }
}
