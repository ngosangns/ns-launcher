import Foundation

/// Facade that coordinates persistence, the Sophon installer, and Wine launching.
struct LauncherCoordinator: Sendable {
    private let settingsStore: SettingsStoring
    private let sophonInstaller: SophonInstalling
    private let wineService: WineServicing

    /// Injects every side-effecting service so the view model stays UI-focused.
    init(
        settingsStore: SettingsStoring,
        sophonInstaller: SophonInstalling,
        wineService: WineServicing
    ) {
        self.settingsStore = settingsStore
        self.sophonInstaller = sophonInstaller
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

    /// Builds a Sophon install plan for the selected game.
    func fetchInstallPlan(for game: GameDefinition, settings: AppSettings) async throws -> InstallPlan {
        let build = try await sophonInstaller.fetchBuild(language: settings.language, onEvent: nil)
        let plan = try await sophonInstaller.planUpdate(for: game, build: build, installedMetadata: nil, onEvent: nil)
        return InstallPlan(
            version: plan.latestVersion,
            steps: [
                InstallStep(kind: .downloadFile, relativePath: "Sophon chunks", bytes: plan.bytesToDownload),
                InstallStep(kind: .verifyChecksum, relativePath: "Sophon assets", bytes: plan.decompressedBytesToWrite),
                InstallStep(kind: .writeMetadata, relativePath: ".nslauncher-install.json", bytes: 0)
            ],
            estimatedBytesToDownload: plan.bytesToDownload,
            peakTemporaryBytes: plan.peakTemporaryBytes
        )
    }

    /// Runs a fresh Sophon install.
    func installGame(
        _ game: GameDefinition,
        settings: AppSettings,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        let build = try await sophonInstaller.fetchBuild(language: settings.language, onEvent: onEvent)
        let plan = try await sophonInstaller.planUpdate(for: game, build: build, installedMetadata: nil, onEvent: onEvent)
        try await applySophonPlan(game, plan: plan, operationController: operationController, onEvent: onEvent)
    }

    /// Builds a Sophon delta update plan for an existing game install.
    func fetchUpdatePlan(
        for game: GameDefinition,
        settings: AppSettings,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> GameUpdatePlan {
        let build = try await sophonInstaller.fetchBuild(language: settings.language, onEvent: onEvent)
        return try await sophonInstaller.planUpdate(
            for: game,
            build: build,
            installedMetadata: installedMetadata(for: game),
            onEvent: onEvent
        )
    }

    /// Applies a previously computed Sophon update plan.
    func updateGame(
        _ game: GameDefinition,
        settings: AppSettings,
        plan: GameUpdatePlan,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await applySophonPlan(game, plan: plan, operationController: operationController, onEvent: onEvent)
    }

    /// Builds a launch profile, runs preflight checks, then launches through Wine.
    func launchGame(
        _ game: GameDefinition,
        settings: AppSettings,
        onOutput: (@Sendable (ProcessOutputChunk) -> Void)? = nil
    ) async throws -> ProcessResult {
        let profile = LaunchRuntimeProfile.build(game: game, settings: settings)

        // Preflight: executable must exist
        guard FileManager.default.fileExists(atPath: profile.executablePath.path) else {
            throw LaunchPreflightError.missingExecutable(profile.executablePath.path)
        }

        // Preflight: install metadata must exist and be valid
        let metadataURL = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        guard let metadataData = try? Data(contentsOf: metadataURL) else {
            throw LaunchPreflightError.missingInstallMetadata
        }
        let metadata: InstalledGameMetadata
        do {
            metadata = try JSONDecoder().decode(InstalledGameMetadata.self, from: metadataData)
        } catch {
            throw LaunchPreflightError.invalidInstallMetadata(error.localizedDescription)
        }
        if metadata.gameID != game.id {
            throw LaunchPreflightError.invalidInstallMetadata("gameID mismatch: expected \(game.id), got \(metadata.gameID)")
        }

        // Preflight: staging directory must not exist (partial update in progress)
        let stagingURL = game.installDirectory.appendingPathComponent(".nslauncher-sophon-staging")
        if FileManager.default.fileExists(atPath: stagingURL.path) {
            throw LaunchPreflightError.updateRequiredBeforeLaunch("Partial update staging detected. Run Update Game to complete.")
        }

        let request = WineLaunchRequest(
            wineBinaryPath: profile.wineBinaryPath,
            prefixDirectory: profile.prefixDirectory,
            executablePath: profile.executablePath,
            arguments: profile.arguments,
            environment: profile.environment,
            currentDirectory: profile.currentDirectory,
            runtimeRequirements: profile.runtimeRequirements,
            onOutput: onOutput
        )
        return try await wineService.launch(request)
    }

    /// Reads the marker metadata written by successful Sophon installs and updates.
    private func installedMetadata(for game: GameDefinition) -> InstalledGameMetadata? {
        let metadataURL = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(InstalledGameMetadata.self, from: data)
    }

    /// Applies the Sophon asset plan through the installer.
    private func applySophonPlan(
        _ game: GameDefinition,
        plan: GameUpdatePlan,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await sophonInstaller.update(
            game: game,
            version: plan.latestVersion,
            targetAssets: plan.sophonTargetAssets.isEmpty ? plan.sophonAssetsToWrite : plan.sophonTargetAssets,
            assets: plan.sophonAssetsToWrite,
            operationController: operationController,
            onEvent: onEvent
        )
    }
}
