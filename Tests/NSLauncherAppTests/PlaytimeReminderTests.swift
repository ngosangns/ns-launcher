import XCTest
@testable import NSLauncherApp

/// The Home screen's playtime countdown is advisory only — it flags when time is up but never
/// stops the game (see `LauncherViewModel.startPlaytimeReminder`). These tests cover the pure
/// formatting pieces directly; the timer itself needs a running launch to observe, which is
/// exercised manually rather than through a mocked `LauncherCoordinator` stack.
final class PlaytimeReminderTests: XCTestCase {
    private let english = AppText(language: .english)
    private let vietnamese = AppText(language: .vietnamese)

    func testDefaultReminderIsThreeHours() {
        XCTAssertEqual(AppSettings.default.playtimeReminderHours, 3)
    }

    func testCountdownFormattingDropsTheHourFieldUnderAnHour() {
        XCTAssertEqual(LauncherViewModel.formattedCountdown(0), "0:00")
        XCTAssertEqual(LauncherViewModel.formattedCountdown(5), "0:05")
        XCTAssertEqual(LauncherViewModel.formattedCountdown(65), "1:05")
        XCTAssertEqual(LauncherViewModel.formattedCountdown(3_599), "59:59")
    }

    func testCountdownFormattingIncludesTheHourFieldAtAnHourAndAbove() {
        XCTAssertEqual(LauncherViewModel.formattedCountdown(3_600), "1:00:00")
        XCTAssertEqual(LauncherViewModel.formattedCountdown(3_661), "1:01:01")
        // The default 3-hour reminder, one second before it runs out.
        XCTAssertEqual(LauncherViewModel.formattedCountdown(3 * 3_600 - 1), "2:59:59")
    }

    func testHoursValueDropsTheDecimalForWholeNumbers() {
        XCTAssertEqual(english.playtimeReminderHoursValue(3), "3h")
        XCTAssertEqual(vietnamese.playtimeReminderHoursValue(3), "3 giờ")
    }

    func testHoursValueKeepsOneDecimalForFractionalHours() {
        XCTAssertEqual(english.playtimeReminderHoursValue(2.5), "2.5h")
        XCTAssertEqual(vietnamese.playtimeReminderHoursValue(2.5), "2.5 giờ")
    }
}
