import Foundation

/// Import-specific validation errors.
enum ImportServiceError: LocalizedError {
    case expectedExecutableMissing(String)

    var errorDescription: String? {
        switch self {
        case let .expectedExecutableMissing(path):
            return "Expected executable was not found for import: \(path)"
        }
    }
}

/// Boundary for validating and registering existing game folders.
protocol ImportServicing: Sendable {
    /// Checks whether the configured executable exists in the selected folder.
    func validate(game: GameDefinition, text: AppText) async -> ImportValidationResult
    /// Writes launcher metadata for a valid existing installation.
    func `import`(
        game: GameDefinition,
        text: AppText,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

/// Registers already-installed game folders without downloading or extracting files.
struct ImportService: ImportServicing {
    init() {}

    /// Validates an import by checking the executable path relative to the install directory.
    func validate(game: GameDefinition, text: AppText) async -> ImportValidationResult {
        let executable = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        guard FileManager.default.fileExists(atPath: executable.path) else {
            return ImportValidationResult(
                isValid: false,
                message: text.missingExpectedExecutable(game.executableRelativePath)
            )
        }

        return ImportValidationResult(
            isValid: true,
            message: text.existingInstallLooksValid
        )
    }

    /// Validates and writes the standard NSLauncher metadata marker into the import folder.
    func `import`(
        game: GameDefinition,
        text: AppText,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        let validation = await validate(game: game, text: text)
        guard validation.isValid else {
            throw ImportServiceError.expectedExecutableMissing(game.executableRelativePath)
        }

        await onEvent(.importing(path: game.installDirectory.path))
        let metadata = InstalledGameMetadata(
            gameID: game.id,
            installMode: .existingInstall,
            installedAt: Date(),
            sourceArchiveFileName: nil,
            executableRelativePath: game.executableRelativePath,
            version: nil
        )
        let data = try JSONEncoder().encode(metadata)
        try data.write(
            to: game.installDirectory.appendingPathComponent(".nslauncher-install.json"),
            options: .atomic
        )
        await onEvent(.finished(version: text.importedVersionLabel))
    }
}
