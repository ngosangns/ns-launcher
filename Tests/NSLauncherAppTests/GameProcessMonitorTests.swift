import XCTest
@testable import NSLauncherApp

final class GameProcessMonitorTests: XCTestCase {
    /// Shared process-table stand-in the monitor's injected probe reads, so tests
    /// flip the "game running" state exactly like the launcher would observe it.
    private actor ProbeState {
        var running = false
        func set(_ newValue: Bool) { running = newValue }
        func isRunning() -> Bool { running }
    }

    private func makeMonitor(probe: ProbeState) -> GameProcessMonitor {
        GameProcessMonitor(
            isGameRunning: { await probe.isRunning() },
            sleep: { try await Task.sleep(nanoseconds: $0) }
        )
    }

    func testWaitUntilRunningReturnsOnceGameAppears() async throws {
        let probe = ProbeState()
        let monitor = makeMonitor(probe: probe)

        let waiter = Task { try await monitor.waitUntilRunning() }
        try await Task.sleep(nanoseconds: 20_000_000)
        await probe.set(true)

        try await waiter.value
    }

    func testWaitUntilRunningReturnsImmediatelyWhenAlreadyRunning() async throws {
        let probe = ProbeState()
        await probe.set(true)
        let monitor = makeMonitor(probe: probe)

        try await monitor.waitUntilRunning()
    }

    func testWaitUntilRunningThrowsOnCancellation() async throws {
        let probe = ProbeState()
        let monitor = makeMonitor(probe: probe)

        let waiter = Task { try await monitor.waitUntilRunning() }
        try await Task.sleep(nanoseconds: 20_000_000)
        waiter.cancel()

        do {
            _ = try await waiter.value
            XCTFail("expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testWaitUntilStoppedReturnsOnceGameStops() async throws {
        let probe = ProbeState()
        await probe.set(true)
        let monitor = makeMonitor(probe: probe)

        let waiter = Task { try await monitor.waitUntilStopped() }
        try await Task.sleep(nanoseconds: 20_000_000)
        await probe.set(false)

        try await waiter.value
    }

    func testWaitUntilStoppedReturnsImmediatelyWhenNotRunning() async throws {
        let probe = ProbeState()
        let monitor = makeMonitor(probe: probe)

        try await monitor.waitUntilStopped()
    }

    func testWaitUntilStoppedThrowsOnCancellation() async throws {
        let probe = ProbeState()
        await probe.set(true)
        let monitor = makeMonitor(probe: probe)

        let waiter = Task { try await monitor.waitUntilStopped() }
        try await Task.sleep(nanoseconds: 20_000_000)
        waiter.cancel()

        do {
            _ = try await waiter.value
            XCTFail("expected CancellationError")
        } catch is CancellationError {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}