import XCTest
@testable import NSLauncherApp

/// Exercises the real macOS Keychain — this is what the app actually calls,
/// unlike most persistence in this suite which goes through a memory double.
/// A fixed service/account pair means a run that crashes mid-test can leave a
/// stray item behind, so every test cleans up in `tearDown` too, not just at
/// the end of the happy path.
final class AbyssHoyolabCredentialStoreTests: XCTestCase {
    private let store = AbyssHoyolabCredentialStore()

    override func tearDown() {
        try? store.save(ltuid: "", ltoken: "")
        super.tearDown()
    }

    func testSaveThenLoadRoundTrips() throws {
        try store.save(ltuid: "123456789", ltoken: "some_token_value_abc")
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.ltuid, "123456789")
        XCTAssertEqual(loaded.ltoken, "some_token_value_abc")
    }

    /// A second save has to fully replace the first, not merge with it or
    /// leave a duplicate keychain item behind that a later load could pick up
    /// unpredictably.
    func testSecondSaveReplacesTheFirst() throws {
        try store.save(ltuid: "111111111", ltoken: "first")
        try store.save(ltuid: "222222222", ltoken: "second")
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.ltuid, "222222222")
        XCTAssertEqual(loaded.ltoken, "second")
    }

    func testEmptyCredentialsRoundTripJustLikeRealOnes() throws {
        // Not "nothing saved" — an explicit save of empty strings, the state
        // right after `tearDown` clears out a previous test's values. `load`
        // should not treat that as "nothing here" and return nil.
        try store.save(ltuid: "", ltoken: "")
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.ltuid, "")
        XCTAssertEqual(loaded.ltoken, "")
    }
}
