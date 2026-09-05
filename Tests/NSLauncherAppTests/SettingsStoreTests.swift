import XCTest
@testable import NSLauncherApp

final class SettingsStoreTests: XCTestCase {
    private var directory: URL!
    private var store: SettingsStore!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SettingsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = SettingsStore(baseDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTripsEverySetting() throws {
        var settings = AppSettings.default
        settings.language = .vietnamese
        settings.launchDisplayMode = .fullscreen

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)
    }

    /// Settings files written before a setting existed must keep loading, with the new key taking
    /// its default rather than failing the whole decode.
    func testKeysMissingFromAnOlderFileFallBackToDefaults() throws {
        try store.save(AppSettings.default)
        try stripKeys(["language", "launchDisplayMode"])

        let loaded = try store.load()

        XCTAssertEqual(loaded.language, .english)
        XCTAssertEqual(loaded.launchDisplayMode, .windowed)
    }

    /// Values the file does carry must survive the defaults merge untouched.
    func testStoredValuesWinOverDefaults() throws {
        var settings = AppSettings.default
        settings.language = .vietnamese
        settings.launchDisplayMode = .fullscreen
        try store.save(settings)

        let loaded = try store.load()

        XCTAssertEqual(loaded.language, .vietnamese)
        XCTAssertEqual(loaded.launchDisplayMode, .fullscreen)
    }

    /// Keys from removed settings must not break the decode — older settings.json files still
    /// carry the removed Mac Driver / launch-option / D3DMetal toggles, and a decode failure there
    /// would reset the whole settings file to defaults.
    func testUnknownKeysFromRemovedSettingsAreIgnored() throws {
        try store.save(AppSettings.default)
        try mutateJSON { json in
            json["leftCommandIsCtrl"] = true
            json["showMetalHUD"] = true
            json["cloudCompatibilityMode"] = false
            json["proxyEnabled"] = true
            json["proxyHost"] = "http://127.0.0.1:8080"
            json["metalRenderBackend"] = "d3dMetal"
            json["d3dMetalSampleNaNToZero"] = true
            json["macDriverRetina"] = true
            json["enableHDR"] = true
        }

        XCTAssertNoThrow(try store.load())
    }

    /// `dxmt` is `RuntimeRequirement`'s raw value before it was renamed to `dxmtBundled`. A settings
    /// file written by an older launcher version still carries it in a game's
    /// `runtimeRequirements`, and a decode failure there resets the whole settings file to defaults
    /// (see `SettingsStore` header), so it has to keep loading as the equivalent `.dxmt` requirement.
    func testLegacyDXMTRuntimeRequirementDecodesAsDXMT() throws {
        try store.save(AppSettings.default)
        try mutateJSON { json in
            guard var games = json["games"] as? [[String: Any]] else { return XCTFail("no games in default settings") }
            games[0]["runtimeRequirements"] = ["wine", "dxmt"]
            json["games"] = games
        }

        let loaded = try store.load()

        XCTAssertEqual(loaded.games.first?.runtimeRequirements, [.wine, .dxmt])
    }

    /// `d3dMetal` is the raw value of the removed Apple D3DMetal backend requirement. A settings
    /// file from before D3DMetal was removed still carries it, and it must keep loading as the
    /// remaining Metal-native requirement rather than fail the whole decode.
    func testLegacyD3DMetalRuntimeRequirementDecodesAsDXMT() throws {
        try store.save(AppSettings.default)
        try mutateJSON { json in
            guard var games = json["games"] as? [[String: Any]] else { return XCTFail("no games in default settings") }
            games[0]["runtimeRequirements"] = ["wine", "d3dMetal"]
            json["games"] = games
        }

        let loaded = try store.load()

        XCTAssertEqual(loaded.games.first?.runtimeRequirements, [.wine, .dxmt])
    }

    func testCreatesDefaultsWhenNoFileExists() throws {
        XCTAssertEqual(try store.load().language, .english)
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsURL.path))
    }

    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }

    private func stripKeys(_ keys: [String]) throws {
        try mutateJSON { json in
            for key in keys { json.removeValue(forKey: key) }
        }
    }

    private func mutateJSON(_ mutate: (inout [String: Any]) -> Void) throws {
        let data = try Data(contentsOf: settingsURL)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        mutate(&json)
        try JSONSerialization.data(withJSONObject: json).write(to: settingsURL)
    }
}
