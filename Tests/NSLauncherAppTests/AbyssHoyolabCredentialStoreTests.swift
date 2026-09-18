import XCTest
@testable import NSLauncherApp

/// The store used to write a keychain item under a fixed service name, so its
/// tests ran against the real login keychain and could leave a stray item on
/// the machine when one crashed. Now that it is a JSON file like the rest of
/// the Abyss state, each test gets its own directory and takes it away again.
final class AbyssHoyolabCredentialStoreTests: XCTestCase {
    private var directory: URL!
    private var store: AbyssHoyolabCredentialStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("abyss-hoyolab-tests-\(UUID().uuidString)", isDirectory: true)
        store = AbyssHoyolabCredentialStore(baseDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private var fileURL: URL { directory.appendingPathComponent("abyss-hoyolab.json") }

    func testSaveThenLoadRoundTrips() throws {
        try store.save(ltuid: "123456789", ltoken: "some_token_value_abc")
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.ltuid, "123456789")
        XCTAssertEqual(loaded.ltoken, "some_token_value_abc")
    }

    /// The store creates its own directory: on a fresh Mac nothing else has
    /// made Application Support/NSLauncher yet when the player presses import.
    func testSavingIntoADirectoryThatDoesNotExistYet() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        try store.save(ltuid: "1", ltoken: "t")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    /// A second save has to fully replace the first, not merge with it or
    /// leave the previous values recoverable in the file.
    func testSecondSaveReplacesTheFirst() throws {
        try store.save(ltuid: "111111111", ltoken: "first")
        try store.save(ltuid: "222222222", ltoken: "second")
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.ltuid, "222222222")
        XCTAssertEqual(loaded.ltoken, "second")

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(contents.contains("first"), "the replaced token is still in the file")
    }

    func testEmptyCredentialsRoundTripJustLikeRealOnes() throws {
        // Not "nothing saved" — an explicit save of empty strings, which is how
        // a player clears the fields. `load` should not read that back as
        // "nothing here" and return nil.
        try store.save(ltuid: "", ltoken: "")
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.ltuid, "")
        XCTAssertEqual(loaded.ltoken, "")
    }

    func testNothingSavedYetLoadsAsNil() {
        XCTAssertNil(store.load())
    }

    /// A file the player edited by hand, or a truncated write, must come back
    /// as "paste them in again" rather than throwing on a launch path.
    func testUnreadableContentLoadsAsNil() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: fileURL)
        XCTAssertNil(store.load())
    }

    /// This is a live login session sitting in a plain file, which is the whole
    /// reason it is not in the Keychain any more. Owner-only is the one bit of
    /// protection left, so it is worth a test rather than a comment.
    func testTheFileIsReadableOnlyByItsOwner() throws {
        try store.save(ltuid: "123456789", ltoken: "some_token_value_abc")
        let permissions = try FileManager.default
            .attributesOfItem(atPath: fileURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.int16Value, 0o600)
    }
}
