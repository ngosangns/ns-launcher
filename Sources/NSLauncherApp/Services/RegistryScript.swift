// RegistryScript.swift
//
// Batches every registry write a launch needs into one `.reg` import.
//
// Each `wine reg add` / `wine reg delete` is a full Wine process, and a launch used to run nine of
// them back to back: six DLL-override removals from the render bridge plus three Mac Driver and
// PlayerPrefs values from the launcher. Measured on the game's own prefix, those nine cost 3.8s;
// the same values imported as a single `.reg` file cost 1.0s. All of it is spent before the game
// window can appear, which is why it is worth collapsing.
//
// Bridges contribute entries rather than running commands (see `RenderBridge.registryEntries`), so
// there is exactly one place that talks to the registry and exactly one process to pay for.

import Foundation

/// A single registry value to write or remove in the game's Wine prefix.
struct RegistryEntry: Sendable {
    enum Value: Sendable {
        case string(String)
        case dword(UInt32)
        /// Remove the value; absence is success.
        case remove
    }

    var key: String
    var name: String
    var value: Value
}

extension RegistryEntry {
    /// Wine's per-prefix DLL override table.
    private static let dllOverridesKey = #"HKEY_CURRENT_USER\Software\Wine\DllOverrides"#

    /// Removes a DLL override so the Wine build's own builtin wins.
    static func removingDLLOverride(_ dllName: String) -> RegistryEntry {
        RegistryEntry(key: dllOverridesKey, name: dllName, value: .remove)
    }

    /// Prefers a DLL copied into the prefix over the Wine builtin.
    static func nativeDLLOverride(_ dllName: String) -> RegistryEntry {
        RegistryEntry(key: dllOverridesKey, name: dllName, value: .string("native,builtin"))
    }
}

/// Renders registry entries as a `.reg` script and imports them in one `wine regedit` run.
enum RegistryScript {
    /// Renders entries into `.reg` syntax, grouping by key in first-seen order.
    ///
    /// UTF-8 rather than the UTF-16 that Windows writes: Wine's `regedit` accepts both, and the
    /// values here are plain ASCII.
    static func render(_ entries: [RegistryEntry]) -> String {
        var orderedKeys: [String] = []
        var grouped: [String: [RegistryEntry]] = [:]
        for entry in entries {
            if grouped[entry.key] == nil {
                orderedKeys.append(entry.key)
            }
            grouped[entry.key, default: []].append(entry)
        }

        var lines = ["Windows Registry Editor Version 5.00", ""]
        for key in orderedKeys {
            lines.append("[\(key)]")
            for entry in grouped[key] ?? [] {
                lines.append("\"\(escape(entry.name))\"=\(literal(for: entry.value))")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Writes the script to a temporary file and imports it.
    ///
    /// Best-effort by contract: the caller treats a failure as a warning, because these are
    /// quality-of-life settings and none of them is worth refusing to start the game over.
    static func apply(
        _ entries: [RegistryEntry],
        wineBinaryPath: String,
        environment: [String: String],
        processRunner: ProcessRunning
    ) async throws {
        guard !entries.isEmpty else { return }

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nslauncher-launch-\(UUID().uuidString).reg")
        try Data(render(entries).utf8).write(to: scriptURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: scriptURL) }

        _ = try await processRunner.run(
            executable: wineBinaryPath,
            arguments: ["regedit", scriptURL.path],
            environment: environment,
            currentDirectory: nil
        )
    }

    private static func literal(for value: RegistryEntry.Value) -> String {
        switch value {
        case let .string(text):
            return "\"\(escape(text))\""
        case let .dword(number):
            return String(format: "dword:%08x", number)
        case .remove:
            return "-"
        }
    }

    /// Escapes the two characters `.reg` string literals treat specially.
    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
