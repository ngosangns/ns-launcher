// AbyssHoyolabClient.swift
//
// Reads a player's full character list from HoYoLAB's Battle Chronicle —
// unlike Enka's Showcase, not capped at eight, but needing the player's own
// HoYoLAB login to ask for it (see AbyssHoyolabCredentialStore) and only
// working at all if they turned on "Character Details" under their HoYoLAB
// privacy settings, a different, less commonly-found toggle than Enka's
// in-game one.
//
// This is not an endpoint HoYoverse documents or supports; the request shape,
// salt and header set below are the ones the actively-maintained open-source
// `genshin.py` client (github.com/thesadru/genshin.py) uses, itself arrived at
// by the same kind of reverse engineering this whole feature already leans on
// for Enka and Yatta. It can stop working the day HoYoverse changes it, with no
// notice, the same risk already accepted for Enka.

import CryptoKit
import Foundation

protocol AbyssFullRosterFetching: Sendable {
    func fetchFullRoster(uid: String, ltuid: String, ltoken: String, map: AbyssGameIDMap) async throws
        -> AbyssHoyolabRoster
}

enum AbyssHoyolabError: LocalizedError, Equatable {
    case malformedUID
    case notFound
    case dataNotPublic
    case invalidCredentials
    case rateLimited
    case badResponse(status: Int)
    case server(retcode: Int, message: String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .malformedUID: return "That is not a valid UID."
        case .notFound: return "No player with that UID."
        case .dataNotPublic:
            return "Character Details are not public for that account. On hoyolab.com, open your profile's "
                + "privacy settings and turn on \"Character Details\" under Battle Chronicle."
        case .invalidCredentials: return "That ltuid_v2/ltoken_v2 pair was rejected — the session may have expired."
        case .rateLimited: return "HoYoLAB is rate-limiting requests. Try again shortly."
        case .badResponse(let status): return "HoYoLAB answered with HTTP \(status)."
        case .server(let retcode, let message): return "HoYoLAB error \(retcode): \(message)"
        case .transport(let message): return message
        }
    }
}

struct AbyssHoyolabClient: AbyssFullRosterFetching {
    private let session: URLSession
    private let host: URL

    private static let userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36"
    /// The overseas Dynamic Secret salt `genshin.py` uses for Game Record
    /// endpoints — a published constant in that project, not something
    /// recovered here.
    private static let dsSalt = "6s25p5ox5y14umn1p61aqyyvbvvl3lrt"

    init(session: URLSession? = nil, host: URL = URL(string: "https://sg-public-api.hoyolab.com")!) {
        self.session = session ?? {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.waitsForConnectivity = false
            return URLSession(configuration: configuration)
        }()
        self.host = host
    }

    /// The server code HoYoLAB expects, from the UID's own prefix — the same
    /// table the game's UID screen and wiki both document. 10-digit UIDs only
    /// have one known prefix so far: Asia's newer accounts, "18".
    static func serverCode(forUID uid: String) -> String? {
        switch uid.count {
        case 9:
            switch uid.first {
            case "6": return "os_usa"
            case "7": return "os_euro"
            case "8": return "os_asia"
            case "9": return "os_cht"
            default: return nil // 0, 1/2/3, 5 are internal/mainland-China servers this client does not target.
            }
        case 10:
            return uid.hasPrefix("18") ? "os_asia" : nil
        default:
            return nil
        }
    }

    func fetchFullRoster(uid: String, ltuid: String, ltoken: String, map: AbyssGameIDMap) async throws
        -> AbyssHoyolabRoster {
        let trimmedUID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let server = Self.serverCode(forUID: trimmedUID) else { throw AbyssHoyolabError.malformedUID }

        var request = URLRequest(url: host.appendingPathComponent("event/game_record/genshin/api/character/list"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["role_id": trimmedUID, "server": server])
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ltuid_v2=\(ltuid.trimmingCharacters(in: .whitespacesAndNewlines)); "
                         + "ltoken_v2=\(ltoken.trimmingCharacters(in: .whitespacesAndNewlines))",
                         forHTTPHeaderField: "Cookie")
        for (field, value) in Self.dynamicSecretHeaders() {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AbyssHoyolabError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AbyssHoyolabError.badResponse(status: http.statusCode)
        }

        // Checked before the strict typed decode below: an error response's
        // `data` is often `null` or `{}` rather than a well-formed character
        // list, and decoding that straight into `HoyolabCharacterList` would
        // fail on the missing `list` key before the retcode is ever read —
        // turning "your Character Details are private" into an opaque decode
        // error instead of the specific one below.
        let envelope = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        try Self.throwForRetcode(envelope?["retcode"] as? Int ?? -1, message: envelope?["message"] as? String ?? "")

        let payload: HoyolabResponse<HoyolabCharacterList>
        do {
            payload = try JSONDecoder().decode(HoyolabResponse<HoyolabCharacterList>.self, from: data)
        } catch {
            throw AbyssHoyolabError.transport(String(describing: error))
        }

        guard let list = payload.data?.list else { throw AbyssHoyolabError.dataNotPublic }
        return Self.convert(list, uid: trimmedUID, map: map)
    }

    // MARK: - Conversion

    static func convert(_ characters: [HoyolabCharacter], uid: String, map: AbyssGameIDMap) -> AbyssHoyolabRoster {
        var converted: [AbyssHoyolabCharacter] = []
        var unmapped: Set<String> = []

        for character in characters {
            guard let characterID = map.characterID(avatarID: character.id, hoyolabElementName: character.element)
            else {
                unmapped.insert("character \(character.id)")
                continue
            }

            var weaponID: String?
            if let weapon = character.weapon {
                if let slug = map.weaponID(itemID: weapon.id) {
                    weaponID = slug
                } else {
                    unmapped.insert("weapon \(weapon.id)")
                }
            }

            converted.append(AbyssHoyolabCharacter(
                characterID: characterID,
                constellation: min(max(character.actived_constellation_num, 0), 6),
                weaponID: weaponID,
                // Unlike Enka's affixMap (a raw 0-based "extra levels beyond
                // base" counter, needing +1), genshin.py's model aliases
                // affix_level -> refinement with no adjustment — evidence this
                // endpoint reports the player-facing R1-R5 number directly.
                // Unverified against a live account; if imported weapons come
                // back one refinement short, this is the first place to check.
                weaponRefinement: min(max(character.weapon?.affix_level ?? 1, 1), 5)))
        }

        return AbyssHoyolabRoster(uid: uid, fetchedAt: Date(),
                                  characters: converted.sorted { $0.characterID < $1.characterID },
                                  unmappedIDs: unmapped.sorted())
    }

    // MARK: - Errors

    /// HoYoLAB wraps every response as `{retcode, message, data}`; these are
    /// the codes `genshin.py` maps to the same handful of causes, not codes
    /// discovered here. Internal rather than private so a test can assert the
    /// mapping directly instead of duplicating it.
    static func throwForRetcode(_ retcode: Int, message: String) throws {
        switch retcode {
        case 0: return
        case -100, 10001: throw AbyssHoyolabError.invalidCredentials
        case 10101: throw AbyssHoyolabError.rateLimited
        case 10102: throw AbyssHoyolabError.dataNotPublic
        case 1009: throw AbyssHoyolabError.notFound
        default: throw AbyssHoyolabError.server(retcode: retcode, message: message)
        }
    }

    // MARK: - Dynamic Secret

    /// Headers every Game Record request needs alongside the cookie — an
    /// app-version/client-type pair the API checks for shape, and `ds`, a
    /// short-lived signature over a timestamp and a random nonce.
    static func dynamicSecretHeaders(lang: String = "en-us") -> [(String, String)] {
        [("x-rpc-app_version", "1.5.0"),
         ("x-rpc-client_type", "5"),
         ("x-rpc-language", lang),
         ("x-rpc-lang", lang),
         ("ds", dynamicSecret())]
    }

    static func dynamicSecret(timestamp: Int = Int(Date().timeIntervalSince1970),
                              random: String = randomAlphabetic(6)) -> String {
        computeDynamicSecret(salt: dsSalt, timestamp: timestamp, random: random)
    }

    /// The pure half of `dynamicSecret`, split out so a fixed timestamp/nonce
    /// can be asserted against a hand-computed MD5 in a test — real calls
    /// never pass `timestamp`/`random` themselves.
    static func computeDynamicSecret(salt: String, timestamp: Int, random: String) -> String {
        let signed = "salt=\(salt)&t=\(timestamp)&r=\(random)"
        let digest = Insecure.MD5.hash(data: Data(signed.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "\(timestamp),\(random),\(hex)"
    }

    private static func randomAlphabetic(_ length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
}

// MARK: - Wire format

/// HoYoLAB's universal response envelope.
struct HoyolabResponse<Payload: Decodable & Sendable>: Decodable, Sendable {
    let retcode: Int
    let message: String
    let data: Payload?
}

struct HoyolabCharacterList: Decodable, Sendable {
    let list: [HoyolabCharacter]
}

/// The subset of `event/game_record/genshin/api/character/list`'s per-character
/// fields this app reads. Field names are exactly the wire names — HoYoLAB
/// does not use camelCase.
struct HoyolabCharacter: Decodable, Sendable {
    let id: Int
    let element: String?
    let actived_constellation_num: Int
    let weapon: HoyolabWeapon?
}

struct HoyolabWeapon: Decodable, Sendable {
    let id: Int
    let affix_level: Int?
}
