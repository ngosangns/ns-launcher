// AbyssHoyolabCredentialStore.swift
//
// Holds the player's own `ltuid_v2`/`ltoken_v2` — their live HoYoLAB login
// session, pasted in by hand — in
// `~/Library/Application Support/NSLauncher/abyss-hoyolab.json`, next to the
// roster and the showcase cache. Same plain-JSON persistence as every other
// piece of Abyss state.
//
// This was a Keychain item first, and the Keychain charged rent for it in
// permission prompts. The app is ad-hoc signed (`codesign --sign -` in
// scripts/bundle-app.sh), so its code identity is a cdhash that changes with
// every build; the ACL macOS attaches to a keychain item names the app that
// created it, so each rebuilt binary looked like a *different* program
// reaching for the previous build's secret. `AbyssViewModel` loads these at
// init, which is app launch — so every launch after a reinstall opened with a
// keychain dialog, and "Always Allow" never survived the next `task install`.
//
// The trade-off is real and worth naming: this is a live session token in a
// readable file rather than in the one store macOS actually protects. Anything
// running as this user can read it without being asked. The file is written
// owner-only (0600) so at least it is not readable across accounts, and the
// token is still never sent anywhere but HoYoLAB's own API.
//
// Nothing migrates the old keychain item: reading it is exactly the prompt
// this change exists to remove. Players re-paste once, and can delete the
// leftover with
// `security delete-generic-password -s com.ns-launcher.abyss.hoyolab`.

import Foundation

protocol AbyssHoyolabCredentialStoring: Sendable {
    /// nil when nothing has been saved yet, or the entry could not be read
    /// back — either way, the answer is "the fields start empty", not an error
    /// worth surfacing for a credential the player can just paste in again.
    func load() -> (ltuid: String, ltoken: String)?
    func save(ltuid: String, ltoken: String) throws
}

struct AbyssHoyolabCredentialStore: AbyssHoyolabCredentialStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private struct Payload: Codable {
        let ltuid: String
        let ltoken: String
    }

    init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher", isDirectory: true)) {
        fileURL = baseDirectory.appendingPathComponent("abyss-hoyolab.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> (ltuid: String, ltoken: String)? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? decoder.decode(Payload.self, from: data) else { return nil }
        return (payload.ltuid, payload.ltoken)
    }

    func save(ltuid: String, ltoken: String) throws {
        let data = try encoder.encode(Payload(ltuid: ltuid, ltoken: ltoken))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        // After the write, not before: an atomic write swaps a fresh temporary
        // file into place and the new inode carries the default mask.
        try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                              ofItemAtPath: fileURL.path)
    }
}
