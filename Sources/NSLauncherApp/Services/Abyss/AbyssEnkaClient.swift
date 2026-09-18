// AbyssEnkaClient.swift
//
// Reads a player's Character Showcase from Enka.Network, given only their UID.
//
// Enka is a public read-only mirror of the showcase the game itself publishes,
// so this needs no login, no cookie and no server picker — the UID carries its
// own region, and the response says which. That is also its limit: the showcase
// is at most eight characters, and it is empty unless the player enabled "Show
// Character Details" in game. There is no unauthenticated way to a full roster.
//
// Their API terms ask for three things, all honoured here: a `User-Agent` that
// identifies the app, no UID enumeration, and respecting the `ttl` in each
// response instead of re-requesting a UID whose data cannot have changed.

import Foundation

protocol AbyssShowcaseFetching: Sendable {
    func fetchShowcase(uid: String, map: AbyssGameIDMap) async throws -> AbyssShowcase
}

enum AbyssEnkaError: LocalizedError, Equatable {
    case malformedUID
    case notFound
    case showcaseEmpty
    case rateLimited
    case gameMaintenance
    case serviceUnavailable
    case badResponse(status: Int)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .malformedUID: return "The UID is not in a valid format."
        case .notFound: return "No player with that UID."
        case .showcaseEmpty: return "That player's Character Showcase is empty or hidden."
        case .rateLimited: return "Enka.Network is rate-limiting this app. Try again shortly."
        case .gameMaintenance: return "The game server is in maintenance."
        case .serviceUnavailable: return "Enka.Network is unavailable."
        case .badResponse(let status): return "Enka.Network answered with HTTP \(status)."
        case .transport(let message): return message
        }
    }
}

struct AbyssEnkaClient: AbyssShowcaseFetching {
    private let session: URLSession
    private let host: URL

    /// Enka asks every consumer to identify itself so they can get in touch
    /// about traffic rather than just blocking it.
    private static let userAgent = "NSLauncher (github.com/ngosangns/ns-launcher)"

    init(session: URLSession? = nil, host: URL = URL(string: "https://enka.network")!) {
        self.session = session ?? {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.waitsForConnectivity = false
            return URLSession(configuration: configuration)
        }()
        self.host = host
    }

    /// A UID is 9-10 digits; the leading digit is the region. Checked before
    /// making a request so a typo costs nothing and never reaches Enka.
    static func isPlausibleUID(_ uid: String) -> Bool {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return (9...10).contains(trimmed.count) && trimmed.allSatisfy(\.isNumber) && !trimmed.hasPrefix("0")
    }

    func fetchShowcase(uid: String, map: AbyssGameIDMap) async throws -> AbyssShowcase {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isPlausibleUID(trimmed) else { throw AbyssEnkaError.malformedUID }

        var request = URLRequest(url: host.appendingPathComponent("api/uid/\(trimmed)"))
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AbyssEnkaError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 400: throw AbyssEnkaError.malformedUID
            case 404: throw AbyssEnkaError.notFound
            case 424: throw AbyssEnkaError.gameMaintenance
            case 429: throw AbyssEnkaError.rateLimited
            case 503: throw AbyssEnkaError.serviceUnavailable
            default: throw AbyssEnkaError.badResponse(status: http.statusCode)
            }
        }

        let payload: EnkaResponse
        do {
            payload = try JSONDecoder().decode(EnkaResponse.self, from: data)
        } catch {
            throw AbyssEnkaError.transport(String(describing: error))
        }
        return try Self.convert(payload, uid: trimmed, map: map)
    }

    // MARK: - Conversion

    static func convert(_ payload: EnkaResponse, uid: String, map: AbyssGameIDMap) throws -> AbyssShowcase {
        guard let avatars = payload.avatarInfoList, !avatars.isEmpty else {
            throw AbyssEnkaError.showcaseEmpty
        }

        var builds: [AbyssShowcaseBuild] = []
        var unmapped: Set<String> = []

        for avatar in avatars {
            guard let characterID = map.characterID(avatarID: avatar.avatarId,
                                                    skillDepotID: avatar.skillDepotId) else {
                unmapped.insert("avatar \(avatar.avatarId)")
                continue
            }

            var weaponID: String?
            var weaponLevel = 1
            var refinement = 1
            var pieces: [String: Int] = [:]

            for equip in avatar.equipList ?? [] {
                if let weapon = equip.weapon {
                    guard let itemId = equip.itemId, let slug = map.weaponID(itemID: itemId) else {
                        if let itemId = equip.itemId { unmapped.insert("weapon \(itemId)") }
                        continue
                    }
                    weaponID = slug
                    weaponLevel = weapon.level ?? 1
                    // affixMap holds the refinement as a 0-based level, so R1 is 0.
                    refinement = (weapon.affixMap?.values.first ?? 0) + 1
                } else if let setId = equip.flat?.setId {
                    guard let slug = map.artifactSetID(setID: setId) else {
                        unmapped.insert("artifact set \(setId)")
                        continue
                    }
                    pieces[slug, default: 0] += 1
                }
            }

            builds.append(AbyssShowcaseBuild(
                characterID: characterID,
                level: Int(avatar.propMap?["4001"]?.val ?? "") ?? 90,
                constellation: min(avatar.talentIdList?.count ?? 0, 6),
                weaponID: weaponID,
                weaponLevel: weaponLevel,
                weaponRefinement: min(max(refinement, 1), 5),
                setPieces: pieces,
                stats: measuredStats(from: avatar.fightPropMap)))
        }

        guard !builds.isEmpty else { throw AbyssEnkaError.showcaseEmpty }

        let info = payload.playerInfo
        return AbyssShowcase(
            uid: uid,
            region: payload.region ?? "",
            nickname: info?.nickname ?? "",
            adventureRank: info?.level ?? 0,
            worldLevel: info?.worldLevel ?? 0,
            fetchedAt: Date(),
            refreshInterval: payload.ttl ?? 60,
            builds: builds.sorted { $0.characterID < $1.characterID },
            unmappedIDs: unmapped.sorted())
    }

    /// `fightPropMap` keys are the game's FIGHT_PROP ids.
    ///
    /// It reports each stat pre-split into its base, percentage and flat parts,
    /// which is the shape `AbyssStats` already uses — so this is a rename, not a
    /// reconstruction, and `base × (1 + percent) + flat` reproduces the totals
    /// the game itself reports.
    static func measuredStats(from properties: [String: Double]?) -> AbyssMeasuredStats {
        func value(_ id: Int) -> Double { properties?[String(id)] ?? 0 }

        var stats = AbyssMeasuredStats()
        stats.baseHP = value(1)
        stats.flatHP = value(2)
        stats.hpPercent = value(3)
        stats.baseATK = value(4)
        stats.flatATK = value(5)
        stats.atkPercent = value(6)
        stats.baseDEF = value(7)
        stats.flatDEF = value(8)
        stats.defPercent = value(9)
        // These carry the character's innate 5% / 50% / 100% already.
        stats.critRate = value(20)
        stats.critDMG = value(22)
        stats.energyRecharge = value(23)
        stats.healingBonus = value(26)
        stats.elementalMastery = value(28)

        // Physical DMG (prop 30) is read but not stored: no character has
        // Physical as their element, so it never reaches the damage model.
        let elements: [(Int, GenshinElement)] = [
            (40, .pyro), (41, .electro), (42, .hydro), (43, .dendro),
            (44, .anemo), (45, .geo), (46, .cryo),
        ]
        for (id, element) in elements where value(id) != 0 {
            stats.elementalDMG[element.rawValue] = value(id)
        }
        return stats
    }
}

// MARK: - Wire format

/// The subset of Enka's response this app reads. Everything is optional: it is
/// someone else's API, and a showcase with details switched off legitimately
/// arrives with most of this missing.
struct EnkaResponse: Decodable, Sendable {
    struct PlayerInfo: Decodable, Sendable {
        let nickname: String?
        let level: Int?
        let worldLevel: Int?
    }

    struct Weapon: Decodable, Sendable {
        let level: Int?
        /// Refinement, 0-based, keyed by an internal affix id.
        let affixMap: [String: Int]?
    }

    struct Flat: Decodable, Sendable {
        let setId: Int?
        let itemType: String?
    }

    struct Equip: Decodable, Sendable {
        let itemId: Int?
        let weapon: Weapon?
        let flat: Flat?
    }

    struct PropValue: Decodable, Sendable {
        let val: String?
    }

    struct Avatar: Decodable, Sendable {
        let avatarId: Int
        let skillDepotId: Int?
        /// Constellations unlocked, one id each.
        let talentIdList: [Int]?
        let propMap: [String: PropValue]?
        let fightPropMap: [String: Double]?
        let equipList: [Equip]?
    }

    let playerInfo: PlayerInfo?
    let avatarInfoList: [Avatar]?
    let ttl: Int?
    let uid: String?
    let region: String?
}
