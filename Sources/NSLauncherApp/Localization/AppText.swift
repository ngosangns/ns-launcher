import Foundation

struct AppText {
    let language: AppLanguage

    var appTitle: String { localized(en: "NS Launcher", vi: "NS Launcher") }
    var settingsTitle: String { localized(en: "Settings", vi: "Cài đặt") }
    var close: String { localized(en: "Close", vi: "Đóng") }
    var openSettings: String { localized(en: "Open Settings", vi: "Mở cài đặt") }
    var open: String { localized(en: "Open", vi: "Mở") }
    var settingsDescription: String { localized(en: "Adjust language and storage locations used by the launcher.", vi: "Điều chỉnh ngôn ngữ và các vị trí lưu trữ mà launcher sử dụng.") }
    var toolsSectionTitle: String { localized(en: "Storage", vi: "Lưu trữ") }
    var gamePackageSectionTitle: String { localized(en: "Game Package", vi: "Gói cài đặt game") }
    var browse: String { localized(en: "Browse", vi: "Chọn") }
    var addLink: String { localized(en: "Add Link", vi: "Thêm link") }
    var remove: String { localized(en: "Remove", vi: "Xóa") }
    var derivedFromFirstPart: String { localized(en: "Derived from the first part link.", vi: "Tự suy ra từ link part đầu tiên.") }
    var packageLinksDescription: String { localized(en: "Edit the download source links used for this game.", vi: "Chỉnh các link tải dùng cho game này.") }
    var packageLinkRow: String { localized(en: "Part link", vi: "Link part") }
    var singlePackageLink: String { localized(en: "Package link", vi: "Link gói cài đặt") }
    var games: String { localized(en: "Games", vi: "Trò chơi") }
    var noGameSelected: String { localized(en: "No game selected", vi: "Chưa chọn game") }
    var ok: String { localized(en: "OK", vi: "Đóng") }
    var nativeLauncherDescription: String { localized(en: "Native macOS launcher shell", vi: "Launcher macOS thuần") }
    var installDirectory: String { localized(en: "Install Directory", vi: "Thư mục cài đặt") }
    var executable: String { localized(en: "Executable", vi: "File chạy") }
    var winePrefix: String { localized(en: "Wine Prefix", vi: "Tiền tố Wine") }
    var archive: String { localized(en: "Archive", vi: "Gói nén") }
    var format: String { localized(en: "Format", vi: "Định dạng") }
    var packageURL: String { localized(en: "Package URL", vi: "URL gói cài đặt") }
    var localLaunchExperimental: String { localized(en: "Local macOS launch is currently experimental.", vi: "Chạy local trên macOS hiện đang ở mức thử nghiệm.") }
    var installPlanner: String { localized(en: "Install Planner", vi: "Kế hoạch cài đặt") }
    var installPlannerDescription: String { localized(en: "This prototype now supports streaming installs, imports, and re-scan flows for Windows games on macOS.", vi: "Bản mẫu này đã hỗ trợ cài đặt streaming, import và quét lại game Windows trên macOS.") }
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
    var resumeTitle: String { localized(en: "Resume", vi: "Tiếp tục") }
    var stopTitle: String { localized(en: "Stop", vi: "Dừng") }
    var preparingStage: String { localized(en: "Preparing", vi: "Chuẩn bị") }
    var downloadingStage: String { localized(en: "Downloading", vi: "Đang tải") }
    var extractingStage: String { localized(en: "Extracting", vi: "Đang giải nén") }
    var verifyingStage: String { localized(en: "Verifying", vi: "Đang xác thực") }
    var validatingStage: String { localized(en: "Validating", vi: "Đang kiểm tra") }
    var importingStage: String { localized(en: "Importing", vi: "Đang import") }
    var rescanningStage: String { localized(en: "Re-scanning", vi: "Đang quét lại") }
    var completedStage: String { localized(en: "Completed", vi: "Hoàn tất") }
    var waitingForProgress: String { localized(en: "Working...", vi: "Đang xử lý...") }
    var connectingToServer: String { localized(en: "Connecting to the package server...", vi: "Đang kết nối tới máy chủ gói cài đặt...") }
    var waitingForFirstDownloadBytes: String { localized(en: "Waiting for the first download data from the server...", vi: "Đang chờ dữ liệu tải đầu tiên từ máy chủ...") }
    var preparingExtractionAfterDownload: String { localized(en: "All parts are downloaded. Preparing extraction...", vi: "Đã tải xong toàn bộ các part. Đang chuẩn bị giải nén...") }
    var downloadedArchivesCleanedUp: String { localized(en: "Downloaded archive parts will be removed from cache after extraction completes.", vi: "Các part đã tải sẽ được xóa khỏi cache sau khi giải nén xong.") }
    var operationPaused: String { localized(en: "Operation paused", vi: "Đã tạm dừng thao tác") }
    var operationResumed: String { localized(en: "Operation resumed", vi: "Đã tiếp tục thao tác") }
    var operationStopped: String { localized(en: "Operation stopped", vi: "Đã dừng thao tác") }
    var pausedDownloadReadyToResume: String { localized(en: "Paused download is ready to resume.", vi: "Bản tải đã tạm dừng và sẵn sàng tiếp tục.") }
    var error: String { localized(en: "Error", vi: "Lỗi") }
    var ready: String { localized(en: "Ready", vi: "Sẵn sàng") }
    var installPlanReady: String { localized(en: "Install plan ready", vi: "Đã sẵn sàng kế hoạch cài đặt") }
    var failedToPlanInstall: String { localized(en: "Failed to plan install", vi: "Không lập được kế hoạch cài đặt") }
    var versionLabel: String { localized(en: "Version", vi: "Phiên bản") }
    var downloadLabel: String { localized(en: "Download", vi: "Tải về") }
    var peakTempLabel: String { localized(en: "Peak temp", vi: "Bộ nhớ tạm tối đa") }
    var stepsLabel: String { localized(en: "Steps", vi: "Số bước") }
    var installCompleted: String { localized(en: "Install completed", vi: "Đã cài đặt xong") }
    var installFailed: String { localized(en: "Install failed", vi: "Cài đặt thất bại") }
    var importCompleted: String { localized(en: "Import completed", vi: "Import thành công") }
    var importFailed: String { localized(en: "Import failed", vi: "Import thất bại") }
    var rescanFailed: String { localized(en: "Re-scan failed", vi: "Quét lại thất bại") }
    var launchFailed: String { localized(en: "Launch failed", vi: "Mở game thất bại") }
    var gameExitedNormally: String { localized(en: "Game exited normally", vi: "Game đã thoát bình thường") }
    var selectedGame: String { localized(en: "Selected Game", vi: "Game đang chọn") }
    var toolPaths: String { localized(en: "Tool Paths", vi: "Đường dẫn công cụ") }
    var languageLabel: String { localized(en: "Language", vi: "Ngôn ngữ") }
    var english: String { localized(en: "English", vi: "Tiếng Anh") }
    var vietnamese: String { localized(en: "Vietnamese", vi: "Tiếng Việt") }
    var name: String { localized(en: "Name", vi: "Tên") }
    var strategy: String { localized(en: "Strategy", vi: "Chiến lược") }
    var installRoot: String { localized(en: "Install root", vi: "Thư mục cài đặt") }
    var executablePath: String { localized(en: "Executable path", vi: "Đường dẫn file chạy") }
    var archiveFormat: String { localized(en: "Archive format", vi: "Định dạng gói nén") }
    var archiveFileName: String { localized(en: "Archive file name", vi: "Tên file gói nén") }
    var partURLs: String { localized(en: "Split package URLs", vi: "Danh sách URL các phần") }
    var partURLsHint: String { localized(en: "Paste one URL per line for multipart downloads.", vi: "Dán mỗi URL trên một dòng cho gói tải nhiều phần.") }
    var packageURLOptional: String { localized(en: "Package URL is optional. Leave it empty to use local archive install only.", vi: "Package URL là tùy chọn. Để trống nếu chỉ muốn cài từ file local.") }
    var multipartHint: String { localized(en: "For split archives, choose the first .001 part locally or list every remote part URL below.", vi: "Với gói tách nhỏ, hãy chọn file .001 đầu tiên ở máy hoặc liệt kê đầy đủ URL các phần bên dưới.") }
    var wineBinary: String { localized(en: "Wine binary", vi: "File Wine") }
    var aria2Binary: String { localized(en: "aria2c binary", vi: "File aria2c") }
    var sevenZipBinary: String { localized(en: "7zz binary", vi: "File 7zz") }
    var downloadCacheDirectory: String { localized(en: "Download cache directory", vi: "Thư mục cache download") }
    var temporaryExtractionDirectory: String { localized(en: "Temporary extraction directory", vi: "Thư mục giải nén tạm") }
    var chooseArchivePackage: String { localized(en: "Choose Archive Package", vi: "Chọn gói nén") }
    var chooseExistingGameFolder: String { localized(en: "Choose Existing Game Folder", vi: "Chọn thư mục game có sẵn") }
    var chooseInstallFolder: String { localized(en: "Choose Install Folder", vi: "Chọn thư mục cài đặt") }
    var noPackageConfigured: String { localized(en: "No package configured", vi: "Chưa cấu hình gói cài đặt") }
    var officialStreamingSource: String { localized(en: "Official streaming source", vi: "Nguồn streaming chính thức") }
    var downloadReady: String { localized(en: "Download ready", vi: "Sẵn sàng tải") }
    var localOnly: String { localized(en: "Local archive only", vi: "Chỉ hỗ trợ file local") }
    var experimentalBadge: String { localized(en: "Experimental", vi: "Thử nghiệm") }
    var selectedSource: String { localized(en: "Selected source", vi: "Nguồn đang chọn") }
    var remoteConfigured: String { localized(en: "Remote package URL configured", vi: "Đã cấu hình remote package URL") }
    var remoteNotConfigured: String { localized(en: "No remote URL configured", vi: "Chưa cấu hình remote URL") }
    var multipartArchiveDescription: String { localized(en: "Split archive (.001 + siblings)", vi: "Gói tách nhỏ (.001 và các part khác)") }
    var singleArchiveDescription: String { localized(en: "Single archive package", vi: "Gói nén đơn") }

    var planInstallTitle: String { localized(en: "Plan Install", vi: "Lập kế hoạch") }
    var planInstallDescription: String { localized(en: "Estimate download size, temporary space, and planned steps.", vi: "Ước tính dung lượng tải, bộ nhớ tạm và các bước cài đặt.") }
    var downloadInstallTitle: String { localized(en: "Download & Install", vi: "Tải và cài đặt") }
    var downloadInstallDescription: String { localized(en: "Download official game files directly into the install directory.", vi: "Tải trực tiếp các file game chính thức vào thư mục cài đặt.") }
    var localArchiveTitle: String { localized(en: "Install From Local Archive", vi: "Cài từ file local") }
    var localArchiveDescription: String { localized(en: "Pick a local .7z, .zip, or split archive and install from it.", vi: "Chọn file .7z, .zip hoặc gói tách nhỏ từ máy để cài đặt.") }
    var importTitle: String { localized(en: "Import Existing Install", vi: "Import bản cài đặt có sẵn") }
    var importDescription: String { localized(en: "Validate an existing game folder and register it with the launcher.", vi: "Kiểm tra thư mục game có sẵn và đăng ký vào launcher.") }
    var rescanTitle: String { localized(en: "Re-scan", vi: "Quét lại") }
    var rescanDescription: String { localized(en: "Check the current install folder again and validate the executable.", vi: "Kiểm tra lại thư mục cài đặt hiện tại và xác thực file chạy.") }
    var chooseFolderTitle: String { localized(en: "Choose Install Folder", vi: "Chọn thư mục cài đặt") }
    var chooseFolderDescription: String { localized(en: "Change where the launcher installs or looks for the game.", vi: "Đổi thư mục mà launcher sử dụng để cài đặt hoặc tìm game.") }
    var launchTitle: String { localized(en: "Launch via Wine", vi: "Chạy qua Wine") }
    var launchDescription: String { localized(en: "Start the configured Windows executable with the current Wine path.", vi: "Chạy file Windows đã cấu hình bằng đường dẫn Wine hiện tại.") }

    func installStrategyDescription(_ strategy: InstallerStrategy) -> String {
        switch strategy {
        case .archivePackage:
            return localized(en: "Archive package strategy", vi: "Chiến lược cài đặt từ gói nén")
        case .existingInstall:
            return localized(en: "Existing install strategy", vi: "Chiến lược import bản cài đặt có sẵn")
        case .manifest:
            return localized(en: "Manifest strategy", vi: "Chiến lược manifest")
        case .streamingManifest:
            return localized(en: "Official streaming strategy", vi: "Chiến lược streaming chính thức")
        }
    }

    func launcherStrategyDescription(_ strategy: InstallerStrategy) -> String {
        switch language {
        case .english:
            return "\(nativeLauncherDescription) with \(installStrategyDescription(strategy).lowercased())"
        case .vietnamese:
            return "\(nativeLauncherDescription) với \(installStrategyDescription(strategy).lowercased())"
        }
    }

    func archiveTypeDescription(_ format: ArchiveFormat) -> String {
        switch format {
        case .multipartZip:
            return multipartArchiveDescription
        case .sevenZip, .zip, .tarGz:
            return singleArchiveDescription
        }
    }

    func installPlanSummary(version: String, download: String, peakTemp: String, steps: Int) -> String {
        """
        \(versionLabel): \(version)
        \(downloadLabel): \(download)
        \(peakTempLabel): \(peakTemp)
        \(stepsLabel): \(steps)
        """
    }

    func planningInstall(for gameName: String) -> String {
        localized(en: "Planning install for \(gameName)...", vi: "Đang lập kế hoạch cài đặt cho \(gameName)...")
    }

    func installing(_ gameName: String) -> String {
        localized(en: "Installing \(gameName)...", vi: "Đang cài đặt \(gameName)...")
    }

    func installingFromArchive(_ gameName: String, archiveName: String) -> String {
        localized(en: "Installing \(gameName) from \(archiveName)...", vi: "Đang cài đặt \(gameName) từ \(archiveName)...")
    }

    func importing(_ gameName: String) -> String {
        localized(en: "Importing \(gameName)...", vi: "Đang import \(gameName)...")
    }

    func rescanning(_ gameName: String) -> String {
        localized(en: "Re-scanning \(gameName)...", vi: "Đang quét lại \(gameName)...")
    }

    func launching(_ gameName: String) -> String {
        localized(en: "Launching \(gameName)...", vi: "Đang mở \(gameName)...")
    }

    func preparing(_ path: String) -> String {
        localized(en: "Preparing \(path)", vi: "Đang chuẩn bị \(path)")
    }

    func extracting(_ path: String) -> String {
        localized(en: "Extracting \(path)", vi: "Đang giải nén \(path)")
    }

    func verifying(_ path: String) -> String {
        localized(en: "Verifying \(path)", vi: "Đang xác thực \(path)")
    }

    func validating(_ path: String) -> String {
        localized(en: "Validating \(path)", vi: "Đang kiểm tra \(path)")
    }

    func importingPath(_ path: String) -> String {
        localized(en: "Importing from \(path)", vi: "Đang import từ \(path)")
    }

    func rescanningPath(_ path: String) -> String {
        localized(en: "Re-scanning \(path)", vi: "Đang quét lại \(path)")
    }

    func installedVersion(_ version: String) -> String {
        localized(en: "Installed version \(version)", vi: "Đã cài bản \(version)")
    }

    func downloaded(_ path: String, received: String, total: String) -> String {
        localized(en: "Downloaded \(path) (\(received) / \(total))", vi: "Đã tải \(path) (\(received) / \(total))")
    }

    func downloadingPackage(_ path: String, received: String, total: String) -> String {
        localized(en: "Downloading package \(path) (\(received) / \(total))", vi: "Đang tải gói \(path) (\(received) / \(total))")
    }

    func progressValue(received: String, total: String) -> String {
        localized(en: "\(received) / \(total)", vi: "\(received) / \(total)")
    }

    func progressValueKB(receivedKB: String, totalKB: String) -> String {
        localized(en: "\(receivedKB) KB / \(totalKB) KB", vi: "\(receivedKB) KB / \(totalKB) KB")
    }

    func partProgress(current: Int, total: Int) -> String {
        localized(en: "Part \(current) / \(total)", vi: "Part \(current) / \(total)")
    }

    func currentPartProgressValue(received: String, total: String) -> String {
        localized(en: "\(received) / \(total) for this part", vi: "\(received) / \(total) cho part này")
    }

    func resumePointValue(_ value: String) -> String {
        localized(en: "Resume from \(value)", vi: "Tiếp tục từ \(value)")
    }

    func speedValue(_ value: String) -> String {
        localized(en: value, vi: value)
    }

    func extractionStartsAfterDownload(downloadedParts: Int, totalParts: Int) -> String {
        localized(
            en: "Downloaded \(downloadedParts)/\(totalParts) parts. Starting extraction...",
            vi: "Đã tải đủ \(downloadedParts)/\(totalParts) part, bắt đầu giải nén..."
        )
    }

    func missingExpectedExecutable(_ path: String) -> String {
        localized(en: "Missing expected executable at \(path)", vi: "Không tìm thấy file chạy mong đợi tại \(path)")
    }

    var existingInstallLooksValid: String {
        localized(en: "Existing install looks valid.", vi: "Bản cài đặt hiện có có vẻ hợp lệ.")
    }

    var importedVersionLabel: String {
        localized(en: "imported", vi: "đã-import")
    }

    var existingInstallVersionLabel: String {
        localized(en: "existing-install", vi: "bản-cài-đặt-có-sẵn")
    }

    var missingVersionLabel: String {
        localized(en: "missing", vi: "thiếu")
    }

    var archiveVersionLabel: String {
        localized(en: "archive", vi: "gói-nén")
    }

    func executableNotFound(_ path: String) -> String {
        localized(en: "Executable not found at \(path)", vi: "Không tìm thấy file chạy tại \(path)")
    }

    func processFailed(code: Int32, details: String) -> String {
        localized(
            en: "Process failed with code \(code): \(details)",
            vi: "Tiến trình thất bại với mã \(code): \(details)"
        )
    }

    var packageSourceMissing: String {
        localized(en: "The selected game does not define a package source.", vi: "Game đang chọn chưa khai báo nguồn gói cài đặt.")
    }

    var packageRemoteURLMissing: String {
        localized(en: "The selected package source does not include a remote URL.", vi: "Nguồn gói cài đặt đang chọn không có remote URL.")
    }

    var packageServerInvalidResponse: String {
        localized(en: "The package server returned an invalid response.", vi: "Máy chủ gói cài đặt trả về phản hồi không hợp lệ.")
    }

    func downloadedPartIntegrityMismatch(_ fileName: String, expected: String, actual: String) -> String {
        localized(
            en: "Downloaded part \(fileName) is incomplete or mismatched: expected \(expected), found \(actual).",
            vi: "Part đã tải \(fileName) bị thiếu hoặc không khớp: cần \(expected), hiện có \(actual)."
        )
    }

    var archivePackageMissing: String {
        localized(en: "The selected game does not define an archive package.", vi: "Game đang chọn chưa khai báo gói nén cài đặt.")
    }

    var officialStreamingMetadataUnavailable: String {
        localized(en: "Official streaming metadata is unavailable for Genshin Impact right now.", vi: "Hiện chưa lấy được metadata streaming chính thức cho Genshin Impact.")
    }

    var streamingManifestIncomplete: String {
        localized(en: "HoYoPlay does not expose a complete official file manifest for Genshin Impact fresh install right now.", vi: "Hiện HoYoPlay chưa công khai đầy đủ file manifest chính thức cho cài mới Genshin Impact.")
    }

    var freshInstallUnsupported: String {
        localized(en: "Fresh install is currently unsupported because the official streaming manifest is incomplete.", vi: "Hiện chưa hỗ trợ cài mới vì manifest streaming chính thức vẫn chưa đầy đủ.")
    }

    var sevenZipBinaryMissing: String {
        localized(
            en: "7zz is not configured. Install 7-Zip or set the binary path in Settings.",
            vi: "Chưa cấu hình 7zz. Hãy cài 7-Zip hoặc đặt đường dẫn binary trong Settings."
        )
    }

    func sevenZipBinaryNotFound(_ path: String) -> String {
        localized(
            en: "Could not find a working 7zz/7z binary. Current setting: \(path)",
            vi: "Không tìm thấy binary 7zz/7z dùng được. Cấu hình hiện tại: \(path)"
        )
    }

    func expectedExecutableMissingAfterExtraction(_ path: String) -> String {
        localized(en: "Expected executable was not found after extraction: \(path)", vi: "Không tìm thấy file chạy mong đợi sau khi giải nén: \(path)")
    }

    var manifestURLMissing: String {
        localized(en: "The selected game does not have a manifest URL.", vi: "Game đang chọn không có manifest URL.")
    }

    var serverInvalidResponse: String {
        localized(en: "The server returned an invalid response.", vi: "Máy chủ trả về phản hồi không hợp lệ.")
    }

    func checksumMismatch(_ path: String) -> String {
        localized(en: "Checksum mismatch for \(path)", vi: "Checksum không khớp cho \(path)")
    }

    private func localized(en: String, vi: String) -> String {
        switch language {
        case .english:
            return en
        case .vietnamese:
            return vi
        }
    }
}
