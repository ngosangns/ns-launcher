// D3DMetalBridge.swift
//
// D3DMetal: Apple's own Direct3D-to-Metal translation layer, shipped as part of the Game Porting
// Toolkit and bundled into CrossOver-derived Wine builds under `lib64/apple_gptk`.
//
// Unlike DXVK (or the DXMT this replaced), D3DMetal cannot be downloaded and installed by the
// launcher: it is Apple's own redistributable, gated behind CrossOver (CodeWeavers) or Apple's
// Game Porting Toolkit (Homebrew, Apple Developer sign-in required). The launcher can only detect
// and use a build the user already has — see `resolveWineBuild` — and must say so plainly when
// none is found, rather than failing with a generic launch error.
//
// Selection needs no file surgery, but it is NOT done through `WINEDLLPATH`. That claim used to sit
// here and was wrong: CrossOver's `wine` script builds `WINEDLLPATH` from `lib/wine` alone and never
// mentions `lib64/apple_gptk`, and Wine no longer consults `WINEDLLPATH` for PE builtins anyway. The
// payload is selected by `CX_GRAPHICS_BACKEND=d3dmetal` together with `CX_ROOT`, which is what
// `cxcompatdb.so` reads — see `RenderBridge.crossOverGraphicsBackend`. `prepare` therefore only
// proves the payload is on disk and exports `CX_APPLEGPTK_LIBD3DSHARED_PATH`.

import CryptoKit
import Darwin
import Foundation

struct D3DMetalBridge: RenderBridge {
    let backend: RuntimeBackend = .d3dMetal
    let crossOverGraphicsBackend = "d3dmetal"

    func launchEnvironment(settings: AppSettings) -> [String: String] {
        // esync + builtin D3D overrides — shared by every Metal-native backend; see
        // RenderBridges.baseMetalNativeEnvironment.
        var env = RenderBridges.baseMetalNativeEnvironment()

        // Float-behaviour overrides for shading faults that hit some models and not others. Set
        // only when asked for: each one changes numeric behaviour for every shader in the game, so
        // the default has to be D3DMetal's own. See `AppSettings.d3dMetalSampleNaNToZero` for why
        // these are exposed at all rather than picked here.
        if settings.d3dMetalSampleNaNToZero {
            env["D3DM_SAMPLE_NAN_TO_ZERO"] = "1"
        }
        if settings.d3dMetalFlushPositiveInfinityToNaN {
            env["D3DM_FLUSH_POS_INF_TO_NAN"] = "1"
        }
        if settings.d3dMetalForceRTZTextureWrite {
            env["D3DM_FORCE_RTZ_TEXWRITE"] = "1"
        }
        if settings.d3dMetalPositionInvariance {
            env["D3DM_POSITION_INVARIANCE"] = "1"
        }

        // D3DMetal maintains its own on-disk pipeline cache with no *environment* configuration at
        // all — verified by running `strings` on a real D3DMetal.framework binary installed via
        // CrossOver: every `D3DM_*` string it contains (device identity spoofing, NaN/RTZ float
        // handling, DXR support, the float-behaviour flags above, etc.) was enumerated, and none
        // of them is a cache path, pre-warm switch, or any other shader/pipeline-cache control.
        // This is a closed line of investigation, not an oversight — don't re-derive it from the
        // name of some other
        // D3DM_* string without re-running the same check against the actual binary.
        //
        // The cache still lives at a fixed, discoverable *location* though (same binary's strings:
        // `%s/d3dm/%s/shaders.cache/`, holding `pipeline_cache.bin`/`bytecode_cache.bin`/
        // `rootsignature_cache.bin`/`stage_cache.bin` per Metal GPU family) — see
        // `shaderCacheDirectory` below, which is what the launcher's cache-clearing feature uses.

        // Rank GStreamer's H.264 decoders (Apple AudioToolbox + FFmpeg) so in-game/cutscene video
        // never selects a broken decoder. Mirrors YAAGL's always-on launch config.
        env["GST_PLUGIN_FEATURE_RANK"] = "atdec:MAX,avdec_h264:MAX"
        return env
    }

    /// Picks the newest installed Wine build that carries D3DMetal under `lib64/apple_gptk`.
    ///
    /// Never falls back to downloading a Wine build: a plain Wine carries no Apple Game Porting
    /// Toolkit payload, so fetching one would still leave D3DMetal unavailable — just slower to find
    /// out. The user has to install CrossOver.
    func resolveWineBuild(
        preferredPath: String,
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws -> WineBuild {
        let search = await WineBinaryLocator.search(
            preferredPath: preferredPath,
            processRunner: processRunner,
            onDiagnostic: onDiagnostic
        )

        for build in search.builds {
            if Self.appleGPTKWindowsDirectory(for: build) != nil {
                return build
            }
            onDiagnostic("no Apple D3DMetal payload under lib64/apple_gptk: \(build.binaryPath)")
        }

        if let quarantined = search.quarantinedPaths.first {
            throw WineServiceError.binaryQuarantined(quarantined)
        }
        throw WineServiceError.d3dMetalUnavailable(
            search.builds.isEmpty ? preferredPath : search.builds.map(\.binaryPath).joined(separator: ", ")
        )
    }

    func prepare(
        wineBuild: WineBuild,
        prefixDirectory: URL,
        environment: inout [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let gptkWindows = Self.appleGPTKWindowsDirectory(for: wineBuild) else {
            throw WineServiceError.d3dMetalUnavailable(wineBuild.binaryPath)
        }

        onDiagnostic("D3DMetal payload=\(gptkWindows.path)")

        // `libd3dshared.dylib` is loaded regardless of which backend is active; CrossOver's own
        // launcher script exports its path the same way.
        let libD3DShared = wineBuild.root.appendingPathComponent("lib64/apple_gptk/external/libd3dshared.dylib")
        if FileManager.default.fileExists(atPath: libD3DShared.path) {
            environment["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = libD3DShared.path
            onDiagnostic("CX_APPLEGPTK_LIBD3DSHARED_PATH=\(libD3DShared.path)")
        }
    }

    /// The directory D3DMetal's Windows-side DLLs live in, or nil when this build does not carry
    /// Apple's Game Porting Toolkit payload at all.
    private static func appleGPTKWindowsDirectory(for build: WineBuild) -> URL? {
        let directory = build.root.appendingPathComponent("lib64/apple_gptk/wine/x86_64-windows", isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent("d3d11.dll").path)
            ? directory
            : nil
    }

    /// Durable mirror of D3DMetal's purgeable Darwin cache.
    static var durableCacheRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NSLauncher/RenderCaches/D3DMetal", isDirectory: true)
    }

    /// POSIX record locks coordinate processes; this lock also serializes callers inside one app.
    private static let inProcessCacheLock = NSLock()

    /// Restores a compatible snapshot only when D3DMetal's live cache is empty. A populated live
    /// cache always wins and is checkpointed instead, so the launcher never replaces newer data.
    @discardableResult
    static func prepareShaderCache(
        forExecutable executableName: String,
        wineBuild: WineBuild,
        liveDirectory: URL? = nil,
        durableRoot: URL? = nil,
        onDiagnostic: (String) -> Void
    ) throws -> String? {
        guard let sourceVersion = d3dMetalSourceVersion(for: wineBuild) else {
            onDiagnostic("D3DMetal cache snapshot skipped: payload SourceVersion unavailable")
            return nil
        }
        guard let live = liveDirectory ?? shaderCacheDirectory(forExecutable: executableName) else {
            onDiagnostic("D3DMetal cache snapshot skipped: Darwin cache directory unavailable")
            return nil
        }
        let root = durableRoot ?? durableCacheRoot
        let executableKey = executableCacheKey(executableName)
        let cacheLock = try CacheLock(executableKey: executableKey, durableRoot: root)
        defer { cacheLock.release() }
        let generation = try cacheGeneration(forExecutableKey: executableKey, durableRoot: root)

        let snapshot = snapshotDirectory(
            forExecutable: executableName,
            sourceVersion: sourceVersion,
            durableRoot: root
        )
        let liveState = cacheState(at: live)

        if liveState.isEmpty {
            let snapshotState = cacheState(at: snapshot)
            guard !snapshotState.isEmpty else {
                onDiagnostic("D3DMetal cache cold sourceVersion=\(sourceVersion)")
                return generation
            }
            try replaceDirectory(at: live, withCopyOf: snapshot)
            onDiagnostic(
                "D3DMetal cache restored sourceVersion=\(sourceVersion) bytes=\(snapshotState.sizeBytes) files=\(snapshotState.fileCount)"
            )
            return generation
        }

        onDiagnostic("D3DMetal cache live bytes=\(liveState.sizeBytes) files=\(liveState.fileCount)")
        try checkpoint(
            liveDirectory: live,
            state: liveState,
            snapshotDirectory: snapshot,
            executableName: executableName,
            sourceVersion: sourceVersion,
            durableRoot: root,
            onDiagnostic: onDiagnostic
        )
        return generation
    }

    /// Persists the latest complete cache after Wine has finished writing it.
    static func checkpointShaderCache(
        forExecutable executableName: String,
        wineBuild: WineBuild,
        expectedGeneration: String? = nil,
        liveDirectory: URL? = nil,
        durableRoot: URL? = nil,
        onDiagnostic: (String) -> Void
    ) throws {
        guard let sourceVersion = d3dMetalSourceVersion(for: wineBuild),
              let live = liveDirectory ?? shaderCacheDirectory(forExecutable: executableName) else {
            return
        }
        let root = durableRoot ?? durableCacheRoot
        let executableKey = executableCacheKey(executableName)
        let cacheLock = try CacheLock(executableKey: executableKey, durableRoot: root)
        defer { cacheLock.release() }

        if let expectedGeneration,
           try cacheGeneration(forExecutableKey: executableKey, durableRoot: root) != expectedGeneration {
            onDiagnostic("D3DMetal cache checkpoint skipped: generation changed")
            return
        }

        let liveState = cacheState(at: live)
        guard !liveState.isEmpty else {
            onDiagnostic("D3DMetal cache checkpoint skipped: live cache empty")
            return
        }
        try checkpoint(
            liveDirectory: live,
            state: liveState,
            snapshotDirectory: snapshotDirectory(
                forExecutable: executableName,
                sourceVersion: sourceVersion,
                durableRoot: root
            ),
            executableName: executableName,
            sourceVersion: sourceVersion,
            durableRoot: root,
            onDiagnostic: onDiagnostic
        )
    }

    /// Every durable snapshot belonging to an executable, used by Cache Management so an explicit
    /// clear cannot be undone by the next launch's restore.
    static func durableCacheDirectories(
        forExecutable executableName: String,
        durableRoot: URL? = nil
    ) -> [URL] {
        (try? existingDurableCacheDirectories(
            forExecutable: executableName,
            durableRoot: durableRoot ?? durableCacheRoot
        )) ?? []
    }

    private static func existingDurableCacheDirectories(
        forExecutable executableName: String,
        durableRoot: URL
    ) throws -> [URL] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: durableRoot.path) else { return [] }
        let executableKey = executableCacheKey(executableName)
        let versions = try fileManager.contentsOfDirectory(
            at: durableRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return versions.compactMap { versionDirectory in
            guard (try? versionDirectory.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return nil
            }
            let directory = versionDirectory.appendingPathComponent(executableKey, isDirectory: true)
            return fileManager.fileExists(atPath: directory.path) ? directory : nil
        }
    }

    /// Clears the live cache and every compatible snapshot under one cross-process lock. Advancing
    /// the generation first prevents an already-running launch from publishing data after clear.
    static func clearShaderCaches(
        forExecutable executableName: String,
        liveDirectory: URL? = nil,
        durableRoot: URL? = nil
    ) throws -> Int64 {
        let root = durableRoot ?? durableCacheRoot
        let executableKey = executableCacheKey(executableName)
        let cacheLock = try CacheLock(executableKey: executableKey, durableRoot: root)
        defer { cacheLock.release() }
        try writeCacheGeneration(
            UUID().uuidString,
            forExecutableKey: executableKey,
            durableRoot: root
        )

        let live = liveDirectory ?? shaderCacheDirectory(forExecutable: executableName)
        let snapshots = try existingDurableCacheDirectories(
            forExecutable: executableName,
            durableRoot: root
        )
        let freed = (live.map { cacheState(at: $0).sizeBytes } ?? 0)
            + snapshots.reduce(0) { $0 + cacheState(at: $1).sizeBytes }

        if let live {
            try removeContents(of: live)
        }
        for snapshot in snapshots {
            try FileManager.default.removeItem(at: snapshot)
        }
        return freed
    }

    /// Where D3DMetal keeps its compiled-shader cache for one game executable, or nil if this
    /// process's Darwin per-user cache directory cannot be resolved.
    ///
    /// Derived from the `%s/d3dm/%s/shaders.cache/` format string in a real D3DMetal.framework
    /// binary: the first `%s` is macOS's per-user cache directory (`confstr(3)` with
    /// `_CS_DARWIN_USER_CACHE_DIR` — NOT `~/Library/Caches`, this is the `/var/folders/.../C/`
    /// directory `getconf DARWIN_USER_CACHE_DIR` prints), the second is the executable's own file
    /// name (`GenshinImpact.exe`, matching what was found on disk at
    /// `.../C/d3dm/GenshinImpact.exe/shaders.cache/`). D3DMetal recreates every file under this
    /// directory the next time each shader is used, so removing it only costs a fresh round of
    /// compile-on-first-use stutter — worth it if the cache itself has gone stale or corrupt.
    static func shaderCacheDirectory(forExecutable executableName: String) -> URL? {
        var buffer = [Int8](repeating: 0, count: Int(PATH_MAX))
        let length = confstr(_CS_DARWIN_USER_CACHE_DIR, &buffer, buffer.count)
        guard length > 0, length <= buffer.count else { return nil }
        let path = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        let cacheRoot = URL(fileURLWithPath: path, isDirectory: true)
        return cacheRoot
            .appendingPathComponent("d3dm", isDirectory: true)
            .appendingPathComponent(executableName, isDirectory: true)
    }

    private struct CacheFile: Equatable {
        let relativePath: String
        let sizeBytes: Int
        let modificationDate: Date?
    }

    private struct CacheState: Equatable {
        let files: [CacheFile]
        let sizeBytes: Int64

        var fileCount: Int { files.count }
        var isEmpty: Bool { files.isEmpty }
    }

    private struct FrameworkVersion: Decodable {
        let sourceVersion: String

        enum CodingKeys: String, CodingKey {
            case sourceVersion = "SourceVersion"
        }
    }

    private static func d3dMetalSourceVersion(for build: WineBuild) -> String? {
        let versionURL = build.root
            .appendingPathComponent("lib64/apple_gptk/external/D3DMetal.framework/Resources/version.plist")
        guard let data = try? Data(contentsOf: versionURL),
              let version = try? PropertyListDecoder().decode(FrameworkVersion.self, from: data) else {
            return nil
        }
        return safePathComponent(version.sourceVersion)
    }

    private static func snapshotDirectory(
        forExecutable executableName: String,
        sourceVersion: String,
        durableRoot: URL
    ) -> URL {
        durableRoot
            .appendingPathComponent(safePathComponent(sourceVersion), isDirectory: true)
            .appendingPathComponent(executableCacheKey(executableName), isDirectory: true)
    }

    private static func executableCacheKey(_ executableName: String) -> String {
        let readablePrefix = String(safePathComponent(executableName).prefix(96))
        let digest = SHA256.hash(data: Data(executableName.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(readablePrefix)-\(digest)"
    }

    private static func generationURL(forExecutableKey executableKey: String, durableRoot: URL) -> URL {
        durableRoot
            .appendingPathComponent(".locks", isDirectory: true)
            .appendingPathComponent("\(executableKey).generation")
    }

    private static func cacheGeneration(forExecutableKey executableKey: String, durableRoot: URL) throws -> String {
        let url = generationURL(forExecutableKey: executableKey, durableRoot: durableRoot)
        if let data = try? Data(contentsOf: url),
           let generation = String(data: data, encoding: .utf8),
           !generation.isEmpty {
            return generation
        }
        let generation = UUID().uuidString
        try writeCacheGeneration(generation, forExecutableKey: executableKey, durableRoot: durableRoot)
        return generation
    }

    private static func writeCacheGeneration(
        _ generation: String,
        forExecutableKey executableKey: String,
        durableRoot: URL
    ) throws {
        try Data(generation.utf8).write(
            to: generationURL(forExecutableKey: executableKey, durableRoot: durableRoot),
            options: .atomic
        )
    }

    private static func safePathComponent(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(
            of: #"[^A-Za-z0-9._-]"#,
            with: "_",
            options: .regularExpression
        )
        guard !sanitized.isEmpty, sanitized != ".", sanitized != ".." else { return "unknown" }
        return sanitized
    }

    private static func cacheState(at directory: URL) -> CacheState {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return CacheState(files: [], sizeBytes: 0)
        }

        let directoryPath = directory.standardizedFileURL.path
        let prefix = directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"
        var files: [CacheFile] = []
        var sizeBytes: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(
                forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
            )
            guard values?.isRegularFile == true else { continue }
            let fileSize = values?.fileSize ?? 0
            let path = fileURL.standardizedFileURL.path
            let relativePath = path.hasPrefix(prefix)
                ? String(path.dropFirst(prefix.count))
                : fileURL.lastPathComponent
            files.append(CacheFile(
                relativePath: relativePath,
                sizeBytes: fileSize,
                modificationDate: values?.contentModificationDate
            ))
            sizeBytes += Int64(fileSize)
        }
        return CacheState(
            files: files.sorted { $0.relativePath < $1.relativePath },
            sizeBytes: sizeBytes
        )
    }

    private static func checkpoint(
        liveDirectory: URL,
        state: CacheState,
        snapshotDirectory: URL,
        executableName: String,
        sourceVersion: String,
        durableRoot: URL,
        onDiagnostic: (String) -> Void
    ) throws {
        if cacheState(at: snapshotDirectory) == state {
            onDiagnostic("D3DMetal cache snapshot unchanged sourceVersion=\(sourceVersion)")
            return
        }
        try replaceDirectory(at: snapshotDirectory, withCopyOf: liveDirectory)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: snapshotDirectory.path
        )
        onDiagnostic(
            "D3DMetal cache checkpointed sourceVersion=\(sourceVersion) bytes=\(state.sizeBytes) files=\(state.fileCount)"
        )
        pruneOldSnapshots(in: durableRoot, forExecutable: executableName)
    }

    /// Replaces a directory through a sibling temporary path. `COPYFILE_CLONE` uses APFS
    /// copy-on-write when available and transparently falls back to a normal recursive copy.
    private static func replaceDirectory(at destination: URL, withCopyOf source: URL) throws {
        let fileManager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let temporary = parent.appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: temporary) }

        let flags = copyfile_flags_t(COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_CLONE)
        let cloneResult = source.path.withCString { sourcePath in
            temporary.path.withCString { destinationPath in
                copyfile(sourcePath, destinationPath, nil, flags)
            }
        }
        if cloneResult != 0 {
            try? fileManager.removeItem(at: temporary)
            try fileManager.copyItem(at: source, to: temporary)
        }

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    private static func removeContents(of directory: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let entries = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        for entry in entries {
            try fileManager.removeItem(at: entry)
        }
    }

    /// An in-process mutex plus `lockf` coordinates launch/cache-management paths across threads
    /// and launcher processes that share the same executable cache.
    private final class CacheLock {
        private var descriptor: Int32 = -1
        private var holdsInProcessLock = true

        init(executableKey: String, durableRoot: URL) throws {
            D3DMetalBridge.inProcessCacheLock.lock()
            do {
                let fileManager = FileManager.default
                let lockDirectory = durableRoot.appendingPathComponent(".locks", isDirectory: true)
                try fileManager.createDirectory(at: lockDirectory, withIntermediateDirectories: true)
                let lockURL = lockDirectory.appendingPathComponent("\(executableKey).lock")
                let fileDescriptor = Darwin.open(
                    lockURL.path,
                    O_CREAT | O_RDWR,
                    mode_t(S_IRUSR | S_IWUSR)
                )
                guard fileDescriptor >= 0 else {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                guard Darwin.lockf(fileDescriptor, F_LOCK, 0) == 0 else {
                    let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                    Darwin.close(fileDescriptor)
                    throw error
                }
                descriptor = fileDescriptor
            } catch {
                D3DMetalBridge.inProcessCacheLock.unlock()
                holdsInProcessLock = false
                throw error
            }
        }

        func release() {
            guard descriptor >= 0 else { return }
            _ = Darwin.lockf(descriptor, F_ULOCK, 0)
            Darwin.close(descriptor)
            descriptor = -1
            if holdsInProcessLock {
                D3DMetalBridge.inProcessCacheLock.unlock()
                holdsInProcessLock = false
            }
        }

        deinit {
            release()
        }
    }

    private static func pruneOldSnapshots(in durableRoot: URL, forExecutable executableName: String) {
        let fileManager = FileManager.default
        let executableKey = executableCacheKey(executableName)
        let snapshots = ((try? fileManager.contentsOfDirectory(
            at: durableRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
            .compactMap { versionDirectory -> URL? in
                guard (try? versionDirectory.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    return nil
                }
                let snapshot = versionDirectory.appendingPathComponent(executableKey, isDirectory: true)
                guard (try? snapshot.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    return nil
                }
                return snapshot
            }
            .sorted {
                let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    ?? .distantPast
                let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    ?? .distantPast
                return left > right
            }
        for snapshot in snapshots.dropFirst(2) {
            try? fileManager.removeItem(at: snapshot)
        }
    }
}
