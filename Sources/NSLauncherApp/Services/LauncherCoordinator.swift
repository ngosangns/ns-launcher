import Foundation

struct LauncherCoordinator: Sendable {
    private let settingsStore: SettingsStoring
    private let downloadStateStore: DownloadStateStoring
    private let manifestInstaller: ManifestInstalling
    private let packageDownloader: PackageDownloading
    private let archiveInstaller: ArchiveInstalling
    private let importService: ImportServicing
    private let wineService: WineServicing

    init(
        settingsStore: SettingsStoring,
        downloadStateStore: DownloadStateStoring,
        manifestInstaller: ManifestInstalling,
        packageDownloader: PackageDownloading,
        archiveInstaller: ArchiveInstalling,
        importService: ImportServicing,
        wineService: WineServicing
    ) {
        self.settingsStore = settingsStore
        self.downloadStateStore = downloadStateStore
        self.manifestInstaller = manifestInstaller
        self.packageDownloader = packageDownloader
        self.archiveInstaller = archiveInstaller
        self.importService = importService
        self.wineService = wineService
    }

    func loadSettings() throws -> AppSettings {
        try settingsStore.load()
    }

    func saveSettings(_ settings: AppSettings) throws {
        try settingsStore.save(settings)
    }

    func loadPersistedDownloadState(for gameID: String) throws -> PersistedDownloadState? {
        try downloadStateStore.load(for: gameID)
    }

    func clearPersistedDownloadState(for gameID: String) throws {
        try downloadStateStore.clear(for: gameID)
    }

    func fetchInstallPlan(for game: GameDefinition, settings: AppSettings) async throws -> InstallPlan {
        let text = AppText(language: settings.language)
        switch game.installerStrategy {
        case .archivePackage:
            return try await packageDownloader.planInstall(for: game)
        case .existingInstall:
            let validation = await importService.validate(game: game, text: text)
            return InstallPlan(
                version: validation.isValid ? text.existingInstallVersionLabel : text.missingVersionLabel,
                steps: [
                    InstallStep(kind: .verifyChecksum, relativePath: game.executableRelativePath, bytes: 0),
                    InstallStep(kind: .writeMetadata, relativePath: ".nslauncher-install.json", bytes: 0)
                ],
                estimatedBytesToDownload: 0,
                peakTemporaryBytes: 0
            )
        case .manifest:
            let manifest = try await manifestInstaller.fetchManifest(for: game)
            return try await manifestInstaller.planInstall(for: game, manifest: manifest)
        }
    }

    func installGame(
        _ game: GameDefinition,
        settings: AppSettings,
        archiveOverrideURL: URL? = nil,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        let text = AppText(language: settings.language)
        switch game.installerStrategy {
        case .archivePackage:
            let archiveURL: URL
            if let archiveOverrideURL {
                archiveURL = archiveOverrideURL
            } else {
                archiveURL = try await packageDownloader.downloadPackage(
                    for: game,
                    settings: settings,
                    operationController: operationController,
                    onEvent: onEvent
                )
                if game.packageSource?.archiveFormat == .multipartZip,
                   let totalParts = game.packageSource?.partURLs?.count,
                   totalParts > 0 {
                    await onEvent(.readyToExtract(downloadedParts: totalParts, totalParts: totalParts))
                }
            }
            try await archiveInstaller.install(
                archiveURL: archiveURL,
                game: game,
                settings: settings,
                operationController: operationController,
                onEvent: onEvent
            )
            if archiveOverrideURL == nil {
                try cleanupDownloadedArchives(for: archiveURL, game: game, settings: settings)
            }
            await onEvent(.finished(version: text.archiveVersionLabel))
        case .existingInstall:
            try await importService.import(game: game, text: text, onEvent: onEvent)
        case .manifest:
            let manifest = try await manifestInstaller.fetchManifest(for: game)
            try await manifestInstaller.install(game: game, manifest: manifest, onEvent: onEvent)
        }
    }

    func rescanGame(
        _ game: GameDefinition,
        settings: AppSettings,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws -> ImportValidationResult {
        await onEvent(.rescanning(path: game.installDirectory.path))
        return await importService.validate(game: game, text: AppText(language: settings.language))
    }

    func launchGame(_ game: GameDefinition, settings: AppSettings) async throws -> ProcessResult {
        let exe = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        let request = WineLaunchRequest(
            wineBinaryPath: settings.wineBinaryPath,
            prefixDirectory: game.winePrefixDirectory,
            executablePath: exe,
            arguments: game.launchArguments,
            environment: [:],
            currentDirectory: game.installDirectory
        )
        return try await wineService.launch(request)
    }

    private func cleanupDownloadedArchives(for archiveURL: URL, game: GameDefinition, settings: AppSettings) throws {
        let fileManager = FileManager.default
        let cacheDirectory = URL(fileURLWithPath: settings.downloadCacheDirectory, isDirectory: true)

        if game.packageSource?.archiveFormat == .multipartZip,
           let partURLs = game.packageSource?.partURLs,
           !partURLs.isEmpty {
            for partURL in partURLs {
                let cachedPart = cacheDirectory.appendingPathComponent(partURL.lastPathComponent)
                if fileManager.fileExists(atPath: cachedPart.path) {
                    try fileManager.removeItem(at: cachedPart)
                }
            }
            return
        }

        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
    }
}
