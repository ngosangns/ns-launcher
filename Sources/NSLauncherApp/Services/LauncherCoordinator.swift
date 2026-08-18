// LauncherCoordinator.swift
//
// Facade the view model talks to: it owns the settings store, the Sophon installer,
// and the Wine service, and coordinates install/update/launch.
//
// Launch path, in order:
//   1. Build the runtime profile and run preflight checks (executable exists, valid
//      `.nslauncher-install.json` with matching game id, no partial staging).
//   2. Opt-in cloud compatibility: install a `HoYoKProtect.sys` stub into the Wine
//      prefix so the driver-load step does not abort Wine (Wine still cannot load a
//      real kernel driver).
//   3. Opt-in AC patch: temporarily move the crash reporter and Vulkan fallback
//      files to `.bak` for the launch, restored via `defer`. This mirrors YAAGL's
//      current Genshin-global behavior (its binary xdelta3 patch list is empty, so
//      no binary diff is applied here).
//   4. Opt-in blockNet: append a ~10s `/etc/hosts` block for
//      `dispatchosglobal.yuanshen.com` through an admin `osascript` prompt.
//
// All three opt-in modes are default-off, unsupported by HoYoverse, and risk the
// account. They are isolated here and gated by explicit settings flags.

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
        let build = try await sophonInstaller.fetchBuild(
            language: settings.language,
            voiceMatchingField: settings.voiceLanguage.sophonMatchingField,
            onEvent: nil
        )
        let plan = try await sophonInstaller.planUpdate(for: game, build: build, installedMetadata: nil, onEvent: nil)
        return InstallPlan(
            version: plan.latestVersion,
            steps: [
                InstallStep(kind: .downloadFile, relativePath: "Sophon chunks", bytes: plan.bytesToDownload),
                InstallStep(kind: .verifyChecksum, relativePath: "Sophon assets", bytes: plan.decompressedBytesToWrite),
                InstallStep(kind: .writeMetadata, relativePath: ".nslauncher-install.json", bytes: 0)
            ],
            estimatedBytesToDownload: plan.bytesToDownload,
            peakTemporaryBytes: plan.peakTemporaryBytes,
            cutsceneSkippedAssets: plan.sophonCutsceneSkippedAssets,
            cutsceneSkippedBytes: plan.sophonCutsceneSkippedBytes
        )
    }

    /// Runs a fresh Sophon install.
    func installGame(
        _ game: GameDefinition,
        settings: AppSettings,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        let build = try await sophonInstaller.fetchBuild(
            language: settings.language,
            voiceMatchingField: settings.voiceLanguage.sophonMatchingField,
            onEvent: onEvent
        )
        let plan = try await sophonInstaller.planUpdate(for: game, build: build, installedMetadata: nil, onEvent: onEvent)
        try await applySophonPlan(game, plan: plan, operationController: operationController, onEvent: onEvent)
    }

    /// Builds a Sophon delta update plan for an existing game install.
    func fetchUpdatePlan(
        for game: GameDefinition,
        settings: AppSettings,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> GameUpdatePlan {
        let build = try await sophonInstaller.fetchBuild(
            language: settings.language,
            voiceMatchingField: settings.voiceLanguage.sophonMatchingField,
            onEvent: onEvent
        )
        return try await sophonInstaller.planUpdate(
            for: game,
            build: build,
            installedMetadata: installedMetadata(for: game),
            onEvent: onEvent
        )
    }

    /// Lists voice-over packages advertised by the live Sophon build.
    func fetchVoicePackages(
        settings: AppSettings,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> [VoicePackage] {
        try await sophonInstaller.fetchVoicePackages(language: settings.language, onEvent: onEvent)
    }

    /// Removes the local files of one non-selected voice pack.
    func removeVoicePack(
        matchingField: String,
        game: GameDefinition,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> Int64 {
        try await sophonInstaller.removeVoicePack(matchingField: matchingField, game: game, onEvent: onEvent)
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

        if settings.cloudCompatibilityMode {
            try installProtectionDriverStub(for: game, prefixDirectory: profile.prefixDirectory)
        }

        if settings.acPatchMode {
            try applyACPatch(for: game, apply: true)
        }
        defer {
            if settings.acPatchMode {
                try? applyACPatch(for: game, apply: false)
            }
        }

        if settings.blockNetMode {
            startTemporaryNetworkBlock()
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

    /// Copies the game's protection driver into the Wine prefix system32 so the driver-load step does not abort.
    private func installProtectionDriverStub(for game: GameDefinition, prefixDirectory: URL) throws {
        let source = game.installDirectory.appendingPathComponent("HoYoKProtect.sys")
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let destinationDirectory = prefixDirectory
            .appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let destination = destinationDirectory.appendingPathComponent("HoYoKProtect.sys")
        if FileManager.default.fileExists(atPath: destination.path) {
            if FileManager.default.contentsEqual(atPath: source.path, andPath: destination.path) { return }
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    /// Files YAAGL currently hides for Genshin global during launch (crash reporter and Vulkan fallback).
    private static let acPatchRemovedFiles = [
        "GenshinImpact_Data/upload_crash.exe",
        "GenshinImpact_Data/Plugins/crashreport.exe",
        "GenshinImpact_Data/Plugins/vulkan-1.dll"
    ]

    /// Temporarily moves the AC-patch "removed" files to `.bak` before launch, or restores them after.
    ///
    /// Note: the `.bak` files live in the install root and are NOT protected by
    /// `InstallTargetPruner`. If the app crashes mid-launch they can linger; recover
    /// manually by removing the `.bak` suffix.
    private func applyACPatch(for game: GameDefinition, apply: Bool) throws {
        let fileManager = FileManager.default
        for relativePath in Self.acPatchRemovedFiles {
            let url = game.installDirectory.appendingPathComponent(relativePath)
            let backupURL = URL(fileURLWithPath: url.path + ".bak")
            if apply {
                if fileManager.fileExists(atPath: url.path), !fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.moveItem(at: url, to: backupURL)
                }
            } else {
                guard fileManager.fileExists(atPath: backupURL.path) else { continue }
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
                try fileManager.moveItem(at: backupURL, to: url)
            }
        }
    }

    /// Temporarily blocks `dispatchosglobal.yuanshen.com` for ~10 seconds during launch via an admin shell.
    private func startTemporaryNetworkBlock() {
        let script = """
        #!/bin/sh
        HOSTS_FILE="/etc/hosts"
        ENTRY="0.0.0.0 dispatchosglobal.yuanshen.com"
        PAD_START="# Temporarily Added by NSLauncher"
        PAD_END="# End of section"
        if ! grep -qF "$ENTRY" "$HOSTS_FILE"; then
          printf '%s\\n%s\\n%s\\n' "$PAD_START" "$ENTRY" "$PAD_END" >> "$HOSTS_FILE"
        fi
        sleep 10
        sed -i.bak "/$PAD_START/,/$PAD_END/d" "$HOSTS_FILE"
        """
        let temporaryPath = "/tmp/nslauncher_network_block.sh"
        do {
            try script.write(toFile: temporaryPath, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [
                "-e",
                "do shell script \"source \\(temporaryPath) > /dev/null 2>&1 &\" with administrator privileges"
            ]
            try process.run()
        } catch {
            // Best-effort: if the admin prompt is cancelled or fails, leave /etc/hosts untouched.
        }
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
