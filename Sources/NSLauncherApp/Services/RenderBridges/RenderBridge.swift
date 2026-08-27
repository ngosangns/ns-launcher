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
// change with no way back.
//
// A bridge does not install its payload; it only proves the payload exists and names itself. The
// payload is selected by `CX_GRAPHICS_BACKEND` — see `crossOverGraphicsBackend` below.

import Foundation

/// Everything one Direct3D-to-Metal (or -Vulkan) translation layer needs to run a game.
protocol RenderBridge: Sendable {
    /// Backend this bridge implements.
    var backend: RuntimeBackend { get }

    /// Value for `CX_GRAPHICS_BACKEND`, the only mechanism that actually selects a translation layer
    /// on a CrossOver-derived Wine.
    ///
    /// `WINEDLLPATH` does NOT do it. CrossOver's own `wine` script builds `WINEDLLPATH` from
    /// `lib/wine` alone and never mentions `lib64/apple_gptk`; the selection lives in
    /// `lib/wine/x86_64-unix/cxcompatdb.so`, whose `set_graphics_backend`/`prepend_cx_root_dll_path`
    /// read `CX_GRAPHICS_BACKEND` plus `CX_ROOT` and prepend `lib64/apple_gptk/wine`, `lib/dxmt` or
    /// `lib/dxvk` internally. Wine also stopped consulting `WINEDLLPATH` for PE builtins, so
    /// prepending a payload directory there selects nothing at all — measured: with only the
    /// `WINEDLLPATH` prepend the game reported `Renderer: Apple M3, Vendor: Unknown (ID=106b)` (a
    /// MoltenVK Vulkan device, i.e. not D3DMetal); with `CX_GRAPHICS_BACKEND=d3dmetal` it reports
    /// `Renderer: AMD Compatibility Mode, Vendor: ATI`, which is D3DMetal's spoofed adapter.
    var crossOverGraphicsBackend: String { get }

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
    /// Picks the backend a game actually launches with: the user's preference when the game
    /// declares support for it, otherwise the first supported fallback.
    static func resolveBackend(requirements: [RuntimeRequirement], preferred: RuntimeBackend) -> RuntimeBackend {
        let preferredRequirement: RuntimeRequirement? = {
            switch preferred {
            case .d3dMetal: return .d3dMetal
            case .dxmt: return .dxmt
            case .dxvk: return .dxvk
            case .plainWine: return nil
            }
        }()
        if let preferredRequirement, requirements.contains(preferredRequirement) {
            return preferred
        }
        if requirements.contains(.d3dMetal) { return .d3dMetal }
        if requirements.contains(.dxmt) { return .dxmt }
        if requirements.contains(.dxvk) { return .dxvk }
        return .plainWine
    }

    static func bridge(for backend: RuntimeBackend) -> RenderBridge? {
        switch backend {
        case .d3dMetal: return D3DMetalBridge()
        case .dxmt: return DXMTBridge()
        case .dxvk: return DXVKBridge()
        case .plainWine: return nil
        }
    }

    /// DLL names a translation layer owns and that a stale native copy in the prefix can shadow.
    ///
    /// `=b` forces Wine to load them as builtins, so the payload CrossOver's selector put on the DLL
    /// search path is the one that runs. Without this, Wine's load order picks the native file in the prefix's
    /// `system32` instead, and an earlier version of this launcher left upstream DXVK 2.7.1 there by
    /// copying it in — so every D3DMetal/DXMT launch silently rendered on that DXVK through MoltenVK
    /// while the launch log still named the intended backend. Measured on one prefix, same files
    /// present, only this variable differing: without it 16154 `[mvk-error]` plus 8164
    /// `SPIRV-Cross:` lines in 120s of play; with it, zero of either.
    ///
    /// This variable is the whole fix. DO NOT try to clean the prefix's copies instead — both ways
    /// of doing that were measured and both are worse:
    ///   - deleting them makes Genshin's own `dxgi.dll` import fail outright (Wine does not
    ///     substitute the builtin for a missing file on this path), and the game exits with code 5
    ///     before loading a single graphics module;
    ///   - replacing them with Wine's own builtin PEs from `lib/wine` makes Wine load *those* in
    ///     place rather than following `WINEDLLPATH`, dropping the game onto wined3d-over-MoltenVK
    ///     (3368 `SPIRV-Cross:` lines in 80s, versus zero when left alone).
    /// With the override in place the prefix's copies are inert, so leave them exactly where they are.
    static func builtinD3DOverrides() -> String {
        "d3d10,d3d10_1,d3d10core,d3d11,dxgi=b"
    }

    /// Environment every Metal-native backend (D3DMetal, DXMT) needs, regardless of which one:
    /// esync, plus the builtin-forcing overrides above.
    ///
    /// `vulkan-1=` used to be here, on the theory that Unity was falling back to Vulkan-via-MoltenVK.
    /// That theory is disproven; DO NOT reintroduce it. The game's own log reports
    /// `Direct3D 11.0 [level 11.1]` and `set vulkan allow: False`, so Unity never probes Vulkan --
    /// MoltenVK was in the picture because the D3D11 implementation itself was the stale native DXVK
    /// described above. Disabling `vulkan-1` could not have stopped that DXVK either: its loader
    /// resolves `vkGetInstanceProcAddr` from `winevulkan.dll` first and only falls back to
    /// `vulkan-1.dll` (all three strings are in the DXVK binary).
    ///
    /// Shared here -- not restated per bridge -- so a future third Metal-native backend inherits it
    /// automatically instead of a maintainer having to remember to copy it in.
    static func baseMetalNativeEnvironment() -> [String: String] {
        [
            "WINEESYNC": "1",
            "WINEDLLOVERRIDES": builtinD3DOverrides()
        ]
    }

    /// Environment for a backend, or nothing when it needs no translation layer.
    static func launchEnvironment(for backend: RuntimeBackend, settings: AppSettings) -> [String: String] {
        bridge(for: backend)?.launchEnvironment(settings: settings) ?? [:]
    }
}
