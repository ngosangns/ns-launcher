// AppText.swift
//
// Centralized English/Vietnamese copy for every user-facing string.
//
// `AppText` is a lightweight value type keyed by the active `AppLanguage`, so the
// view model and views never hard-code user-facing text. Service-layer errors are
// localized here and selected by `LauncherViewModel.localizedErrorMessage(for:)`.
// Labels for the opt-in launch toggles carry their ToS/ban warning inline so the
// risk is always visible in Settings.

import Foundation

/// Centralized localized copy for the launcher UI and error messages.
struct AppText {
    /// Active language used for every localized string.
    let language: AppLanguage

    // MARK: - Static Labels

    var homeTitle: String { localized(en: "Home", vi: "Trang chủ") }
    var settingsTitle: String { localized(en: "Settings", vi: "Cài đặt") }
    var storyTitle: String { localized(en: "Story", vi: "Cốt truyện") }
    var close: String { localized(en: "Close", vi: "Đóng") }
    var open: String { localized(en: "Open", vi: "Mở") }
    var browse: String { localized(en: "Browse", vi: "Chọn") }
    var games: String { localized(en: "Games", vi: "Trò chơi") }
    var noGameSelected: String { localized(en: "No game selected", vi: "Chưa chọn game") }
    var ok: String { localized(en: "OK", vi: "Đóng") }
    var installDirectory: String { localized(en: "Install Directory", vi: "Thư mục cài đặt") }
    var executable: String { localized(en: "Executable", vi: "File chạy") }
    var format: String { localized(en: "Format", vi: "Định dạng") }
    var currentItemLabel: String { localized(en: "Current item", vi: "Mục đang xử lý") }
    var currentItemsLabel: String { localized(en: "Current items", vi: "Các mục đang xử lý") }
    var currentPartProgressLabel: String { localized(en: "Current part progress", vi: "Tiến độ part hiện tại") }
    var totalProgressLabel: String { localized(en: "Overall progress", vi: "Tiến độ toàn bộ") }
    var speedLabel: String { localized(en: "Speed", vi: "Tốc độ") }
    var etaLabel: String { localized(en: "ETA", vi: "Thời gian còn lại") }
    var etaWarmupMessage: String { localized(en: "Stabilizing time estimate...", vi: "Đang ổn định ước tính thời gian...") }
    var progressLabel: String { localized(en: "Progress", vi: "Tiến độ") }
    var pauseTitle: String { localized(en: "Pause", vi: "Tạm dừng") }
    var playTitle: String { localized(en: "Play", vi: "Chơi") }
    var resumeTitle: String { localized(en: "Resume", vi: "Tiếp tục") }
    var stopTitle: String { localized(en: "Stop", vi: "Dừng") }
    var wineRunLogTitle: String { localized(en: "Wine log (filtered)", vi: "Log Wine (đã lọc)") }
    var updateRunLogTitle: String { localized(en: "Update log", vi: "Log cập nhật") }
    var diagnosticsTitle: String { localized(en: "Diagnostics", vi: "Chẩn đoán") }
    var noDiagnosticsYet: String {
        localized(
            en: "No diagnostics yet. Logs appear here while the game updates or launches.",
            vi: "Chưa có chẩn đoán. Log sẽ hiện ở đây khi game cập nhật hoặc khởi chạy."
        )
    }
    var preparingStage: String { localized(en: "Preparing", vi: "Chuẩn bị") }
    var downloadingStage: String { localized(en: "Downloading", vi: "Đang tải") }
    var verifyingStage: String { localized(en: "Verifying", vi: "Đang xác thực") }
    var validatingStage: String { localized(en: "Validating", vi: "Đang kiểm tra") }
    var completedStage: String { localized(en: "Completed", vi: "Hoàn tất") }
    var waitingForProgress: String { localized(en: "Working...", vi: "Đang xử lý...") }
    var operationPaused: String { localized(en: "Operation paused", vi: "Đã tạm dừng thao tác") }
    var operationResumed: String { localized(en: "Operation resumed", vi: "Đã tiếp tục thao tác") }
    var operationStopped: String { localized(en: "Operation stopped", vi: "Đã dừng thao tác") }
    var error: String { localized(en: "Error", vi: "Lỗi") }
    var ready: String { localized(en: "Ready", vi: "Sẵn sàng") }
    var installFailed: String { localized(en: "Install failed", vi: "Cài đặt thất bại") }
    var updateCompleted: String { localized(en: "Update completed", vi: "Đã cập nhật xong") }
    var updateFailed: String { localized(en: "Update failed", vi: "Cập nhật thất bại") }
    var launchFailed: String { localized(en: "Launch failed", vi: "Mở game thất bại") }
    var gameExitedNormally: String { localized(en: "Game exited normally", vi: "Game đã thoát bình thường") }
    var selectedGame: String { localized(en: "Selected Game", vi: "Game đang chọn") }
    /// Localized display name for a voice-over language, used to label leftover voice packs found
    /// on disk in the storage inventory (the launcher itself no longer downloads any voice pack).
    func voiceLanguageName(_ language: VoiceLanguage) -> String {
        switch language {
        case .english: return localized(en: "English", vi: "Tiếng Anh")
        case .chinese: return localized(en: "Chinese", vi: "Tiếng Trung")
        case .japanese: return localized(en: "Japanese", vi: "Tiếng Nhật")
        case .korean: return localized(en: "Korean", vi: "Tiếng Hàn")
        }
    }
    var displayModeLabel: String { localized(en: "Display mode", vi: "Chế độ hiển thị") }
    var windowedMode: String { localized(en: "Windowed", vi: "Cửa sổ") }
    var fullscreenMode: String { localized(en: "Fullscreen", vi: "Toàn màn hình") }
    var fullscreenHint: String {
        localized(
            en: "Fullscreen runs the game in exclusive fullscreen at your display's own resolution, so the picture is never stretched to fit the screen.",
            vi: "Toàn màn hình chạy game ở chế độ fullscreen độc quyền theo đúng độ phân giải màn hình, nên hình không bị kéo dãn cho vừa màn hình."
        )
    }
    var playtimeReminderLabel: String { localized(en: "Playtime reminder", vi: "Nhắc nhở giờ chơi") }
    var playtimeReminderDescription: String {
        localized(
            en: "Shows a countdown on the Home screen after Play and flags it once it runs out. Advisory only — it never stops the game.",
            vi: "Hiện đồng hồ đếm ngược ở Trang chủ sau khi bấm Chơi và báo khi hết giờ. Chỉ mang tính nhắc nhở — không tự tắt game."
        )
    }
    /// Formats the Stepper's current value, e.g. "3h" / "3 giờ" or "2.5h" / "2.5 giờ".
    func playtimeReminderHoursValue(_ hours: Double) -> String {
        let formatted = hours.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", hours)
            : String(format: "%.1f", hours)
        return localized(en: "\(formatted)h", vi: "\(formatted) giờ")
    }
    var playtimeReminderDue: String { localized(en: "Reminder time's up", vi: "Đã hết giờ nhắc nhở") }
    var displayOptionsLabel: String { localized(en: "Display & input", vi: "Hiển thị & nhập liệu") }
    var name: String { localized(en: "Name", vi: "Tên") }
    var installRoot: String { localized(en: "Install root", vi: "Thư mục cài đặt") }
    var executablePath: String { localized(en: "Executable path", vi: "Đường dẫn file chạy") }

    // MARK: - Storage Management

    var storageSectionTitle: String { localized(en: "Storage", vi: "Dung lượng") }
    var installedContentLabel: String { localized(en: "Installed content", vi: "Nội dung đã cài") }
    var audioStorageLabel: String { localized(en: "Game audio", vi: "Âm thanh game") }
    var localStorageLabel: String { localized(en: "On disk", vi: "Trên máy") }
    var availableStorageLabel: String { localized(en: "In current build", vi: "Trong build hiện tại") }
    var storageFilesLabel: String { localized(en: "Files", vi: "Số file") }
    var noStorageContentFound: String { localized(en: "No matching local content found. Refresh after the game is installed.", vi: "Chưa có nội dung local phù hợp. Hãy làm mới sau khi game được cài đặt.") }
    var questResourceAnalysisLabel: String { localized(en: "Quest resource analysis", vi: "Phân tích dữ liệu nhiệm vụ") }
    var questResourceMappingUnavailable: String { localized(en: "No verified quest-to-file mapping is available for desktop Genshin. NS Launcher cannot identify completed quests or files that are safe to remove.", vi: "Chưa có mapping quest-to-file đã được xác minh cho Genshin desktop. NS Launcher không thể xác định nhiệm vụ đã hoàn thành hoặc file nào an toàn để xóa.") }
    var runtimeContainersLabel: String { localized(en: "Runtime containers (read-only)", vi: "Runtime container (chỉ đọc)") }
    func questAssetContainerLabel(_ kind: QuestAssetContainerKind) -> String {
        switch kind {
        case .encryptedBlock: return localized(en: "Encrypted blocks (.blk)", vi: "Khối mã hóa (.blk)")
        case .cabBundle: return localized(en: "CAB bundles (.cab)", vi: "Gói CAB (.cab)")
        case .assetBundle: return localized(en: "Asset bundles (.bundle)", vi: "Gói asset (.bundle)")
        case .assetIndex: return localized(en: "Asset index", vi: "Chỉ mục asset")
        }
    }
    var voicePacksLabel: String { localized(en: "Voice packs", vi: "Gói lồng tiếng") }
    var refreshVoicePacksTitle: String { localized(en: "Refresh", vi: "Làm mới") }
    var removeVoicePackTitle: String { localized(en: "Remove", vi: "Gỡ") }
    var voicePackSizeLabel: String { localized(en: "Size", vi: "Dung lượng") }
    var voicePackFilesLabel: String { localized(en: "Files", vi: "Số file") }
    var noVoicePacksFound: String { localized(en: "No voice packs found. Run Refresh after the game is installed.", vi: "Chưa có gói lồng tiếng. Hãy bấm Làm mới sau khi game đã cài đặt.") }
    var checkingStorageInventory: String { localized(en: "Checking game storage...", vi: "Đang kiểm tra dung lượng game...") }
    var storageInventoryFailed: String { localized(en: "Failed to check game storage", vi: "Kiểm tra dung lượng game thất bại") }
    var removingVoicePack: String { localized(en: "Removing voice pack...", vi: "Đang gỡ gói lồng tiếng...") }
    func voicePackRemoved(_ freedBytes: String) -> String {
        localized(en: "Removed voice pack. Freed \(freedBytes).", vi: "Đã gỡ gói lồng tiếng. Giải phóng \(freedBytes).")
    }
    var voicePackRemoveFailed: String { localized(en: "Failed to remove voice pack", vi: "Gỡ gói lồng tiếng thất bại") }

    // MARK: - Cache Management

    var cacheManagementTitle: String { localized(en: "Cache", vi: "Cache") }
    var cacheManagementSubtitle: String { localized(en: "Removable caches that can be safely cleared to reclaim disk space.", vi: "Các cache có thể xóa an toàn để giải phóng dung lượng.") }
    var removableCacheLabel: String { localized(en: "Removable caches", vi: "Cache có thể xóa") }
    var clearCacheTitle: String { localized(en: "Clear", vi: "Xóa") }
    var clearingCache: String { localized(en: "Clearing cache...", vi: "Đang xóa cache...") }
    func cacheCleared(_ freedBytes: String) -> String {
        localized(en: "Cache cleared. Freed \(freedBytes).", vi: "Đã xóa cache. Giải phóng \(freedBytes).")
    }
    var cacheClearFailed: String { localized(en: "Failed to clear cache", vi: "Xóa cache thất bại") }
    var noRemovableCache: String { localized(en: "No removable cache found. Refresh after the game is installed.", vi: "Chưa có cache nào có thể xóa. Hãy làm mới sau khi game được cài đặt.") }
    var totalRemovableCacheLabel: String { localized(en: "Total", vi: "Tổng cộng") }

    // MARK: - CrossOver Setup

    var installCrossOverButtonTitle: String { localized(en: "Install CrossOver via Homebrew", vi: "Cài CrossOver qua Homebrew") }
    var installingCrossOver: String { localized(en: "Installing CrossOver via Homebrew...", vi: "Đang cài CrossOver qua Homebrew...") }
    var crossOverInstalled: String { localized(en: "CrossOver installed.", vi: "Đã cài CrossOver.") }
    var crossOverInstallFailedStatus: String { localized(en: "Installing CrossOver failed", vi: "Cài CrossOver thất bại") }

    /// Error text when Homebrew itself is not installed.
    ///
    /// The launcher never installs Homebrew itself — its official installer runs arbitrary code
    /// via `curl | bash` and asks for the user's password, which needs the user to review and run
    /// it directly rather than a GUI app triggering it silently.
    func homebrewNotFound() -> String {
        localized(
            en: "Homebrew is not installed. Install it yourself from https://brew.sh, then try again.",
            vi: "Chưa cài Homebrew. Hãy tự cài từ https://brew.sh rồi thử lại."
        )
    }

    /// Error text when `brew install --cask crossover` ran but left no usable CrossOver behind.
    func crossOverInstallFailed(_ details: String) -> String {
        localized(
            en: "Installing CrossOver through Homebrew failed: \(details)",
            vi: "Cài CrossOver qua Homebrew thất bại: \(details)"
        )
    }
    func cacheKindLabel(_ kind: RemovableCache.Kind) -> String {
        switch kind {
        case .cutsceneVideos: return localized(en: "Cutscene videos", vi: "Video cutscene")
        case .gameWebCache: return localized(en: "Web cache", vi: "Cache web")
        case .gameSDKCache: return localized(en: "SDK cache", vi: "Cache SDK")
        case .gameWorldAssetCache: return localized(en: "World asset cache", vi: "Cache tài nguyên thế giới")
        case .winePrefixTemp: return localized(en: "Wine temporary files", vi: "File tạm Wine")
        case .launcherDownloadArchives: return localized(en: "Download archives", vi: "Archive tải về")
        }
    }
    func cacheKindDescription(_ kind: RemovableCache.Kind) -> String {
        switch kind {
        case .cutsceneVideos:
            return localized(
                en: "Stale copy the game downloaded itself while cutscenes were missing from the install. Safe to delete once an update has installed them.",
                vi: "Bản trùng do game tự tải khi cutscene còn thiếu trong bản cài. Xóa an toàn sau khi đã cập nhật để cài lại cutscene."
            )
        case .gameWebCache:
            return localized(
                en: "Browser cache generated by the game.",
                vi: "Cache trình duyệt do game tạo."
            )
        case .gameSDKCache:
            return localized(
                en: "SDK cache generated by the game.",
                vi: "Cache SDK do game tạo."
            )
        case .gameWorldAssetCache:
            return localized(
                en: "Open-world scenery (Persistent/AssetBundles) the client streams in and re-downloads incrementally as you explore, together with the version counters that track it. If old terrain/props/lighting, missing models, or wrong-looking textures keep showing up, this cache and its version counters have fallen out of sync with each other — clearing both together resets it to a consistent state, forcing a fresh incremental re-download (typically well under its full size shown here) the next time you visit each area.",
                vi: "Cảnh vật thế giới mở (Persistent/AssetBundles) mà client tự tải và cập nhật dần khi bạn khám phá, cùng với các bộ đếm version theo dõi nó. Nếu địa hình/vật thể/ánh sáng cũ, model biến mất, hoặc texture sai màu vẫn hiện ra, cache này và bộ đếm version của nó đã lệch nhau — xoá cả hai cùng lúc sẽ đưa về trạng thái nhất quán, buộc tải lại dần (thường ít hơn nhiều so với dung lượng hiển thị ở đây) mỗi khi bạn ghé lại từng khu vực."
            )
        case .winePrefixTemp:
            return localized(
                en: "Temporary files inside the Wine prefix.",
                vi: "File tạm trong Wine prefix."
            )
        case .launcherDownloadArchives:
            return localized(
                en: "Compressed archives left after extraction (DXVK/Wine).",
                vi: "Archive nén còn lại sau khi giải nén (DXVK/Wine)."
            )
        }
    }

    // MARK: - Action Labels

    var updateGameTitle: String { localized(en: "Update Game", vi: "Cập nhật game") }
    var launchTitle: String { localized(en: "Launch via Wine", vi: "Chạy qua Wine") }

    /// Formats the multiline update plan summary.
    func updatePlanSummary(currentVersion: String, latestVersion: String, download: String, files: Int, skipped: Int) -> String {
        localized(
            en: "Current: \(currentVersion)\nLatest: \(latestVersion)\nDownload: \(download)\nChanged files: \(files)\nUnchanged files: \(skipped)",
            vi: "Hiện tại: \(currentVersion)\nMới nhất: \(latestVersion)\nDung lượng tải: \(download)\nFile cần cập nhật: \(files)\nFile giữ nguyên: \(skipped)"
        )
    }

    // MARK: - Status Messages

    /// Status text shown during Sophon installs.
    func installing(_ gameName: String) -> String {
        localized(en: "Installing \(gameName)...", vi: "Đang cài đặt \(gameName)...")
    }

    /// Status text shown while checking update metadata.
    func checkingForUpdates(_ gameName: String) -> String {
        localized(en: "Checking updates for \(gameName)...", vi: "Đang kiểm tra cập nhật cho \(gameName)...")
    }

    /// Status text shown while applying Sophon updates.
    func updating(_ gameName: String) -> String {
        localized(en: "Updating \(gameName)...", vi: "Đang cập nhật \(gameName)...")
    }

    /// Status text shown while launching through Wine.
    func launching(_ gameName: String) -> String {
        localized(en: "Launching \(gameName)...", vi: "Đang mở \(gameName)...")
    }

    /// Stage text for preparation events.
    func preparing(_ path: String) -> String {
        localized(en: "Preparing \(path)", vi: "Đang chuẩn bị \(path)")
    }

    /// Stage text for verification events.
    func verifying(_ path: String) -> String {
        localized(en: "Verifying \(path)", vi: "Đang xác thực \(path)")
    }

    /// Stage text for install validation events.
    func validating(_ path: String) -> String {
        localized(en: "Validating \(path)", vi: "Đang kiểm tra \(path)")
    }

    /// Completion text with installed version.
    func installedVersion(_ version: String) -> String {
        localized(en: "Installed version \(version)", vi: "Đã cài bản \(version)")
    }

    /// Completion text with updated version.
    func updatedVersion(_ version: String) -> String {
        localized(en: "Updated to version \(version)", vi: "Đã cập nhật lên bản \(version)")
    }

    /// Status text when no changed files are found.
    func gameUpToDate(_ version: String) -> String {
        localized(en: "Game is already up to date at version \(version)", vi: "Game đã ở bản mới nhất \(version)")
    }

    /// Progress text for Sophon asset downloads.
    func downloaded(_ path: String, received: String, total: String) -> String {
        localized(en: "Downloaded \(path) (\(received) / \(total))", vi: "Đã tải \(path) (\(received) / \(total))")
    }

    /// Progress text for Sophon asset downloads.
    func downloadingSophonAsset(_ path: String, received: String, total: String) -> String {
        localized(en: "Downloading Sophon asset \(path) (\(received) / \(total))", vi: "Đang tải asset Sophon \(path) (\(received) / \(total))")
    }

    /// Generic byte progress value.
    func progressValue(received: String, total: String) -> String {
        localized(en: "\(received) / \(total)", vi: "\(received) / \(total)")
    }

    /// KB progress value used by detailed status tiles.
    func progressValueKB(receivedKB: String, totalKB: String) -> String {
        localized(en: "\(receivedKB) KB / \(totalKB) KB", vi: "\(receivedKB) KB / \(totalKB) KB")
    }

    // MARK: - Error Messages

    var missingVersionLabel: String {
        localized(en: "missing", vi: "thiếu")
    }

    /// Error text for missing process executables.
    func executableNotFound(_ path: String) -> String {
        localized(en: "Executable not found at \(path)", vi: "Không tìm thấy file chạy tại \(path)")
    }

    /// Error text for non-zero external process exits.
    func processFailed(code: Int32, details: String) -> String {
        localized(
            en: "Process failed with code \(code): \(details)",
            vi: "Tiến trình thất bại với mã \(code): \(details)"
        )
    }

    /// Error text for Wine binaries blocked by macOS Gatekeeper quarantine.
    func wineBinaryQuarantined(_ path: String) -> String {
        localized(
            en: "macOS is blocking Wine because it is quarantined or not verified. Open Terminal and run: xattr -dr com.apple.quarantine \"\(path)\". Then launch again.",
            vi: "macOS đang chặn Wine vì file còn quarantine hoặc chưa được xác minh. Mở Terminal và chạy: xattr -dr com.apple.quarantine \"\(path)\". Sau đó chạy lại."
        )
    }

    /// Error text when no installed Wine build carries DXMT.
    ///
    /// Only CrossOver is named as a remedy: the popular `game-porting-toolkit` Homebrew cask
    /// (`gcenx/wine` tap) ships the open-source DXMT project relabeled, and Apple's own Game
    /// Porting Toolkit is gated behind an Apple Developer sign-in with no public download to point
    /// at. Use the Settings screen's install button for CrossOver instead of typing a command here.
    func dxmtUnavailable(_ path: String) -> String {
        localized(
            en: "No Wine build with DXMT was found. Checked: \(path). DXMT ships only inside CrossOver (CodeWeavers) — NSLauncher cannot download it on its own. Install CrossOver from Settings, then try again.",
            vi: "Chưa tìm thấy bản Wine nào có DXMT. Đã kiểm tra: \(path). DXMT chỉ đi kèm CrossOver (CodeWeavers) — NSLauncher không thể tự tải DXMT. Hãy cài CrossOver từ màn hình Cài đặt rồi thử lại."
        )
    }

    /// Converts a domain error into the localized, actionable text shown to the user.
    ///
    /// Lives here rather than in the view model because every branch resolves to a string on this
    /// type: keeping the mapping next to the strings means adding an error case and forgetting its
    /// text is one edit away from being noticed, not two files apart.
    func message(for error: Error) -> String {
        switch error {
        case let preflightError as LaunchPreflightError:
            switch preflightError {
            case let .missingExecutable(path):
                return preflightMissingExecutable(path)
            case .missingInstallMetadata:
                return preflightMissingMetadata
            case let .invalidInstallMetadata(detail):
                return preflightInvalidMetadata(detail)
            case let .updateRequiredBeforeLaunch(reason):
                return preflightUpdateRequired(reason)
            case let .gameAlreadyRunning(pids):
                return preflightGameAlreadyRunning(pids)
            }
        case let wineError as WineServiceError:
            switch wineError {
            case let .binaryQuarantined(path):
                return wineBinaryQuarantined(path)
            case let .dxmtUnavailable(path):
                return dxmtUnavailable(path)
            case let .wineRootNotFound(path):
                return wineRootNotFound(path)
            case let .unsupportedKernelDriver(driver):
                return unsupportedKernelDriver(driver)
            }
        case let crossOverError as CrossOverInstallError:
            switch crossOverError {
            case .homebrewNotFound:
                return homebrewNotFound()
            case let .installFailed(details):
                return crossOverInstallFailed(details)
            }
        case let processError as ProcessRunnerError:
            switch processError {
            case let .executableNotFound(path):
                return executableNotFound(path)
            case let .nonZeroExit(result):
                let details = result.stderr.isEmpty ? result.stdout : result.stderr
                return processFailed(code: result.exitCode, details: details)
            }
        case let sophonError as SophonInstallerError:
            switch sophonError {
            case .zstdUnavailable:
                return sophonZstdUnavailable
            default:
                return sophonUpdateFailed(sophonError.localizedDescription)
            }
        case is CancellationError:
            return operationStopped
        default:
            return error.localizedDescription
        }
    }

    /// Error text when a Wine binary has no sibling `lib/wine` directory, so its install root
    /// cannot be located.
    func wineRootNotFound(_ path: String) -> String {
        localized(
            en: "Unable to locate the Wine installation for \(path).",
            vi: "Không xác định được thư mục cài đặt Wine cho \(path)."
        )
    }

    /// Error text when Wine cannot load a Windows kernel driver required by the game.
    func unsupportedKernelDriver(_ driver: String) -> String {
        localized(
            en: "Wine cannot load the Windows kernel driver \(driver). This game requires an anti-cheat or protection driver that Wine on macOS cannot run. Update the game through NSLauncher first to ensure files are valid. If the error persists, Wine/macOS does not support this protection driver — use Windows or the official cloud gaming option instead.",
            vi: "Wine không load được driver kernel Windows \(driver). Game này yêu cầu driver anti-cheat/protection mà Wine trên macOS không chạy được. Hãy cập nhật game qua NSLauncher trước để đảm bảo file hợp lệ. Nếu lỗi vẫn xảy ra, Wine/macOS không hỗ trợ driver protection này — hãy dùng Windows hoặc tùy chọn cloud gaming chính thức."
        )
    }

    // MARK: - Preflight Errors

    /// Preflight error: game executable not found.
    func preflightMissingExecutable(_ path: String) -> String {
        localized(
            en: "Game executable not found at \(path). Run Update Game to restore missing files.",
            vi: "Không tìm thấy file chạy game tại \(path). Hãy chạy Cập nhật game để khôi phục file thiếu."
        )
    }

    /// Preflight error: install metadata missing.
    var preflightMissingMetadata: String {
        localized(
            en: "Install metadata is missing. Run Update Game before launching to create the required metadata file.",
            vi: "Thiếu metadata cài đặt. Hãy chạy Cập nhật game trước khi mở game để tạo file metadata cần thiết."
        )
    }

    /// Preflight error: install metadata is invalid or mismatched.
    func preflightInvalidMetadata(_ detail: String) -> String {
        localized(
            en: "Install metadata is invalid: \(detail). Run Update Game to repair.",
            vi: "Metadata cài đặt không hợp lệ: \(detail). Hãy chạy Cập nhật game để sửa."
        )
    }

    /// Preflight error: the game is already running in this Wine prefix.
    func preflightGameAlreadyRunning(_ pids: [Int32]) -> String {
        let list = pids.map(String.init).joined(separator: ", ")
        return localized(
            en: "The game is already running (PID \(list)). A Wine prefix holds one session at a time; starting a second one makes both hang. Close the running game, or quit those processes, then launch again.",
            vi: "Game đang chạy rồi (PID \(list)). Một prefix Wine chỉ chứa được một phiên tại một thời điểm; mở phiên thứ hai sẽ làm cả hai treo. Hãy đóng game đang chạy, hoặc tắt các tiến trình đó, rồi mở lại."
        )
    }

    /// Preflight error: update required before launch.
    func preflightUpdateRequired(_ reason: String) -> String {
        localized(
            en: "Update Game is required before launch: \(reason)",
            vi: "Cần Cập nhật game trước khi mở: \(reason)"
        )
    }

    /// Error text when the temporary Sophon zstd backend is unavailable.
    var sophonZstdUnavailable: String {
        localized(
            en: "Sophon update needs the zstd command-line tool to decompress HoYoPlay manifests and chunks. Install zstd with Homebrew, then try Update Game again.",
            vi: "Cập nhật Sophon cần công cụ dòng lệnh zstd để giải nén manifest và chunk của HoYoPlay. Hãy cài zstd bằng Homebrew, rồi bấm Cập nhật game lại."
        )
    }

    /// Generic Sophon update failure text.
    func sophonUpdateFailed(_ details: String) -> String {
        localized(
            en: "Sophon update failed: \(details)",
            vi: "Cập nhật Sophon thất bại: \(details)"
        )
    }

    /// Error text for manifest checksum mismatches.
    func checksumMismatch(_ path: String) -> String {
        localized(en: "Checksum mismatch for \(path)", vi: "Checksum không khớp cho \(path)")
    }

    // MARK: - Story Tab

    var storyLoadingLabel: String { localized(en: "Loading story content...", vi: "Đang tải nội dung cốt truyện...") }
    var storySearchPlaceholder: String {
        localized(en: "Search characters, chapters, quests...", vi: "Tìm nhân vật, chương, nhiệm vụ...")
    }
    var storyChaptersLabel: String { localized(en: "Story", vi: "Cốt truyện") }
    var storyEntitiesLabel: String { localized(en: "Characters & Events", vi: "Nhân vật & sự kiện") }
    var storyQuestsLabel: String { localized(en: "Quest Reference", vi: "Nhiệm vụ") }
    var storyAppearsInLabel: String { localized(en: "Appears in", vi: "Xuất hiện trong") }
    var storyRelatedQuestsLabel: String { localized(en: "Related quests", vi: "Liên quan trong nhiệm vụ") }
    var storyNoSummaryLabel: String { localized(en: "No summary yet.", vi: "Chưa có tóm tắt.") }
    var storyAlsoKnownAsLabel: String { localized(en: "Also known as", vi: "Còn được gọi là") }
    var storyEmptySearchResult: String { localized(en: "No results.", vi: "Không tìm thấy kết quả.") }
    var storySelectAPrompt: String {
        localized(en: "Pick a chapter, character, or quest on the left.", vi: "Chọn một chương, nhân vật, hoặc nhiệm vụ ở bên trái.")
    }

    func storyEntityKindLabel(_ kind: StoryEntity.Kind) -> String {
        switch kind {
        case .character: return localized(en: "Character", vi: "Nhân vật")
        case .archon: return localized(en: "Archon", vi: "Archon")
        case .faction: return localized(en: "Faction", vi: "Phe phái")
        case .nation: return localized(en: "Nation", vi: "Quốc gia")
        case .event: return localized(en: "Event", vi: "Sự kiện")
        case .concept: return localized(en: "Concept", vi: "Khái niệm")
        }
    }

    /// Shown once at the top of the Story tab — required alongside the fan
    /// content itself, not just in repo documentation, since this ships to
    /// end users.
    var storyCopyrightNotice: String {
        localized(
            en: "Genshin Impact and its characters, locations, and original "
                + "story are property of HoYoverse. This tab is a personal, "
                + "non-commercial retelling for reference — not a translation "
                + "or reproduction of in-game text.",
            vi: "Genshin Impact cùng nhân vật, địa danh và cốt truyện gốc "
                + "thuộc bản quyền HoYoverse. Tab này chỉ là bản diễn giải cá "
                + "nhân, phi lợi nhuận để tham khảo — không phải bản dịch hay "
                + "tái bản nội dung trong game."
        )
    }

    /// Returns the string for the currently selected language.
    private func localized(en: String, vi: String) -> String {
        switch language {
        case .english:
            return en
        case .vietnamese:
            return vi
        }
    }
}
