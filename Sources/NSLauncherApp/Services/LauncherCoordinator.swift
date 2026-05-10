import Foundation

/// Facade that coordinates persistence, install backends, import validation, and launching.
struct LauncherCoordinator: Sendable {
    private let settingsStore: SettingsStoring
    private let downloadStateStore: DownloadStateStoring
    private let manifestInstaller: ManifestInstalling
    private let genshinStreamingMetadataService: GenshinStreamingMetadataProviding
    private let sophonInstaller: SophonInstalling
    private let packageDownloader: PackageDownloading
    private let archiveInstaller: ArchiveInstalling
    private let importService: ImportServicing
    private let wineService: WineServicing

    /// Injects every side-effecting service so the view model stays UI-focused.
    init(
        settingsStore: SettingsStoring,
        downloadStateStore: DownloadStateStoring,
        manifestInstaller: ManifestInstalling,
        genshinStreamingMetadataService: GenshinStreamingMetadataProviding,
        sophonInstaller: SophonInstalling,
        packageDownloader: PackageDownloading,
        archiveInstaller: ArchiveInstalling,
        importService: ImportServicing,
        wineService: WineServicing
    ) {
        self.settingsStore = settingsStore
        self.downloadStateStore = downloadStateStore
        self.manifestInstaller = manifestInstaller
        self.genshinStreamingMetadataService = genshinStreamingMetadataService
        self.sophonInstaller = sophonInstaller
        self.packageDownloader = packageDownloader
        self.archiveInstaller = archiveInstaller
        self.importService = importService
        self.wineService = wineService
    }

    /// Loads persisted application settings.
    func loadSettings() throws -> AppSettings {
        try settingsStore.load()
    }

    /// Saves application settings after UI changes.
    func saveSettings(_ settings: AppSettings) throws {
        try settingsStore.save(settings)
    }

    /// Loads a paused package download checkpoint for the selected game.
    func loadPersistedDownloadState(for gameID: String) throws -> PersistedDownloadState? {
        try downloadStateStore.load(for: gameID)
    }

    /// Clears a stale or intentionally stopped package download checkpoint.
    func clearPersistedDownloadState(for gameID: String) throws {
        try downloadStateStore.clear(for: gameID)
    }

    /// Builds an install plan using the selected install strategy.
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
        case .streamingManifest:
            let manifest = try await genshinStreamingMetadataService.fetchManifest(for: game, language: settings.language)
            return try await manifestInstaller.planInstall(for: game, manifest: manifest)
        }
    }

    /// Runs the install/import flow for the selected strategy.
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
            // Local archive overrides skip downloading but reuse the same extraction path.
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
                // Remote archives are cache artifacts, so remove them once extraction succeeds.
                await onEvent(.cleaningDownloadedArchives(path: archiveURL.lastPathComponent))
                try cleanupDownloadedArchives(for: archiveURL, game: game, settings: settings)
            }
            await onEvent(.finished(version: text.archiveVersionLabel))
        case .existingInstall:
            try await importService.import(game: game, text: text, onEvent: onEvent)
        case .manifest:
            let manifest = try await manifestInstaller.fetchManifest(for: game)
            try await manifestInstaller.install(
                game: game,
                manifest: manifest,
                operationController: operationController,
                onEvent: onEvent
            )
        case .streamingManifest:
            let manifest = try await genshinStreamingMetadataService.fetchManifest(for: game, language: settings.language)
            try await manifestInstaller.install(
                game: game,
                manifest: manifest,
                operationController: operationController,
                onEvent: onEvent
            )
        }
    }

    /// Builds a delta update plan for manifest-backed game installs.
    func fetchUpdatePlan(for game: GameDefinition, settings: AppSettings) async throws -> GameUpdatePlan {
        if game.installerStrategy == .streamingManifest, game.id == "genshin-global" {
            let build = try await sophonInstaller.fetchBuild(language: settings.language)
            return try await sophonInstaller.planUpdate(
                for: game,
                build: build,
                installedMetadata: installedMetadata(for: game)
            )
        }

        let manifest = try await updateManifest(for: game, settings: settings)
        return try await manifestInstaller.planUpdate(
            for: game,
            manifest: manifest,
            installedMetadata: installedMetadata(for: game)
        )
    }

    /// Applies a previously computed update plan using the existing manifest download pipeline.
    func updateGame(
        _ game: GameDefinition,
        settings: AppSettings,
        plan: GameUpdatePlan,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        if plan.sourceKind == .sophon {
            try await sophonInstaller.update(
                game: game,
                version: plan.latestVersion,
                targetAssets: plan.sophonTargetAssets.isEmpty ? plan.sophonAssetsToWrite : plan.sophonTargetAssets,
                assets: plan.sophonAssetsToWrite,
                operationController: operationController,
                onEvent: onEvent
            )
            return
        }

        let targetFiles = plan.targetFiles.isEmpty ? plan.filesToDownload : plan.targetFiles
        let manifest = RemoteGameManifest(version: plan.latestVersion, files: targetFiles)
        try await manifestInstaller.install(
            game: game,
            manifest: manifest,
            files: plan.filesToDownload,
            operationController: operationController,
            onEvent: onEvent
        )
    }

    /// Creates a Wine launch request from the saved game configuration.
    func launchGame(
        _ game: GameDefinition,
        settings: AppSettings,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)? = nil
    ) async throws -> ProcessResult {
        let exe = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        let request = WineLaunchRequest(
            wineBinaryPath: settings.wineBinaryPath,
            prefixDirectory: game.winePrefixDirectory,
            executablePath: exe,
            arguments: settings.launchArguments(for: game),
            environment: [:],
            currentDirectory: game.installDirectory,
            runtimeRequirements: game.runtimeRequirements,
            onOutput: onOutput
        )
        return try await wineService.launch(request)
    }

    /// Fetches the latest manifest shape suitable for update checks.
    private func updateManifest(for game: GameDefinition, settings: AppSettings) async throws -> RemoteGameManifest {
        switch game.installerStrategy {
        case .manifest:
            return try await manifestInstaller.fetchManifest(for: game)
        case .streamingManifest:
            return try await genshinStreamingMetadataService.fetchUpdateManifest(for: game, language: settings.language)
        case .archivePackage, .existingInstall:
            throw ManifestInstallerError.manifestURLMissing
        }
    }

    /// Reads the marker metadata written by successful installs/imports.
    private func installedMetadata(for game: GameDefinition) -> InstalledGameMetadata? {
        let metadataURL = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(InstalledGameMetadata.self, from: data)
    }

    /// Deletes cached archive files after a successful remote package install.
    private func cleanupDownloadedArchives(for archiveURL: URL, game: GameDefinition, settings: AppSettings) throws {
        let fileManager = FileManager.default
        let cacheDirectory = URL(fileURLWithPath: settings.downloadCacheDirectory, isDirectory: true)

        if game.packageSource?.archiveFormat == .multipartZip,
           let partURLs = game.packageSource?.partURLs,
           !partURLs.isEmpty {
            // Multipart archives must remove every sibling part, not just the .001 entry.
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
