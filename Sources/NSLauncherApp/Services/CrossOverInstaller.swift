// CrossOverInstaller.swift
//
// Installs CrossOver through Homebrew so `D3DMetalBridge` has a Wine build carrying Apple's real
// D3DMetal to select.
//
// D3DMetal is Apple's own redistributable and ships only inside CrossOver-derived Wine builds
// under `lib64/apple_gptk` — the launcher cannot download and install it on its own (see
// `D3DMetalBridge`). The Homebrew cask `crossover` is the only verified way to get a genuine copy:
// the community `gcenx/wine` tap's "game-porting-toolkit" cask, despite the name, ships a Wine
// build with the open-source DXMT project compiled in as its own `d3d11.dll`/`dxgi.dll` — the exact
// backend this launcher moved away from — and carries no `lib64/apple_gptk` at all.
//
// CrossOver itself is CodeWeavers' commercial product: the cask installs a full trial that expires
// after 14 days and then needs a purchased license to keep running. This is why installing it is
// never automatic — only a user action with the trial spelled out in the UI triggers it (see
// `LauncherViewModel.installCrossOverViaHomebrew`).
//
// Homebrew itself is never installed here either: its official installer runs arbitrary code via
// `curl | bash` and asks for the user's password, which is not something to trigger without the
// user directly reviewing and running it themselves.

import Foundation

/// Failures specific to installing CrossOver through Homebrew.
enum CrossOverInstallError: LocalizedError {
    /// No `brew` executable found on PATH or in the common Homebrew install locations.
    case homebrewNotFound
    /// `brew install --cask crossover` ran but did not leave a usable CrossOver behind.
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .homebrewNotFound:
            return "Homebrew is not installed."
        case let .installFailed(details):
            return "Installing CrossOver through Homebrew failed: \(details)"
        }
    }
}

enum CrossOverInstaller {
    /// Where Homebrew's cask puts CrossOver — the same location `WineBinaryLocator` already
    /// scans for it.
    private static let appPath = "/Applications/CrossOver.app"

    /// The Wine root inside the CrossOver bundle, and where D3DMetal's payload has to be for
    /// `D3DMetalBridge` to pick this installation up.
    private static var appleGPTKMarker: String {
        appPath + "/Contents/SharedSupport/CrossOver/lib64/apple_gptk/wine/x86_64-windows/d3d11.dll"
    }

    /// True once a CrossOver carrying D3DMetal is in place. Used to hide the install action once
    /// it is no longer needed, and to confirm an install actually left a usable copy behind.
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: appleGPTKMarker)
    }

    /// Installs CrossOver via `brew install --cask crossover`, streaming Homebrew's own output.
    ///
    /// Only ever called from an explicit user action — see the file header for why this must never
    /// run on its own.
    static func install(
        processRunner: ProcessRunning,
        onDiagnostic: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let brewPath = BinaryLocator.resolveManagedExecutable(.brew, preferredPath: "") else {
            throw CrossOverInstallError.homebrewNotFound
        }
        onDiagnostic("using Homebrew at \(brewPath)")

        do {
            _ = try await processRunner.run(
                executable: brewPath,
                arguments: ["install", "--cask", "crossover"],
                environment: [:],
                currentDirectory: nil,
                onOutput: { chunk in onDiagnostic(chunk.text) }
            )
        } catch let ProcessRunnerError.nonZeroExit(result) {
            let details = result.stderr.isEmpty ? result.stdout : result.stderr
            throw CrossOverInstallError.installFailed(details)
        }

        guard isInstalled else {
            throw CrossOverInstallError.installFailed(
                "brew reported success but \(appleGPTKMarker) is still missing."
            )
        }
        onDiagnostic("CrossOver installed with D3DMetal at \(appPath)")
    }
}
