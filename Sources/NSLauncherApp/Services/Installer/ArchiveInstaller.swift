import Foundation

enum ArchiveInstallerError: LocalizedError {
    case packageSourceMissing
    case sevenZipBinaryMissing
    case expectedExecutableMissing(String)

    var errorDescription: String? {
        switch self {
        case .packageSourceMissing:
            return "The selected game does not define an archive package."
        case .sevenZipBinaryMissing:
            return "7zz binary path is empty."
        case let .expectedExecutableMissing(path):
            return "Expected executable was not found after extraction: \(path)"
        }
    }
}

protocol ArchiveInstalling: Sendable {
    func install(
        archiveURL: URL,
        game: GameDefinition,
        settings: AppSettings,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

struct ArchiveInstaller: ArchiveInstalling {
    private let processRunner: ProcessRunning

    init(processRunner: ProcessRunning) {
        self.processRunner = processRunner
    }

    func install(
        archiveURL: URL,
        game: GameDefinition,
        settings: AppSettings,
        operationController: OperationController? = nil,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        guard game.packageSource != nil else {
            throw ArchiveInstallerError.packageSourceMissing
        }
        guard !settings.sevenZipBinaryPath.isEmpty else {
            throw ArchiveInstallerError.sevenZipBinaryMissing
        }
        try await operationController?.checkpoint()

        try FileManager.default.createDirectory(at: game.installDirectory, withIntermediateDirectories: true)

        let tempDirectory = URL(fileURLWithPath: settings.temporaryExtractionDirectory, isDirectory: true)
            .appendingPathComponent(game.id, isDirectory: true)
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        await onEvent(.extracting(path: archiveURL.lastPathComponent))
        try await operationController?.checkpoint()
        let extractionSource = normalizedArchiveURL(for: archiveURL, game: game)
        _ = try await processRunner.run(
            executable: settings.sevenZipBinaryPath,
            arguments: [
                "x",
                "-y",
                "-o\(tempDirectory.path)",
                extractionSource.path
            ],
            environment: [:],
            currentDirectory: nil
        )

        try await operationController?.checkpoint()
        try mergeContents(of: tempDirectory, into: game.installDirectory)

        let executable = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        guard FileManager.default.fileExists(atPath: executable.path) else {
            throw ArchiveInstallerError.expectedExecutableMissing(game.executableRelativePath)
        }

        await onEvent(.validatingInstall(path: game.executableRelativePath))
        try await operationController?.checkpoint()
        let metadata = InstalledGameMetadata(
            gameID: game.id,
            installMode: .archivePackage,
            installedAt: Date(),
            sourceArchiveFileName: archiveURL.lastPathComponent,
            executableRelativePath: game.executableRelativePath,
            version: nil
        )
        let metadataURL = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
    }

    private func normalizedArchiveURL(for archiveURL: URL, game: GameDefinition) -> URL {
        guard game.packageSource?.archiveFormat == .multipartZip else {
            return archiveURL
        }

        let lowercasedName = archiveURL.lastPathComponent.lowercased()
        if lowercasedName.hasSuffix(".001") {
            return archiveURL
        }

        let firstPartCandidate = archiveURL.deletingPathExtension().appendingPathExtension("001")
        if FileManager.default.fileExists(atPath: firstPartCandidate.path) {
            return firstPartCandidate
        }

        return archiveURL
    }

    private func mergeContents(of sourceDirectory: URL, into destinationDirectory: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: [URLResourceKey.isDirectoryKey]
        ) else {
            return
        }

        for case let source as URL in enumerator {
            let relativePath = source.path.replacingOccurrences(of: sourceDirectory.path + "/", with: "")
            let destination = destinationDirectory.appendingPathComponent(relativePath)
            let values = try source.resourceValues(forKeys: [.isDirectoryKey])

            if values.isDirectory == true {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                continue
            }

            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: source, to: destination)
        }
    }
}
