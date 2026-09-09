import XCTest
@testable import NSLauncherApp

final class AbyssRosterStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("abyss-roster-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testMissingFileIsAnEmptyRosterNotAnError() throws {
        let store = AbyssRosterStore(baseDirectory: directory)
        XCTAssertEqual(try store.load(), .empty, "first run should start empty rather than fail")
    }

    func testRoundTripsCharactersAndWeapons() throws {
        let store = AbyssRosterStore(baseDirectory: directory)
        let roster = AbyssRoster(
            characters: [.init(id: "hu-tao", constellation: 1), .init(id: "bennett", constellation: 5)],
            weapons: [.init(id: "staff-of-homa", refinement: 1), .init(id: "the-catch", refinement: 5)])

        try store.save(roster)
        XCTAssertEqual(try store.load(), roster)
    }

    /// A malformed file must surface, not be silently replaced: the roster is
    /// hand-entered data that would be tedious to reconstruct.
    func testCorruptFileSurfacesAsAnError() throws {
        let store = AbyssRosterStore(baseDirectory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: directory.appendingPathComponent("abyss-roster.json"))
        XCTAssertThrowsError(try store.load())
    }

    /// The example roster shipped with the Python tool must decode here, since
    /// the whole point of the shared format is copying the file either way.
    func testPythonExampleRosterDecodes() throws {
        let roster = try AbyssGoldenFixture.exampleRoster()
        XCTAssertEqual(roster.characters.count, 15)
        XCTAssertEqual(roster.weapons.count, 13)
        XCTAssertEqual(roster.constellation(for: "xingqiu"), 6)
        XCTAssertEqual(roster.refinement(for: "the-catch"), 5)
        // A weapon that is not owned still answers R1 rather than trapping.
        XCTAssertEqual(roster.refinement(for: "staff-of-the-scarlet-sands"), 1)
    }

    /// Rosters written before artifacts left the model carry an `artifactSets`
    /// key. Decoding has to ignore it rather than fail, or every roster saved by
    /// an older build stops loading.
    func testRosterFileFromBeforeArtifactsLeftTheModelStillLoads() throws {
        let legacy = """
        {"characters":[{"id":"hu-tao","constellation":0}],
         "weapons":[{"id":"staff-of-homa","refinement":1}],
         "artifactSets":["crimson-witch-of-flames"]}
        """
        let roster = try JSONDecoder().decode(AbyssRoster.self, from: Data(legacy.utf8))
        XCTAssertEqual(roster.characters.map(\.id), ["hu-tao"])
        XCTAssertEqual(roster.weapons.map(\.id), ["staff-of-homa"])
    }

    func testExportProducesAFileThePythonToolCouldRead() throws {
        let store = AbyssRosterStore(baseDirectory: directory)
        let roster = AbyssRoster(characters: [.init(id: "nahida")], weapons: [.init(id: "a-thousand-floating-dreams", refinement: 2)])
        let exported = directory.appendingPathComponent("exported.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try store.exportRoster(roster, to: exported)
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: exported)) as? [String: Any]
        XCTAssertNotNil(raw?["characters"])
        XCTAssertNotNil(raw?["weapons"])
        XCTAssertNil(raw?["artifactSets"],
                     "artifacts are farmable, so the roster no longer records which sets are owned")
        XCTAssertEqual(try store.importRoster(from: exported), roster)
    }
}
