import XCTest
@testable import NSLauncherApp

final class InstallTargetPrunerTests: XCTestCase {
    private var installDirectory: URL!

    override func setUpWithError() throws {
        installDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("InstallTargetPrunerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: installDirectory)
    }

    /// Files the game writes for itself never appear in a Sophon manifest. Pruning them makes the
    /// client re-download tens of gigabytes into `Persistent`, so the protected list must hold.
    func testKeepsProtectedDirectoriesOutsideTheTargetSet() throws {
        let persistent = "GenshinImpact_Data/Persistent"
        try write("GenshinImpact_Data/StreamingAssets/kept.blk")
        try write("GenshinImpact_Data/StreamingAssets/orphan.blk")
        try write("\(persistent)/VideoAssets/StandaloneWindows64/opening.usm")
        try write("\(persistent)/res_versions_persist")

        try InstallTargetPruner.prune(
            installDirectory: installDirectory,
            targetRelativePaths: ["GenshinImpact_Data/StreamingAssets/kept.blk"],
            protectedURLs: [installDirectory.appendingPathComponent(persistent, isDirectory: true)]
        )

        XCTAssertTrue(exists("GenshinImpact_Data/StreamingAssets/kept.blk"))
        XCTAssertFalse(exists("GenshinImpact_Data/StreamingAssets/orphan.blk"))
        XCTAssertTrue(exists("\(persistent)/VideoAssets/StandaloneWindows64/opening.usm"))
        XCTAssertTrue(exists("\(persistent)/res_versions_persist"))
    }

    /// Without the protection the same tree is removed, which is the regression being guarded.
    func testRemovesGameOwnedFilesWhenNotProtected() throws {
        try write("GenshinImpact_Data/Persistent/VideoAssets/opening.usm")

        try InstallTargetPruner.prune(
            installDirectory: installDirectory,
            targetRelativePaths: []
        )

        XCTAssertFalse(exists("GenshinImpact_Data/Persistent/VideoAssets/opening.usm"))
    }

    private func write(_ relativePath: String) throws {
        let url = installDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("x".utf8).write(to: url)
    }

    private func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: installDirectory.appendingPathComponent(relativePath).path
        )
    }
}
