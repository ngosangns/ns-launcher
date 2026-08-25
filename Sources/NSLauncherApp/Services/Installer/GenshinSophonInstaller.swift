// GenshinSophonInstaller.swift
//
// HoYoPlay Sophon install/update backend — the single download path for Genshin.
//
// Fresh install and update share this pipeline (a fresh install is just a delta
// against an empty local root):
//   1. getGameBranches → live branch (package id, branch, password, tag).
//   2. getBuild → category manifests (game resources + voice-over packs).
//   3. Select the "game" manifest plus the user-selected voice manifest.
//   4. Download zstd-compressed protobuf manifests; verify compressed size,
//      decompressed size, and manifest MD5.
//   5. Decode assets/chunks; plan changed assets by local size + asset MD5.
//   6. Prune files outside the target set (via InstallTargetPruner).
//   7. Download missing chunks with bounded concurrency; decompress with in-process
//      libzstd when available (CLI fallback); verify each decompressed chunk MD5;
//      write by offset into `.nslauncher-sophon-staging`.
//   8. Verify the full asset MD5 and atomically replace the final file.
//   9. Write `.nslauncher-install.json` only after the expected executable exists.
//
// Tuning: concurrency is split into asset workers (`maxConcurrentAssets`), per-asset
// chunk tasks (`maxConcurrentChunksPerAsset`), and a global HTTP request cap
// (`maxActiveChunkRequests`) to avoid CDN throttling. Resume state is flushed every
// `stateFlushChunkCount` chunks instead of per chunk, trading a few re-downloaded
// chunks after a crash for far less metadata I/O.
//
// Storage inventory: `fetchStorageInventory` decodes the game and voice manifests,
// then reports local bytes without hashing assets; `removeVoicePack` deletes only the
// files named by that category's manifest so game resources are never touched. The category
// `matching_field` values (`game`, `en-us`, `zh-cn`, `ja-jp`, `ko-kr`) come from the
// live API; if HoYoverse changes them, unknown packs still list via `categoryName`.

import CryptoKit
import Darwin
import Foundation

/// Errors specific to HoYoPlay Sophon metadata and chunk reconstruction.
enum SophonInstallerError: LocalizedError {
    case metadataUnavailable
    case buildUnavailable
    case manifestUnavailable(String)
    case manifestChecksumMismatch(String)
    case zstdUnavailable
    case zstdFailed(String)
    case invalidManifest(String)
    case invalidChunk(String)
    case checksumMismatch(String)
    case expectedExecutableMissing(String)
    case voicePackUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .metadataUnavailable:
            return "Sophon metadata is unavailable."
        case .buildUnavailable:
            return "Sophon build metadata is unavailable."
        case let .voicePackUnavailable(field):
            return "Voice pack is unavailable: \(field)"
        case let .manifestUnavailable(path):
            return "Sophon manifest is unavailable: \(path)"
        case let .manifestChecksumMismatch(path):
            return "Sophon manifest checksum mismatch: \(path)"
        case .zstdUnavailable:
            return "zstd binary was not found."
        case let .zstdFailed(details):
            return "zstd decompression failed: \(details)"
        case let .invalidManifest(path):
            return "Invalid Sophon manifest: \(path)"
        case let .invalidChunk(path):
            return "Invalid Sophon chunk: \(path)"
        case let .checksumMismatch(path):
            return "Checksum mismatch for Sophon asset: \(path)"
        case let .expectedExecutableMissing(path):
            return "Expected executable was not found after Sophon update: \(path)"
        }
    }
}

/// Boundary for Genshin's newer HoYoPlay Sophon update flow.
protocol SophonInstalling: Sendable {
    func fetchBuild(
        language: AppLanguage,
        voiceMatchingField: String,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)?
    ) async throws -> SophonBuild
    /// Builds local storage inventory from the live Sophon manifests.
    func fetchStorageInventory(
        game: GameDefinition,
        language: AppLanguage,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)?
    ) async throws -> GameStorageInventory
    /// Deletes the local files of one non-selected voice pack and returns the freed byte count.
    func removeVoicePack(
        matchingField: String,
        game: GameDefinition,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)?
    ) async throws -> Int64
    func planUpdate(
        for game: GameDefinition,
        build: SophonBuild,
        installedMetadata: InstalledGameMetadata?,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)?
    ) async throws -> GameUpdatePlan
    func update(
        game: GameDefinition,
        version: String,
        targetAssets: [SophonAsset],
        assets: [SophonAsset],
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws
}

/// Downloads zstd-compressed Sophon manifests/chunks and reconstructs final game files.
actor GenshinSophonInstaller: SophonInstalling {
    private static let gameBranchesURL = "https://sg-hyp-api.hoyoverse.com/hyp/hyp-connect/api/getGameBranches"
    private static let getBuildURL = "https://sg-public-api.hoyoverse.com/downloader/sophon_chunk/api/getBuild"
    private static let gameID = "gopR6Cufr3"
    private static let launcherID = "VYTpXlbWo8"
    private static let platApp = "ddxf6vlr1reo"
    private static let maxConcurrentAssets = 2
    private static let maxConcurrentChunksPerAsset = 6
    private static let maxActiveChunkRequests = 12
    private static let stateFlushChunkCount = 64
    private static let connectionRetryDelayNanoseconds: UInt64 = 2_000_000_000

    private let session: URLSession
    private let fileManager: FileManager
    private let zstd: ZstdDecompressing
    private let requestLimiter = SophonDownloadRequestLimiter(maxConcurrentRequests: maxActiveChunkRequests)

    init(
        session: URLSession? = nil,
        fileManager: FileManager = .default,
        zstd: ZstdDecompressing = ZstdDecompressor()
    ) {
        self.session = session ?? Self.makeDownloadSession()
        self.fileManager = fileManager
        self.zstd = zstd
    }

    /// Builds the URLSession used for high-concurrency Sophon metadata and chunk downloads.
    private static func makeDownloadSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = maxActiveChunkRequests
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    /// Fetches and decodes the selected Genshin Sophon build.
    func fetchBuild(
        language: AppLanguage,
        voiceMatchingField: String,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> SophonBuild {
        await onEvent?(.diagnostic("fetch branch metadata language=\(language.officialMetadataLanguageCode)"))
        let branch = try await fetchBranch(language: language)
        await onEvent?(.diagnostic("branch resolved package=\(branch.packageID) tag=\(branch.tag) branch=\(branch.branch.isEmpty ? "main" : branch.branch)"))
        await onEvent?(.diagnostic("fetch Sophon build metadata"))
        let buildResponse = try await fetchBuildResponse(branch: branch)
        let selectedIdentities = selectInstallIdentities(from: buildResponse.data.manifests, voiceMatchingField: voiceMatchingField)
        await onEvent?(.diagnostic("build tag=\(buildResponse.data.tag.isEmpty ? branch.tag : buildResponse.data.tag) manifests total=\(buildResponse.data.manifests.count) selected=\(selectedIdentities.map(\.matchingField).joined(separator: ","))"))
        guard !selectedIdentities.isEmpty else {
            throw SophonInstallerError.buildUnavailable
        }

        var manifests: [SophonCategoryManifest] = []
        for identity in selectedIdentities {
            await onEvent?(.diagnostic("fetch manifest field=\(identity.matchingField) compressed=\(Self.formatBytes(identity.manifest.compressedSize)) uncompressed=\(Self.formatBytes(identity.manifest.uncompressedSize)) files=\(identity.stats.fileCount) chunks=\(identity.stats.chunkCount)"))
            let manifest = try await fetchCategoryManifest(identity: identity, onEvent: onEvent)
            await onEvent?(.diagnostic("decoded manifest field=\(manifest.matchingField) assets=\(manifest.assets.count) files=\(manifest.fileCount) chunks=\(manifest.chunkCount)"))
            manifests.append(manifest)
        }

        return SophonBuild(
            version: buildResponse.data.tag.isEmpty ? branch.tag : buildResponse.data.tag,
            packageID: branch.packageID,
            manifests: manifests
        )
    }

    /// Builds local storage inventory from game and voice manifests without hashing files.
    func fetchStorageInventory(
        game: GameDefinition,
        language: AppLanguage,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> GameStorageInventory {
        let branch = try await fetchBranch(language: language)
        await onEvent?(.diagnostic("fetch storage inventory branch tag=\(branch.tag)"))
        let buildResponse = try await fetchBuildResponse(branch: branch)
        var voicePackages: [VoicePackage] = []
        var gameAssets: [SophonAsset] = []

        for identity in buildResponse.data.manifests {
            let manifest = try await fetchCategoryManifest(identity: identity, onEvent: onEvent)
            let assets = manifest.assets.filter { !$0.isDirectory }
            if identity.matchingField == "game" {
                gameAssets = assets
                continue
            }

            let localStats = localStorageStats(for: assets, game: game)
            guard localStats.fileCount > 0 else { continue }
            voicePackages.append(
                VoicePackage(
                    matchingField: identity.matchingField,
                    categoryName: identity.categoryName,
                    localBytes: localStats.bytes,
                    localFileCount: localStats.fileCount
                )
            )
        }

        let audioAssets = gameAssets.filter { Self.isAudioAsset($0.path) }
        return GameStorageInventory(
            voicePackages: voicePackages,
            contentGroups: [
                storageGroup(kind: .audio, assets: audioAssets, game: game)
            ],
            questAssetAnalysis: questAssetAnalysis(for: gameAssets, game: game)
        )
    }

    private func storageGroup(
        kind: StorageContentKind,
        assets: [SophonAsset],
        game: GameDefinition
    ) -> StorageContentGroup {
        let localStats = localStorageStats(for: assets, game: game)
        return StorageContentGroup(
            kind: kind,
            localBytes: localStats.bytes,
            localFileCount: localStats.fileCount,
            availableBytes: assets.reduce(Int64(0)) { $0 + $1.size },
            availableFileCount: assets.count
        )
    }

    /// Reports only local runtime-container totals and never infers quest ownership.
    private func questAssetAnalysis(for assets: [SophonAsset], game: GameDefinition) -> QuestAssetAnalysis {
        var totals: [QuestAssetContainerKind: (bytes: Int64, fileCount: Int)] = [:]

        for asset in assets {
            guard !asset.isDirectory,
                  let kind = QuestAssetContainerClassifier.kind(for: asset.path) else {
                continue
            }
            let destination = game.installDirectory.appendingPathComponent(asset.path)
            guard let attributes = try? fileManager.attributesOfItem(atPath: destination.path),
                  let size = (attributes[.size] as? NSNumber)?.int64Value else {
                continue
            }
            let current = totals[kind] ?? (bytes: 0, fileCount: 0)
            totals[kind] = (bytes: current.bytes + size, fileCount: current.fileCount + 1)
        }

        let groups = QuestAssetContainerKind.allCases.compactMap { kind -> QuestAssetContainerGroup? in
            guard let total = totals[kind], total.fileCount > 0 else { return nil }
            return QuestAssetContainerGroup(
                kind: kind,
                localBytes: total.bytes,
                localFileCount: total.fileCount
            )
        }
        return QuestAssetAnalysis(containerGroups: groups, mappingStatus: .unavailable)
    }

    private func localStorageStats(for assets: [SophonAsset], game: GameDefinition) -> (bytes: Int64, fileCount: Int) {
        assets.reduce(into: (bytes: Int64(0), fileCount: 0)) { stats, asset in
            let destination = game.installDirectory.appendingPathComponent(asset.path)
            guard let attributes = try? fileManager.attributesOfItem(atPath: destination.path),
                  let size = (attributes[.size] as? NSNumber)?.int64Value else {
                return
            }
            stats.bytes += size
            stats.fileCount += 1
        }
    }

    private static func isAudioAsset(_ path: String) -> Bool {
        let normalized = path.lowercased()
        let components = normalized.split(separator: "/")
        let audioDirectories = ["audio", "sound", "voice", "music"]
        if components.dropLast().contains(where: { audioDirectories.contains(String($0)) }) {
            return true
        }

        guard let dot = normalized.lastIndex(of: ".") else { return false }
        let audioExtensions = ["acb", "awb", "bnk", "m4a", "mp3", "ogg", "opus", "pck", "wav", "wem"]
        return audioExtensions.contains(String(normalized[normalized.index(after: dot)...]))
    }

    /// Deletes the local files of one non-selected voice pack and returns the freed byte count.
    func removeVoicePack(
        matchingField: String,
        game: GameDefinition,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> Int64 {
        let branch = try await fetchBranch(language: .english)
        let buildResponse = try await fetchBuildResponse(branch: branch)
        guard let identity = buildResponse.data.manifests.first(where: { $0.matchingField == matchingField }) else {
            throw SophonInstallerError.voicePackUnavailable(matchingField)
        }
        await onEvent?(.diagnostic("remove voice pack field=\(matchingField) files=\(identity.stats.fileCount)"))

        let manifest = try await fetchCategoryManifest(identity: identity, onEvent: onEvent)
        let assetPaths = manifest.assets.filter { !$0.isDirectory }.map(\.path)
        await onEvent?(.diagnostic("voice pack \(matchingField) decoded assets=\(assetPaths.count)"))

        var freedBytes: Int64 = 0
        for relativePath in assetPaths {
            let destination = game.installDirectory.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: destination.path) else { continue }
            guard !Self.isProtectedInstallPath(relativePath) else {
                await onEvent?(.diagnostic("skip protected voice asset \(relativePath)"))
                continue
            }
            let attributes = try? fileManager.attributesOfItem(atPath: destination.path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            try fileManager.removeItem(at: destination)
            freedBytes += size
        }
        await onEvent?(.diagnostic("voice pack \(matchingField) removed files=\(assetPaths.count) freed=\(Self.formatBytes(freedBytes))"))
        return freedBytes
    }

    /// Guards against removing launcher metadata, staging, or the Wine prefix when deleting voice assets.
    private static func isProtectedInstallPath(_ relativePath: String) -> Bool {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        let protectedPrefixes = [".nslauncher-install.json", ".nslauncher-sophon-staging", ".wine"]
        return protectedPrefixes.contains(where: { normalized == $0 || normalized.hasPrefix($0 + "/") })
    }

    /// Computes a full-build Sophon delta by checking existing files by size and MD5.
    ///
    /// The target set is the full manifest: any file the launcher withholds is one the
    /// game re-downloads for itself into `GenshinImpact_Data/Persistent`, so filtering
    /// here saves nothing and only moves the bytes onto a slower, unobserved path.
    func planUpdate(
        for game: GameDefinition,
        build: SophonBuild,
        installedMetadata: InstalledGameMetadata?,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)? = nil
    ) async throws -> GameUpdatePlan {
        let assets = build.manifests.flatMap(\.assets).filter { !$0.isDirectory }
        await onEvent?(.diagnostic("scan local install root=\(game.installDirectory.path) targetAssets=\(assets.count) installedVersion=\(installedMetadata?.version ?? "missing") latestVersion=\(build.version)"))
        var assetsToWrite: [SophonAsset] = []
        var skippedAssets = 0

        for (index, asset) in assets.enumerated() {
            let destination = game.installDirectory.appendingPathComponent(asset.path)
            if try existingAssetMatches(asset, at: destination) {
                skippedAssets += 1
            } else {
                assetsToWrite.append(asset)
            }
            if (index + 1).isMultiple(of: 250) || index + 1 == assets.count {
                await onEvent?(.diagnostic("scan progress \(index + 1)/\(assets.count) valid=\(skippedAssets) changed=\(assetsToWrite.count) current=\(asset.path)"))
            }
        }

        let compressedBytes = assetsToWrite.reduce(Int64(0)) { $0 + $1.compressedBytes }
        let decompressedBytes = assetsToWrite.reduce(Int64(0)) { $0 + $1.size }
        await onEvent?(.diagnostic("plan computed changed=\(assetsToWrite.count) valid=\(skippedAssets) download=\(Self.formatBytes(compressedBytes)) write=\(Self.formatBytes(decompressedBytes))"))
        let metadataNeedsUpdate = installedMetadata?.gameID != game.id
            || installedMetadata?.installMode != game.installerStrategy
            || installedMetadata?.executableRelativePath != game.executableRelativePath
            || installedMetadata?.version != build.version

        return GameUpdatePlan(
            sourceKind: .sophon,
            installedVersion: installedMetadata?.version,
            latestVersion: build.version,
            sophonTargetAssets: assets,
            sophonAssetsToWrite: assetsToWrite,
            sophonSkippedAssets: skippedAssets,
            bytesToDownload: compressedBytes,
            decompressedBytesToWrite: decompressedBytes,
            peakTemporaryBytes: min(
                assetsToWrite.sorted { $0.size > $1.size }.prefix(Self.maxConcurrentAssets).reduce(Int64(0)) { $0 + $1.size },
                decompressedBytes
            ),
            metadataNeedsUpdate: metadataNeedsUpdate
        )
    }

    /// Applies Sophon assets through staging files and atomic replacement.
    func update(
        game: GameDefinition,
        version: String,
        targetAssets: [SophonAsset],
        assets: [SophonAsset],
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        await onEvent(.diagnostic("apply Sophon plan assetsToWrite=\(assets.count) targetAssets=\(targetAssets.count) version=\(version)"))
        try fileManager.createDirectory(at: game.installDirectory, withIntermediateDirectories: true)
        let progress = SophonProgressTracker(totalBytes: assets.reduce(Int64(0)) { $0 + $1.compressedBytes })
        let queue = SophonAssetQueue(assets: assets)
        try await operationController?.checkpoint()
        await onEvent(.diagnostic("prune install target before apply"))
        try InstallTargetPruner.pruneBeforeApplyingTarget(
            installDirectory: game.installDirectory,
            targetRelativePaths: Set(targetAssets.map(\.path)),
            protectedURLs: [game.winePrefixDirectory] + Self.gameOwnedRuntimeDirectories(in: game),
            fileManager: fileManager
        )
        await onEvent(.diagnostic("prune completed; start workers assets=\(min(Self.maxConcurrentAssets, max(assets.count, 1))) chunkConcurrencyPerAsset=\(Self.maxConcurrentChunksPerAsset) requestLimit=\(Self.maxActiveChunkRequests)"))
        try await operationController?.checkpoint()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<min(Self.maxConcurrentAssets, max(assets.count, 1)) {
                group.addTask {
                    while let asset = await queue.next() {
                        try await self.installAsset(
                            asset,
                            for: game,
                            operationController: operationController,
                            progress: progress,
                            onEvent: onEvent
                        )
                    }
                }
            }

            try await group.waitForAll()
        }
        await onEvent(.diagnostic("asset workers completed; flush progress"))
        await progress.flush(onEvent: onEvent)

        let executable = game.installDirectory.appendingPathComponent(game.executableRelativePath)
        await onEvent(.diagnostic("validate executable path=\(executable.path)"))
        guard fileManager.fileExists(atPath: executable.path) else {
            throw SophonInstallerError.expectedExecutableMissing(game.executableRelativePath)
        }

        let metadata = InstalledGameMetadata(
            gameID: game.id,
            installMode: game.installerStrategy,
            installedAt: Date(),
            executableRelativePath: game.executableRelativePath,
            version: version
        )
        let data = try JSONEncoder().encode(metadata)
        await onEvent(.diagnostic("write install metadata .nslauncher-install.json"))
        try data.write(to: game.installDirectory.appendingPathComponent(".nslauncher-install.json"), options: .atomic)

        // Best-effort removal of the staging tree after success. Assets are moved out
        // of staging one by one, which would otherwise leave an empty
        // `.nslauncher-sophon-staging` folder behind — and that folder trips the
        // "partial update staging" launch preflight on the next run.
        let stagingDirectory = game.installDirectory
            .appendingPathComponent(".nslauncher-sophon-staging", isDirectory: true)
        if fileManager.fileExists(atPath: stagingDirectory.path) {
            do {
                try fileManager.removeItem(at: stagingDirectory)
                await onEvent(.diagnostic("removed leftover staging directory after successful apply"))
            } catch {
                await onEvent(.diagnostic("failed to remove leftover staging directory: \(error.localizedDescription)"))
            }
        }
        await onEvent(.finished(version: version))
    }

    private func installAsset(
        _ asset: SophonAsset,
        for game: GameDefinition,
        operationController: OperationController?,
        progress: SophonProgressTracker,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await operationController?.checkpoint()
        let destination = game.installDirectory.appendingPathComponent(asset.path)
        if try existingAssetMatches(asset, at: destination) {
            await progress.registerExistingBytes(asset.compressedBytes, path: asset.path, fileTotal: asset.compressedBytes, onEvent: onEvent)
            return
        }

        await onEvent(.preparing(asset.path))
        let staging = stagingURL(for: asset, game: game)
        let stateURL = staging.appendingPathExtension("chunks.json")
        try fileManager.createDirectory(at: staging.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: staging.path) {
            try? fileManager.removeItem(at: stateURL)
            fileManager.createFile(atPath: staging.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: staging)
        try handle.truncate(atOffset: UInt64(asset.size))
        try handle.close()

        let state = SophonAssetStateStore(url: stateURL)
        var completed = try state.load(asset: asset)
        if !completed.isEmpty {
            await onEvent(.diagnostic("resume state loaded asset=\(asset.path) completedChunks=\(completed.count)/\(asset.chunks.count)"))
            let validatedCompleted = try await validateCompletedChunks(
                completed,
                of: asset,
                at: staging,
                onEvent: onEvent
            )
            if validatedCompleted != completed {
                completed = validatedCompleted
                try state.save(completed: completed, asset: asset)
                await onEvent(.diagnostic("resume state repaired asset=\(asset.path) validChunks=\(completed.count)/\(asset.chunks.count)"))
            } else {
                await onEvent(.diagnostic("resume state verified asset=\(asset.path) validChunks=\(completed.count)/\(asset.chunks.count)"))
            }
        }
        let completedBytes = asset.chunks
            .filter { completed.contains($0.resumeKey) }
            .reduce(Int64(0)) { $0 + $1.compressedSize }
        if completedBytes > 0 {
            await progress.registerExistingBytes(
                completedBytes,
                path: asset.path,
                fileTotal: asset.compressedBytes,
                onEvent: onEvent
            )
        }
        let writer = try SophonAssetWriter(url: staging)
        do {
            try await installPendingChunks(
                asset.chunks.filter { !completed.contains($0.resumeKey) },
                of: asset,
                completed: &completed,
                state: state,
                writer: writer,
                progress: progress,
                operationController: operationController,
                onEvent: onEvent
            )
            try await writer.close()
        } catch {
            try? await writer.close()
            throw error
        }

        await onEvent(.verifying(path: asset.path))
        try verifyAsset(asset, at: staging)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: staging, to: destination)
        try? fileManager.removeItem(at: staging.appendingPathExtension("chunks.json"))
    }

    private func validateCompletedChunks(
        _ completed: Set<String>,
        of asset: SophonAsset,
        at staging: URL,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws -> Set<String> {
        guard !completed.isEmpty else { return [] }

        var validCompleted = Set<String>()
        let handle = try FileHandle(forReadingFrom: staging)
        defer { try? handle.close() }

        for chunk in asset.chunks where completed.contains(chunk.resumeKey) || completed.contains(chunk.name) {
            await Task.yield()
            if try stagedChunkMatches(chunk, handle: handle) {
                validCompleted.insert(chunk.resumeKey)
            } else {
                await onEvent(.diagnostic("resume chunk invalid; redownload asset=\(asset.path) chunk=\(chunk.name) offset=\(chunk.offset)"))
            }
        }

        return validCompleted
    }

    private func stagedChunkMatches(_ chunk: SophonChunk, handle: FileHandle) throws -> Bool {
        guard chunk.offset >= 0,
              chunk.decompressedSize >= 0,
              chunk.decompressedSize <= Int64(Int.max) else {
            return false
        }

        try handle.seek(toOffset: UInt64(chunk.offset))
        let data = try handle.read(upToCount: Int(chunk.decompressedSize)) ?? Data()
        guard Int64(data.count) == chunk.decompressedSize else {
            return false
        }
        return md5Hex(data).caseInsensitiveCompare(chunk.decompressedMD5) == .orderedSame
    }

    private func installPendingChunks(
        _ chunks: [SophonChunk],
        of asset: SophonAsset,
        completed: inout Set<String>,
        state: SophonAssetStateStore,
        writer: SophonAssetWriter,
        progress: SophonProgressTracker,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        guard !chunks.isEmpty else { return }

        try await withThrowingTaskGroup(of: String.self) { group in
            var nextIndex = 0
            var activeTasks = 0
            var chunksSinceStateSave = 0

            func enqueueNextChunk() {
                guard nextIndex < chunks.count else { return }
                let chunk = chunks[nextIndex]
                nextIndex += 1
                activeTasks += 1
                group.addTask {
                    try await self.downloadAndWriteChunk(
                        chunk,
                        of: asset,
                        writer: writer,
                        progress: progress,
                        operationController: operationController,
                        onEvent: onEvent
                    )
                    return chunk.resumeKey
                }
            }

            for _ in 0..<min(Self.maxConcurrentChunksPerAsset, chunks.count) {
                enqueueNextChunk()
            }

            while activeTasks > 0 {
                guard let chunkKey = try await group.next() else { break }
                activeTasks -= 1
                completed.insert(chunkKey)
                chunksSinceStateSave += 1
                if chunksSinceStateSave >= Self.stateFlushChunkCount {
                    try state.save(completed: completed, asset: asset)
                    chunksSinceStateSave = 0
                }
                try await operationController?.checkpoint()
                enqueueNextChunk()
            }

            if chunksSinceStateSave > 0 {
                try state.save(completed: completed, asset: asset)
            }
        }
    }

    private func downloadAndWriteChunk(
        _ chunk: SophonChunk,
        of asset: SophonAsset,
        writer: SophonAssetWriter,
        progress: SophonProgressTracker,
        operationController: OperationController?,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async throws {
        try await operationController?.checkpoint()
        let compressedData = try await downloadChunkWithRetry(chunk, operationController: operationController)
        try await operationController?.checkpoint()
        let decompressedData = try await zstd.decompress(compressedData, expectedSize: chunk.decompressedSize)
        guard Int64(decompressedData.count) == chunk.decompressedSize,
              md5Hex(decompressedData).caseInsensitiveCompare(chunk.decompressedMD5) == .orderedSame else {
            throw SophonInstallerError.invalidChunk(chunk.name)
        }

        try await writer.write(decompressedData, at: chunk.offset)

        await progress.advance(
            bytes: chunk.compressedSize,
            path: asset.path,
            fileTotal: asset.compressedBytes,
            onEvent: onEvent
        )
    }

    private func downloadChunkWithRetry(
        _ chunk: SophonChunk,
        operationController: OperationController?
    ) async throws -> Data {
        var attempts = 0
        while true {
            try await operationController?.checkpoint()
            do {
                return try await downloadChunk(chunk)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                attempts += 1
                guard attempts < 4, shouldRetryChunkDownload(error) else {
                    throw error
                }
                try await waitForRetryDelay(operationController: operationController)
            }
        }
    }

    private func downloadChunk(_ chunk: SophonChunk) async throws -> Data {
        await requestLimiter.acquire()

        var request = URLRequest(url: chunk.url)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let compressedData: Data
        let response: URLResponse
        do {
            (compressedData, response) = try await session.data(for: request)
            await requestLimiter.release()
        } catch {
            await requestLimiter.release()
            throw error
        }
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SophonInstallerError.invalidChunk(chunk.name)
        }
        guard Int64(compressedData.count) == chunk.compressedSize else {
            throw SophonInstallerError.invalidChunk(chunk.name)
        }

        return compressedData
    }

    private func shouldRetryChunkDownload(_ error: Error) -> Bool {
        if case SophonInstallerError.invalidChunk = error {
            return true
        }
        guard let urlError = error as? URLError else {
            return false
        }
        switch urlError.code {
        case .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }

    /// Sleeps in short chunks so pause/stop remains responsive during retry backoff.
    private func waitForRetryDelay(operationController: OperationController?) async throws {
        let slice: UInt64 = 250_000_000
        var waited: UInt64 = 0
        while waited < Self.connectionRetryDelayNanoseconds {
            try await operationController?.checkpoint()
            let delay = min(slice, Self.connectionRetryDelayNanoseconds - waited)
            try await Task.sleep(nanoseconds: delay)
            waited += delay
        }
    }

    private func fetchBranch(language: AppLanguage) async throws -> SophonBranch {
        var components = URLComponents(string: Self.gameBranchesURL)
        components?.queryItems = [
            URLQueryItem(name: "game_ids[]", value: Self.gameID),
            URLQueryItem(name: "launcher_id", value: Self.launcherID),
            URLQueryItem(name: "language", value: language.officialMetadataLanguageCode)
        ]
        guard let url = components?.url else { throw SophonInstallerError.metadataUnavailable }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SophonInstallerError.metadataUnavailable
        }

        let decoded = try JSONDecoder().decode(SophonBranchesResponse.self, from: data)
        guard let branch = decoded.data.gameBranches.first(where: { $0.game.biz == "hk4e_global" })?.main,
              !branch.tag.isEmpty,
              !branch.packageID.isEmpty else {
            throw SophonInstallerError.metadataUnavailable
        }
        return branch
    }

    private func fetchBuildResponse(branch: SophonBranch) async throws -> SophonBuildResponse {
        var components = URLComponents(string: Self.getBuildURL)
        components?.queryItems = [
            URLQueryItem(name: "branch", value: branch.branch.isEmpty ? "main" : branch.branch),
            URLQueryItem(name: "package_id", value: branch.packageID),
            URLQueryItem(name: "password", value: branch.password),
            URLQueryItem(name: "plat_app", value: Self.platApp)
        ]
        guard let url = components?.url else { throw SophonInstallerError.buildUnavailable }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SophonInstallerError.buildUnavailable
        }

        let decoded = try JSONDecoder().decode(SophonBuildResponse.self, from: data)
        guard decoded.retcode == 0, !decoded.data.manifests.isEmpty else {
            throw SophonInstallerError.buildUnavailable
        }
        return decoded
    }

    private func selectInstallIdentities(
        from identities: [SophonBuildIdentity],
        voiceMatchingField: String
    ) -> [SophonBuildIdentity] {
        identities.filter { identity in
            identity.matchingField == "game" || identity.matchingField == voiceMatchingField
        }
    }

    private func fetchCategoryManifest(
        identity: SophonBuildIdentity,
        onEvent: (@Sendable (InstallProgressEvent) async -> Void)?
    ) async throws -> SophonCategoryManifest {
        let manifestURL = identity.manifestDownload.urlPrefix.appendingPathComponent(identity.manifest.id, isDirectory: false)
        let (data, response) = try await session.data(from: manifestURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SophonInstallerError.manifestUnavailable(identity.manifest.id)
        }
        guard Int64(data.count) == identity.manifest.compressedSize else {
            throw SophonInstallerError.manifestUnavailable(identity.manifest.id)
        }
        await onEvent?(.diagnostic("manifest downloaded field=\(identity.matchingField) bytes=\(Self.formatBytes(Int64(data.count)))"))
        let decompressedData = try await zstd.decompress(data, expectedSize: identity.manifest.uncompressedSize)
        await onEvent?(.diagnostic("manifest decompressed field=\(identity.matchingField) bytes=\(Self.formatBytes(Int64(decompressedData.count)))"))
        guard Int64(decompressedData.count) == identity.manifest.uncompressedSize else {
            throw SophonInstallerError.invalidManifest(identity.manifest.id)
        }
        guard md5Hex(decompressedData).caseInsensitiveCompare(identity.manifest.checksum) == .orderedSame else {
            throw SophonInstallerError.manifestChecksumMismatch(identity.manifest.id)
        }
        await onEvent?(.diagnostic("manifest checksum ok field=\(identity.matchingField)"))

        let assets = try SophonManifestProtoDecoder().decodeAssets(
            decompressedData,
            matchingField: identity.matchingField,
            categoryName: identity.categoryName,
            chunkBaseURL: identity.chunkDownload.urlPrefix
        )

        return SophonCategoryManifest(
            categoryID: identity.categoryID,
            matchingField: identity.matchingField,
            categoryName: identity.categoryName,
            manifestID: identity.manifest.id,
            manifestMD5: identity.manifest.checksum,
            manifestCompressedSize: identity.manifest.compressedSize,
            manifestUncompressedSize: identity.manifest.uncompressedSize,
            manifestBaseURL: identity.manifestDownload.urlPrefix,
            chunkBaseURL: identity.chunkDownload.urlPrefix,
            compressedBytes: identity.stats.compressedSize,
            decompressedBytes: identity.stats.uncompressedSize,
            fileCount: identity.stats.fileCount,
            chunkCount: identity.stats.chunkCount,
            assets: assets
        )
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Directories the game itself writes and owns, which never appear in a Sophon manifest.
    ///
    /// `GenshinImpact_Data/Persistent` holds the client's own resource downloads plus
    /// `ctable.dat`, `res_versions_persist` and the download preferences. Pruning it makes the
    /// client treat the install as incomplete and re-download tens of gigabytes into it on the
    /// next launch, so it must survive every update.
    private static func gameOwnedRuntimeDirectories(in game: GameDefinition) -> [URL] {
        ["GenshinImpact_Data/Persistent"].map {
            game.installDirectory.appendingPathComponent($0, isDirectory: true)
        }
    }

    private func existingAssetMatches(_ asset: SophonAsset, at url: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: url.path),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              (attributes[.size] as? NSNumber)?.int64Value == asset.size else {
            return false
        }

        do {
            try verifyAsset(asset, at: url)
            return true
        } catch {
            return false
        }
    }

    private func verifyAsset(_ asset: SophonAsset, at url: URL) throws {
        guard try md5FileHex(url).caseInsensitiveCompare(asset.md5) == .orderedSame else {
            throw SophonInstallerError.checksumMismatch(asset.path)
        }
    }

    private func stagingURL(for asset: SophonAsset, game: GameDefinition) -> URL {
        game.installDirectory
            .appendingPathComponent(".nslauncher-sophon-staging", isDirectory: true)
            .appendingPathComponent(asset.matchingField, isDirectory: true)
            .appendingPathComponent(asset.path)
            .appendingPathExtension("partial")
    }
}

protocol ZstdDecompressing: Sendable {
    func decompress(_ data: Data, expectedSize: Int64) async throws -> Data
}

private struct ZstdDecompressor: ZstdDecompressing {
    private let processRunner: ProcessRunning
    private let dynamicLibrary = ZstdDynamicLibrary.load()

    init(processRunner: ProcessRunning = ProcessRunner()) {
        self.processRunner = processRunner
    }

    func decompress(_ data: Data, expectedSize: Int64) async throws -> Data {
        if let decompressed = try decompressInProcess(data, expectedSize: expectedSize) {
            return decompressed
        }

        return try await decompressWithCLI(data, expectedSize: expectedSize)
    }

    private func decompressInProcess(_ data: Data, expectedSize: Int64) throws -> Data? {
        guard let dynamicLibrary else { return nil }
        guard expectedSize >= 0, expectedSize <= Int64(Int.max) else {
            throw SophonInstallerError.invalidChunk("zstd-size")
        }

        var output = Data(count: Int(expectedSize))
        let decompressedSize = output.withUnsafeMutableBytes { outputBuffer in
            data.withUnsafeBytes { inputBuffer in
                dynamicLibrary.decompress(
                    outputBuffer.baseAddress,
                    outputBuffer.count,
                    inputBuffer.baseAddress,
                    inputBuffer.count
                )
            }
        }

        if dynamicLibrary.isError(decompressedSize) == 0 {
            guard decompressedSize == Int(expectedSize) else {
                throw SophonInstallerError.invalidChunk("zstd-size")
            }
            return output
        }

        return nil
    }

    private func decompressWithCLI(_ data: Data, expectedSize: Int64) async throws -> Data {
        guard BinaryLocator.resolveExecutable(preferredPath: "zstd", candidateNames: ["zstd"]) != nil else {
            throw SophonInstallerError.zstdUnavailable
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NSLauncher-Zstd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let input = tempDirectory.appendingPathComponent("input.zst")
        let output = tempDirectory.appendingPathComponent("output")
        try data.write(to: input)
        do {
            _ = try await processRunner.run(
                executable: "zstd",
                arguments: ["-q", "-d", "-f", input.path, "-o", output.path],
                environment: [:],
                currentDirectory: tempDirectory
            )
            let decompressed = try Data(contentsOf: output)
            guard Int64(decompressed.count) == expectedSize else {
                throw SophonInstallerError.invalidChunk("zstd-size")
            }
            return decompressed
        } catch let ProcessRunnerError.nonZeroExit(result) {
            throw SophonInstallerError.zstdFailed(result.stderr)
        } catch {
            throw error
        }
    }
}

private struct ZstdDynamicLibrary: @unchecked Sendable {
    typealias Decompress = @convention(c) (UnsafeMutableRawPointer?, Int, UnsafeRawPointer?, Int) -> Int
    typealias IsError = @convention(c) (Int) -> UInt32

    let handle: UnsafeMutableRawPointer
    let decompress: Decompress
    let isError: IsError

    static func load() -> ZstdDynamicLibrary? {
        let candidates = [
            "/opt/homebrew/lib/libzstd.dylib",
            "/usr/local/lib/libzstd.dylib",
            "libzstd.dylib"
        ]

        for candidate in candidates {
            guard let handle = dlopen(candidate, RTLD_NOW | RTLD_LOCAL) else { continue }
            guard let decompressSymbol = dlsym(handle, "ZSTD_decompress"),
                  let isErrorSymbol = dlsym(handle, "ZSTD_isError") else {
                dlclose(handle)
                continue
            }

            return ZstdDynamicLibrary(
                handle: handle,
                decompress: unsafeBitCast(decompressSymbol, to: Decompress.self),
                isError: unsafeBitCast(isErrorSymbol, to: IsError.self)
            )
        }

        return nil
    }
}

private actor SophonDownloadRequestLimiter {
    private let maxConcurrentRequests: Int
    private var activeRequests = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(maxConcurrentRequests: Int) {
        self.maxConcurrentRequests = maxConcurrentRequests
    }

    func acquire() async {
        if activeRequests < maxConcurrentRequests {
            activeRequests += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            activeRequests = max(activeRequests - 1, 0)
        }
    }
}

private actor SophonAssetWriter {
    private var handle: FileHandle?

    init(url: URL) throws {
        self.handle = try FileHandle(forWritingTo: url)
    }

    func write(_ data: Data, at offset: Int64) throws {
        guard let handle else { return }
        try handle.seek(toOffset: UInt64(offset))
        try handle.write(contentsOf: data)
    }

    func close() throws {
        guard let handle else { return }
        try handle.close()
        self.handle = nil
    }
}

private actor SophonAssetQueue {
    private let assets: [SophonAsset]
    private var index = 0

    init(assets: [SophonAsset]) {
        self.assets = assets.sorted { lhs, rhs in
            lhs.compressedBytes == rhs.compressedBytes
                ? lhs.path < rhs.path
                : lhs.compressedBytes > rhs.compressedBytes
        }
    }

    func next() -> SophonAsset? {
        guard index < assets.count else { return nil }
        let asset = assets[index]
        index += 1
        return asset
    }
}

private actor SophonProgressTracker {
    private var receivedBytes: Int64 = 0
    private var emittedBytes: Int64 = 0
    private let totalBytes: Int64
    private var fileBytes: [String: Int64] = [:]
    private var lastPath: String?
    private var lastFileTotal: Int64 = 0
    private var lastEmitDate = Date.distantPast
    private let emitByteThreshold: Int64 = 4 * 1024 * 1024
    private let emitTimeThreshold: TimeInterval = 0.25

    init(totalBytes: Int64) {
        self.totalBytes = totalBytes
    }

    func registerExistingBytes(
        _ bytes: Int64,
        path: String,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        receivedBytes += bytes
        fileBytes[path] = fileTotal
        lastPath = path
        lastFileTotal = fileTotal
        emittedBytes = receivedBytes
        lastEmitDate = Date()
        await onEvent(.downloadingSophonAsset(
            path: path,
            overallReceived: receivedBytes,
            overallTotal: totalBytes,
            fileReceived: fileTotal,
            fileTotal: fileTotal
        ))
    }

    func advance(
        bytes: Int64,
        path: String,
        fileTotal: Int64,
        onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void
    ) async {
        receivedBytes += bytes
        fileBytes[path, default: 0] = min((fileBytes[path] ?? 0) + bytes, fileTotal)
        lastPath = path
        lastFileTotal = fileTotal
        let now = Date()
        guard receivedBytes - emittedBytes >= emitByteThreshold
            || now.timeIntervalSince(lastEmitDate) >= emitTimeThreshold
            || receivedBytes >= totalBytes else {
            return
        }

        emittedBytes = receivedBytes
        lastEmitDate = now
        await onEvent(.downloadingSophonAsset(
            path: path,
            overallReceived: receivedBytes,
            overallTotal: totalBytes,
            fileReceived: fileBytes[path] ?? 0,
            fileTotal: fileTotal
        ))
    }

    func flush(onEvent: @escaping @Sendable (InstallProgressEvent) async -> Void) async {
        guard emittedBytes != receivedBytes, let lastPath else { return }
        emittedBytes = receivedBytes
        lastEmitDate = Date()
        await onEvent(.downloadingSophonAsset(
            path: lastPath,
            overallReceived: receivedBytes,
            overallTotal: totalBytes,
            fileReceived: fileBytes[lastPath] ?? 0,
            fileTotal: lastFileTotal
        ))
    }
}

private struct SophonAssetStateStore {
    var url: URL

    func load(asset: SophonAsset) throws -> Set<String> {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SophonAssetState.self, from: data),
              state.assetPath == asset.path,
              state.assetMD5 == asset.md5,
              state.assetSize == asset.size else {
            return []
        }
        return Set(state.completedChunks)
    }

    func save(completed: Set<String>, asset: SophonAsset) throws {
        let state = SophonAssetState(
            assetPath: asset.path,
            assetMD5: asset.md5,
            assetSize: asset.size,
            completedChunks: Array(completed).sorted()
        )
        let data = try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

private struct SophonAssetState: Codable {
    var assetPath: String
    var assetMD5: String
    var assetSize: Int64
    var completedChunks: [String]
}

private func md5Hex(_ data: Data) -> String {
    Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func md5FileHex(_ url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }

    var hasher = Insecure.MD5()
    while true {
        let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
        if data.isEmpty { break }
        hasher.update(data: data)
    }

    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

private struct SophonBranchesResponse: Decodable {
    var data: DataPayload

    struct DataPayload: Decodable {
        var gameBranches: [GameBranch]

        private enum CodingKeys: String, CodingKey {
            case gameBranches = "game_branches"
        }
    }

    struct GameBranch: Decodable {
        var game: Game
        var main: SophonBranch
    }

    struct Game: Decodable {
        var biz: String
    }
}

private struct SophonBranch: Decodable {
    var packageID: String
    var branch: String
    var password: String
    var tag: String

    private enum CodingKeys: String, CodingKey {
        case packageID = "package_id"
        case branch
        case password
        case tag
    }
}

private struct SophonBuildResponse: Decodable {
    var retcode: Int
    var data: DataPayload

    struct DataPayload: Decodable {
        var tag: String
        var manifests: [SophonBuildIdentity]
    }
}

private struct SophonBuildIdentity: Decodable {
    var categoryID: String
    var categoryName: String
    var manifest: SophonManifestFile
    var chunkDownload: SophonURLInfo
    var manifestDownload: SophonURLInfo
    var matchingField: String
    var stats: SophonStats

    private enum CodingKeys: String, CodingKey {
        case categoryID = "category_id"
        case categoryName = "category_name"
        case manifest
        case chunkDownload = "chunk_download"
        case manifestDownload = "manifest_download"
        case matchingField = "matching_field"
        case stats
    }
}

private struct SophonManifestFile: Decodable {
    var id: String
    var checksum: String
    var compressedSize: Int64
    var uncompressedSize: Int64

    private enum CodingKeys: String, CodingKey {
        case id
        case checksum
        case compressedSize = "compressed_size"
        case uncompressedSize = "uncompressed_size"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        checksum = try container.decode(String.self, forKey: .checksum)
        compressedSize = try container.decodeFlexibleInt64(forKey: .compressedSize)
        uncompressedSize = try container.decodeFlexibleInt64(forKey: .uncompressedSize)
    }
}

private struct SophonURLInfo: Decodable {
    var urlPrefix: URL
    var compression: Int

    private enum CodingKeys: String, CodingKey {
        case urlPrefix = "url_prefix"
        case compression
    }
}

private struct SophonStats: Decodable {
    var compressedSize: Int64
    var uncompressedSize: Int64
    var fileCount: Int
    var chunkCount: Int

    private enum CodingKeys: String, CodingKey {
        case compressedSize = "compressed_size"
        case uncompressedSize = "uncompressed_size"
        case fileCount = "file_count"
        case chunkCount = "chunk_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        compressedSize = try container.decodeFlexibleInt64(forKey: .compressedSize)
        uncompressedSize = try container.decodeFlexibleInt64(forKey: .uncompressedSize)
        fileCount = try container.decodeFlexibleInt(forKey: .fileCount)
        chunkCount = try container.decodeFlexibleInt(forKey: .chunkCount)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt64(forKey key: Key) throws -> Int64 {
        if let value = try? decode(Int64.self, forKey: key) {
            return value
        }
        let string = try decode(String.self, forKey: key)
        guard let value = Int64(string) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected Int64 string")
        }
        return value
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        let string = try decode(String.self, forKey: key)
        guard let value = Int(string) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected Int string")
        }
        return value
    }
}
