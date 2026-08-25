import XCTest
@testable import NSLauncherApp

final class GameLogFileTests: XCTestCase {
    func testPreparedPathIsNamedForTheSession() throws {
        let url = try XCTUnwrap(GameLogFile.prepare(now: Date(timeIntervalSince1970: 0)))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("game-"))
        XCTAssertEqual(url.pathExtension, "log")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "NSLauncher")
    }

    func testPreparingTwiceInTheSameSecondDoesNotCollideAcrossSessions() throws {
        let first = try XCTUnwrap(GameLogFile.prepare(now: Date(timeIntervalSince1970: 0)))
        let second = try XCTUnwrap(GameLogFile.prepare(now: Date(timeIntervalSince1970: 61)))
        XCTAssertNotEqual(first, second)
    }
}

final class ProcessRunnerLogFileTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ProcessRunnerLogFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Redirected output must land on disk instead of being streamed through the launcher.
    func testRedirectedOutputGoesToTheFileAndNotToTheCallback() async throws {
        let logURL = directory.appendingPathComponent("run.log")
        let streamed = OutputCollector()

        let result = try await ProcessRunner().run(
            executable: "/bin/sh",
            arguments: ["-c", "echo to-stdout; echo to-stderr 1>&2"],
            environment: [:],
            currentDirectory: nil,
            logFileURL: logURL,
            onOutput: { chunk in streamed.append(chunk.text) }
        )

        let onDisk = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(onDisk.contains("to-stdout"))
        XCTAssertTrue(onDisk.contains("to-stderr"))
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(streamed.text.isEmpty)
    }

    /// Failure classification reads the file back, so a non-zero exit still carries its output.
    func testFailureStillCarriesTheOutputForClassification() async throws {
        let logURL = directory.appendingPathComponent("fail.log")

        do {
            _ = try await ProcessRunner().run(
                executable: "/bin/sh",
                arguments: ["-c", "echo HoYoKProtect.sys 1>&2; exit 3"],
                environment: [:],
                currentDirectory: nil,
                logFileURL: logURL,
                onOutput: nil
            )
            XCTFail("expected a non-zero exit")
        } catch let ProcessRunnerError.nonZeroExit(result) {
            XCTAssertEqual(result.exitCode, 3)
            XCTAssertTrue(result.stdout.contains("HoYoKProtect.sys"))
        }
    }

    /// Without a log file the streaming path must keep working for the launcher's own tools.
    func testPipedRunStillStreams() async throws {
        let streamed = OutputCollector()

        let result = try await ProcessRunner().run(
            executable: "/bin/sh",
            arguments: ["-c", "echo streamed"],
            environment: [:],
            currentDirectory: nil,
            onOutput: { chunk in streamed.append(chunk.text) }
        )

        XCTAssertTrue(result.stdout.contains("streamed"))
        XCTAssertTrue(streamed.text.contains("streamed"))
    }
}

/// Output arrives on a background queue, so collection needs its own lock.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""

    var text: String { lock.withLock { storage } }

    func append(_ chunk: String) {
        lock.withLock { storage += chunk }
    }
}
