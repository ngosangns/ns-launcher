import XCTest
@testable import NSLauncherApp

/// Exercises the real `libproc`/`sysctl` path against a controlled subprocess rather than mocking
/// it — the whole point of this code is reading the live process table correctly, which a mock
/// cannot verify.
final class GameProcessInspectorTests: XCTestCase {
    /// A real, long-lived process whose command line contains the game path being searched for
    /// (`/usr/bin/yes` repeats its arguments forever), the same shape a Wine process running the
    /// game exe under a steam.exe parent has: the launcher's own binary with the target path as an
    /// argument rather than as its own executable image.
    func testFindsARunningProcessByItsCommandLineArgument() async throws {
        let needle = "/tmp/GameProcessInspectorTests-\(UUID().uuidString)/GenshinImpact.exe"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/yes")
        process.arguments = [needle]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        defer { process.terminate() }

        // The process table entry appears as soon as exec() completes; poll briefly rather than
        // asserting on the very first read, which can race a slow CI scheduler.
        var found: Set<Int32> = []
        for _ in 0..<50 {
            found = await GameProcessInspector.runningProcessIDs(forExecutable: URL(fileURLWithPath: needle))
            if found.contains(process.processIdentifier) { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(found.contains(process.processIdentifier))
    }

    /// A path nothing on the system was launched with must not match by accident.
    func testFindsNothingForAPathNoProcessWasLaunchedWith() async {
        let found = await GameProcessInspector.runningProcessIDs(
            forExecutable: URL(fileURLWithPath: "/tmp/GameProcessInspectorTests-\(UUID().uuidString)/NoSuchGame.exe")
        )
        XCTAssertTrue(found.isEmpty)
    }

    /// A terminated process must stop being reported once it has actually exited.
    func testATerminatedProcessStopsBeingReported() async throws {
        let needle = "/tmp/GameProcessInspectorTests-\(UUID().uuidString)/GenshinImpact.exe"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/yes")
        process.arguments = [needle]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let pid = process.processIdentifier

        var foundWhileRunning: Set<Int32> = []
        for _ in 0..<50 {
            foundWhileRunning = await GameProcessInspector.runningProcessIDs(forExecutable: URL(fileURLWithPath: needle))
            if foundWhileRunning.contains(pid) { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(foundWhileRunning.contains(pid))

        process.terminate()
        process.waitUntilExit()

        let foundAfterExit = await GameProcessInspector.runningProcessIDs(forExecutable: URL(fileURLWithPath: needle))
        XCTAssertFalse(foundAfterExit.contains(pid))
    }

    /// The Windows `Z:\…` spelling Wine hands a game through its steam.exe parent (see
    /// `WineService`) must match the same way the POSIX path does.
    func testMatchesTheWindowsDriveSpelling() {
        let path = URL(fileURLWithPath: "/Users/tester/Games/Genshin Impact/GenshinImpact.exe")
        XCTAssertEqual(
            GameProcessInspector.windowsPath(for: path),
            #"Z:\Users\tester\Games\Genshin Impact\GenshinImpact.exe"#
        )
    }

    /// `allPIDs` and `commandLine` are the two syscalls everything else builds on; at minimum this
    /// process's own PID must be among them with a readable command line.
    func testAllPIDsIncludesTheCurrentProcessWithAReadableCommandLine() {
        let pids = GameProcessInspector.allPIDs()
        let myPID = ProcessInfo.processInfo.processIdentifier

        XCTAssertTrue(pids.contains(myPID))
        XCTAssertNotNil(GameProcessInspector.commandLine(forPID: myPID))
    }
}
