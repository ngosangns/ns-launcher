import CryptoKit
import Foundation

enum ManifestInstallerError: LocalizedError {
    case manifestURLMissing
    case invalidResponse
    case checksumMismatch(path: String)

    var errorDescription: String? {
        switch self {
        case .manifestURLMissing:
            return "The selected game does not have a manifest URL."
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .checksumMismatch(path):
            return "Checksum mismatch for \(path)"
        }
    }
}

protocol ManifestInstalling: Sendable {
    func fetchManifest(for game: GameDefinition) async throws -> RemoteGameManifest
    func planInstall(for game: GameDefinition, manifest: RemoteGameManifest) async throws -> InstallPlan
    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

actor ManifestInstaller: ManifestInstalling {
    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func fetchManifest(for game: GameDefinition) async throws -> RemoteGameManifest {
        guard let manifestURL = game.manifestURL else {
            throw ManifestInstallerError.manifestURLMissing
        }

        let (data, response) = try await session.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ManifestInstallerError.invalidResponse
        }

        return try JSONDecoder().decode(RemoteGameManifest.self, from: data)
    }

    func planInstall(for game: GameDefinition, manifest: RemoteGameManifest) async throws -> InstallPlan {
        let peakTemp = manifest.files.map(\.size).max() ?? 0
        let steps = manifest.files.flatMap { file in
            [
                InstallStep(kind: .createDirectory, relativePath: (file.path as NSString).deletingLastPathComponent, bytes: 0),
                InstallStep(kind: .downloadFile, relativePath: file.path, bytes: file.size),
                InstallStep(kind: .moveIntoPlace, relativePath: file.path, bytes: file.size),
                InstallStep(kind: .verifyChecksum, relativePath: file.path, bytes: file.size)
            ]
        }

        let total = manifest.files.reduce(Int64(0)) { $0 + $1.size }
        return InstallPlan(version: manifest.version, steps: steps, estimatedBytesToDownload: total, peakTemporaryBytes: peakTemp)
    }

    func install(
        game: GameDefinition,
        manifest: RemoteGameManifest,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try fileManager.createDirectory(at: game.installDirectory, withIntermediateDirectories: true)

        for file in manifest.files {
            let destination = game.installDirectory.appendingPathComponent(file.path)
            let directory = destination.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let partial = destination.appendingPathExtension("partial")
            if fileManager.fileExists(atPath: partial.path) {
                try fileManager.removeItem(at: partial)
            }

            await onEvent(.preparing(file.path))

            let (downloadURL, response) = try await session.download(from: file.url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw ManifestInstallerError.invalidResponse
            }

            if fileManager.fileExists(atPath: partial.path) {
                try fileManager.removeItem(at: partial)
            }
            try fileManager.moveItem(at: downloadURL, to: partial)

            await onEvent(.downloading(path: file.path, received: file.size, total: file.size))

            if let sha256 = file.sha256 {
                await onEvent(.verifying(path: file.path))
                try verifySHA256(of: partial, expectedHex: sha256, path: file.path)
            }

            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: partial, to: destination)
        }

        let metadata = game.installDirectory.appendingPathComponent(".nslauncher-install.json")
        let data = try JSONEncoder().encode(["version": manifest.version])
        try data.write(to: metadata, options: .atomic)
        await onEvent(.finished(version: manifest.version))
    }

    private func verifySHA256(of fileURL: URL, expectedHex: String, path: String) throws {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = try? handle.read(upToCount: 1024 * 1024)
            guard let data, !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(expectedHex) == .orderedSame else {
            throw ManifestInstallerError.checksumMismatch(path: path)
        }
    }
}
