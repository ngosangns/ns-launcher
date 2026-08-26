// RenderBridge.swift
//
// One type per Direct3D translation layer, so everything a backend needs lives together:
// the environment the game runs with, the Wine build it can run on, and how it is put in
// place. Adding a backend is adding a file here, not editing branches in Models and
// WineService.
//
// Non-destructive by contract: `prepare` may write into the game's Wine PREFIX, which the
// launcher owns, but must never modify the Wine installation itself. The installation is
// shared with anything else using that build, and overwriting its builtin DLLs is a one-way
// change with no way back. Bridges that ship their own DLLs are selected by putting their
// directory first on `WINEDLLPATH`, which is the same mechanism CrossOver uses to choose
// between its own builtins and a bundled translation layer.
//
// Bridges declare the registry state they need rather than writing it. Every `wine reg` call is a
// whole Wine process on the launch path, so `WineService` collects the declarations and imports
// them in one go — see `RegistryScript`.

import Foundation

/// Everything one Direct3D-to-Metal (or -Vulkan) translation layer needs to run a game.
protocol RenderBridge: Sendable {
    /// Backend this bridge implements.
    var backend: RuntimeBackend { get }

    /// Environment derived from settings alone, with no filesystem knowledge.
    ///
    /// Called while building the launch profile, so the values show up in the launch log even
    /// when the launch later fails.
    func launchEnvironment(settings: AppSettings) -> [String: String]

    /// Picks the Wine build this bridge can run on, newest first.
    ///
    /// Throws rather than returning nil: only the bridge knows why none of the installed builds
    /// qualified, and that reason is what the user has to act on.
    func resolveWineBuild(
        preferredPath: String,
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws -> WineBuild

    /// Registry state the prefix needs before the game starts.
    ///
    /// Applied in one batch with the launcher's own settings, so this must be idempotent — it is
    /// re-declared on every launch rather than tracked with a marker.
    func registryEntries() -> [RegistryEntry]

    /// Puts the bridge in place and contributes the environment that depends on where things
    /// landed. Must not modify anything inside the Wine build.
    func prepare(
        wineBuild: WineBuild,
        prefixDirectory: URL,
        environment: inout [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws
}

extension RenderBridge {
    /// Most bridges need no registry state of their own.
    func registryEntries() -> [RegistryEntry] { [] }

    /// Default resolution: the newest usable Wine, with no extra requirement.
    ///
    /// Bridges that need more — D3DMetal's `lib64/apple_gptk` requirement — override this.
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
        if let build = search.builds.first { return build }
        if let quarantined = search.quarantinedPaths.first {
            throw WineServiceError.binaryQuarantined(quarantined)
        }
        throw ProcessRunnerError.executableNotFound(preferredPath)
    }
}

/// Maps a resolved backend onto its bridge.
enum RenderBridges {
    static func bridge(for backend: RuntimeBackend) -> RenderBridge? {
        switch backend {
        case .d3dMetal: return D3DMetalBridge()
        case .dxvk: return DXVKBridge()
        case .plainWine: return nil
        }
    }

    /// Environment for a backend, or nothing when it needs no translation layer.
    static func launchEnvironment(for backend: RuntimeBackend, settings: AppSettings) -> [String: String] {
        bridge(for: backend)?.launchEnvironment(settings: settings) ?? [:]
    }
}

/// Shared plumbing for bridges that ship a downloadable payload.
enum RenderBridgePayload {
    /// Root the launcher unpacks bridge payloads into.
    ///
    /// Application Support rather than Caches: once a payload is on `WINEDLLPATH` it is a runtime
    /// dependency of every launch, and macOS purges Caches exactly when the disk is full.
    static var root: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NSLauncher/RenderBridges", isDirectory: true)
    }

    /// Downloads and extracts an archive once, keyed by the directory it unpacks into.
    ///
    /// `isComplete` decides whether an existing extraction can be reused; a half-extracted
    /// directory from an interrupted run must not be treated as usable.
    static func extractedPayload(
        archiveURL: URL,
        archiveName: String,
        into directory: URL,
        extractedDirectoryName: String,
        isComplete: (URL) -> Bool,
        processRunner: ProcessRunning,
        failure: (String) -> Error
    ) async throws -> URL {
        let extractedURL = directory.appendingPathComponent(extractedDirectoryName, isDirectory: true)
        if isComplete(extractedURL) { return extractedURL }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let localArchive = directory.appendingPathComponent(archiveName)
        if !FileManager.default.fileExists(atPath: localArchive.path) {
            let (temporaryURL, response) = try await URLSession.shared.download(from: archiveURL)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw failure("Unable to download \(archiveName).")
            }
            if FileManager.default.fileExists(atPath: localArchive.path) {
                try FileManager.default.removeItem(at: localArchive)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: localArchive)
        }

        if FileManager.default.fileExists(atPath: extractedURL.path) {
            try FileManager.default.removeItem(at: extractedURL)
        }
        // `-xf` rather than `-xzf`: payloads arrive gzipped, Wine distributions xz-compressed, and
        // tar picks the decompressor from the archive itself.
        _ = try await processRunner.run(
            executable: "/usr/bin/tar",
            arguments: ["-xf", localArchive.path, "-C", directory.path],
            environment: [:],
            currentDirectory: nil
        )
        guard isComplete(extractedURL) else {
            throw failure("\(archiveName) did not extract the expected files.")
        }
        return extractedURL
    }

    /// Puts directories at the front of `WINEDLLPATH`, keeping the Wine build's own entries after.
    ///
    /// Wine expects each entry to be an architecture directory (`.../x86_64-windows`) and finds the
    /// matching Unix `.so` in the sibling `x86_64-unix`, which is why a payload's own layout can be
    /// used as-is instead of being copied into the Wine tree.
    static func prependToDLLPath(
        _ directories: [URL],
        wineRoot: URL,
        environment: inout [String: String]
    ) {
        var entries = directories.map(\.path)
        for suffix in ["lib/wine/x86_64-windows", "lib/wine/i386-windows", "lib/wine"] {
            let directory = wineRoot.appendingPathComponent(suffix, isDirectory: true)
            if FileManager.default.fileExists(atPath: directory.path) {
                entries.append(directory.path)
            }
        }
        if let existing = environment["WINEDLLPATH"], !existing.isEmpty {
            entries.append(existing)
        }
        var seen = Set<String>()
        environment["WINEDLLPATH"] = entries.filter { seen.insert($0).inserted }.joined(separator: ":")
    }

    /// Copies selected DLLs into a Wine Windows system directory inside the game's prefix.
    static func copyDLLs(_ names: [String], from sourceDirectory: URL, to destinationDirectory: URL) throws {
        for name in names {
            let source = sourceDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = destinationDirectory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }
}
