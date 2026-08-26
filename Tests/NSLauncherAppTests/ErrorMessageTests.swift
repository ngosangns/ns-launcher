import XCTest
@testable import NSLauncherApp

/// Every error the launcher can surface passes through one mapping. A case that falls through to
/// `localizedDescription` shows the user untranslated developer text with no remedy in it — which
/// is exactly what the mapping exists to prevent, and is invisible until that error happens.
final class ErrorMessageTests: XCTestCase {
    private let vietnamese = AppText(language: .vietnamese)
    private let english = AppText(language: .english)

    /// D3DMetal cannot be downloaded by the launcher, so its unavailability error has to name the
    /// remedy (installing CrossOver) rather than just failing. Apple's Game Porting Toolkit is
    /// deliberately not named here: the popular Homebrew cask that goes by that name ships DXMT
    /// relabeled, not Apple's real D3DMetal, so naming it would send users to the wrong fix.
    func testTheD3DMetalUnavailableErrorExplainsWhatToDo() {
        let message = english.message(for: WineServiceError.d3dMetalUnavailable("/opt/wine"))
        XCTAssertTrue(message.contains("/opt/wine"))
        XCTAssertTrue(message.contains("CrossOver"))
        XCTAssertFalse(message.contains("Game Porting Toolkit"))
    }

    /// A prefix is single-tenant; the message has to carry the PIDs so the user can act on it.
    func testTheAlreadyRunningErrorNamesThePIDs() {
        let message = english.message(for: LaunchPreflightError.gameAlreadyRunning([4242, 4243]))
        XCTAssertTrue(message.contains("4242"))
        XCTAssertTrue(message.contains("4243"))
    }

    /// Quarantine needs the path the user must clear, not the loader the launcher tried to run.
    func testTheQuarantineErrorCarriesTheOffendingPath() {
        let message = english.message(for: WineServiceError.binaryQuarantined("/Applications/CrossOver.app"))
        XCTAssertTrue(message.contains("/Applications/CrossOver.app"))
    }

    /// A cancelled operation is not a failure and must not read like one.
    func testCancellationReadsAsAStopNotAnError() {
        XCTAssertEqual(english.message(for: CancellationError()), english.operationStopped)
        XCTAssertEqual(vietnamese.message(for: CancellationError()), vietnamese.operationStopped)
    }

    /// A failed process is only diagnosable if its output survives; stderr is where Wine writes.
    func testAFailedProcessCarriesItsOutput() {
        let result = ProcessResult(exitCode: 53, stdout: "", stderr: "err:module:import_dll not found")
        let message = english.message(for: ProcessRunnerError.nonZeroExit(result))
        XCTAssertTrue(message.contains("53"))
        XCTAssertTrue(message.contains("err:module:import_dll not found"))
    }

    /// stdout is the fallback when a process fails without writing to stderr.
    func testAFailedProcessFallsBackToStdout() {
        let result = ProcessResult(exitCode: 1, stdout: "something on stdout", stderr: "")
        XCTAssertTrue(english.message(for: ProcessRunnerError.nonZeroExit(result)).contains("something on stdout"))
    }

    /// Every case of every mapped error domain must produce localized text in both languages —
    /// this is what catches a newly added case that nobody wired into the mapping.
    func testEveryMappedErrorIsLocalizedInBothLanguages() {
        let errors: [Error] = [
            LaunchPreflightError.missingExecutable("/games/x.exe"),
            LaunchPreflightError.missingInstallMetadata,
            LaunchPreflightError.invalidInstallMetadata("bad id"),
            LaunchPreflightError.updateRequiredBeforeLaunch("version drift"),
            LaunchPreflightError.gameAlreadyRunning([1]),
            WineServiceError.binaryQuarantined("/p"),
            WineServiceError.dxvkBootstrapFailed("d"),
            WineServiceError.d3dMetalUnavailable("/p"),
            WineServiceError.dxmtUnavailable("/p"),
            WineServiceError.wineDistributionFailed("d"),
            WineServiceError.wineRootNotFound("/p"),
            WineServiceError.unsupportedKernelDriver("HoYoKProtect.sys"),
            CrossOverInstallError.homebrewNotFound,
            CrossOverInstallError.installFailed("d"),
            ProcessRunnerError.executableNotFound("/p"),
            SophonInstallerError.zstdUnavailable
        ]

        for error in errors {
            let en = english.message(for: error)
            let vi = vietnamese.message(for: error)
            XCTAssertFalse(en.isEmpty, "\(error) has no English text")
            XCTAssertFalse(vi.isEmpty, "\(error) has no Vietnamese text")
            // Falling through to `localizedDescription` returns the same string for both
            // languages, which is the signature of an unmapped case.
            XCTAssertNotEqual(en, vi, "\(error) looks unmapped — both languages returned the same text")
        }
    }

    /// An error from outside the mapped domains still has to say something rather than nothing.
    func testAnUnknownErrorFallsBackToItsOwnDescription() {
        struct Unmapped: LocalizedError {
            var errorDescription: String? { "something unexpected" }
        }
        XCTAssertEqual(english.message(for: Unmapped()), "something unexpected")
    }
}
