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
    var close: String { localized(en: "Close", vi: "Đóng") }
    var open: String { localized(en: "Open", vi: "Mở") }
    var browse: String { localized(en: "Browse", vi: "Chọn") }
    var games: String { localized(en: "Games", vi: "Trò chơi") }
    var noGameSelected: String { localized(en: "No game selected", vi: "Chưa chọn game") }
    var ok: String { localized(en: "OK", vi: "Đóng") }
    var installDirectory: String { localized(en: "Install Directory", vi: "Thư mục cài đặt") }
    var executable: String { localized(en: "Executable", vi: "File chạy") }
    var format: String { localized(en: "Format", vi: "Định dạng") }
    var status: String { localized(en: "Status", vi: "Trạng thái") }
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
    var renderBackendLabel: String { localized(en: "Render backend", vi: "Backend render") }
    var renderBackendD3DMetal: String { localized(en: "D3DMetal", vi: "D3DMetal") }
    var renderBackendDXMT: String { localized(en: "DXMT (experimental)", vi: "DXMT (thử nghiệm)") }
    var renderBackendDXVK: String { localized(en: "DXVK (experimental)", vi: "DXVK (thử nghiệm)") }
    var renderBackendDescription: String {
        localized(
            en: "D3DMetal is the recommended default. DXMT is a different Metal translator worth trying when a specific effect renders wrong. DXVK translates through Vulkan and MoltenVK, so it may be slower, and its shader translation is the least reliable of the three on Apple GPUs.",
            vi: "D3DMetal là lựa chọn mặc định khuyến nghị. DXMT là một translator Metal khác, đáng thử khi một hiệu ứng cụ thể render sai. DXVK dịch qua Vulkan và MoltenVK nên có thể chậm hơn, và phần dịch shader của nó là kém tin cậy nhất trong ba lựa chọn trên GPU Apple."
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
            en: "Render at a resolution you choose instead of the one the launcher picks. Left off, Fullscreen runs at your display's own resolution and Windowed at 1280x720; either way the size is rewritten before every launch, so a resolution changed in-game cannot carry over.",
            vi: "Render ở độ phân giải bạn chọn thay vì độ phân giải launcher tự chọn. Nếu tắt, chế độ Fullscreen chạy đúng độ phân giải màn hình còn Windowed chạy 1280x720; dù chọn cách nào thì kích thước cũng được ghi lại trước mỗi lần chạy, nên độ phân giải đổi trong game không còn dính sang lần sau."
        )
    }
    func resolutionAspectMismatchWarning(displayWidth: Int, displayHeight: Int) -> String {
        localized(
            en: "This is a different shape from your display (\(displayWidth)×\(displayHeight)). In Fullscreen the screen is filled by stretching it, which distorts models. Match your display's aspect ratio, or turn this off to render at the display's own resolution.",
            vi: "Tỉ lệ này khác với màn hình của bạn (\(displayWidth)×\(displayHeight)). Ở chế độ Fullscreen, hình sẽ bị kéo dãn cho đầy màn hình nên model bị méo. Hãy chọn đúng tỉ lệ màn hình, hoặc tắt mục này để game render đúng độ phân giải của màn hình."
        )
    }
    var resolutionWidthLabel: String { localized(en: "Width", vi: "Chiều rộng") }
    var resolutionHeightLabel: String { localized(en: "Height", vi: "Chiều cao") }
    var hdrLabel: String { localized(en: "Enable HDR", vi: "Bật HDR") }
    var hdrDescription: String {
        localized(
            en: "Set the game's HDR registry flag before launch. Leave it off unless you want HDR: the flag is rewritten on every launch, so turning it off here also clears an HDR mode enabled inside the game — which on Wine renders with washed-out, wrong-looking colour.",
            vi: "Bật cờ HDR trong registry của game trước khi chạy. Nên để tắt nếu bạn không cần HDR: cờ này được ghi lại mỗi lần chạy, nên tắt ở đây cũng tắt luôn chế độ HDR đã bật trong game — trên Wine chế độ đó làm màu bị bợt và sai."
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
    var metalFXUpscalingLabel: String { localized(en: "MetalFX upscaling (experimental)", vi: "MetalFX upscaling (thử nghiệm)") }
    var metalFXUpscalingDescription: String {
        localized(
            en: "D3DMetal renders at the game's own resolution and lets Metal upscale to the window size. Only has an effect if you also lower the resolution below your display's native size (use Custom windowed resolution above). Lowering the render resolution this way also reduces stutter when the game has to compile new shaders — rotating the camera, loading a new scene, or switching characters — since there is less GPU work competing with that compile.",
            vi: "D3DMetal sẽ render ở độ phân giải game đang đặt rồi để Metal upscale lên kích thước cửa sổ. Chỉ có tác dụng nếu bạn cũng hạ độ phân giải thấp hơn màn hình (dùng Custom windowed resolution ở trên). Hạ độ phân giải render theo cách này cũng giảm giật khi game phải biên dịch shader mới — lúc xoay camera, load cảnh mới, hoặc đổi nhân vật — vì GPU có ít việc hơn để tranh chấp với lúc biên dịch đó."
        )
    }
    var metalFXNeedsCustomResolutionWarning: String {
        localized(
            en: "No effect yet: turn on Custom windowed resolution and set it below your display's native size, otherwise the game still renders at full resolution.",
            vi: "Chưa có tác dụng: bật Custom windowed resolution và đặt thấp hơn độ phân giải gốc của màn hình, nếu không game vẫn render ở độ phân giải đầy đủ."
        )
    }
    var metalFXUnsupportedBackendWarning: String {
        localized(
            en: "No effect: MetalFX upscaling is D3DMetal-only. Switch the render backend to D3DMetal above to use it, or turn this off with the current backend.",
            vi: "Không có tác dụng: MetalFX upscaling chỉ dùng được với D3DMetal. Đổi backend render sang D3DMetal ở trên để dùng, hoặc tắt mục này với backend hiện tại."
        )
    }
    var d3dMetalAsyncCommitLabel: String { localized(en: "Async command commit (experimental)", vi: "Async command commit (thử nghiệm)") }
    var d3dMetalAsyncCommitDescription: String {
        localized(
            en: "D3DM_ENABLE_ASYNC_COMMIT: lets D3DMetal overlap encoding the next frame with submitting the previous one instead of stalling the CPU on each submit. On by default; turn off if you suspect it is causing stutter or instability.",
            vi: "D3DM_ENABLE_ASYNC_COMMIT: cho phép D3DMetal chồng lấn việc encode frame kế tiếp với việc submit frame trước, thay vì để CPU chờ ở mỗi lần submit. Mặc định bật; tắt đi nếu nghi ngờ nó gây giật hoặc mất ổn định."
        )
    }
    var d3dMetalMultithreadedInterfaceLabel: String { localized(en: "Multithreaded D3D11 interface (experimental)", vi: "Multithreaded D3D11 interface (thử nghiệm)") }
    var d3dMetalMultithreadedInterfaceDescription: String {
        localized(
            en: "D3DM_MULTITHREADED_INTERFACE_ENABLE: stops D3DMetal serializing D3D11 context access more conservatively than the game's own threading needs. On by default; turn off if you suspect it is causing stutter or instability.",
            vi: "D3DM_MULTITHREADED_INTERFACE_ENABLE: ngăn D3DMetal khoá truy cập D3D11 context chặt hơn mức game thực sự cần khi đa luồng. Mặc định bật; tắt đi nếu nghi ngờ nó gây giật hoặc mất ổn định."
        )
    }
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

    // MARK: - D3DMetal Setup

    var d3dMetalSetupTitle: String { localized(en: "D3DMetal (render backend)", vi: "D3DMetal (render backend)") }
    var d3dMetalAlreadyInstalled: String {
        localized(
            en: "CrossOver with Apple D3DMetal is installed.",
            vi: "Đã cài CrossOver kèm Apple D3DMetal."
        )
    }
    var d3dMetalSetupDescription: String {
        localized(
            en: "Genshin needs a Direct3D-to-Metal layer to run. Apple's D3DMetal ships only inside CrossOver, which this button installs through Homebrew as a 14-day trial — after that CrossOver needs a license purchased from CodeWeavers to keep running. This downloads about 1 GB and installs CrossOver.app into /Applications.",
            vi: "Genshin cần một lớp dịch Direct3D-to-Metal để chạy. Apple D3DMetal chỉ đi kèm CrossOver, và nút này cài CrossOver qua Homebrew dưới dạng dùng thử 14 ngày — sau đó CrossOver cần mua license từ CodeWeavers để tiếp tục dùng. Việc này tải khoảng 1 GB và cài CrossOver.app vào /Applications."
        )
    }
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
        case .d3dMetalShaderCache: return localized(en: "Render (D3DMetal) shader cache", vi: "Cache shader render (D3DMetal)")
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
        case .d3dMetalShaderCache:
            return localized(
                en: "Compiled shaders D3DMetal caches on disk. Rebuilt automatically as the game runs; clearing it can fix stutter or crashes caused by a stale or corrupted cache, at the cost of a fresh round of one-time compile stutter on the next launch.",
                vi: "Shader đã biên dịch mà D3DMetal lưu trên đĩa. Tự tạo lại khi game chạy; xóa cache này có thể khắc phục giật hoặc crash do cache cũ/hỏng, đổi lại là một đợt giật biên dịch lại từ đầu ở lần chạy kế tiếp."
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

    /// Error text for automatic DXVK setup failures.
    func dxvkBootstrapFailed(_ details: String) -> String {
        localized(
            en: "DXVK setup failed before launching Wine: \(details)",
            vi: "Thiết lập DXVK trước khi chạy Wine thất bại: \(details)"
        )
    }

    /// Error text when no installed Wine build carries Apple D3DMetal.
    ///
    /// Only CrossOver is named as a remedy: the popular `game-porting-toolkit` Homebrew cask
    /// (`gcenx/wine` tap) ships the open-source DXMT project relabeled, not Apple's real D3DMetal,
    /// and Apple's own Game Porting Toolkit is gated behind an Apple Developer sign-in with no
    /// public download to point at. Use the Settings screen's install button for CrossOver instead
    /// of typing a command here.
    func d3dMetalUnavailable(_ path: String) -> String {
        localized(
            en: "No Wine build with Apple D3DMetal was found. Checked: \(path). D3DMetal ships only inside CrossOver (CodeWeavers) — NSLauncher cannot download it on its own. Install CrossOver from Settings, then try again.",
            vi: "Chưa tìm thấy bản Wine nào có Apple D3DMetal. Đã kiểm tra: \(path). D3DMetal chỉ đi kèm CrossOver (CodeWeavers) — NSLauncher không thể tự tải D3DMetal. Hãy cài CrossOver từ màn hình Cài đặt rồi thử lại."
        )
    }
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
            case let .dxvkBootstrapFailed(details):
                return dxvkBootstrapFailed(details)
            case let .d3dMetalUnavailable(path):
                return d3dMetalUnavailable(path)
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
