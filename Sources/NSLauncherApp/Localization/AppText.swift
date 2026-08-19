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

    var appTitle: String { localized(en: "NS Launcher", vi: "NS Launcher") }
    var settingsTitle: String { localized(en: "Settings", vi: "Cài đặt") }
    var close: String { localized(en: "Close", vi: "Đóng") }
    var openSettings: String { localized(en: "Open Settings", vi: "Mở cài đặt") }
    var open: String { localized(en: "Open", vi: "Mở") }
    var browse: String { localized(en: "Browse", vi: "Chọn") }
    var games: String { localized(en: "Games", vi: "Trò chơi") }
    var noGameSelected: String { localized(en: "No game selected", vi: "Chưa chọn game") }
    var ok: String { localized(en: "OK", vi: "Đóng") }
    var installDirectory: String { localized(en: "Install Directory", vi: "Thư mục cài đặt") }
    var executable: String { localized(en: "Executable", vi: "File chạy") }
    var winePrefix: String { localized(en: "Wine Prefix", vi: "Tiền tố Wine") }
    var format: String { localized(en: "Format", vi: "Định dạng") }
    var installPlanner: String { localized(en: "Install Planner", vi: "Kế hoạch cài đặt") }
    var status: String { localized(en: "Status", vi: "Trạng thái") }
    var currentStepLabel: String { localized(en: "Current step", vi: "Bước hiện tại") }
    var currentItemLabel: String { localized(en: "Current item", vi: "Mục đang xử lý") }
    var currentItemsLabel: String { localized(en: "Current items", vi: "Các mục đang xử lý") }
    var currentPartLabel: String { localized(en: "Current part", vi: "Part hiện tại") }
    var resumePointLabel: String { localized(en: "Resume point", vi: "Điểm tiếp tục") }
    var currentPartProgressLabel: String { localized(en: "Current part progress", vi: "Tiến độ part hiện tại") }
    var totalProgressLabel: String { localized(en: "Overall progress", vi: "Tiến độ toàn bộ") }
    var transferDetailsLabel: String { localized(en: "Transfer details", vi: "Chi tiết truyền tải") }
    var speedLabel: String { localized(en: "Speed", vi: "Tốc độ") }
    var etaLabel: String { localized(en: "ETA", vi: "Thời gian còn lại") }
    var etaWarmupMessage: String { localized(en: "Stabilizing time estimate...", vi: "Đang ổn định ước tính thời gian...") }
    var totalSizeKBLabel: String { localized(en: "Overall size (KB)", vi: "Dung lượng tổng (KB)") }
    var partSizeKBLabel: String { localized(en: "Current part size (KB)", vi: "Dung lượng part hiện tại (KB)") }
    var progressLabel: String { localized(en: "Progress", vi: "Tiến độ") }
    var pauseTitle: String { localized(en: "Pause", vi: "Tạm dừng") }
    var playTitle: String { localized(en: "Play", vi: "Chơi") }
    var resumeTitle: String { localized(en: "Resume", vi: "Tiếp tục") }
    var stopTitle: String { localized(en: "Stop", vi: "Dừng") }
    var wineRunLogTitle: String { localized(en: "Wine run log (filtered)", vi: "Log chạy Wine (đã lọc)") }
    var updateRunLogTitle: String { localized(en: "Update log", vi: "Log cập nhật") }
    var showDiagnostics: String { localized(en: "Show diagnostics", vi: "Hiện chẩn đoán") }
    var hideDiagnostics: String { localized(en: "Hide diagnostics", vi: "Ẩn chẩn đoán") }
    var launchOptionsTitle: String { localized(en: "Launch options", vi: "Tùy chọn khởi chạy") }
    var preparingStage: String { localized(en: "Preparing", vi: "Chuẩn bị") }
    var downloadingStage: String { localized(en: "Downloading", vi: "Đang tải") }
    var verifyingStage: String { localized(en: "Verifying", vi: "Đang xác thực") }
    var validatingStage: String { localized(en: "Validating", vi: "Đang kiểm tra") }
    var completedStage: String { localized(en: "Completed", vi: "Hoàn tất") }
    var waitingForProgress: String { localized(en: "Working...", vi: "Đang xử lý...") }
    var waitingForFirstDownloadBytes: String { localized(en: "Waiting for the first download data from the server...", vi: "Đang chờ dữ liệu tải đầu tiên từ máy chủ...") }
    var operationPaused: String { localized(en: "Operation paused", vi: "Đã tạm dừng thao tác") }
    var operationResumed: String { localized(en: "Operation resumed", vi: "Đã tiếp tục thao tác") }
    var operationStopped: String { localized(en: "Operation stopped", vi: "Đã dừng thao tác") }
    var error: String { localized(en: "Error", vi: "Lỗi") }
    var ready: String { localized(en: "Ready", vi: "Sẵn sàng") }
    var installPlanReady: String { localized(en: "Install plan ready", vi: "Đã sẵn sàng kế hoạch cài đặt") }
    var failedToPlanInstall: String { localized(en: "Failed to plan install", vi: "Không lập được kế hoạch cài đặt") }
    var versionLabel: String { localized(en: "Version", vi: "Phiên bản") }
    var downloadLabel: String { localized(en: "Download", vi: "Tải về") }
    var peakTempLabel: String { localized(en: "Peak temp", vi: "Bộ nhớ tạm tối đa") }
    var stepsLabel: String { localized(en: "Steps", vi: "Số bước") }
    var cutscenesLabel: String { localized(en: "Cutscenes skipped", vi: "Cutscene bỏ qua") }
    var installCompleted: String { localized(en: "Install completed", vi: "Đã cài đặt xong") }
    var installFailed: String { localized(en: "Install failed", vi: "Cài đặt thất bại") }
    var updateCompleted: String { localized(en: "Update completed", vi: "Đã cập nhật xong") }
    var updateFailed: String { localized(en: "Update failed", vi: "Cập nhật thất bại") }
    var launchFailed: String { localized(en: "Launch failed", vi: "Mở game thất bại") }
    var gameExitedNormally: String { localized(en: "Game exited normally", vi: "Game đã thoát bình thường") }
    var selectedGame: String { localized(en: "Selected Game", vi: "Game đang chọn") }
    var toolPaths: String { localized(en: "Tool Paths", vi: "Đường dẫn công cụ") }
    var languageLabel: String { localized(en: "Language", vi: "Ngôn ngữ") }
    var english: String { localized(en: "English", vi: "Tiếng Anh") }
    var vietnamese: String { localized(en: "Vietnamese", vi: "Tiếng Việt") }
    var voiceLanguageLabel: String { localized(en: "Voice Pack", vi: "Gói lồng tiếng") }
    var voiceLanguageDescription: String { localized(en: "Voice-over language downloaded with game resources. Keep one pack to minimize install and update size.", vi: "Ngôn ngữ lồng tiếng tải cùng tài nguyên game. Chỉ giữ một gói để giảm dung lượng cài đặt và cập nhật.") }

    /// Localized display name for a voice-over language.
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
    var cloudCompatibilityLabel: String { localized(en: "Cloud compatibility mode", vi: "Chế độ tương thích cloud") }
    var cloudCompatibilityDescription: String {
        localized(
            en: "Launch the Windows client in cloud-gaming mode and place a protection-driver stub so it can start under Wine. Unsupported by HoYoverse and may risk your account.",
            vi: "Chạy client Windows ở chế độ cloud-gaming và đặt driver protection giả để game khởi động được dưới Wine. HoYoverse không hỗ trợ và có thể khiến tài khoản gặp rủi ro."
        )
    }
    var acPatchLabel: String { localized(en: "AC patch (hide crash/Vulkan files)", vi: "AC patch (ẩn file crash/Vulkan)") }
    var acPatchDescription: String {
        localized(
            en: "Temporarily move the crash reporter and Vulkan fallback files out of the way during launch, then restore them. Mirrors YAAGL's current Genshin behavior.",
            vi: "Tạm di chuyển file crash reporter và Vulkan fallback ra chỗ khác trong lúc chạy game, rồi khôi phục sau. Theo đúng hành vi Genshin hiện tại của YAAGL."
        )
    }
    var blockNetLabel: String { localized(en: "Launch network block", vi: "Chặn mạng lúc mở game") }
    var blockNetDescription: String {
        localized(
            en: "Temporarily block the anti-cheat and telemetry hosts in the Wine prefix hosts file for the whole launch, then restore. No administrator password required.",
            vi: "Tạm chặn host anti-cheat và telemetry trong file hosts của Wine prefix suốt phiên game, rồi khôi phục. Không cần mật khẩu quản trị."
        )
    }
    var timeoutFixLabel: String { localized(en: "Network timeout fix", vi: "Sửa lỗi timeout mạng") }
    var timeoutFixDescription: String {
        localized(
            en: "Set WINE_ENABLE_TIMEOUT_FIX so YAAGL-patched Wine keeps sockets from dropping the game back to the title screen mid-session. Ignored by Wine builds without the patch.",
            vi: "Bật WINE_ENABLE_TIMEOUT_FIX để Wine bản YAAGL không làm rớt kết nối khiến game quay về màn hình chờ giữa lúc chơi. Bản Wine không có patch sẽ bỏ qua."
        )
    }
    var steamPatchLabel: String { localized(en: "Steam parent patch", vi: "Steam parent patch") }
    var steamPatchDescription: String {
        localized(
            en: "Launch through a real steam.exe + lsteamclient.dll parent so the anti-cheat skips loading its kernel driver. The stubs are downloaded once and cached.",
            vi: "Chạy game qua tiến trình cha steam.exe + lsteamclient.dll thật để anti-cheat bỏ qua việc nạp kernel driver. File stub chỉ tải một lần và được lưu cache."
        )
    }
    var retinaLabel: String { localized(en: "Retina scaling", vi: "Hiển thị Retina") }
    var retinaDescription: String {
        localized(
            en: "Enable HiDPI Retina rendering through the Wine Mac Driver registry.",
            vi: "Bật render Retina độ phân giải cao qua registry Mac Driver của Wine."
        )
    }
    var leftCommandLabel: String { localized(en: "Left Command as Ctrl", vi: "Command trái thành Ctrl") }
    var leftCommandDescription: String {
        localized(
            en: "Treat the left Command key as Ctrl for games that assume Windows keyboard bindings.",
            vi: "Dùng phím Command trái như phím Ctrl cho game dùng phím tắt kiểu Windows."
        )
    }
    var metalHUDLabel: String { localized(en: "Metal HUD overlay", vi: "Hiển thị Metal HUD") }
    var metalHUDDescription: String {
        localized(
            en: "Show the Metal performance HUD during launch (MTL_HUD_ENABLED).",
            vi: "Hiện bảng thông số hiệu năng Metal khi chạy game (MTL_HUD_ENABLED)."
        )
    }
    var resolutionCustomLabel: String { localized(en: "Custom resolution", vi: "Độ phân giải tùy chỉnh") }
    var resolutionCustomDescription: String {
        localized(
            en: "Write a windowed resolution into the game's registry before launch.",
            vi: "Ghi độ phân giải cửa sổ vào registry của game trước khi chạy."
        )
    }
    var resolutionWidthLabel: String { localized(en: "Width", vi: "Chiều rộng") }
    var resolutionHeightLabel: String { localized(en: "Height", vi: "Chiều cao") }
    var hdrLabel: String { localized(en: "Enable HDR", vi: "Bật HDR") }
    var hdrDescription: String {
        localized(
            en: "Set the game's HDR registry flag before launch.",
            vi: "Bật cờ HDR trong registry của game trước khi chạy."
        )
    }
    var proxyEnabledLabel: String { localized(en: "Proxy", vi: "Proxy") }
    var proxyEnabledDescription: String {
        localized(
            en: "Route the game through an HTTP/HTTPS proxy.",
            vi: "Định tuyến game qua proxy HTTP/HTTPS."
        )
    }
    var proxyHostLabel: String { localized(en: "Proxy host", vi: "Địa chỉ proxy") }
    var displayOptionsLabel: String { localized(en: "Display & input", vi: "Hiển thị & nhập liệu") }
    var maxFrameRateLabel: String { localized(en: "Frame rate cap", vi: "Giới hạn FPS") }
    var maxFrameRateDescription: String {
        localized(
            en: "Optional Metal frame-pacing cap for DXMT. Must be a factor of your display refresh rate (e.g. 60 on a 60/120 Hz display). Set 0 to disable.",
            vi: "Giới hạn FPS qua Metal frame pacing cho DXMT (tùy chọn). Phải là ước số của tần số quét màn hình (vd: 60 trên màn 60/120 Hz). Đặt 0 để tắt."
        )
    }
    var name: String { localized(en: "Name", vi: "Tên") }
    var installRoot: String { localized(en: "Install root", vi: "Thư mục cài đặt") }
    var executablePath: String { localized(en: "Executable path", vi: "Đường dẫn file chạy") }
    var wineBinary: String { localized(en: "Wine binary", vi: "File Wine") }
    var officialSophonSource: String { localized(en: "Official Sophon chunk source", vi: "Nguồn chunk Sophon chính thức") }
    var selectedSource: String { localized(en: "Selected source", vi: "Nguồn đang chọn") }

    // MARK: - Storage Management

    var storageSectionTitle: String { localized(en: "Storage", vi: "Dung lượng") }
    var installedContentLabel: String { localized(en: "Installed content", vi: "Nội dung đã cài") }
    var cutsceneStorageLabel: String { localized(en: "Cutscenes", vi: "Cutscene") }
    var audioStorageLabel: String { localized(en: "Game audio", vi: "Âm thanh game") }
    var localStorageLabel: String { localized(en: "On disk", vi: "Trên máy") }
    var availableStorageLabel: String { localized(en: "In current build", vi: "Trong build hiện tại") }
    var storageFilesLabel: String { localized(en: "Files", vi: "Số file") }
    var cutscenesExcludedNote: String { localized(en: "Excluded from NS Launcher updates", vi: "Bị loại khỏi cập nhật của NS Launcher") }
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
    var selectedVoicePackBadge: String { localized(en: "Selected", vi: "Đang chọn") }
    var removeVoicePackTitle: String { localized(en: "Remove", vi: "Gỡ") }
    var voicePackSizeLabel: String { localized(en: "Size", vi: "Dung lượng") }
    var voicePackFilesLabel: String { localized(en: "Files", vi: "Số file") }
    var noVoicePacksFound: String { localized(en: "No voice packs found. Run Refresh after the game is installed.", vi: "Chưa có gói lồng tiếng. Hãy bấm Làm mới sau khi game đã cài đặt.") }
    var checkingVoicePacks: String { localized(en: "Checking voice packs...", vi: "Đang kiểm tra gói lồng tiếng...") }
    var checkingStorageInventory: String { localized(en: "Checking game storage...", vi: "Đang kiểm tra dung lượng game...") }
    var storageInventoryFailed: String { localized(en: "Failed to check game storage", vi: "Kiểm tra dung lượng game thất bại") }
    var removingVoicePack: String { localized(en: "Removing voice pack...", vi: "Đang gỡ gói lồng tiếng...") }
    func voicePackRemoved(_ freedBytes: String) -> String {
        localized(en: "Removed voice pack. Freed \(freedBytes).", vi: "Đã gỡ gói lồng tiếng. Giải phóng \(freedBytes).")
    }
    var voicePackRemoveFailed: String { localized(en: "Failed to remove voice pack", vi: "Gỡ gói lồng tiếng thất bại") }
    var voicePackAlreadySelected: String { localized(en: "This voice pack is selected and cannot be removed.", vi: "Gói lồng tiếng này đang được chọn nên không thể gỡ.") }

    // MARK: - Action Labels

    var planInstallTitle: String { localized(en: "Plan Install", vi: "Lập kế hoạch") }
    var planInstallDescription: String { localized(en: "Estimate download size, temporary space, and planned steps.", vi: "Ước tính dung lượng tải, bộ nhớ tạm và các bước cài đặt.") }
    var downloadInstallTitle: String { localized(en: "Download & Install", vi: "Tải và cài đặt") }
    var downloadInstallDescription: String { localized(en: "Download and reconstruct game assets from official Sophon chunks.", vi: "Tải và dựng asset game từ chunk Sophon chính thức.") }
    var updateGameTitle: String { localized(en: "Update Game", vi: "Cập nhật game") }
    var updateGameDescription: String { localized(en: "Check the latest Sophon build and download only changed assets.", vi: "Kiểm tra build Sophon mới nhất và chỉ tải asset thay đổi.") }
    var launchTitle: String { localized(en: "Launch via Wine", vi: "Chạy qua Wine") }
    var launchDescription: String { localized(en: "Start the configured Windows executable with the current Wine path.", vi: "Chạy file Windows đã cấu hình bằng đường dẫn Wine hiện tại.") }

    /// Formats the multiline install plan summary.
    func installPlanSummary(version: String, download: String, peakTemp: String, steps: Int, cutscenes: String) -> String {
        """
        \(versionLabel): \(version)
        \(downloadLabel): \(download)
        \(peakTempLabel): \(peakTemp)
        \(stepsLabel): \(steps)
        \(cutscenesLabel): \(cutscenes)
        """
    }

    /// Formats the multiline update plan summary.
    func updatePlanSummary(currentVersion: String, latestVersion: String, download: String, files: Int, skipped: Int, cutscenes: String) -> String {
        localized(
            en: "Current: \(currentVersion)\nLatest: \(latestVersion)\nDownload: \(download)\nChanged files: \(files)\nUnchanged files: \(skipped)\nCutscene files skipped: \(cutscenes)",
            vi: "Hiện tại: \(currentVersion)\nMới nhất: \(latestVersion)\nDung lượng tải: \(download)\nFile cần cập nhật: \(files)\nFile giữ nguyên: \(skipped)\nFile cutscene bị bỏ qua: \(cutscenes)"
        )
    }

    // MARK: - Status Messages

    /// Status text shown while the planner is running.
    func planningInstall(for gameName: String) -> String {
        localized(en: "Planning install for \(gameName)...", vi: "Đang lập kế hoạch cài đặt cho \(gameName)...")
    }

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

    /// Pass-through hook reserved for future localized speed formatting.
    func speedValue(_ value: String) -> String {
        localized(en: value, vi: value)
    }

    /// Error text for a missing configured executable.
    func missingExpectedExecutable(_ path: String) -> String {
        localized(en: "Missing expected executable at \(path)", vi: "Không tìm thấy file chạy mong đợi tại \(path)")
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

    /// Error text for automatic DXVK setup failures.
    func dxvkBootstrapFailed(_ details: String) -> String {
        localized(
            en: "DXVK setup failed before launching Wine: \(details)",
            vi: "Thiết lập DXVK trước khi chạy Wine thất bại: \(details)"
        )
    }

    /// Error text for automatic DXMT setup failures.
    func dxmtBootstrapFailed(_ details: String) -> String {
        localized(
            en: "DXMT setup failed before launching Wine: \(details)",
            vi: "Thiết lập DXMT trước khi chạy Wine thất bại: \(details)"
        )
    }

    /// Error text when the selected Wine build cannot host DXMT.
    func dxmtUnsupportedWine(_ path: String) -> String {
        localized(
            en: "No DXMT-compatible Wine binary was found. Checked: \(path). DXMT needs winemac to export the macdrv_functions Metal interface (or macdrv_view_create_metal_view), which only DXMT-patched Wine builds (Wine 9.9+/11.x, e.g. yaagl/anime-game-wine or 3Shain/wine) provide — stock WineHQ and Game Porting Toolkit do not. Install a DXMT-patched Wine, then try again.",
            vi: "Chưa tìm thấy Wine binary tương thích DXMT. Đã kiểm tra: \(path). DXMT cần winemac export interface Metal macdrv_functions (hoặc macdrv_view_create_metal_view), chỉ có ở Wine đã patch DXMT (Wine 9.9+/11.x, ví dụ yaagl/anime-game-wine hoặc 3Shain/wine) — WineHQ thường và Game Porting Toolkit đều không có. Hãy cài Wine patch DXMT rồi thử lại."
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

    var serverInvalidResponse: String {
        localized(en: "The server returned an invalid response.", vi: "Máy chủ trả về phản hồi không hợp lệ.")
    }

    /// Error text for manifest checksum mismatches.
    func checksumMismatch(_ path: String) -> String {
        localized(en: "Checksum mismatch for \(path)", vi: "Checksum không khớp cho \(path)")
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
