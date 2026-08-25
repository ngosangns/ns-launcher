// DXVKBridge.swift
//
// DXVK: Direct3D 11 translated to Vulkan, which MoltenVK then translates to Metal.
//
// Two translation hops instead of one, so it is strictly more overhead than DXMT on
// Apple hardware. It stays available for game definitions that ask for it, but it is not the
// choice for anything that can use a direct Metal bridge.
//
// Unlike the Metal bridges, DXVK ships plain Windows DLLs with no Unix-side counterpart, so it is
// installed into the game's own Wine prefix as native overrides rather than selected through
// `WINEDLLPATH`. The prefix belongs to the launcher; the Wine installation is still untouched.

import Foundation

struct DXVKBridge: RenderBridge {
    private static let version = "2.7.1"
    private static let archiveName = "dxvk-2.7.1.tar.gz"
    private static let archiveURL = URL(string: "https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1.tar.gz")!

    let backend: RuntimeBackend = .dxvk

    func launchEnvironment(settings: AppSettings, displayRefreshRate: Int) -> [String: String] {
        // msync only exists on Wine builds carrying the marzent patches (the DXMT-managed wine);
        // generic DXVK setups stay on esync regardless of the setting.
        ["WINEESYNC": "1"]
    }

    /// DXVK's DLLs are copied into the prefix, so they need native overrides to win over the Wine
    /// builtins. Re-declared every launch rather than tracked by the payload marker below: the
    /// prefix registry and the copied files can drift apart, and reasserting costs nothing now
    /// that all registry state is written in one batch.
    func registryEntries() -> [RegistryEntry] {
        ["d3d11", "dxgi"].map(RegistryEntry.nativeDLLOverride)
    }

    func prepare(
        wineBuild: WineBuild,
        prefixDirectory: URL,
        environment: inout [String: String],
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        let markerURL = prefixDirectory.appendingPathComponent(".nslauncher-dxvk-\(Self.version)")
        let system32 = prefixDirectory.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
        let syswow64 = prefixDirectory.appendingPathComponent("drive_c/windows/syswow64", isDirectory: true)
        if FileManager.default.fileExists(atPath: markerURL.path),
           FileManager.default.fileExists(atPath: system32.appendingPathComponent("d3d11.dll").path),
           FileManager.default.fileExists(atPath: system32.appendingPathComponent("dxgi.dll").path) {
            onDiagnostic("DXVK marker current")
            return
        }

        do {
            let payload = try await RenderBridgePayload.extractedPayload(
                archiveURL: Self.archiveURL,
                archiveName: Self.archiveName,
                into: RenderBridgePayload.root.appendingPathComponent("DXVK", isDirectory: true),
                extractedDirectoryName: "dxvk-\(Self.version)",
                isComplete: { url in
                    ["x64/d3d11.dll", "x64/dxgi.dll", "x32/d3d11.dll", "x32/dxgi.dll"]
                        .allSatisfy { FileManager.default.fileExists(atPath: url.appendingPathComponent($0).path) }
                },
                processRunner: processRunner,
                failure: { WineServiceError.dxvkBootstrapFailed($0) }
            )
            onDiagnostic("DXVK payload path=\(payload.path)")

            try FileManager.default.createDirectory(at: system32, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: syswow64, withIntermediateDirectories: true)
            onDiagnostic("copy DXVK DLLs into prefix")
            try RenderBridgePayload.copyDLLs(
                ["d3d11.dll", "dxgi.dll"],
                from: payload.appendingPathComponent("x64", isDirectory: true),
                to: system32
            )
            try RenderBridgePayload.copyDLLs(
                ["d3d11.dll", "dxgi.dll"],
                from: payload.appendingPathComponent("x32", isDirectory: true),
                to: syswow64
            )

            try Data("installed\n".utf8).write(to: markerURL, options: .atomic)
        } catch let wineError as WineServiceError {
            throw wineError
        } catch {
            throw WineServiceError.dxvkBootstrapFailed(error.localizedDescription)
        }
    }
}
