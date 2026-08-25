// GameProcessInspector.swift
//
// Finds game processes already running under Wine.
//
// Two callers need this. The launch preflight refuses to start a second copy into a prefix that
// already has one — a Wine prefix is single-tenant, and a second client attaching to the running
// wineserver deadlocks in the loader instead of failing. `WineService` uses it afterwards to tell
// "Wine's wrapper exited non-zero but the game is up" from a real failure.
//
// Matching covers both spellings of the executable. A direct launch hands Wine the POSIX path, but
// the steam.exe parent path — the default for Genshin, see `WineService` — hands it the Windows
// `Z:\…` form, and `ps` shows whichever one Wine was given. Matching only the POSIX form made this
// return nothing for every launch that went through steam.exe, which is nearly all of them.

import Foundation

enum GameProcessInspector {
    /// Returns PIDs running the given executable, matched by either path spelling.
    static func runningProcessIDs(
        forExecutable executablePath: URL,
        processRunner: ProcessRunning
    ) async -> Set<Int32> {
        let needles = [executablePath.path, windowsPath(for: executablePath)]
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
                    guard let firstSpace = trimmed.firstIndex(where: \.isWhitespace) else { return nil }
                    let command = trimmed[trimmed.index(after: firstSpace)...]
                    guard needles.contains(where: command.contains) else { return nil }
                    return Int32(trimmed[..<firstSpace])
                })
        } catch {
            return []
        }
    }

    /// Converts a macOS absolute path into the `Z:` drive path Wine presents to Windows programs.
    static func windowsPath(for url: URL) -> String {
        "Z:" + url.path.replacingOccurrences(of: "/", with: "\\")
    }
}
