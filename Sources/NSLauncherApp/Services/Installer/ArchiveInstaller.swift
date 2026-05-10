import Foundation

/// Archive installation failures reported before localization.
enum ArchiveInstallerError: LocalizedError {
    case packageSourceMissing
    case sevenZipBinaryMissing
    case sevenZipBinaryNotFound(String)
    case expectedExecutableMissing(String)

    var errorDescription: String? {
        switch self {
        case .packageSourceMissing:
            return "The selected game does not define an archive package."
        case .sevenZipBinaryMissing:
            return "7zz binary path is empty."
        case let .sevenZipBinaryNotFound(path):
            return "7zz executable not found. Checked: \(path)"
        case let .expectedExecutableMissing(path):
            return "Expected executable was not found after extraction: \(path)"
        }
    }
}

/// Boundary for extracting an archive package into a game install directory.
protocol ArchiveInstalling: Sendable {
    func install(
        archiveURL: URL,
        game: GameDefinition,
        settings: AppSettings,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

/// Installs downloaded or user-selected archives with 7-Zip.
struct ArchiveInstaller: ArchiveInstalling {
    private let processRunner: ProcessRunning

    init(processRunner: ProcessRunning) {
        self.processRunner = processRunner
    }

    /// Extracts an archive into a temporary folder, merges it into place, and writes install metadata.
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
        let sevenZipBinaryPath = BinaryLocator.resolveExecutable(
            preferredPath: settings.sevenZipBinaryPath,
            candidateNames: ["7zz", "7z", "7za"]
        )

        guard !settings.sevenZipBinaryPath.isEmpty || sevenZipBinaryPath != nil else {
            throw ArchiveInstallerError.sevenZipBinaryMissing
        }
        guard let sevenZipBinaryPath else {
            throw ArchiveInstallerError.sevenZipBinaryNotFound(settings.sevenZipBinaryPath)
        }
        try await operationController?.checkpoint()

        try FileManager.default.createDirectory(at: game.installDirectory, withIntermediateDirectories: true)

        // Extraction happens in a clean temp directory so failed runs do not leave partial files in place.
        let tempDirectory = URL(fileURLWithPath: settings.temporaryExtractionDirectory, isDirectory: true)
            .appendingPathComponent(game.id, isDirectory: true)
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        await onEvent(.extracting(path: archiveURL.lastPathComponent))
        try await operationController?.checkpoint()
        // 7-Zip expects the first .001 member when reading multipart zip packages.
        let extractionSource = normalizedArchiveURL(for: archiveURL, game: game)
        _ = try await processRunner.run(
            executable: sevenZipBinaryPath,
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
        let targetPaths = try extractedFileRelativePaths(in: tempDirectory)
        try InstallTargetPruner.pruneBeforeApplyingTarget(
            installDirectory: game.installDirectory,
            targetRelativePaths: targetPaths,
            protectedURLs: [game.winePrefixDirectory]
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

    /// Collects the exact file set produced by an archive extraction.
    private func extractedFileRelativePaths(in sourceDirectory: URL) throws -> Set<String> {
        guard let enumerator = FileManager.default.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        var paths = Set<String>()
        for case let source as URL in enumerator {
            let values = try source.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory != true else { continue }
            let relativePath = source.path.replacingOccurrences(of: sourceDirectory.path + "/", with: "")
            paths.insert(relativePath)
        }
        return paths
    }

    /// Returns the correct first archive part for multipart packages when possible.
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

    /// Moves extracted files into the install directory while preserving nested paths.
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
                // Create directories first so file moves can always assume their parent exists.
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
