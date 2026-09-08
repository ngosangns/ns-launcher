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

    // MARK: - Cutscene Browser

    var cutscenesTitle: String { localized(en: "Cutscenes", vi: "Cutscene") }
    var cutscenesSubtitle: String {
        localized(
            en: "Every cutscene video installed under StreamingAssets, for you to review yourself. NS Launcher cannot tell which quest or Traveler-gender variant a file belongs to, so nothing here is selected automatically — open a file to check it, then delete only what you're sure you don't need.",
            vi: "Toàn bộ video cutscene đã cài trong StreamingAssets, để bạn tự xem lại. NS Launcher không thể biết một file thuộc nhiệm vụ nào hay biến thể giới tính Traveler nào, nên không có gì được chọn sẵn — hãy mở file để kiểm tra rồi chỉ xóa những gì bạn chắc chắn không cần."
        )
    }
    var travelerGenderLabel: String { localized(en: "Traveler gender", vi: "Giới tính Traveler") }
    var travelerGenderHint: String {
        localized(
            en: "For your own reference while reviewing the list below — it does not filter or select anything.",
            vi: "Chỉ để bạn tham khảo khi xem danh sách bên dưới — không dùng để lọc hay chọn file nào cả."
        )
    }
    func travelerGenderName(_ gender: TravelerGender) -> String {
        switch gender {
        case .aether: return localized(en: "Aether (Boy)", vi: "Aether (Nam)")
        case .lumine: return localized(en: "Lumine (Girl)", vi: "Lumine (Nữ)")
        }
    }
    /// Short label for the Boy/Girl cutscene tab picker — `travelerGenderName` is too long for a
    /// segmented control.
    func travelerGenderShortName(_ gender: TravelerGender) -> String {
        switch gender {
        case .aether: return localized(en: "Boy", vi: "Nam")
        case .lumine: return localized(en: "Girl", vi: "Nữ")
        }
    }
    var cutsceneSearchPlaceholder: String { localized(en: "Filter by filename", vi: "Lọc theo tên file") }
    var cutsceneSortLabel: String { localized(en: "Sort", vi: "Sắp xếp") }
    var cutsceneSortSizeDescending: String { localized(en: "Size (largest first)", vi: "Dung lượng (lớn nhất trước)") }
    var cutsceneSortSizeAscending: String { localized(en: "Size (smallest first)", vi: "Dung lượng (nhỏ nhất trước)") }
    var cutsceneSortNameAscending: String { localized(en: "Name (A–Z)", vi: "Tên (A–Z)") }
    var cutsceneSortNameDescending: String { localized(en: "Name (Z–A)", vi: "Tên (Z–A)") }
    var refreshCutscenesTitle: String { localized(en: "Refresh", vi: "Làm mới") }
    var openCutsceneTitle: String { localized(en: "Open", vi: "Mở") }
    var revealCutsceneTitle: String { localized(en: "Reveal in Finder", vi: "Hiện trong Finder") }
    var deleteCutsceneTitle: String { localized(en: "Delete", vi: "Xóa") }
    var deleteCutsceneConfirmTitle: String { localized(en: "Delete this cutscene?", vi: "Xóa cutscene này?") }
    func deleteCutsceneConfirmMessage(_ filename: String) -> String {
        localized(
            en: "\"\(filename)\" will be moved to the Trash. You can recover it from there if you change your mind.",
            vi: "\"\(filename)\" sẽ được chuyển vào Thùng rác. Bạn có thể khôi phục lại nếu đổi ý."
        )
    }
    func cutsceneDeleted(_ filename: String) -> String {
        localized(en: "Moved \"\(filename)\" to the Trash.", vi: "Đã chuyển \"\(filename)\" vào Thùng rác.")
    }
    var noCutscenesFound: String { localized(en: "No cutscene files found. Refresh after the game is installed.", vi: "Chưa tìm thấy cutscene nào. Hãy làm mới sau khi game được cài đặt.") }
    var cancel: String { localized(en: "Cancel", vi: "Hủy") }
    var giCutscenesPathLabel: String { localized(en: "GI-cutscenes tool path", vi: "Đường dẫn công cụ GI-cutscenes") }
    var giCutscenesPathHint: String {
        localized(
            en: "A separate tool you install yourself (github.com/ToaHartor/GI-cutscenes). NS Launcher does not bundle it or any decryption logic — Open just runs the binary at this path to decrypt a cutscene, then opens the result.",
            vi: "Một công cụ riêng bạn tự cài (github.com/ToaHartor/GI-cutscenes). NS Launcher không đóng gói công cụ này hay logic giải mã nào — nút Mở chỉ chạy binary tại đường dẫn này để giải mã cutscene rồi mở kết quả."
        )
    }
    var decryptingCutscene: String { localized(en: "Decrypting cutscene...", vi: "Đang giải mã cutscene...") }
    var cutsceneDecryptFailed: String { localized(en: "Failed to decrypt cutscene", vi: "Giải mã cutscene thất bại") }
    func cutsceneDecryptOutputMissing(_ details: String) -> String {
        let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
        return localized(
            en: "GI-cutscenes ran but did not produce a playable file.\(trimmed.isEmpty ? "" : " Its output: \(trimmed)")",
            vi: "GI-cutscenes đã chạy nhưng không tạo ra file phát được.\(trimmed.isEmpty ? "" : " Output của công cụ: \(trimmed)")"
        )
    }
    func clearAllCutscenesTitle(_ genderShortName: String) -> String {
        localized(en: "Clear all \(genderShortName)", vi: "Xóa tất cả \(genderShortName)")
    }
    func clearAllCutscenesSummary(_ count: Int, _ size: String) -> String {
        localized(en: "\(count) files · \(size)", vi: "\(count) file · \(size)")
    }
    func noCutscenesForGender(_ genderShortName: String) -> String {
        localized(
            en: "No \(genderShortName) cutscene files found.",
            vi: "Không tìm thấy file cutscene \(genderShortName)."
        )
    }
    var clearAllCutscenesConfirmTitle: String { localized(en: "Clear all these cutscenes?", vi: "Xóa toàn bộ cutscene này?") }
    func clearAllCutscenesConfirmMessage(_ count: Int, _ size: String, _ genderShortName: String) -> String {
        localized(
            en: "\(count) \(genderShortName) files (\(size)) will be moved to the Trash. You can recover them from there if you change your mind.",
            vi: "\(count) file \(genderShortName) (\(size)) sẽ được chuyển vào Thùng rác. Bạn có thể khôi phục lại nếu đổi ý."
        )
    }

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
        case let decryptionError as CutsceneDecryptionError:
            switch decryptionError {
            case let .decryptedFileNotProduced(details):
                return cutsceneDecryptOutputMissing(details)
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

    // MARK: - Abyss

    var abyssTitle: String { localized(en: "Abyss", vi: "La Hoàn") }
    var abyssLoadingLabel: String { localized(en: "Loading Abyss data...", vi: "Đang tải dữ liệu La Hoàn...") }

    var abyssRosterSection: String { localized(en: "My roster", vi: "Roster của tôi") }
    var abyssResultsSection: String { localized(en: "Suggested teams", vi: "Đội hình gợi ý") }
    var abyssCharactersTab: String { localized(en: "Characters", vi: "Nhân vật") }
    var abyssWeaponsTab: String { localized(en: "Weapons", vi: "Vũ khí") }

    var abyssSearchCharacters: String { localized(en: "Search characters", vi: "Tìm nhân vật") }
    var abyssSearchWeapons: String { localized(en: "Search weapons", vi: "Tìm vũ khí") }
    var abyssClearSearch: String { localized(en: "Clear search", vi: "Xoá ô tìm kiếm") }
    var abyssClearFilters: String { localized(en: "Clear filters", vi: "Bỏ bộ lọc") }
    var abyssAllWeaponTypes: String { localized(en: "All types", vi: "Mọi loại") }
    var abyssOwnedOnly: String { localized(en: "Owned only", vi: "Chỉ đồ đang có") }

    func abyssShowingCount(shown: Int, total: Int) -> String {
        localized(en: "\(shown) of \(total)", vi: "\(shown) / \(total)")
    }

    var abyssNoMatches: String {
        localized(en: "Nothing matches that search", vi: "Không có gì khớp với tìm kiếm")
    }
    var abyssRecompute: String { localized(en: "Find teams", vi: "Tìm đội hình") }
    var abyssRecomputing: String { localized(en: "Searching...", vi: "Đang tìm...") }
    var abyssCancel: String { localized(en: "Stop", vi: "Dừng") }
    var abyssImport: String { localized(en: "Import", vi: "Nhập") }
    var abyssExport: String { localized(en: "Export", vi: "Xuất") }
    func abyssSortLabel(_ sort: AbyssViewModel.RosterSort) -> String {
        switch sort {
        case .name: return localized(en: "Name", vi: "Tên")
        case .rarity: return localized(en: "Stars", vi: "Số sao")
        case .element: return localized(en: "Element", vi: "Nguyên tố")
        case .release: return localized(en: "Release date", vi: "Ngày ra mắt")
        case .attack: return localized(en: "Base ATK", vi: "ATK gốc")
        case .owned: return localized(en: "Owned", vi: "Đang sở hữu")
        }
    }

    /// Spells out which end of the sort comes first, because "descending" means
    /// something different for each key — Z first, 5★ first, newest first.
    func abyssSortDirection(_ sort: AbyssViewModel.RosterSort, descending: Bool) -> String {
        switch sort {
        case .name:
            return descending ? "Z → A" : "A → Z"
        case .rarity:
            return descending ? "5★ → 1★" : "1★ → 5★"
        case .element:
            return descending ? localized(en: "Z → A", vi: "Z → A") : localized(en: "A → Z", vi: "A → Z")
        case .release:
            return descending ? localized(en: "newest first", vi: "mới nhất trước")
                              : localized(en: "oldest first", vi: "cũ nhất trước")
        case .attack:
            return descending ? localized(en: "highest first", vi: "cao nhất trước")
                              : localized(en: "lowest first", vi: "thấp nhất trước")
        case .owned:
            return descending ? localized(en: "owned first", vi: "đang có trước")
                              : localized(en: "missing first", vi: "chưa có trước")
        }
    }

    var abyssFlipSortDirection: String {
        localized(en: "Reverse the order", vi: "Đảo chiều sắp xếp")
    }
    var abyssClearCharacters: String { localized(en: "Clear characters", vi: "Xoá hết nhân vật") }
    var abyssClearWeapons: String { localized(en: "Clear weapons", vi: "Xoá hết vũ khí") }

    func abyssOwnedCount(characters: Int, weapons: Int) -> String {
        localized(en: "\(characters) characters · \(weapons) weapons",
                  vi: "\(characters) nhân vật · \(weapons) vũ khí")
    }

    var abyssEmptyRosterTitle: String {
        localized(en: "Nothing in your roster yet", vi: "Roster còn trống")
    }

    var abyssEmptyRosterHint: String {
        localized(
            en: "Mark the characters and weapons you own, or import a roster file. "
                + "You can also search teams across every character to compare in theory.",
            vi: "Đánh dấu nhân vật và vũ khí bạn đang có, hoặc nhập từ file roster. "
                + "Bạn cũng có thể tìm đội hình trên toàn bộ nhân vật để so sánh lý thuyết.")
    }

    var abyssUseFullRoster: String {
        localized(en: "Compare across all characters", vi: "So sánh toàn bộ nhân vật")
    }

    var abyssNoResultsYet: String {
        localized(en: "No teams computed yet", vi: "Chưa tính đội hình nào")
    }

    var abyssNoResultsHint: String {
        localized(en: "Press \"Find teams\" to search.", vi: "Bấm \"Tìm đội hình\" để bắt đầu.")
    }

    /// Constellations are stored but do not change the score yet. Saying so
    /// where the stepper is avoids everyone assuming otherwise.
    var abyssConstellationNotScored: String {
        localized(en: "C-level is saved but does not affect scoring yet",
                  vi: "Cung mệnh được lưu nhưng chưa tính vào điểm")
    }

    func abyssFloorTitle(_ floor: Int) -> String {
        localized(en: "Floor \(floor)", vi: "Tầng \(floor)")
    }

    func abyssMonsterLevel(_ level: Int) -> String {
        localized(en: "Enemies ~Lv\(level)", vi: "Quái ~cấp \(level)")
    }

    var abyssOnFieldLabel: String { localized(en: "on-field", vi: "đứng sân") }
    var abyssDamageShare: String { localized(en: "of team damage", vi: "sát thương đội") }

    func abyssCyclePeriod(start: String, end: String) -> String {
        localized(en: "Rotation \(start) → \(end)", vi: "Chu kỳ \(start) → \(end)")
    }

    var abyssCycleExpired: String { localized(en: "Rotation expired", vi: "Chu kỳ đã hết hạn") }

    /// Bundled Abyss data goes stale every two weeks, so a released build will
    /// eventually recommend teams for a rotation that is no longer live.
    var abyssCycleExpiredHint: String {
        localized(
            en: "This build ships the rotation that was live when it was made. Drop an "
                + "updated cycle file into ~/Library/Application Support/NSLauncher/abyss-cycles/ "
                + "to refresh it without waiting for a new release.",
            vi: "Bản này mang dữ liệu của chu kỳ lúc build. Đặt file chu kỳ mới vào "
                + "~/Library/Application Support/NSLauncher/abyss-cycles/ để cập nhật mà "
                + "không cần chờ bản phát hành mới.")
    }

    func abyssRosterUnknownIDs(_ ids: [String]) -> String {
        localized(en: "Not in the data, ignored: \(ids.joined(separator: ", "))",
                  vi: "Không có trong dữ liệu, đã bỏ qua: \(ids.joined(separator: ", "))")
    }

    func abyssRoleLabel(_ role: AbyssRole) -> String {
        switch role {
        case .mainDPS: return localized(en: "Main DPS", vi: "DPS chính")
        case .subDPS: return localized(en: "Sub DPS", vi: "DPS phụ")
        case .support: return localized(en: "Support", vi: "Hỗ trợ")
        case .shield: return localized(en: "Shield", vi: "Khiên")
        case .healer: return localized(en: "Healer", vi: "Hồi máu")
        }
    }

    func abyssElementLabel(_ element: GenshinElement) -> String {
        switch element {
        case .anemo: return localized(en: "Anemo", vi: "Phong")
        case .geo: return localized(en: "Geo", vi: "Nham")
        case .electro: return localized(en: "Electro", vi: "Lôi")
        case .dendro: return localized(en: "Dendro", vi: "Thảo")
        case .hydro: return localized(en: "Hydro", vi: "Thủy")
        case .pyro: return localized(en: "Pyro", vi: "Hỏa")
        case .cryo: return localized(en: "Cryo", vi: "Băng")
        }
    }

    func abyssWeaponTypeLabel(_ type: WeaponType) -> String {
        switch type {
        case .sword: return localized(en: "Sword", vi: "Kiếm")
        case .claymore: return localized(en: "Claymore", vi: "Đại kiếm")
        case .polearm: return localized(en: "Polearm", vi: "Thương")
        case .bow: return localized(en: "Bow", vi: "Cung")
        case .catalyst: return localized(en: "Catalyst", vi: "Pháp khí")
        }
    }

    func abyssTeamNote(_ note: AbyssTeamNote) -> String {
        switch note {
        case .noSustainPenalty:
            return localized(en: "No healer or shield — scored down for survivability",
                             vi: "Không có hồi máu/khiên — bị trừ điểm sinh tồn")
        case .breaksShield(let elements):
            let names = elements.map { abyssElementLabel($0) }.joined(separator: "/")
            return localized(en: "Can break \(names) shields", vi: "Phá được khiên \(names)")
        case .exploitsWeakness(let elements):
            let names = elements.map { abyssElementLabel($0) }.joined(separator: "/")
            return localized(en: "Exploits \(names) weakness", vi: "Khai thác điểm yếu \(names)")
        case .moonsignAscendantGleam:
            return localized(en: "Moonsign: Ascendant Gleam", vi: "Nguyệt Triệu: Ascendant Gleam")
        case .hexereiSecretRite:
            return localized(en: "Hexerei: Secret Rite", vi: "Hexerei: Secret Rite")
        case .resonance(let name):
            return localized(en: "Resonance: \(name)", vi: "Cộng hưởng: \(name)")
        case .weaponContested(let weapons):
            let names = weapons.joined(separator: ", ")
            return localized(
                en: "Roster is short a weapon: \(names) is assigned to more than one character",
                vi: "Roster thiếu vũ khí: \(names) đang xếp cho nhiều nhân vật")
        case .mixedStatSources:
            return localized(
                en: "Mixes imported and assumed builds — the score is not a like-for-like comparison",
                vi: "Trộn nhân vật có chỉ số thật với nhân vật build giả định — điểm không so ngang được")
        }
    }

    // MARK: - Abyss showcase import

    var abyssImportFromUID: String { localized(en: "Import from UID", vi: "Nhập từ UID") }
    var abyssUIDPlaceholder: String { localized(en: "UID (9-10 digits)", vi: "UID (9-10 chữ số)") }
    var abyssFetching: String { localized(en: "Fetching...", vi: "Đang tải...") }
    var abyssClearShowcase: String { localized(en: "Forget import", vi: "Xoá dữ liệu đã nhập") }
    var abyssMeasuredBadge: String { localized(en: "your build", vi: "chỉ số thật") }
    var abyssModelledBadge: String { localized(en: "assumed build", vi: "build giả định") }

    /// The UID is enough — its first digit is the region — so the tab never
    /// asks which server the account is on.
    var abyssUIDHint: String {
        localized(
            en: "Via Enka.Network — no login, no server to pick. Up to 8 characters; needs "
                + "\"Show Character Details\" on in-game.",
            vi: "Qua Enka.Network — không cần đăng nhập, không cần chọn server. Tối đa 8 nhân vật; "
                + "cần bật \"Hiển thị chi tiết nhân vật\" trong game.")
    }

    func abyssShowcaseSummary(nickname: String, count: Int) -> String {
        localized(en: "\(nickname) — \(count) characters imported with their real stats",
                  vi: "\(nickname) — đã nhập \(count) nhân vật kèm chỉ số thật")
    }

    func abyssShowcaseFetchedAt(_ date: String) -> String {
        localized(en: "Last fetched \(date)", vi: "Lấy lúc \(date)")
    }

    func abyssShowcaseUnmapped(_ ids: [String]) -> String {
        localized(en: "Newer than the bundled data, skipped: \(ids.joined(separator: ", "))",
                  vi: "Mới hơn dữ liệu đi kèm nên bỏ qua: \(ids.joined(separator: ", "))")
    }

    func abyssShowcaseTooSoon(_ seconds: Int) -> String {
        localized(en: "Enka has no newer data yet — try again in \(seconds)s",
                  vi: "Enka chưa có dữ liệu mới — thử lại sau \(seconds)s")
    }

    func abyssEnkaError(_ error: AbyssEnkaError) -> String {
        switch error {
        case .malformedUID:
            return localized(en: "That is not a valid UID.", vi: "UID không hợp lệ.")
        case .notFound:
            return localized(en: "No player with that UID.", vi: "Không tìm thấy người chơi với UID này.")
        case .showcaseEmpty:
            return localized(
                en: "That showcase is empty or hidden. In game, open your profile, edit the "
                    + "Character Showcase, and turn on \"Show Character Details\".",
                vi: "Showcase trống hoặc đang ẩn. Trong game, mở hồ sơ, sửa Showcase nhân vật và bật "
                    + "\"Hiển thị chi tiết nhân vật\".")
        case .rateLimited:
            return localized(en: "Enka.Network is rate-limiting requests. Try again shortly.",
                             vi: "Enka.Network đang giới hạn truy cập. Thử lại sau ít phút.")
        case .gameMaintenance:
            return localized(en: "The game server is in maintenance.", vi: "Máy chủ game đang bảo trì.")
        case .serviceUnavailable:
            return localized(en: "Enka.Network is unavailable right now.",
                             vi: "Enka.Network hiện không truy cập được.")
        case .badResponse(let status):
            return localized(en: "Enka.Network answered with HTTP \(status).",
                             vi: "Enka.Network trả về HTTP \(status).")
        case .transport(let message):
            return localized(en: "Could not reach Enka.Network: \(message)",
                             vi: "Không kết nối được Enka.Network: \(message)")
        }
    }

    /// Imported characters carry their own artifacts, so the advice for them is
    /// a comparison rather than a suggestion.
    func abyssArtifactUpgrade(from current: String, gain: Double) -> String {
        let percent = String(format: "%.1f", gain * 100)
        return localized(en: "You have \(current) — switching is worth +\(percent)%",
                         vi: "Bạn đang đeo \(current) — đổi sang bộ này hơn +\(percent)%")
    }

    func abyssArtifactAlreadyBest(_ name: String) -> String {
        localized(en: "You already have \(name) — nothing better for this floor",
                  vi: "Bạn đã đeo \(name) — không có bộ nào tốt hơn cho tầng này")
    }

    var abyssShowcaseNotice: String {
        localized(
            en: "Imported characters are scored on the artifacts you actually rolled; everyone "
                + "else is scored on a standard build. Teams that mix the two are flagged.",
            vi: "Nhân vật đã nhập được chấm bằng thánh di vật thật của bạn; những người còn lại "
                + "dùng build chuẩn giả định. Đội trộn cả hai loại sẽ được đánh dấu.")
    }

    // MARK: - Abyss artifact advice

    var abyssArtifactsLabel: String { localized(en: "Artifacts", vi: "Thánh di vật") }
    var abyssSandsSlot: String { localized(en: "Sands", vi: "Đồng hồ") }
    var abyssGobletSlot: String { localized(en: "Goblet", vi: "Ly") }
    var abyssCircletSlot: String { localized(en: "Circlet", vi: "Mũ") }
    var abyssSubstatsLabel: String { localized(en: "Substats", vi: "Chỉ số phụ") }

    /// The set was chosen for this floor and these team mates, which is the
    /// whole point of showing it per team rather than once per character.
    func abyssArtifactGain(_ gain: Double) -> String {
        let percent = String(format: "%.1f", gain * 100)
        return localized(en: "+\(percent)% over the generic pick",
                         vi: "+\(percent)% so với bộ chọn chung")
    }

    func abyssArtifactAlternative(_ names: String, gap: Double) -> String {
        let percent = String(format: "%.1f", gap * 100)
        return localized(en: "Or \(names) (−\(percent)%)", vi: "Hoặc \(names) (−\(percent)%)")
    }

    func abyssTeamArtifactGain(_ gain: Double) -> String {
        let percent = String(format: "%.1f", gain * 100)
        return localized(en: "artifacts +\(percent)%", vi: "thánh di vật +\(percent)%")
    }

    var abyssArtifactAdviceNotice: String {
        localized(
            en: "Artifacts are picked per team and per floor, so the same character can want a "
                + "different set depending on who they are with and what the enemies resist. Most "
                + "of the gain shown is supports being given sets that buff the party instead of "
                + "sets that raise their own damage.",
            vi: "Thánh di vật được chọn riêng cho từng đội và từng tầng, nên cùng một nhân vật có "
                + "thể cần bộ khác nhau tuỳ đồng đội và tuỳ kháng của quái. Phần lớn mức tăng hiển "
                + "thị đến từ việc nhân vật hỗ trợ được đổi sang bộ buff cả đội thay vì bộ tăng sát "
                + "thương của riêng họ.")
    }

    func abyssMainStatName(_ stat: AbyssMainStat) -> String {
        switch stat {
        case .atkPercent: return "ATK%"
        case .hpPercent: return "HP%"
        case .defPercent: return "DEF%"
        case .elementalMastery: return localized(en: "EM", vi: "Tinh Thông")
        case .energyRecharge: return localized(en: "ER", vi: "Hồi Năng")
        case .critRate: return localized(en: "CRIT Rate", vi: "Tỉ Lệ Bạo")
        case .critDMG: return localized(en: "CRIT DMG", vi: "ST Bạo")
        case .healingBonus: return localized(en: "Healing", vi: "Trị Liệu")
        case .elementalDMG(let element):
            return localized(en: "\(element.rawValue) DMG", vi: "ST \(abyssElementLabel(element))")
        }
    }

    /// Substat keys as they are written in `tuning.json`.
    func abyssSubstatName(_ key: String) -> String {
        switch key {
        case "crit_rate": return localized(en: "CRIT Rate", vi: "Tỉ Lệ Bạo")
        case "crit_dmg": return localized(en: "CRIT DMG", vi: "ST Bạo")
        case "atk_pct": return "ATK%"
        case "hp_pct": return "HP%"
        case "def_pct": return "DEF%"
        case "em": return localized(en: "EM", vi: "Tinh Thông")
        case "er": return localized(en: "ER", vi: "Hồi Năng")
        case "flat_atk": return localized(en: "flat ATK", vi: "ATK cố định")
        case "flat_hp": return localized(en: "flat HP", vi: "HP cố định")
        case "flat_def": return localized(en: "flat DEF", vi: "DEF cố định")
        default: return key
        }
    }

    /// The scores are a ranking heuristic, not a DPS simulation. This belongs
    /// in the UI, not only in the repo docs — a number with no caveat reads as
    /// a measurement.
    var abyssMethodologyNotice: String {
        localized(
            en: "Ranking estimate, not a damage simulation: no rotation/energy/constellations; "
                + "artifacts assume a standard build.",
            vi: "Điểm chỉ để xếp hạng, không mô phỏng sát thương: chưa tính rotation/năng lượng/"
                + "cung mệnh; thánh di vật dùng build chuẩn giả định.")
    }

    var abyssDataNotice: String {
        localized(
            en: "Genshin data © HoYoverse, via Yatta/Ambr + Genshin Wiki (CC BY-SA 3.0). Reference only.",
            vi: "Dữ liệu Genshin © HoYoverse, qua Yatta/Ambr + Genshin Wiki (CC BY-SA 3.0). "
                + "Chỉ để tham khảo.")
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
