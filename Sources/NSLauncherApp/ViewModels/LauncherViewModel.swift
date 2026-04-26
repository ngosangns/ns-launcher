import Foundation
import SwiftUI

struct OperationProgress: Equatable {
    var stageTitle: String
    var itemPath: String?
    var itemPaths: [String]? = nil
    var partText: String?
    var detailText: String?
    var resumePointText: String? = nil
    var fractionCompleted: Double?
    var isIndeterminate: Bool
    var currentPartDetailText: String?
    var currentPartFractionCompleted: Double?
    var currentPartIsIndeterminate: Bool
    var speedText: String?
    var etaText: String?
    var isETAWarmingUp: Bool = false
    var totalKBText: String?
    var currentPartKBText: String?
}

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var statusText: String
    @Published var lastPlanSummary = ""
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var operationProgress: OperationProgress?
    @Published var isPaused = false

    private let coordinator: LauncherCoordinator
    private var currentTask: Task<Void, Never>?
    private var operationController: OperationController?
    private var resumableDownloadGameID: String?
    private var lastTransferMetricsUpdateAt: Date?
    private var displayedSpeedText: String?
    private var displayedEtaText: String?
    private var transferSamples: [TransferSample] = []
    private var lastDownloadFieldsUpdateAt: Date?
    private var displayedDownloadFields: DownloadFieldSnapshot?
    private var activeManifestItems: [String: Date] = [:]

    init(settings: AppSettings, coordinator: LauncherCoordinator) {
        self.settings = settings
        self.statusText = AppText(language: settings.language).ready
        self.coordinator = coordinator
        restorePersistedDownloadStateIfNeeded()
    }

    static func bootstrap() -> LauncherViewModel {
        let processRunner = ProcessRunner()
        let coordinator = LauncherCoordinator(
            settingsStore: SettingsStore(),
            downloadStateStore: DownloadStateStore(),
            manifestInstaller: ManifestInstaller(),
            genshinStreamingMetadataService: GenshinStreamingMetadataService(),
            packageDownloader: PackageDownloadService(),
            archiveInstaller: ArchiveInstaller(processRunner: processRunner),
            importService: ImportService(),
            wineService: WineService(processRunner: processRunner)
        )

        let loadedSettings = (try? coordinator.loadSettings()) ?? .default
        let settings = loadedSettings.applyingBundledGenshinDefaultsIfNeeded()
        if settings != loadedSettings {
            try? coordinator.saveSettings(settings)
        }
        return LauncherViewModel(settings: settings, coordinator: coordinator)
    }

    var games: [GameDefinition] { settings.games }

    var selectedGame: GameDefinition? {
        games.first
    }

    var selectedGamePackageName: String {
        guard let game = selectedGame else { return text.noPackageConfigured }
        if game.installerStrategy == .streamingManifest {
            return text.officialStreamingSource
        }
        return game.packageSource?.archiveFileName ?? text.noPackageConfigured
    }

    var canDownloadSelectedGame: Bool {
        guard let game = selectedGame else { return false }
        switch game.installerStrategy {
        case .streamingManifest:
            return true
        case .manifest:
            return game.manifestURL != nil
        case .archivePackage:
            guard let packageSource = game.packageSource else { return false }
            return packageSource.remoteURL != nil || !(packageSource.partURLs?.isEmpty ?? true)
        case .existingInstall:
            return false
        }
    }

    var canInstallFromLocalArchive: Bool {
        selectedGame?.installerStrategy == .archivePackage
    }

    var text: AppText {
        AppText(language: settings.language)
    }

    func persistSettings() {
        do {
            try coordinator.saveSettings(settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setLanguage(_ language: AppLanguage) {
        settings.language = language
        statusText = AppText(language: language).ready
        persistSettings()
    }

    func refreshPlan() {
        guard let game = selectedGame else { return }
        resetTransferMetricsDisplay()
        resetActiveManifestItems()
        currentTask?.cancel()
        isBusy = true
        isPaused = false
        operationController = OperationController()
        operationProgress = OperationProgress(
            stageTitle: text.planInstallTitle,
            itemPath: game.displayName,
            partText: nil,
            detailText: nil,
            fractionCompleted: nil,
            isIndeterminate: true,
            currentPartDetailText: nil,
            currentPartFractionCompleted: nil,
            currentPartIsIndeterminate: true,
            speedText: nil,
            etaText: nil,
            totalKBText: nil,
            currentPartKBText: nil
        )
        statusText = text.planningInstall(for: game.displayName)
        errorMessage = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isBusy = false
                self.isPaused = false
                self.currentTask = nil
                self.operationController = nil
            }
            do {
                let plan = try await coordinator.fetchInstallPlan(for: game, settings: self.settings)
                lastPlanSummary = text.installPlanSummary(
                    version: plan.version,
                    download: ByteCountFormatter.string(fromByteCount: plan.estimatedBytesToDownload, countStyle: .file),
                    peakTemp: ByteCountFormatter.string(fromByteCount: plan.peakTemporaryBytes, countStyle: .file),
                    steps: plan.steps.count
                )
                statusText = text.installPlanReady
                operationProgress = OperationProgress(
                    stageTitle: text.planInstallTitle,
                    itemPath: game.displayName,
                    partText: nil,
                    detailText: text.installPlanReady,
                    fractionCompleted: 1,
                    isIndeterminate: false,
                    currentPartDetailText: nil,
                    currentPartFractionCompleted: nil,
                    currentPartIsIndeterminate: false,
                    speedText: nil,
                    etaText: nil,
                    totalKBText: nil,
                    currentPartKBText: nil
                )
            } catch {
                if error is CancellationError {
                    self.statusText = self.text.operationStopped
                } else {
                    self.errorMessage = self.localizedErrorMessage(for: error)
                    self.statusText = self.text.failedToPlanInstall
                }
                self.operationProgress = nil
            }
        }
    }

    func installSelectedGame(archiveOverrideURL: URL? = nil) {
        guard let game = selectedGame else { return }
        resetTransferMetricsDisplay()
        resetActiveManifestItems()
        resumableDownloadGameID = nil
        currentTask?.cancel()
        isBusy = true
        isPaused = false
        operationController = OperationController()
        operationProgress = OperationProgress(
            stageTitle: text.downloadInstallTitle,
            itemPath: archiveOverrideURL?.lastPathComponent ?? selectedGamePackageName,
            partText: nil,
            detailText: archiveOverrideURL == nil ? text.connectingToServer : text.waitingForProgress,
            fractionCompleted: nil,
            isIndeterminate: archiveOverrideURL != nil,
            currentPartDetailText: nil,
            currentPartFractionCompleted: nil,
            currentPartIsIndeterminate: true,
            speedText: nil,
            etaText: nil,
            totalKBText: nil,
            currentPartKBText: nil
        )
        statusText = archiveOverrideURL == nil
            ? text.installing(game.displayName)
            : text.installingFromArchive(game.displayName, archiveName: archiveOverrideURL!.lastPathComponent)
        errorMessage = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            var shouldKeepPausedState = false
            defer {
                if shouldKeepPausedState {
                    self.currentTask = nil
                    self.operationController = nil
                } else {
                    self.isBusy = false
                    self.isPaused = false
                    self.resumableDownloadGameID = nil
                    self.currentTask = nil
                    self.operationController = nil
                }
            }
            do {
                try await self.coordinator.installGame(
                    game,
                    settings: self.settings,
                    archiveOverrideURL: archiveOverrideURL,
                    operationController: self.operationController
                ) { [weak self] event in
                    await MainActor.run {
                        self?.apply(event: event)
                    }
                }
                self.statusText = self.text.installCompleted
                self.operationProgress = OperationProgress(
                    stageTitle: self.text.downloadInstallTitle,
                    itemPath: game.displayName,
                    partText: nil,
                    detailText: self.text.installCompleted,
                    fractionCompleted: 1,
                    isIndeterminate: false,
                    currentPartDetailText: nil,
                    currentPartFractionCompleted: nil,
                    currentPartIsIndeterminate: false,
                    speedText: nil,
                    etaText: nil,
                    totalKBText: nil,
                    currentPartKBText: nil
                )
            } catch {
                if let interruption = error as? PackageDownloadInterruption, interruption == .paused {
                    shouldKeepPausedState = true
                    if let state = try? self.coordinator.loadPersistedDownloadState(for: game.id) {
                        self.applyPersistedDownloadState(state, for: game.id)
                    }
                } else if error is CancellationError {
                    self.statusText = self.text.operationStopped
                    self.operationProgress = nil
                } else {
                    self.errorMessage = self.localizedErrorMessage(for: error)
                    self.statusText = self.text.installFailed
                    self.operationProgress = nil
                }
            }
        }
    }

    func importSelectedGame(from directoryURL: URL? = nil) {
        guard let game = selectedGame else { return }
        resetTransferMetricsDisplay()
        resetActiveManifestItems()
        let importDirectory = directoryURL ?? game.installDirectory
        updateSelectedGame { current in
            current.installDirectory = importDirectory
            current.winePrefixDirectory = importDirectory.appendingPathComponent(".wine", isDirectory: true)
        }

        currentTask?.cancel()
        isBusy = true
        isPaused = false
        operationController = OperationController()
        operationProgress = OperationProgress(
            stageTitle: text.importTitle,
            itemPath: importDirectory.path,
            partText: nil,
            detailText: nil,
            fractionCompleted: nil,
            isIndeterminate: true,
            currentPartDetailText: nil,
            currentPartFractionCompleted: nil,
            currentPartIsIndeterminate: true,
            speedText: nil,
            etaText: nil,
            totalKBText: nil,
            currentPartKBText: nil
        )
        statusText = text.importing(game.displayName)
        errorMessage = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isBusy = false
                self.isPaused = false
                self.currentTask = nil
                self.operationController = nil
            }
            do {
                let importGame = self.selectedGame ?? game
                try await self.coordinator.installGame(
                    self.gameForExistingInstall(importGame),
                    settings: self.settings,
                    operationController: self.operationController
                ) { [weak self] event in
                    await MainActor.run {
                        self?.apply(event: event)
                    }
                }
                self.persistSettings()
                self.statusText = self.text.importCompleted
                self.operationProgress = OperationProgress(
                    stageTitle: self.text.importTitle,
                    itemPath: importDirectory.path,
                    partText: nil,
                    detailText: self.text.importCompleted,
                    fractionCompleted: 1,
                    isIndeterminate: false,
                    currentPartDetailText: nil,
                    currentPartFractionCompleted: nil,
                    currentPartIsIndeterminate: false,
                    speedText: nil,
                    totalKBText: nil,
                    currentPartKBText: nil
                )
            } catch {
                if error is CancellationError {
                    self.statusText = self.text.operationStopped
                } else {
                    self.errorMessage = self.localizedErrorMessage(for: error)
                    self.statusText = self.text.importFailed
                }
                self.operationProgress = nil
            }
        }
    }

    func rescanSelectedGame() {
        guard let game = selectedGame else { return }
        resetTransferMetricsDisplay()
        resetActiveManifestItems()
        currentTask?.cancel()
        isBusy = true
        isPaused = false
        operationController = OperationController()
        operationProgress = OperationProgress(
            stageTitle: text.rescanTitle,
            itemPath: game.installDirectory.path,
            partText: nil,
            detailText: nil,
            fractionCompleted: nil,
            isIndeterminate: true,
            currentPartDetailText: nil,
            currentPartFractionCompleted: nil,
            currentPartIsIndeterminate: true,
            speedText: nil,
            etaText: nil,
            totalKBText: nil,
            currentPartKBText: nil
        )
        statusText = text.rescanning(game.displayName)
        errorMessage = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isBusy = false
                self.isPaused = false
                self.currentTask = nil
                self.operationController = nil
            }
            do {
                let result = try await self.coordinator.rescanGame(game, settings: self.settings) { [weak self] event in
                    await MainActor.run {
                        self?.apply(event: event)
                    }
                }
                self.statusText = result.message
                self.operationProgress = OperationProgress(
                    stageTitle: self.text.rescanTitle,
                    itemPath: game.installDirectory.path,
                    partText: nil,
                    detailText: result.message,
                    fractionCompleted: 1,
                    isIndeterminate: false,
                    currentPartDetailText: nil,
                    currentPartFractionCompleted: nil,
                    currentPartIsIndeterminate: false,
                    speedText: nil,
                    totalKBText: nil,
                    currentPartKBText: nil
                )
            } catch {
                if error is CancellationError {
                    self.statusText = self.text.operationStopped
                } else {
                    self.errorMessage = self.localizedErrorMessage(for: error)
                    self.statusText = self.text.rescanFailed
                }
                self.operationProgress = nil
            }
        }
    }

    func setInstallDirectoryForSelectedGame(_ url: URL) {
        updateSelectedGame { game in
            game.installDirectory = url
            game.winePrefixDirectory = url.appendingPathComponent(".wine", isDirectory: true)
        }
        persistSettings()
    }

    func setExecutableRelativePathForSelectedGame(_ path: String) {
        updateSelectedGame { game in
            game.executableRelativePath = path
        }
        persistSettings()
    }

    func setArchiveFileNameForSelectedGame(_ fileName: String) {
        updateSelectedGame { game in
            let current = game.packageSource ?? PackageSource(
                remoteURL: nil,
                partURLs: nil,
                archiveFileName: fileName,
                archiveFormat: .sevenZip,
                expectedArchiveSize: nil
            )
            game.packageSource = PackageSource(
                remoteURL: current.remoteURL,
                partURLs: current.partURLs,
                archiveFileName: fileName,
                archiveFormat: current.archiveFormat,
                expectedArchiveSize: current.expectedArchiveSize
            )
        }
        persistSettings()
    }

    func setPackageURLForSelectedGame(_ url: URL) {
        updateSelectedGame { current in
            let packageSource = current.packageSource ?? PackageSource(
                remoteURL: nil,
                partURLs: nil,
                archiveFileName: "package.7z",
                archiveFormat: .sevenZip,
                expectedArchiveSize: nil
            )
            current.packageSource = PackageSource(
                remoteURL: url,
                partURLs: packageSource.partURLs,
                archiveFileName: packageSource.archiveFileName,
                archiveFormat: packageSource.archiveFormat,
                expectedArchiveSize: packageSource.expectedArchiveSize
            )
        }
        persistSettings()
    }

    func setPartURLsForSelectedGame(_ urls: [URL]) {
        updateSelectedGame { current in
            let packageSource = current.packageSource ?? PackageSource(
                remoteURL: urls.first,
                partURLs: urls,
                archiveFileName: urls.first?.lastPathComponent ?? "package.zip.001",
                archiveFormat: .multipartZip,
                expectedArchiveSize: nil
            )
            current.packageSource = PackageSource(
                remoteURL: urls.first ?? packageSource.remoteURL,
                partURLs: urls.isEmpty ? nil : urls,
                archiveFileName: urls.first?.lastPathComponent ?? packageSource.archiveFileName,
                archiveFormat: urls.isEmpty ? packageSource.archiveFormat : .multipartZip,
                expectedArchiveSize: packageSource.expectedArchiveSize
            )
        }
        persistSettings()
    }

    func clearPackageURLForSelectedGame() {
        guard let game = selectedGame, let packageSource = game.packageSource else { return }
        updateSelectedGame { current in
            current.packageSource = PackageSource(
                remoteURL: nil,
                partURLs: packageSource.partURLs,
                archiveFileName: packageSource.archiveFileName,
                archiveFormat: packageSource.archiveFormat,
                expectedArchiveSize: packageSource.expectedArchiveSize
            )
        }
        persistSettings()
    }

    func setArchiveFormatForSelectedGame(_ format: ArchiveFormat) {
        updateSelectedGame { game in
            let current = game.packageSource ?? PackageSource(
                remoteURL: nil,
                partURLs: nil,
                archiveFileName: "package.\(format.fileExtensionHint)",
                archiveFormat: format,
                expectedArchiveSize: nil
            )
            game.packageSource = PackageSource(
                remoteURL: current.remoteURL,
                partURLs: current.partURLs,
                archiveFileName: current.archiveFileName,
                archiveFormat: format,
                expectedArchiveSize: current.expectedArchiveSize
            )
        }
        persistSettings()
    }

    func launchSelectedGame() {
        guard let game = selectedGame else { return }
        resetTransferMetricsDisplay()
        currentTask?.cancel()
        isBusy = true
        isPaused = false
        operationController = OperationController()
        operationProgress = OperationProgress(
            stageTitle: text.launchTitle,
            itemPath: game.executableRelativePath,
            partText: nil,
            detailText: nil,
            fractionCompleted: nil,
            isIndeterminate: true,
            currentPartDetailText: nil,
            currentPartFractionCompleted: nil,
            currentPartIsIndeterminate: true,
            speedText: nil,
            etaText: nil,
            totalKBText: nil,
            currentPartKBText: nil
        )
        statusText = text.launching(game.displayName)
        errorMessage = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isBusy = false
                self.isPaused = false
                self.currentTask = nil
                self.operationController = nil
            }
            do {
                _ = try await self.coordinator.launchGame(game, settings: self.settings)
                self.statusText = self.text.gameExitedNormally
                self.operationProgress = OperationProgress(
                    stageTitle: self.text.launchTitle,
                    itemPath: game.executableRelativePath,
                    partText: nil,
                    detailText: self.text.gameExitedNormally,
                    fractionCompleted: 1,
                    isIndeterminate: false,
                    currentPartDetailText: nil,
                    currentPartFractionCompleted: nil,
                    currentPartIsIndeterminate: false,
                    speedText: nil,
                    totalKBText: nil,
                    currentPartKBText: nil
                )
            } catch {
                if error is CancellationError {
                    self.statusText = self.text.operationStopped
                } else {
                    self.errorMessage = self.localizedErrorMessage(for: error)
                    self.statusText = self.text.launchFailed
                }
                self.operationProgress = nil
            }
        }
    }

    func togglePause() {
        if isPaused, currentTask == nil, let game = selectedGame, resumableDownloadGameID == game.id {
            installSelectedGame()
            statusText = text.operationResumed
            return
        }

        guard isBusy, let operationController else { return }
        let newPausedValue = !isPaused
        isPaused = newPausedValue
        Task {
            if newPausedValue {
                await operationController.pause()
            } else {
                await operationController.resume()
            }
        }
        statusText = newPausedValue ? text.operationPaused : text.operationResumed
    }

    func stopCurrentOperation() {
        guard isBusy else { return }
        resetTransferMetricsDisplay()
        if currentTask == nil, let gameID = resumableDownloadGameID {
            do {
                try coordinator.clearPersistedDownloadState(for: gameID)
            } catch {
                errorMessage = localizedErrorMessage(for: error)
            }
            resumableDownloadGameID = nil
            isBusy = false
            isPaused = false
            statusText = text.operationStopped
            operationProgress = nil
            return
        }

        Task {
            await operationController?.stop()
        }
        currentTask?.cancel()
        statusText = text.operationStopped
        isPaused = false
        resumableDownloadGameID = nil
        operationProgress = nil
    }

    private func apply(event: InstallProgressEvent) {
        switch event {
        case let .preparing(path):
            statusText = text.preparing(path)
            operationProgress = OperationProgress(
                stageTitle: text.preparingStage,
                itemPath: path,
                partText: nil,
                detailText: nil,
                fractionCompleted: nil,
                isIndeterminate: true,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: true,
                speedText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .readyToExtract(downloadedParts, totalParts):
            let detail = text.extractionStartsAfterDownload(downloadedParts: downloadedParts, totalParts: totalParts)
            statusText = detail
            operationProgress = OperationProgress(
                stageTitle: text.preparingStage,
                itemPath: nil,
                partText: text.partProgress(current: downloadedParts, total: totalParts),
                detailText: detail,
                resumePointText: nil,
                fractionCompleted: 1,
                isIndeterminate: false,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: false,
                speedText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .downloadingPackage(path, received, total, currentPart, totalParts, currentPartReceived, currentPartTotal, _):
            let receivedText = ByteCountFormatter.string(fromByteCount: received, countStyle: .file)
            let totalText = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            let currentPartReceivedText = ByteCountFormatter.string(fromByteCount: currentPartReceived ?? 0, countStyle: .file)
            let currentPartTotalText = ByteCountFormatter.string(fromByteCount: currentPartTotal ?? 0, countStyle: .file)
            let derivedMetrics = deriveTransferMetrics(received: received, total: total)
            let latestSpeedText = derivedMetrics.speedBytesPerSecond.map {
                ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) + "/s"
            }
            let latestEtaText: String? = {
                guard derivedMetrics.isWarmupComplete,
                      let speedBytesPerSecond = derivedMetrics.speedBytesPerSecond,
                      speedBytesPerSecond > 0,
                      total > received else { return nil }
                return formatETA(seconds: Double(total - received) / Double(speedBytesPerSecond))
            }()
            let transferMetrics = throttledTransferMetrics(
                latestSpeedText: latestSpeedText,
                latestEtaText: latestEtaText
            )
            let partLabel: String? = {
                if let currentPart, let totalParts {
                    return text.partProgress(current: currentPart, total: totalParts)
                }
                return nil
            }()
            let latestDetailText = received == 0
                ? text.waitingForFirstDownloadBytes
                : text.progressValue(received: receivedText, total: totalText)
            let latestCurrentPartDetailText = (currentPartReceived ?? 0) == 0
                ? text.waitingForFirstDownloadBytes
                : text.currentPartProgressValue(received: currentPartReceivedText, total: currentPartTotalText)
            let latestTotalKBText = text.progressValueKB(
                receivedKB: String(received / 1024),
                totalKB: String(total / 1024)
            )
            let latestCurrentPartKBText: String? = {
                guard let currentPartReceived, let currentPartTotal else { return nil }
                return text.progressValueKB(
                    receivedKB: String(currentPartReceived / 1024),
                    totalKB: String(currentPartTotal / 1024)
                )
            }()
            let throttledFields = throttledDownloadFields(
                path: path,
                partText: partLabel,
                latestDetailText: latestDetailText,
                latestCurrentPartDetailText: latestCurrentPartDetailText,
                latestTotalKBText: latestTotalKBText,
                latestCurrentPartKBText: latestCurrentPartKBText
            )
            statusText = text.downloadingPackage(
                path,
                received: receivedText,
                total: totalText
            )
            operationProgress = OperationProgress(
                stageTitle: text.downloadingStage,
                itemPath: path,
                partText: throttledFields.partText,
                detailText: throttledFields.detailText,
                resumePointText: received > 0 ? text.resumePointValue(receivedText) : nil,
                fractionCompleted: total > 0 ? min(max(Double(received) / Double(total), 0), 1) : nil,
                isIndeterminate: total <= 0 || received == 0,
                currentPartDetailText: throttledFields.currentPartDetailText,
                currentPartFractionCompleted: {
                    guard let currentPartReceived, let currentPartTotal, currentPartTotal > 0 else { return nil }
                    return min(max(Double(currentPartReceived) / Double(currentPartTotal), 0), 1)
                }(),
                currentPartIsIndeterminate: (currentPartTotal ?? 0) <= 0 || (currentPartReceived ?? 0) == 0,
                speedText: transferMetrics.speedText,
                etaText: transferMetrics.etaText,
                isETAWarmingUp: !derivedMetrics.isWarmupComplete && received > 0,
                totalKBText: throttledFields.totalKBText,
                currentPartKBText: throttledFields.currentPartKBText
            )
        case let .downloading(path, received, total):
            let receivedText = ByteCountFormatter.string(fromByteCount: received, countStyle: .file)
            let totalText = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            statusText = text.downloaded(
                path,
                received: receivedText,
                total: totalText
            )
            operationProgress = OperationProgress(
                stageTitle: text.downloadingStage,
                itemPath: path,
                partText: nil,
                detailText: text.progressValue(received: receivedText, total: totalText),
                fractionCompleted: total > 0 ? min(max(Double(received) / Double(total), 0), 1) : nil,
                isIndeterminate: total <= 0,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: true,
                speedText: nil,
                etaText: nil,
                totalKBText: text.progressValueKB(
                    receivedKB: String(received / 1024),
                    totalKB: String(total / 1024)
                ),
                currentPartKBText: nil
            )
        case let .downloadingManifest(path, overallReceived, overallTotal, fileReceived, fileTotal):
            let overallReceivedText = ByteCountFormatter.string(fromByteCount: overallReceived, countStyle: .file)
            let overallTotalText = ByteCountFormatter.string(fromByteCount: overallTotal, countStyle: .file)
            let fileReceivedText = ByteCountFormatter.string(fromByteCount: fileReceived, countStyle: .file)
            let fileTotalText = ByteCountFormatter.string(fromByteCount: fileTotal, countStyle: .file)
            let activeItems = registerActiveManifestItem(path)
            statusText = text.downloadingPackage(
                path,
                received: overallReceivedText,
                total: overallTotalText
            )
            operationProgress = OperationProgress(
                stageTitle: text.downloadingStage,
                itemPath: path,
                itemPaths: activeItems,
                partText: nil,
                detailText: text.progressValue(received: overallReceivedText, total: overallTotalText),
                fractionCompleted: overallTotal > 0 ? min(max(Double(overallReceived) / Double(overallTotal), 0), 1) : nil,
                isIndeterminate: overallTotal <= 0,
                currentPartDetailText: text.currentPartProgressValue(received: fileReceivedText, total: fileTotalText),
                currentPartFractionCompleted: fileTotal > 0 ? min(max(Double(fileReceived) / Double(fileTotal), 0), 1) : nil,
                currentPartIsIndeterminate: fileTotal <= 0,
                speedText: nil,
                etaText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .extracting(path):
            statusText = text.extracting(path)
            operationProgress = OperationProgress(
                stageTitle: text.extractingStage,
                itemPath: path,
                partText: nil,
                detailText: nil,
                fractionCompleted: nil,
                isIndeterminate: true,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: true,
                speedText: nil,
                etaText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .verifying(path):
            statusText = text.verifying(path)
            operationProgress = OperationProgress(
                stageTitle: text.verifyingStage,
                itemPath: path,
                partText: nil,
                detailText: nil,
                fractionCompleted: nil,
                isIndeterminate: true,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: true,
                speedText: nil,
                etaText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .validatingInstall(path):
            statusText = text.validating(path)
            operationProgress = OperationProgress(
                stageTitle: text.validatingStage,
                itemPath: path,
                partText: nil,
                detailText: nil,
                fractionCompleted: nil,
                isIndeterminate: true,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: true,
                speedText: nil,
                etaText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .importing(path):
            statusText = text.importingPath(path)
            operationProgress = OperationProgress(
                stageTitle: text.importingStage,
                itemPath: path,
                partText: nil,
                detailText: nil,
                fractionCompleted: nil,
                isIndeterminate: true,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: true,
                speedText: nil,
                etaText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .rescanning(path):
            statusText = text.rescanningPath(path)
            operationProgress = OperationProgress(
                stageTitle: text.rescanningStage,
                itemPath: path,
                partText: nil,
                detailText: nil,
                fractionCompleted: nil,
                isIndeterminate: true,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: true,
                speedText: nil,
                etaText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        case let .finished(version):
            statusText = text.installedVersion(version)
            operationProgress = OperationProgress(
                stageTitle: text.completedStage,
                itemPath: version,
                partText: nil,
                detailText: text.installedVersion(version),
                fractionCompleted: 1,
                isIndeterminate: false,
                currentPartDetailText: nil,
                currentPartFractionCompleted: nil,
                currentPartIsIndeterminate: false,
                speedText: nil,
                etaText: nil,
                totalKBText: nil,
                currentPartKBText: nil
            )
        }
    }

    private func formatETA(seconds: Double) -> String? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        let roundedSeconds: Double
        switch seconds {
        case 0..<60:
            roundedSeconds = (seconds / 5).rounded() * 5
        case 60..<600:
            roundedSeconds = (seconds / 15).rounded() * 15
        case 600..<3600:
            roundedSeconds = (seconds / 30).rounded() * 30
        default:
            roundedSeconds = (seconds / 60).rounded() * 60
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = roundedSeconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter.string(from: roundedSeconds)
    }

    private func throttledTransferMetrics(latestSpeedText: String?, latestEtaText: String?) -> (speedText: String?, etaText: String?) {
        let now = Date()
        let shouldRefresh = {
            guard let lastTransferMetricsUpdateAt else { return true }
            return now.timeIntervalSince(lastTransferMetricsUpdateAt) >= 1.5
        }()

        if shouldRefresh || displayedSpeedText == nil || displayedEtaText == nil {
            displayedSpeedText = latestSpeedText
            displayedEtaText = latestEtaText
            lastTransferMetricsUpdateAt = now
        } else if latestSpeedText == nil {
            displayedSpeedText = nil
        }

        if latestEtaText == nil {
            displayedEtaText = nil
        }

        return (displayedSpeedText, displayedEtaText)
    }

    private func resetTransferMetricsDisplay() {
        lastTransferMetricsUpdateAt = nil
        displayedSpeedText = nil
        displayedEtaText = nil
        transferSamples = []
        lastDownloadFieldsUpdateAt = nil
        displayedDownloadFields = nil
    }

    private func throttledDownloadFields(
        path: String,
        partText: String?,
        latestDetailText: String,
        latestCurrentPartDetailText: String?,
        latestTotalKBText: String?,
        latestCurrentPartKBText: String?
    ) -> DownloadFieldSnapshot {
        let now = Date()
        let latest = DownloadFieldSnapshot(
            path: path,
            partText: partText,
            detailText: latestDetailText,
            currentPartDetailText: latestCurrentPartDetailText,
            totalKBText: latestTotalKBText,
            currentPartKBText: latestCurrentPartKBText
        )

        let shouldRefresh = {
            guard let displayedDownloadFields else { return true }
            guard let lastDownloadFieldsUpdateAt else { return true }
            if displayedDownloadFields.path != latest.path || displayedDownloadFields.partText != latest.partText {
                return true
            }
            return now.timeIntervalSince(lastDownloadFieldsUpdateAt) >= 0.8
        }()

        if shouldRefresh {
            displayedDownloadFields = latest
            lastDownloadFieldsUpdateAt = now
        }

        return displayedDownloadFields ?? latest
    }

    private func deriveTransferMetrics(received: Int64, total: Int64) -> (speedBytesPerSecond: Int64?, etaSeconds: Double?, isWarmupComplete: Bool) {
        let now = Date()
        let minimumSampleSpacing: TimeInterval = 0.5
        let rollingWindow: TimeInterval = 12
        let etaWarmupDuration: TimeInterval = 5

        if let lastSample = transferSamples.last {
            let deltaTime = now.timeIntervalSince(lastSample.date)
            let deltaBytes = received - lastSample.receivedBytes
            if deltaTime >= minimumSampleSpacing || deltaBytes >= 512 * 1024 || deltaBytes < 0 {
                transferSamples.append(TransferSample(date: now, receivedBytes: received))
            } else {
                transferSamples[transferSamples.count - 1] = TransferSample(date: now, receivedBytes: received)
            }
        } else {
            transferSamples.append(TransferSample(date: now, receivedBytes: received))
        }

        transferSamples.removeAll { now.timeIntervalSince($0.date) > rollingWindow }

        guard let first = transferSamples.first, let last = transferSamples.last else {
            return (nil, nil, false)
        }

        let elapsed = last.date.timeIntervalSince(first.date)
        let transferredBytes = last.receivedBytes - first.receivedBytes
        guard elapsed >= 1, transferredBytes > 0 else {
            return (nil, nil, false)
        }

        let speed = Int64((Double(transferredBytes) / elapsed).rounded())
        let eta: Double? = {
            guard speed > 0, total > received else { return nil }
            return Double(total - received) / Double(speed)
        }()
        return (speed, eta, elapsed >= etaWarmupDuration)
    }

    private func updateSelectedGame(_ update: (inout GameDefinition) -> Void) {
        guard !settings.games.isEmpty else { return }
        update(&settings.games[0])
    }

    private func gameForExistingInstall(_ game: GameDefinition) -> GameDefinition {
        GameDefinition(
            id: game.id,
            displayName: game.displayName,
            installDirectory: game.installDirectory,
            executableRelativePath: game.executableRelativePath,
            winePrefixDirectory: game.winePrefixDirectory,
            installerStrategy: .existingInstall,
            runtimeRequirements: game.runtimeRequirements,
            manifestURL: game.manifestURL,
            packageSource: game.packageSource,
            launchArguments: game.launchArguments
        )
    }

    private func restorePersistedDownloadStateIfNeeded() {
        guard currentTask == nil, let game = selectedGame else { return }

        guard let state = try? coordinator.loadPersistedDownloadState(for: game.id) else {
            if resumableDownloadGameID == game.id {
                resumableDownloadGameID = nil
                isBusy = false
                isPaused = false
                operationProgress = nil
                statusText = text.ready
            }
            return
        }

        applyPersistedDownloadState(state, for: game.id)
    }

    private func applyPersistedDownloadState(_ state: PersistedDownloadState, for gameID: String) {
        resumableDownloadGameID = gameID
        isBusy = true
        isPaused = true

        let totalBytes = state.totalExpectedBytes ?? max(state.downloadedBytes, 0)
        let receivedText = ByteCountFormatter.string(fromByteCount: state.downloadedBytes, countStyle: .file)
        let totalText = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let currentPartReceivedText = ByteCountFormatter.string(fromByteCount: state.currentPartReceivedBytes, countStyle: .file)
        let currentPartTotalText = ByteCountFormatter.string(fromByteCount: state.currentPartExpectedBytes ?? 0, countStyle: .file)

        statusText = text.pausedDownloadReadyToResume
        operationProgress = OperationProgress(
            stageTitle: text.downloadingStage,
            itemPath: state.currentPartFileName,
            partText: {
                guard let currentPart = state.currentPart, let totalParts = state.totalParts else { return nil }
                return text.partProgress(current: currentPart, total: totalParts)
            }(),
            detailText: text.progressValue(received: receivedText, total: totalText),
            resumePointText: text.resumePointValue(receivedText),
            fractionCompleted: totalBytes > 0 ? min(max(Double(state.downloadedBytes) / Double(totalBytes), 0), 1) : nil,
            isIndeterminate: totalBytes <= 0,
            currentPartDetailText: state.currentPartExpectedBytes.map { _ in
                text.currentPartProgressValue(received: currentPartReceivedText, total: currentPartTotalText)
            },
            currentPartFractionCompleted: {
                guard let currentPartExpectedBytes = state.currentPartExpectedBytes, currentPartExpectedBytes > 0 else { return nil }
                return min(max(Double(state.currentPartReceivedBytes) / Double(currentPartExpectedBytes), 0), 1)
            }(),
            currentPartIsIndeterminate: (state.currentPartExpectedBytes ?? 0) <= 0,
            speedText: nil,
            etaText: nil,
            totalKBText: text.progressValueKB(
                receivedKB: String(state.downloadedBytes / 1024),
                totalKB: String(totalBytes / 1024)
            ),
            currentPartKBText: state.currentPartExpectedBytes.map {
                text.progressValueKB(
                    receivedKB: String(state.currentPartReceivedBytes / 1024),
                    totalKB: String($0 / 1024)
                )
            }
        )
    }

    private func localizedErrorMessage(for error: Error) -> String {
        switch error {
        case let processError as ProcessRunnerError:
            switch processError {
            case let .executableNotFound(path):
                return text.executableNotFound(path)
            case let .nonZeroExit(result):
                let details = result.stderr.isEmpty ? result.stdout : result.stderr
                return text.processFailed(code: result.exitCode, details: details)
            }
        case let downloadError as PackageDownloadError:
            switch downloadError {
            case .packageSourceMissing:
                return text.packageSourceMissing
            case .remoteURLMissing:
                return text.packageRemoteURLMissing
            case .invalidResponse:
                return text.packageServerInvalidResponse
            case let .downloadedPartIntegrityMismatch(fileName, expectedBytes, actualBytes):
                return text.downloadedPartIntegrityMismatch(
                    fileName,
                    expected: ByteCountFormatter.string(fromByteCount: expectedBytes, countStyle: .file),
                    actual: ByteCountFormatter.string(fromByteCount: actualBytes, countStyle: .file)
                )
            }
        case let archiveError as ArchiveInstallerError:
            switch archiveError {
            case .packageSourceMissing:
                return text.archivePackageMissing
            case .sevenZipBinaryMissing:
                return text.sevenZipBinaryMissing
            case let .sevenZipBinaryNotFound(path):
                return text.sevenZipBinaryNotFound(path)
            case let .expectedExecutableMissing(path):
                return text.expectedExecutableMissingAfterExtraction(path)
            }
        case let manifestError as ManifestInstallerError:
            switch manifestError {
            case .manifestURLMissing:
                return text.manifestURLMissing
            case .invalidResponse:
                return text.serverInvalidResponse
            case let .checksumMismatch(path):
                return text.checksumMismatch(path)
            case let .expectedExecutableMissing(path):
                return text.missingExpectedExecutable(path)
            }
        case let streamingError as GenshinStreamingMetadataError:
            switch streamingError {
            case .officialStreamingMetadataUnavailable:
                return text.officialStreamingMetadataUnavailable
            case .streamingManifestIncomplete:
                return text.streamingManifestIncomplete
            case .freshInstallUnsupported:
                return text.freshInstallUnsupported
            }
        case let importError as ImportServiceError:
            switch importError {
            case let .expectedExecutableMissing(path):
                return text.missingExpectedExecutable(path)
            }
        case is CancellationError:
            return text.operationStopped
        default:
            return error.localizedDescription
        }
    }

    private func registerActiveManifestItem(_ path: String) -> [String] {
        let now = Date()
        activeManifestItems[path] = now
        activeManifestItems = activeManifestItems.filter { now.timeIntervalSince($0.value) < 2.5 }
        return activeManifestItems
            .sorted { $0.value > $1.value }
            .map(\.key)
            .prefix(16)
            .map { $0 }
    }

    private func resetActiveManifestItems() {
        activeManifestItems.removeAll()
    }
}

private struct TransferSample {
    let date: Date
    let receivedBytes: Int64
}

private struct DownloadFieldSnapshot {
    let path: String
    let partText: String?
    let detailText: String
    let currentPartDetailText: String?
    let totalKBText: String?
    let currentPartKBText: String?
}
