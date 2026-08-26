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
        settings.metalFXUpscaling = true
        settings.showMetalHUD = true
        settings.proxyHost = "http://127.0.0.1:8080"

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)
    }

    /// Settings files written before a setting existed must keep loading, with the new key taking
    /// its default rather than failing the whole decode.
    func testKeysMissingFromAnOlderFileFallBackToDefaults() throws {
        try store.save(AppSettings.default)
        try stripKeys(["metalFXUpscaling", "resolutionWidth"])

        let loaded = try store.load()

        XCTAssertEqual(loaded.metalFXUpscaling, false)
        XCTAssertEqual(loaded.resolutionWidth, 1920)
    }

    /// Values the file does carry must survive the defaults merge untouched.
    func testStoredValuesWinOverDefaults() throws {
        var settings = AppSettings.default
        settings.metalFXUpscaling = true
        settings.resolutionWidth = 2560
        try store.save(settings)

        let loaded = try store.load()

        XCTAssertEqual(loaded.metalFXUpscaling, true)
        XCTAssertEqual(loaded.resolutionWidth, 2560)
    }

    /// Keys from removed settings must not break the decode.
    func testUnknownKeysFromRemovedSettingsAreIgnored() throws {
        try store.save(AppSettings.default)
        try mutateJSON { $0["maxFrameRate"] = 72 }

        XCTAssertNoThrow(try store.load())
    }

    /// `dxmt` is `RuntimeRequirement`'s raw value before the D3DMetal rename. A settings file
    /// written by an older launcher version still carries it in a game's `runtimeRequirements`,
    /// and a decode failure there resets the whole settings file to defaults (see `SettingsStore`
    /// header), so it has to keep loading as the equivalent `.d3dMetal` requirement.
    func testLegacyDXMTRuntimeRequirementDecodesAsD3DMetal() throws {
        try store.save(AppSettings.default)
        try mutateJSON { json in
            guard var games = json["games"] as? [[String: Any]] else { return XCTFail("no games in default settings") }
            games[0]["runtimeRequirements"] = ["wine", "dxmt"]
            json["games"] = games
        }

        let loaded = try store.load()

        XCTAssertEqual(loaded.games.first?.runtimeRequirements, [.wine, .d3dMetal])
    }

    func testCreatesDefaultsWhenNoFileExists() throws {
        XCTAssertEqual(try store.load().metalFXUpscaling, false)
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
