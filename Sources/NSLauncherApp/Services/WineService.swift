// WineService.swift
//
// Launches the Windows game through Wine: resolves the Wine binary, applies the
// environment, bootstraps DXMT (preferred) or DXVK into the prefix, streams output,
// and maps failures to targeted errors.
//
// DXMT is the Direct3D↔Metal bridge used for the bundled Genshin definition; it
// requires a Wine whose `x86_64-unix/winemac.so` exports
// `macdrv_view_create_metal_view` (a CrossOver-only symbol, absent from stock
// WineHQ builds), so the service verifies that symbol with `nm` before launching.
//
// Wine cannot load Windows kernel drivers, so output is scanned for known protection
// driver names (`HoYoKProtect.sys`, `HoYoProtect.sys`, `mhyprot2.sys`) and surfaced
// as `.unsupportedKernelDriver` instead of a generic process failure.

import Foundation

/// Complete request needed to launch a Windows executable through Wine.
struct WineLaunchRequest {
    var wineBinaryPath: String
    var prefixDirectory: URL
    var executablePath: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectory: URL?
    var runtimeRequirements: [RuntimeRequirement]
    var onOutput: (@Sendable (ProcessOutputChunk) -> Void)?
}

/// Wine launch failures that need targeted user remediation.
enum WineServiceError: LocalizedError {
    case binaryQuarantined(String)
    case dxvkBootstrapFailed(String)
    case dxmtBootstrapFailed(String)
    case dxmtUnsupportedWine(String)
    case unsupportedKernelDriver(String)

    var errorDescription: String? {
        switch self {
        case let .binaryQuarantined(path):
            return "Wine is blocked by macOS quarantine at \(path)."
        case let .dxvkBootstrapFailed(details):
            return "DXVK setup failed: \(details)"
        case let .dxmtBootstrapFailed(details):
            return "DXMT setup failed: \(details)"
        case let .dxmtUnsupportedWine(path):
            return "Wine at \(path) does not expose the winemac.drv symbols required by DXMT."
        case let .unsupportedKernelDriver(driver):
            return "Wine cannot load the Windows kernel driver \(driver)."
        }
    }
}

/// Boundary for Wine launch behavior.
protocol WineServicing: Sendable {
    func launch(_ request: WineLaunchRequest) async throws -> ProcessResult
}

/// Uses ProcessRunner to start a configured executable with WINEPREFIX applied.
struct WineService: WineServicing {
    private static let dxvkVersion = "2.7.1"
    private static let dxvkArchiveName = "dxvk-2.7.1.tar.gz"
    private static let dxvkArchiveURL = URL(string: "https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1.tar.gz")!
    private static let dxmtVersion = "v0.80"
    private static let dxmtArchiveName = "dxmt-v0.80-builtin.tar.gz"
    private static let dxmtArchiveURL = URL(string: "https://github.com/3Shain/dxmt/releases/download/v0.80/dxmt-v0.80-builtin.tar.gz")!

    let processRunner: ProcessRunning

    init(processRunner: ProcessRunning) {
        self.processRunner = processRunner
    }

    /// Launches the game executable through Wine and returns the completed process result.
    func launch(_ request: WineLaunchRequest) async throws -> ProcessResult {
        emitDiagnostic("launch request executable=\(request.executablePath.path)", request: request)
        emitDiagnostic("launch request currentDirectory=\(request.currentDirectory?.path ?? "nil") prefix=\(request.prefixDirectory.path)", request: request)
        emitDiagnostic("launch request runtime=\(request.runtimeRequirements.map(\.rawValue).joined(separator: ",")) args=\(request.arguments.joined(separator: " "))", request: request)
        let resolvedWineBinary: String
        if request.runtimeRequirements.contains(.dxmt) {
            emitDiagnostic("resolve DXMT-compatible Wine from preferred=\(request.wineBinaryPath)", request: request)
            resolvedWineBinary = try await resolveDXMTCompatibleWineBinary(preferredPath: request.wineBinaryPath)
        } else {
            emitDiagnostic("resolve Wine executable preferred=\(request.wineBinaryPath)", request: request)
            guard let binary = BinaryLocator.resolveExecutable(
                preferredPath: request.wineBinaryPath,
                candidateNames: BinaryLocator.candidateNames(forExecutable: request.wineBinaryPath)
            ) else {
                throw ProcessRunnerError.executableNotFound(request.wineBinaryPath)
            }
            resolvedWineBinary = binary
        }
        emitDiagnostic("resolved Wine binary=\(resolvedWineBinary)", request: request)

        if let quarantinedPath = Self.quarantinedPath(forExecutableAtPath: resolvedWineBinary) {
            emitDiagnostic("quarantine detected path=\(quarantinedPath)", request: request)
            throw WineServiceError.binaryQuarantined(quarantinedPath)
        }
        request.onOutput?(ProcessOutputChunk(stream: .stdout, text: "NSLauncher selected Wine binary: \(resolvedWineBinary)\n"))

        // Caller-supplied environment values win except for WINEPREFIX, which must match settings.
        // Enforce WINEARCH and WINEDEBUG defaults if caller did not supply them.
        var baseEnv: [String: String] = [
            "WINEARCH": "win64",
            "WINEDEBUG": "fixme-all,err-unwind"
        ]
        baseEnv.merge(request.environment) { _, new in new }
        baseEnv["WINEPREFIX"] = request.prefixDirectory.path

        // Ensure DXMT log/config directory exists when DXMT env vars reference it.
        if let dxmtLogPath = baseEnv["DXMT_LOG_PATH"] {
            let logDir = URL(fileURLWithPath: dxmtLogPath).deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        }
        if let dxmtConfigFile = baseEnv["DXMT_CONFIG_FILE"] {
            let configDir = URL(fileURLWithPath: dxmtConfigFile).deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            // Create empty config file if it doesn't exist so DXMT doesn't warn.
            if !FileManager.default.fileExists(atPath: dxmtConfigFile) {
                FileManager.default.createFile(atPath: dxmtConfigFile, contents: nil)
            }
        }

        let env = baseEnv
        emitDiagnostic("environment WINEPREFIX=\(env["WINEPREFIX"] ?? "") WINEARCH=\(env["WINEARCH"] ?? "") WINEDEBUG=\(env["WINEDEBUG"] ?? "") customKeys=\(request.environment.keys.sorted().joined(separator: ","))", request: request)

        if request.runtimeRequirements.contains(.dxmt) {
            emitDiagnostic("ensure DXMT runtime", request: request)
            try await ensureDXMTInstalled(
                prefixDirectory: request.prefixDirectory,
                wineBinaryPath: resolvedWineBinary,
                environment: env,
                onDiagnostic: { emitDiagnostic($0, request: request) }
            )
            emitDiagnostic("DXMT runtime ready", request: request)
        } else if request.runtimeRequirements.contains(.dxvk) {
            emitDiagnostic("ensure DXVK runtime", request: request)
            try await ensureDXVKInstalled(
                prefixDirectory: request.prefixDirectory,
                wineBinaryPath: resolvedWineBinary,
                environment: env,
                onDiagnostic: { emitDiagnostic($0, request: request) }
            )
            emitDiagnostic("DXVK runtime ready", request: request)
        }

        emitDiagnostic("snapshot existing game processes", request: request)
        let alreadyRunningGamePIDs = await runningExecutableProcessIDs(request.executablePath)
        emitDiagnostic("existing game process count=\(alreadyRunningGamePIDs.count)", request: request)
        let launchResult: ProcessResult
        do {
            emitDiagnostic("start process command=\(resolvedWineBinary) \(([request.executablePath.path] + request.arguments).joined(separator: " "))", request: request)
            launchResult = try await processRunner.run(
                executable: resolvedWineBinary,
                arguments: [request.executablePath.path] + request.arguments,
                environment: env,
                currentDirectory: request.currentDirectory,
                onOutput: request.onOutput
            )
        } catch let ProcessRunnerError.nonZeroExit(result) {
            emitDiagnostic("process exited non-zero code=\(result.exitCode); checking whether game stayed alive", request: request)
            if await hasNewLaunchedExecutableProcess(request.executablePath, excluding: alreadyRunningGamePIDs) {
                emitDiagnostic("detected launched game process after Wine exit; treating launch as successful", request: request)
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if result.exitCode == 15, Self.outputIndicatesGameStarted(result.stdout + "\n" + result.stderr) {
                emitDiagnostic("Wine exit 15 with started-game signal; treating launch as successful", request: request)
                launchResult = ProcessResult(exitCode: 0, stdout: result.stdout, stderr: result.stderr)
            } else if request.runtimeRequirements.contains(.dxmt),
               Self.outputIndicatesDXMTUnsupportedWine(result.stdout + "\n" + result.stderr) {
                emitDiagnostic("DXMT unsupported Wine signal detected", request: request)
                throw WineServiceError.dxmtUnsupportedWine(resolvedWineBinary)
            } else if let driverName = Self.unsupportedKernelDriverName(in: result.stdout + "\n" + result.stderr) {
                emitDiagnostic("unsupported kernel driver detected=\(driverName)", request: request)
                throw WineServiceError.unsupportedKernelDriver(driverName)
            } else {
                emitDiagnostic("non-zero process exit remains failure code=\(result.exitCode)", request: request)
                throw ProcessRunnerError.nonZeroExit(result)
            }
        }

        // Best-effort wineserver -w: flush registry and wait for Wine processes to exit.
        await waitForWineserver(wineBinaryPath: resolvedWineBinary, environment: env, request: request)

        return launchResult
    }

    private func emitDiagnostic(_ message: String, request: WineLaunchRequest) {
        request.onOutput?(ProcessOutputChunk(stream: .stdout, text: "[NSLauncher][launch-detail] \(message)\n"))
    }

    /// Best-effort wait for wineserver to exit, flushing registry writes and logs.
    private func waitForWineserver(wineBinaryPath: String, environment: [String: String], request: WineLaunchRequest) async {
        do {
            let wineRoot = try wineRootDirectory(forBinaryAtPath: wineBinaryPath)
            let wineserverPath = wineRoot.appendingPathComponent("bin/wineserver").path
            guard FileManager.default.isExecutableFile(atPath: wineserverPath) else {
                emitDiagnostic("wineserver not found at \(wineserverPath); skipping wait", request: request)
                return
            }
            emitDiagnostic("wineserver -w wait start", request: request)
            _ = try await processRunner.run(
                executable: wineserverPath,
                arguments: ["-w"],
                environment: environment,
                currentDirectory: nil
            )
            emitDiagnostic("wineserver -w completed", request: request)
        } catch {
            emitDiagnostic("wineserver -w best-effort failed: \(error.localizedDescription)", request: request)
        }
    }

    /// Installs the DXMT builtin payload into the Wine runtime and clears prefix overrides.
    private func ensureDXMTInstalled(
        prefixDirectory: URL,
        wineBinaryPath: String,
        environment: [String: String],
        onDiagnostic: (String) -> Void = { _ in }
    ) async throws {
        do {
            onDiagnostic("prepare DXMT payload")
            let extractedURL = try await prepareDXMTPayload()
            onDiagnostic("DXMT payload path=\(extractedURL.path)")
            let wineRoot = try wineRootDirectory(forBinaryAtPath: wineBinaryPath)
            onDiagnostic("Wine root for DXMT=\(wineRoot.path)")
            let wineLibrary = wineRoot.appendingPathComponent("lib/wine", isDirectory: true)
            try await ensureDXMTWineSymbolsAvailable(wineLibrary: wineLibrary, wineBinaryPath: wineBinaryPath)
            onDiagnostic("DXMT Wine symbols available")
            let x64Windows = wineLibrary.appendingPathComponent("x86_64-windows", isDirectory: true)
            let x86Windows = wineLibrary.appendingPathComponent("i386-windows", isDirectory: true)
            let x64Unix = wineLibrary.appendingPathComponent("x86_64-unix", isDirectory: true)
            let prefixSystem32 = prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
            let prefixSyswow64 = prefixDirectory.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
            let markerURL = wineLibrary.appendingPathComponent(".nslauncher-dxmt-\(Self.dxmtVersion)")
            let x64Source = extractedURL.appendingPathComponent("x86_64-windows", isDirectory: true)
            let x86Source = extractedURL.appendingPathComponent("i386-windows", isDirectory: true)
            let x64UnixSource = extractedURL.appendingPathComponent("x86_64-unix", isDirectory: true)

            let requiredCopies = [
                DXMTPayloadCopy(
                    names: ["d3d10core.dll", "d3d11.dll", "dxgi.dll", "nvapi64.dll", "nvngx.dll", "winemetal.dll"],
                    sourceDirectory: x64Source,
                    destinationDirectory: x64Windows
                ),
                DXMTPayloadCopy(
                    names: ["d3d10core.dll", "d3d11.dll", "dxgi.dll", "winemetal.dll"],
                    sourceDirectory: x86Source,
                    destinationDirectory: x86Windows
                ),
                DXMTPayloadCopy(
                    names: ["winemetal.so"],
                    sourceDirectory: x64UnixSource,
                    destinationDirectory: x64Unix
                ),
                DXMTPayloadCopy(
                    names: ["winemetal.dll"],
                    sourceDirectory: x64Source,
                    destinationDirectory: prefixSystem32
                ),
                DXMTPayloadCopy(
                    names: ["winemetal.dll"],
                    sourceDirectory: x86Source,
                    destinationDirectory: prefixSyswow64
                )
            ]

            if !FileManager.default.fileExists(atPath: markerURL.path) || !dxmtPayloadIsCurrent(requiredCopies) {
                onDiagnostic("install DXMT payload into Wine library and prefix")
                try FileManager.default.createDirectory(at: x64Windows, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: x86Windows, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: x64Unix, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: prefixSystem32, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: prefixSyswow64, withIntermediateDirectories: true)

                for copy in requiredCopies {
                    try copyDLLs(copy.names, from: copy.sourceDirectory, to: copy.destinationDirectory)
                }
                try Data("installed\n".utf8).write(to: markerURL, options: .atomic)
            } else {
                onDiagnostic("DXMT payload marker current")
            }

            // The DXMT builtin payload replaces Wine builtin DLLs, so native overrides must be absent.
            for dllName in ["d3d10core", "d3d11", "dxgi", "nvapi64", "nvngx", "winemetal"] {
                onDiagnostic("clear DXMT DLL override \(dllName)")
                try await deleteDLLOverride(dllName, wineBinaryPath: wineBinaryPath, environment: environment)
            }
        } catch let wineError as WineServiceError {
            throw wineError
        } catch {
            throw WineServiceError.dxmtBootstrapFailed(error.localizedDescription)
        }
    }

    /// Selects the latest WineHQ Devel binary and verifies that it can host DXMT.
    private func resolveDXMTCompatibleWineBinary(preferredPath: String) async throws -> String {
        var attemptedPaths: [String] = []

        for candidate in Self.dxmtWineCandidatePaths(preferredPath: preferredPath) {
            guard FileManager.default.isExecutableFile(atPath: candidate) else { continue }
            if let quarantinedPath = Self.quarantinedPath(forExecutableAtPath: candidate) {
                throw WineServiceError.binaryQuarantined(quarantinedPath)
            }

            do {
                let wineRoot = try wineRootDirectory(forBinaryAtPath: candidate)
                try await ensureDXMTWineSymbolsAvailable(
                    wineLibrary: wineRoot.appendingPathComponent("lib/wine", isDirectory: true),
                    wineBinaryPath: candidate
                )
                return candidate
            } catch WineServiceError.dxmtUnsupportedWine {
                attemptedPaths.append(candidate)
            } catch WineServiceError.dxmtBootstrapFailed {
                attemptedPaths.append(candidate)
            }
        }

        let details = attemptedPaths.isEmpty ? preferredPath : attemptedPaths.joined(separator: ", ")
        throw WineServiceError.dxmtUnsupportedWine(details)
    }

    /// Installs DXVK into the Wine prefix once, so DirectX 11 games do not fall back to WineD3D.
    private func ensureDXVKInstalled(
        prefixDirectory: URL,
        wineBinaryPath: String,
        environment: [String: String],
        onDiagnostic: (String) -> Void = { _ in }
    ) async throws {
        let markerURL = prefixDirectory.appendingPathComponent(".nslauncher-dxvk-\(Self.dxvkVersion)")
        let system32 = prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        let syswow64 = prefixDirectory.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
        if FileManager.default.fileExists(atPath: markerURL.path),
           FileManager.default.fileExists(atPath: system32.appendingPathComponent("d3d11.dll").path),
           FileManager.default.fileExists(atPath: system32.appendingPathComponent("dxgi.dll").path) {
            onDiagnostic("DXVK marker current")
            return
        }

        do {
            onDiagnostic("prepare DXVK payload")
            let extractedURL = try await prepareDXVKPayload()
            onDiagnostic("DXVK payload path=\(extractedURL.path)")
            try FileManager.default.createDirectory(at: system32, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: syswow64, withIntermediateDirectories: true)

            onDiagnostic("copy DXVK DLLs into prefix")
            try copyDXVKDLLs(
                from: extractedURL.appendingPathComponent("x64", isDirectory: true),
                to: system32
            )
            try copyDXVKDLLs(
                from: extractedURL.appendingPathComponent("x32", isDirectory: true),
                to: syswow64
            )

            onDiagnostic("set DXVK DLL overrides")
            try await setDLLOverride("d3d11", wineBinaryPath: wineBinaryPath, environment: environment)
            try await setDLLOverride("dxgi", wineBinaryPath: wineBinaryPath, environment: environment)
            try Data("installed\n".utf8).write(to: markerURL, options: .atomic)
        } catch let wineError as WineServiceError {
            throw wineError
        } catch {
            throw WineServiceError.dxvkBootstrapFailed(error.localizedDescription)
        }
    }

    /// Downloads and extracts the pinned DXVK release into the launcher cache.
    private func prepareDXVKPayload() async throws -> URL {
        let cacheDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/NSLauncher/DXVK", isDirectory: true)
        let archiveURL = cacheDirectory.appendingPathComponent(Self.dxvkArchiveName)
        let extractedURL = cacheDirectory.appendingPathComponent("dxvk-\(Self.dxvkVersion)", isDirectory: true)

        if FileManager.default.fileExists(atPath: extractedURL.appendingPathComponent("x64/d3d11.dll").path),
           FileManager.default.fileExists(atPath: extractedURL.appendingPathComponent("x64/dxgi.dll").path),
           FileManager.default.fileExists(atPath: extractedURL.appendingPathComponent("x32/d3d11.dll").path),
           FileManager.default.fileExists(atPath: extractedURL.appendingPathComponent("x32/dxgi.dll").path) {
            return extractedURL
        }

        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: archiveURL.path) {
            let (temporaryURL, response) = try await URLSession.shared.download(from: Self.dxvkArchiveURL)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw WineServiceError.dxvkBootstrapFailed("Unable to download DXVK \(Self.dxvkVersion).")
            }
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                try FileManager.default.removeItem(at: archiveURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)
        }

        if FileManager.default.fileExists(atPath: extractedURL.path) {
            try FileManager.default.removeItem(at: extractedURL)
        }
        _ = try await processRunner.run(
            executable: "/usr/bin/tar",
            arguments: ["-xzf", archiveURL.path, "-C", cacheDirectory.path],
            environment: [:],
            currentDirectory: nil
        )
        return extractedURL
    }

    /// Downloads and extracts the pinned DXMT release into the launcher cache.
    private func prepareDXMTPayload() async throws -> URL {
        let cacheDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/NSLauncher/DXMT", isDirectory: true)
        let archiveURL = cacheDirectory.appendingPathComponent(Self.dxmtArchiveName)
        let extractedURL = cacheDirectory.appendingPathComponent(Self.dxmtVersion, isDirectory: true)

        if FileManager.default.fileExists(atPath: extractedURL.appendingPathComponent("x86_64-windows/d3d11.dll").path),
           FileManager.default.fileExists(atPath: extractedURL.appendingPathComponent("x86_64-windows/winemetal.dll").path),
           FileManager.default.fileExists(atPath: extractedURL.appendingPathComponent("x86_64-unix/winemetal.so").path) {
            return extractedURL
        }

        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: archiveURL.path) {
            let (temporaryURL, response) = try await URLSession.shared.download(from: Self.dxmtArchiveURL)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw WineServiceError.dxmtBootstrapFailed("Unable to download DXMT \(Self.dxmtVersion).")
            }
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                try FileManager.default.removeItem(at: archiveURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)
        }

        if FileManager.default.fileExists(atPath: extractedURL.path) {
            try FileManager.default.removeItem(at: extractedURL)
        }
        _ = try await processRunner.run(
            executable: "/usr/bin/tar",
            arguments: ["-xzf", archiveURL.path, "-C", cacheDirectory.path],
            environment: [:],
            currentDirectory: nil
        )
        return extractedURL
    }

    /// Copies the DXVK D3D11 bridge DLLs into a Wine Windows system directory.
    private func copyDXVKDLLs(from sourceDirectory: URL, to destinationDirectory: URL) throws {
        try copyDLLs(["d3d11.dll", "dxgi.dll"], from: sourceDirectory, to: destinationDirectory)
    }

    /// Copies selected bridge DLLs into a Wine Windows system directory.
    private func copyDLLs(_ dllNames: [String], from sourceDirectory: URL, to destinationDirectory: URL) throws {
        for dllName in dllNames {
            let source = sourceDirectory.appendingPathComponent(dllName)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = destinationDirectory.appendingPathComponent(dllName)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }

    /// Checks all DXMT files because users may reinstall Wine while the old marker file remains.
    private func dxmtPayloadIsCurrent(_ copies: [DXMTPayloadCopy]) -> Bool {
        copies.allSatisfy { copy in
            copy.names.allSatisfy { name in
                let source = copy.sourceDirectory.appendingPathComponent(name)
                let destination = copy.destinationDirectory.appendingPathComponent(name)
                return FileManager.default.fileExists(atPath: source.path)
                    && FileManager.default.contentsEqual(atPath: source.path, andPath: destination.path)
            }
        }
    }

    /// DXMT needs Wine's Unix-side winemac bridge to export macOS/Metal view symbols.
    private func ensureDXMTWineSymbolsAvailable(wineLibrary: URL, wineBinaryPath: String) async throws {
        let unixDirectory = wineLibrary.appendingPathComponent("x86_64-unix", isDirectory: true)
        // Stock Wine names the mac bridge `winemac.so`; CrossOver-derived builds use `winemac.drv.so`.
        let winemacBridge = ["winemac.so", "winemac.drv.so"]
            .map { unixDirectory.appendingPathComponent($0, isDirectory: false) }
            .first { FileManager.default.fileExists(atPath: $0.path) }

        guard let winemacBridge else {
            throw WineServiceError.dxmtUnsupportedWine(wineBinaryPath)
        }

        do {
            let result = try await processRunner.run(
                executable: "/usr/bin/nm",
                arguments: ["-gU", winemacBridge.path],
                environment: [:],
                currentDirectory: nil
            )
            // DXMT resolves the mac driver interface through the `macdrv_functions` table on modern
            // Wine; older DXMT-patched builds exported the individual `macdrv_view_create_metal_view`
            // symbol instead. Accept either.
            if !result.stdout.contains("macdrv_functions"),
               !result.stdout.contains("macdrv_view_create_metal_view") {
                throw WineServiceError.dxmtUnsupportedWine(wineBinaryPath)
            }
        } catch let wineError as WineServiceError {
            throw wineError
        } catch {
            throw WineServiceError.dxmtUnsupportedWine(wineBinaryPath)
        }
    }

    /// Configures Wine to prefer the DXVK DLLs copied into the prefix.
    private func setDLLOverride(
        _ dllName: String,
        wineBinaryPath: String,
        environment: [String: String]
    ) async throws {
        _ = try await processRunner.run(
            executable: wineBinaryPath,
            arguments: [
                "reg",
                "add",
                "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides",
                "/v",
                dllName,
                "/d",
                "native,builtin",
                "/f"
            ],
            environment: environment,
            currentDirectory: nil
        )
    }

    /// Removes a Wine DLL override if it exists.
    private func deleteDLLOverride(
        _ dllName: String,
        wineBinaryPath: String,
        environment: [String: String]
    ) async throws {
        do {
            _ = try await processRunner.run(
                executable: wineBinaryPath,
                arguments: [
                    "reg",
                    "delete",
                    "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides",
                    "/v",
                    dllName,
                    "/f"
                ],
                environment: environment,
                currentDirectory: nil
            )
        } catch ProcessRunnerError.nonZeroExit {
            // Missing values are fine; the desired state is that no override is present.
        }
    }

    /// Resolves the Wine root directory that contains bin/wine and lib/wine.
    private func wineRootDirectory(forBinaryAtPath path: String) throws -> URL {
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let binaryDirectory = resolvedURL.deletingLastPathComponent()
        let wineRoot = binaryDirectory.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: wineRoot.appendingPathComponent("lib/wine").path) else {
            throw WineServiceError.dxmtBootstrapFailed("Unable to locate Wine lib/wine directory for \(path).")
        }
        return wineRoot
    }

    /// Wine can return a non-zero wrapper code after successfully spawning the Windows GUI process.
    private func hasNewLaunchedExecutableProcess(_ executablePath: URL, excluding existingPIDs: Set<Int32>) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let currentPIDs = await runningExecutableProcessIDs(executablePath)
            return !currentPIDs.subtracting(existingPIDs).isEmpty
        } catch {
            return false
        }
    }

    /// Returns running process IDs for the exact executable path, ignoring older unrelated Wine processes.
    private func runningExecutableProcessIDs(_ executablePath: URL) async -> Set<Int32> {
        do {
            let result = try await processRunner.run(
                executable: "/bin/ps",
                arguments: ["axo", "pid=,command="],
                environment: [:],
                currentDirectory: nil
            )
            return Set(result.stdout
                .split(whereSeparator: \.isNewline)
                .compactMap { line -> Int32? in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard let firstSpace = trimmed.firstIndex(where: \.isWhitespace),
                          trimmed[trimmed.index(after: firstSpace)...].contains(executablePath.path) else {
                        return nil
                    }
                    return Int32(trimmed[..<firstSpace])
                })
        } catch {
            return []
        }
    }

    /// Gatekeeper quarantine commonly causes Wine to terminate before it can launch the game.
    private static func quarantinedPath(forExecutableAtPath path: String) -> String? {
        let resolvedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let candidatePaths = [
            enclosingAppBundlePath(for: resolvedURL),
            resolvedURL.path,
            path
        ].compactMap(\.self)

        return candidatePaths.first(where: hasQuarantineAttribute)
    }

    /// Returns the enclosing .app bundle for a Wine executable nested inside one.
    private static func enclosingAppBundlePath(for url: URL) -> String? {
        let components = url.pathComponents
        guard let appIndex = components.lastIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }
        return NSString.path(withComponents: Array(components.prefix(appIndex + 1)))
    }

    private static func hasQuarantineAttribute(atPath path: String) -> Bool {
        path.withCString { fileSystemPath in
            getxattr(fileSystemPath, "com.apple.quarantine", nil, 0, 0, 0) >= 0
        }
    }

    private static func outputIndicatesDXMTUnsupportedWine(_ output: String) -> Bool {
        output.localizedCaseInsensitiveContains("no exported symbols needed by DXMT")
    }

    /// Detects Windows kernel drivers that Wine cannot load, most commonly anti-cheat/protection drivers.
    private static func unsupportedKernelDriverName(in output: String) -> String? {
        let driverNames = ["HoYoKProtect.sys", "HoYoProtect.sys", "mhyprot2.sys"]
        return driverNames.first { output.localizedCaseInsensitiveContains($0) }
    }

    /// Some Wine builds return 15 when the GUI game session closes cleanly.
    private static func outputIndicatesGameStarted(_ output: String) -> Bool {
        output.contains("MultiThreadStackTrace init success")
            || output.contains("GCGMAH active")
            || output.contains("\"message\":\"app running\"")
    }

    /// Candidate Wine binaries: the launcher-managed DXMT-patched Wine first, then the preferred
    /// PATH binary and CrossOver/GPTK/WineHQ app bundles as fallbacks. PATH wine (e.g. Game Porting
    /// Toolkit) may export a `macdrv_functions` table with an incompatible struct layout and crash
    /// at load time, so the managed build must win.
    private static func dxmtWineCandidatePaths(preferredPath: String) -> [String] {
        let preferredPath = preferredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitCandidates = [
            managedWineDirectory.appendingPathComponent("bin/wine64").path,
            managedWineDirectory.appendingPathComponent("bin/wine").path,
            preferredPath,
            BinaryLocator.resolveExecutable(
                preferredPath: preferredPath,
                candidateNames: BinaryLocator.candidateNames(forExecutable: preferredPath)
            ),
            "/Applications/Wine Devel.app/Contents/Resources/wine/bin/wine",
            "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine64",
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64"
        ].compactMap { $0 }.filter { !$0.isEmpty }

        var seen = Set<String>()
        var candidates = explicitCandidates.filter { seen.insert($0).inserted }

        candidates.append(contentsOf: wineExecutables(in: managedWineDirectory, seen: &seen))

        for appName in ["CrossOver.app", "Game Porting Toolkit.app", "Wine Devel.app"] {
            for root in applicationSearchRoots() {
                let appURL = root.appendingPathComponent(appName, isDirectory: true)
                candidates.append(contentsOf: wineExecutables(in: appURL, seen: &seen))
            }
        }

        return candidates
    }

    /// Launcher-managed directory where a DXMT-patched Wine can be extracted so the resolver can
    /// pick it up without any system-wide install or PATH changes.
    private static var managedWineDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/NSLauncher/wine", isDirectory: true)
    }

    /// Searches standard app locations without scanning the whole filesystem.
    private static func applicationSearchRoots() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    /// Finds wine/wine64 executables inside a known app bundle.
    private static func wineExecutables(in appURL: URL, seen: inout Set<String>) -> [String] {
        guard FileManager.default.fileExists(atPath: appURL.path),
              let enumerator = FileManager.default.enumerator(
                  at: appURL,
                  includingPropertiesForKeys: [.isExecutableKey, .isRegularFileKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        var results: [String] = []
        for case let url as URL in enumerator {
            guard ["wine", "wine64"].contains(url.lastPathComponent),
                  url.pathComponents.contains("bin"),
                  seen.insert(url.path).inserted,
                  FileManager.default.isExecutableFile(atPath: url.path) else {
                continue
            }
            results.append(url.path)
        }
        return results
    }
}

private struct DXMTPayloadCopy {
    var names: [String]
    var sourceDirectory: URL
    var destinationDirectory: URL
}
