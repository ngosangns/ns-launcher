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
        settings.maxFrameRate = 72
        settings.useMsync = true
        settings.proxyHost = "http://127.0.0.1:8080"

        try store.save(settings)

        XCTAssertEqual(try store.load(), settings)
    }

    /// Settings files written before a setting existed must keep loading, with the new key taking
    /// its default rather than failing the whole decode.
    func testKeysMissingFromAnOlderFileFallBackToDefaults() throws {
        try store.save(AppSettings.default)
        try stripKeys(["metalFXScaleFactor", "useMsync", "maxFrameRate"])

        let loaded = try store.load()

        XCTAssertEqual(loaded.metalFXScaleFactor, 1.5)
        XCTAssertFalse(loaded.useMsync)
        XCTAssertEqual(loaded.maxFrameRate, 0)
    }

    /// Values the file does carry must survive the defaults merge untouched.
    func testStoredValuesWinOverDefaults() throws {
        var settings = AppSettings.default
        settings.maxFrameRate = 72
        settings.metalFXScaleFactor = 2.0
        try store.save(settings)
        try stripKeys(["useMsync"])

        let loaded = try store.load()

        XCTAssertEqual(loaded.maxFrameRate, 72)
        XCTAssertEqual(loaded.metalFXScaleFactor, 2.0)
    }

    /// Keys from removed settings must not break the decode.
    func testUnknownKeysFromRemovedSettingsAreIgnored() throws {
        try store.save(AppSettings.default)
        try mutateJSON { $0["renderBackend"] = "d3dMetal" }

        XCTAssertNoThrow(try store.load())
    }

    func testCreatesDefaultsWhenNoFileExists() throws {
        XCTAssertEqual(try store.load().metalFXScaleFactor, 1.5)
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
