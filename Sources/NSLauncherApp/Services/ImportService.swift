import Foundation

enum ImportServiceError: LocalizedError {
    case expectedExecutableMissing(String)

    var errorDescription: String? {
        switch self {
        case let .expectedExecutableMissing(path):
            return "Expected executable was not found for import: \(path)"
        }
    }
}

protocol ImportServicing: Sendable {
    func validate(game: GameDefinition, text: AppText) async -> ImportValidationResult
    func `import`(
        game: GameDefinition,
        text: AppText,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

struct ImportService: ImportServicing {
    init() {}

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
