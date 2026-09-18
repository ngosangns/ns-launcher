import XCTest
@testable import NSLauncherApp

final class CutsceneLibraryTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("CutsceneLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    private func makeGame() -> GameDefinition {
        GameDefinition(
            id: "test-game",
            displayName: "Test Game",
            installDirectory: root,
            executableRelativePath: "GenshinImpact.exe",
            winePrefixDirectory: root.appendingPathComponent(".wine", isDirectory: true),
            installerStrategy: .sophon,
            runtimeRequirements: [],
            launchArguments: []
        )
    }

    private func write(_ relativePath: String, bytes: Int, under base: URL) throws {
        let url = base.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0, count: bytes).write(to: url)
    }

    func testListCutsceneFilesFindsOnlyUSMFilesWithCorrectSizeAndRelativePath() throws {
        let videoAssets = root
            .appendingPathComponent("GenshinImpact_Data/StreamingAssets/VideoAssets", isDirectory: true)

        try write("StandaloneWindows64/Cs_Example.usm", bytes: 1024, under: videoAssets)
        try write("StandaloneWindows64/Cs_OtherClip.USM", bytes: 2048, under: videoAssets)
        try write("StandaloneWindows64/Cs_Example.srt", bytes: 10, under: videoAssets)
        try write("readme.txt", bytes: 5, under: videoAssets)

        let files = LauncherCoordinator.listCutsceneFiles(for: makeGame())
            .sorted { $0.relativePath < $1.relativePath }

        XCTAssertEqual(files.map(\.relativePath), [
            "StandaloneWindows64/Cs_Example.usm",
            "StandaloneWindows64/Cs_OtherClip.USM"
        ])
        XCTAssertEqual(files.first(where: { $0.relativePath.hasSuffix(".usm") })?.sizeBytes, 1024)
        XCTAssertEqual(files.first(where: { $0.relativePath.hasSuffix(".USM") })?.sizeBytes, 2048)
    }

    func testListCutsceneFilesReturnsEmptyWhenVideoAssetsMissing() {
        XCTAssertEqual(LauncherCoordinator.listCutsceneFiles(for: makeGame()), [])
    }

    func testCutsceneCacheDirectoryIsStableAndDistinctPerRelativePath() {
        let fileA = CutsceneFile(url: root, relativePath: "StandaloneWindows64/Cs_Example.usm", sizeBytes: 0)
        let fileB = CutsceneFile(url: root, relativePath: "StandaloneWindows64/Cs_OtherClip.usm", sizeBytes: 0)

        let dirA1 = LauncherCoordinator.cutsceneCacheDirectory(for: fileA)
        let dirA2 = LauncherCoordinator.cutsceneCacheDirectory(for: fileA)
        let dirB = LauncherCoordinator.cutsceneCacheDirectory(for: fileB)

        XCTAssertEqual(dirA1, dirA2)
        XCTAssertNotEqual(dirA1, dirB)
        XCTAssertEqual(dirA1.lastPathComponent, "StandaloneWindows64_Cs_Example.usm")
    }

    func testFirstMKVFindsMKVCaseInsensitivelyAndIgnoresOtherExtensions() throws {
        let directory = root.appendingPathComponent("decoded", isDirectory: true)
        try write("decoded/Cs_Example.ivf", bytes: 4, under: root)
        try write("decoded/Cs_Example_0.wav", bytes: 4, under: root)

        XCTAssertNil(LauncherCoordinator.firstMKV(in: directory))

        try write("decoded/Cs_Example.MKV", bytes: 4, under: root)

        XCTAssertEqual(LauncherCoordinator.firstMKV(in: directory)?.lastPathComponent, "Cs_Example.MKV")
    }

    func testFirstMKVReturnsNilForMissingDirectory() {
        XCTAssertNil(LauncherCoordinator.firstMKV(in: root.appendingPathComponent("does-not-exist")))
    }

    /// Filenames confirmed against a real Genshin install's `StreamingAssets/VideoAssets`.
    func testTravelerGenderTokenMatchesRealFilenameConventions() {
        XCTAssertEqual(
            LauncherCoordinator.travelerGenderToken(inRelativePath: "StandaloneWindows64/Cs_Sumeru_AQ_30280701_MS_Boy.usm"),
            .aether
        )
        XCTAssertEqual(
            LauncherCoordinator.travelerGenderToken(inRelativePath: "StandaloneWindows64/Cs_Fontaine_LQ140061601_SUDO_Girl.usm"),
            .lumine
        )
        XCTAssertEqual(
            LauncherCoordinator.travelerGenderToken(inRelativePath: "StandaloneWindows64/MDAQ001_OPNew_Part2_PlayerBoy.usm"),
            .aether
        )
        XCTAssertEqual(
            LauncherCoordinator.travelerGenderToken(inRelativePath: "StandaloneWindows64/MDAQ001_OPNew_Part2_PlayerGirl.usm"),
            .lumine
        )
        XCTAssertNil(LauncherCoordinator.travelerGenderToken(inRelativePath: "StandaloneWindows64/Cs_LQ1101505_YunjinOpera.usm"))
        // Case must match exactly — no accidental substring match on an unrelated lowercase word.
        XCTAssertNil(LauncherCoordinator.travelerGenderToken(inRelativePath: "StandaloneWindows64/Cs_Cowboy.usm"))
    }
}
