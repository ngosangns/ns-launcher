import XCTest
@testable import NSLauncherApp

final class WineServiceCacheTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("WineServiceCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    func testMissingWineserverDoesNotConfirmShutdown() async {
        let stopped = await WineService.waitForWineserver(
            wineBuild: makeWineBuild(),
            environment: [:],
            processRunner: SuccessfulProcessRunner(),
            onDiagnostic: { _ in }
        )

        XCTAssertFalse(stopped)
    }

    func testSuccessfulWineserverWaitConfirmsShutdown() async throws {
        let build = makeWineBuild()
        try createWineserver(in: build.root)

        let stopped = await WineService.waitForWineserver(
            wineBuild: build,
            environment: [:],
            processRunner: SuccessfulProcessRunner(),
            onDiagnostic: { _ in }
        )

        XCTAssertTrue(stopped)
    }

    func testFailedWineserverWaitDoesNotConfirmShutdown() async throws {
        let build = makeWineBuild()
        try createWineserver(in: build.root)

        let stopped = await WineService.waitForWineserver(
            wineBuild: build,
            environment: [:],
            processRunner: FailingProcessRunner(),
            onDiagnostic: { _ in }
        )

        XCTAssertFalse(stopped)
    }

    private func makeWineBuild() -> WineBuild {
        WineBuild(
            binaryPath: root.appendingPathComponent("bin/wineloader").path,
            root: root,
            majorVersion: 11
        )
    }

    private func createWineserver(in wineRoot: URL) throws {
        let wineserver = wineRoot.appendingPathComponent("bin/wineserver")
        try FileManager.default.createDirectory(
            at: wineserver.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        _ = FileManager.default.createFile(atPath: wineserver.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wineserver.path)
    }
}

private struct SuccessfulProcessRunner: ProcessRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?,
        logFileURL: URL?,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
    ) async throws -> ProcessResult {
        ProcessResult(exitCode: 0, stdout: "", stderr: "")
    }
}

private struct FailingProcessRunner: ProcessRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        currentDirectory: URL?,
        logFileURL: URL?,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
    ) async throws -> ProcessResult {
        throw ProcessRunnerError.executableNotFound(executable)
    }
}
