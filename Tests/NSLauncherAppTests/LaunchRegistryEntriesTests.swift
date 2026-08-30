import XCTest
@testable import NSLauncherApp

/// The launch registry values are the launcher's only way to overrule what the game persisted for
/// itself. Both reported rendering faults — wrong colour, stretched models — came from a value being
/// written in one direction only, so what these cover is that the "off" state is written too.
final class LaunchRegistryEntriesTests: XCTestCase {
    private let genshin = #"HKEY_CURRENT_USER\Software\miHoYo\Genshin Impact"#
    private let macDriver = #"HKEY_CURRENT_USER\Software\Wine\Mac Driver"#

    private func makeRequest(
        renderSize: RenderSize? = nil,
        enableHDR: Bool = false,
        fullscreen: Bool = false
    ) -> WineLaunchRequest {
        WineLaunchRequest(
            wineBinaryPath: "/usr/local/bin/wine",
            prefixDirectory: URL(fileURLWithPath: "/tmp/prefix"),
            executablePath: URL(fileURLWithPath: "/tmp/game/GenshinImpact.exe"),
            arguments: [],
            environment: [:],
            currentDirectory: URL(fileURLWithPath: "/tmp/game"),
            runtimeRequirements: [.wine, .d3dMetal],
            renderSize: renderSize,
            enableHDR: enableHDR,
            fullscreen: fullscreen
        )
    }

    private func dword(_ entries: [RegistryEntry], key: String, name: String) -> UInt32? {
        for entry in entries where entry.key == key && entry.name == name {
            if case let .dword(value) = entry.value { return value }
        }
        return nil
    }

    private func string(_ entries: [RegistryEntry], key: String, name: String) -> String? {
        for entry in entries where entry.key == key && entry.name == name {
            if case let .string(value) = entry.value { return value }
        }
        return nil
    }

    /// The wrong-colour bug: with HDR left unwritten, an HDR flag the game had set for itself stayed
    /// set forever and the launcher's toggle could only ever turn it on.
    func testHDRFlagIsWrittenOffAsWellAsOn() {
        let off = WineService.launchRegistryEntries(for: makeRequest(enableHDR: false))
        XCTAssertEqual(dword(off, key: genshin, name: "WINDOWS_HDR_ON_h3132281285"), 0)

        let on = WineService.launchRegistryEntries(for: makeRequest(enableHDR: true))
        XCTAssertEqual(dword(on, key: genshin, name: "WINDOWS_HDR_ON_h3132281285"), 1)
    }

    /// Unity's persisted fullscreen flag has to agree with the `-screen-fullscreen` argument and
    /// with macdrv's display capture; it used to be pinned to 0 while the other two said fullscreen.
    func testUnityFullscreenFlagFollowsTheDisplayMode() {
        let windowed = WineService.launchRegistryEntries(for: makeRequest(fullscreen: false))
        XCTAssertEqual(dword(windowed, key: genshin, name: "Screenmanager Is Fullscreen mode_h3981298716"), 0)
        XCTAssertEqual(string(windowed, key: macDriver, name: "CaptureDisplaysForFullscreen"), "n")

        let fullscreen = WineService.launchRegistryEntries(for: makeRequest(fullscreen: true))
        XCTAssertEqual(dword(fullscreen, key: genshin, name: "Screenmanager Is Fullscreen mode_h3981298716"), 1)
        XCTAssertEqual(string(fullscreen, key: macDriver, name: "CaptureDisplaysForFullscreen"), "y")
    }

    /// The stretched-models bug: a resolution set inside the game persisted into the next launch,
    /// which then captured the display for a mode of a different shape.
    func testResolutionIsRewrittenFromTheLaunchesOwnRenderSize() {
        let entries = WineService.launchRegistryEntries(
            for: makeRequest(renderSize: RenderSize(width: 1512, height: 982), fullscreen: true)
        )
        XCTAssertEqual(dword(entries, key: genshin, name: "Screenmanager Resolution Width_h182942802"), 1512)
        XCTAssertEqual(dword(entries, key: genshin, name: "Screenmanager Resolution Height_h2627697771"), 982)
    }

    func testResolutionIsLeftAloneWhenTheLaunchNamesNoSize() {
        let entries = WineService.launchRegistryEntries(for: makeRequest(renderSize: nil))
        XCTAssertNil(dword(entries, key: genshin, name: "Screenmanager Resolution Width_h182942802"))
        XCTAssertNil(dword(entries, key: genshin, name: "Screenmanager Resolution Height_h2627697771"))
    }
}
