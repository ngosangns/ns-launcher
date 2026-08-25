import XCTest
@testable import NSLauncherApp

/// The log panel is the only window into a launch that fails silently, so what the filter drops
/// and what the buffer retains decide whether a failure is diagnosable at all.
final class WineLogFilterTests: XCTestCase {
    private var filter = WineLogFilter()

    // MARK: - MoltenVK dump suppression

    /// MoltenVK prints its version and then several hundred extension lines. The dump is replaced
    /// by one summary line — dropping it silently would make it look like MoltenVK never loaded.
    func testTheFirstMoltenVKDumpIsReplacedByASummaryLine() {
        let summary = filter.filtered("[mvk-info] MoltenVK version 1.2.7.", prefix: "[stderr] ")
        XCTAssertEqual(summary, "[stderr] [mvk-info] MoltenVK initialized; verbose Vulkan capability dump hidden")

        XCTAssertNil(filter.filtered("The following 89 Vulkan extensions are supported:", prefix: "[stderr] "))
        XCTAssertNil(filter.filtered("VK_KHR_swapchain v70", prefix: "[stderr] "))
        XCTAssertNil(filter.filtered("[mvk-info] GPU device: Apple M3", prefix: "[stderr] "))
    }

    /// A second dump in the same run adds nothing; only the first is announced.
    func testALaterMoltenVKDumpIsDroppedEntirely() {
        _ = filter.filtered("[mvk-info] MoltenVK version 1.2.7.", prefix: "[stderr] ")
        _ = filter.filtered("some real line", prefix: "[stderr] ")
        XCTAssertNil(filter.filtered("[mvk-info] MoltenVK version 1.2.7.", prefix: "[stderr] "))
    }

    /// The dump has no terminator, so suppression ends at the first line that is not part of it.
    /// Ending it too late would swallow the launch failure that follows.
    func testSuppressionStopsAtTheFirstLineOutsideTheDump() {
        _ = filter.filtered("[mvk-info] MoltenVK version 1.2.7.", prefix: "[stderr] ")
        XCTAssertNil(filter.filtered("VK_KHR_surface v25", prefix: "[stderr] "))

        let real = filter.filtered("err:module:import_dll Library d3d11.dll not found", prefix: "[stderr] ")
        XCTAssertEqual(real, "[stderr] err:module:import_dll Library d3d11.dll not found")
        // And the next capability-looking line is no longer swallowed by dump state.
        XCTAssertEqual(filter.filtered("The following is not a dump", prefix: "[stderr] "), "[stderr] The following is not a dump")
    }

    /// A new launch must not inherit the previous run's suppression, or its first dump would be
    /// dropped without a summary.
    func testResetLetsTheNextRunAnnounceItsDumpAgain() {
        _ = filter.filtered("[mvk-info] MoltenVK version 1.2.7.", prefix: "[stderr] ")
        filter.reset()
        XCTAssertEqual(
            filter.filtered("[mvk-info] MoltenVK version 1.2.7.", prefix: "[stderr] "),
            "[stderr] [mvk-info] MoltenVK initialized; verbose Vulkan capability dump hidden"
        )
    }

    // MARK: - Low-signal lines

    func testCapabilityNoiseIsDropped() {
        for line in [
            "GPU Family Apple 9",
            "Metal Shading Language 3.1",
            "vendorID: 0x106b",
            "supports the following GPU Features:",
            "wineserver: using server-side synchronization",
            "ntlm_check_version ntlm_auth was not found"
        ] {
            XCTAssertNil(filter.filtered(line, prefix: "[stdout] "), "\(line) should be dropped")
        }
    }

    /// The lines that explain a failure must survive, including the ones this whole change set was
    /// written to make visible.
    func testDiagnosticsThatExplainAFailureSurvive() {
        for line in [
            "err:module:import_dll Library winemetal.dll not found",
            "RtlpWaitForCriticalSection ... loader_section",
            "wine client error:308: partial wakeup read 0",
            "[CacheReader] Failed to resolve cache path"
        ] {
            XCTAssertEqual(filter.filtered(line, prefix: "[stderr] "), "[stderr] " + line)
        }
    }

    /// A blank line is spacing, not noise: dropping it would run separate stack traces together.
    func testBlankLinesAreKeptAsBlank() {
        XCTAssertEqual(filter.filtered("", prefix: "[stdout] "), "")
        XCTAssertEqual(filter.filtered("   ", prefix: "[stdout] "), "")
    }

    // MARK: - Chunks

    func testStderrAndStdoutAreLabelledDifferently() {
        var stderrFilter = WineLogFilter()
        var stdoutFilter = WineLogFilter()
        let text = "something happened"
        XCTAssertEqual(
            stderrFilter.filtered(ProcessOutputChunk(stream: .stderr, text: text)),
            "[stderr] something happened\n"
        )
        XCTAssertEqual(
            stdoutFilter.filtered(ProcessOutputChunk(stream: .stdout, text: text)),
            "[stdout] something happened\n"
        )
    }

    /// A chunk whose every line is noise must produce nothing, not an empty append that still
    /// triggers a publish and a SwiftUI layout pass.
    func testAChunkOfPureNoiseProducesNothing() {
        let chunk = ProcessOutputChunk(stream: .stdout, text: "vendorID: 0x106b\ndeviceID: 0x1\nGPU memory used: 12")
        XCTAssertNil(filter.filtered(chunk))
    }

    func testFilteredChunksAlwaysEndInANewline() {
        let chunk = ProcessOutputChunk(stream: .stdout, text: "line one\nline two")
        XCTAssertEqual(filter.filtered(chunk), "[stdout] line one\n[stdout] line two\n")
    }
}

final class RunLogBufferTests: XCTestCase {
    private var buffer = RunLogBuffer()

    /// Nothing appended is visible until a flush; that is what keeps a chatty game from driving a
    /// SwiftUI layout pass per line.
    func testAppendedTextIsInvisibleUntilFlushed() {
        buffer.append("first\n")
        XCTAssertEqual(buffer.contents, "")
        XCTAssertTrue(buffer.hasPendingText)

        XCTAssertTrue(buffer.flush())
        XCTAssertEqual(buffer.contents, "first\n")
        XCTAssertFalse(buffer.hasPendingText)
    }

    /// The return value is what lets the owner skip a needless publish.
    func testFlushingNothingReportsNoChange() {
        XCTAssertFalse(buffer.flush())
        buffer.append("x")
        XCTAssertTrue(buffer.flush())
        XCTAssertFalse(buffer.flush())
    }

    func testFlushesAccumulateInOrder() {
        for line in ["a\n", "b\n", "c\n"] {
            buffer.append(line)
            buffer.flush()
        }
        XCTAssertEqual(buffer.contents, "a\nb\nc\n")
    }

    /// Trimming keeps the newest text: the tail is where the failure is.
    func testAnOversizedLogIsTrimmedToItsTail() {
        let marker = "THE-INTERESTING-PART"
        buffer.append(String(repeating: "x", count: RunLogBuffer.trimThreshold + 1_000) + marker)
        buffer.flush()

        XCTAssertEqual(buffer.contents.count, RunLogBuffer.retainedCharacters)
        XCTAssertTrue(buffer.contents.hasSuffix(marker))
    }

    /// Trimming below the threshold would pay an O(n) string copy on every append.
    func testALogUnderTheThresholdIsLeftAlone() {
        let text = String(repeating: "x", count: RunLogBuffer.trimThreshold)
        buffer.append(text)
        buffer.flush()
        XCTAssertEqual(buffer.contents.count, RunLogBuffer.trimThreshold)
    }

    /// Retention has to be strictly below the trigger, or every append past the threshold trims.
    func testTheRetainedSizeIsBelowTheTrimThreshold() {
        XCTAssertLessThan(RunLogBuffer.retainedCharacters, RunLogBuffer.trimThreshold)
    }

    /// A new run discards buffered text but keeps what is already on screen until it is reset.
    func testDiscardingPendingTextLeavesFlushedContentsAlone() {
        buffer.append("kept\n")
        buffer.flush()
        buffer.append("dropped\n")
        buffer.discardPending()

        XCTAssertFalse(buffer.hasPendingText)
        XCTAssertEqual(buffer.contents, "kept\n")
        XCTAssertFalse(buffer.flush())
    }

    func testResetClearsFlushedContentsToo() {
        buffer.append("gone\n")
        buffer.flush()
        buffer.reset()
        XCTAssertEqual(buffer.contents, "")
        XCTAssertFalse(buffer.hasPendingText)
    }
}
