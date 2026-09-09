// AbyssHoyolabCredentialStore.swift
//
// Holds the player's own `ltuid_v2`/`ltoken_v2` — their live HoYoLAB login
// session, pasted in by hand — in the macOS Keychain rather than in
// `settings.json`. That file is plain JSON on disk, fine for preferences and
// already used for several; a live session token is a different kind of
// thing, and belongs in the one place macOS actually protects secrets.
//
// This is *their* credential for *their* own account, entered once so the
// import button works on the next launch too. It is never sent anywhere but
// HoYoLAB's own API, and nothing here reads or writes any other keychain item.

import Foundation
import Security

protocol AbyssHoyolabCredentialStoring: Sendable {
    /// nil when nothing has been saved yet, or the entry could not be read
    /// back — either way, the answer is "the fields start empty", not an error
    /// worth surfacing for a credential the player can just paste in again.
    func load() -> (ltuid: String, ltoken: String)?
    func save(ltuid: String, ltoken: String) throws
}

struct AbyssHoyolabCredentialStore: AbyssHoyolabCredentialStoring {
    private static let service = "com.ns-launcher.abyss.hoyolab"
    private static let account = "ltuid_v2+ltoken_v2"

    private struct Payload: Codable {
        let ltuid: String
        let ltoken: String
    }

    private func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Self.service,
         kSecAttrAccount as String: Self.account]
    }

    func load() -> (ltuid: String, ltoken: String)? {
        var attributes = query()
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(attributes as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }
        return (payload.ltuid, payload.ltoken)
    }

    func save(ltuid: String, ltoken: String) throws {
        let data = try JSONEncoder().encode(Payload(ltuid: ltuid, ltoken: ltoken))

        // Overwrite semantics: delete first rather than SecItemUpdate: a save
        // always replaces whatever was there, and this keeps the "does it
        // already exist" branch out of the picture entirely.
        SecItemDelete(query() as CFDictionary)

        var attributes = query()
        attributes[kSecValueData as String] = data
        // Available as soon as the user unlocks their Mac once after boot, and
        // never synced to their other devices via iCloud Keychain — this is a
        // per-machine session, not a credential to carry around.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AbyssHoyolabCredentialStoreError.keychain(status: status)
        }
    }
}

enum AbyssHoyolabCredentialStoreError: LocalizedError, Equatable {
    case keychain(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            return (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)."
        }
    }
}
