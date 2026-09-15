// AbyssSearchCache.swift
//
// A saved search result, and what decides whether it still answers the
// question being asked.
//
// The search is a pure function of its inputs: the same roster, the same pool
// flags, the same showcase, against the same rotation, always produces the same
// teams — no randomness anywhere in `AbyssOptimizer`. That is what makes caching
// the result safe with no "force refresh" escape hatch: whenever the key below
// matches, the cached output *is* what running the search again would produce,
// so there is nothing to refresh.

import CryptoKit
import Foundation

/// Everything a search result depends on, folded into one comparable value.
///
/// Deliberately built from the same fields `AbyssOptimizerRequest` carries,
/// plus the one thing outside the request that the output also depends on: which
/// rotation's monsters and buffs the search ran against.
struct AbyssSearchCacheKey: Encodable, Equatable, Sendable {
    let roster: AbyssRoster
    let usesFullCharacterPool: Bool
    let usesFullWeaponPool: Bool
    let usesMeasuredStats: Bool
    let showcase: [AbyssShowcaseBuild]
    let floors: [Int]?
    let topN: Int
    let poolSize: Int
    let refinesArtifacts: Bool
    let splitsHalves: Bool
    /// The rotation these teams were planned against. Two different rotations
    /// must never share a cache entry even if every other field happens to
    /// match, which is why this is part of the key rather than checked
    /// separately.
    let cyclePeriodStart: String?
    /// `AbyssDataLibrary.dataDigest`: the bytes of every data file the search
    /// read. `cyclePeriodStart` names *which* rotation; this says whether that
    /// rotation's file — or any character's, or `tuning.json` — is still the
    /// one the cached answer was computed from. The first thing to prove it
    /// necessary was a change that rewrote every floor-12 monster's resistance
    /// and left `periodStart` untouched.
    let dataDigest: String

    init(request: AbyssOptimizerRequest, cyclePeriodStart: String?, dataDigest: String = "") {
        // Sorted, because the search does not read the roster as a sequence:
        // `AbyssOptimizer` filters the library's own character list by owned
        // id and looks constellations and refinements up by id. Two rosters
        // holding the same people in a different order — a HoYoLAB re-import
        // that came back in another order, say — are the same question, and
        // an order-sensitive key would answer it with a needless re-run.
        let unordered = request.roster ?? .empty
        roster = AbyssRoster(characters: unordered.characters.sorted { $0.id < $1.id },
                             weapons: unordered.weapons.sorted { $0.id < $1.id })
        usesFullCharacterPool = request.usesFullCharacterPool
        usesFullWeaponPool = request.usesFullWeaponPool
        usesMeasuredStats = request.usesMeasuredStats
        showcase = request.showcase
        floors = request.floors
        topN = request.topN
        poolSize = request.poolSize
        refinesArtifacts = request.refinesArtifacts
        splitsHalves = request.splitsHalves
        self.cyclePeriodStart = cyclePeriodStart
        self.dataDigest = dataDigest
    }

    /// A stable digest of every field above.
    ///
    /// SHA-256 over a `.sortedKeys` JSON encoding rather than comparing the
    /// structs directly: the persisted cache holds one digest string next to
    /// the output, so checking "is this still the right cache" never needs to
    /// decode the (potentially large) roster or showcase that produced it, only
    /// compare two short strings. `.sortedKeys` makes the encoding
    /// order-independent, which is what makes the digest of two field sets with
    /// the same values but a different in-memory dictionary order come out
    /// identical.
    var digest: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else {
            // Every field here is a plain Codable value; encoding cannot fail
            // in practice. Falling back to a key nothing will ever match is
            // safer than crashing over what is only a cache.
            return "unencodable-\(UUID().uuidString)"
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// One cached search result, keyed and timestamped.
///
/// Single-slot by design: there is one "current suggested lineup", not a
/// history of past ones. A roster edit or a new rotation changes the digest, so
/// the old entry simply stops matching rather than needing to be found and
/// evicted — `AbyssSearchCacheStore` just overwrites it.
///
/// `AbyssSearchCacheStore.maxAge` still bounds the entry's life, but not
/// because the key can miss a data change any more — `dataDigest` covers that.
/// The week is there for the one thing no digest sees: this app's own code
/// changing what it computes from the same bytes.
struct AbyssSearchCache: Codable, Sendable {
    let key: String
    let computedAt: Date
    let output: AbyssOptimizerOutput
}
