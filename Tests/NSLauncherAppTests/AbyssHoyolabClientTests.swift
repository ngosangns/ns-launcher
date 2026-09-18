import XCTest
@testable import NSLauncherApp

/// Nothing here touches the real network — HoYoLAB has no sandbox and this
/// needs a real login session to call for real. What can be verified without
/// one: the Dynamic Secret matches the reference implementation byte for
/// byte, UID prefixes map to the server codes the game's own wiki documents,
/// the wire format decodes (and every retcode maps) the way `genshin.py`
/// does, and — via a stubbed `URLProtocol` — that the request actually goes
/// to the *overseas* Game Record host, not the mainland-China one from
/// `genshin.py`'s own routing table that an earlier version of this client
/// used by mistake (see `testRequestsTheOverseasGameRecordHostAndPath`).
final class AbyssHoyolabClientTests: XCTestCase {

    /// Computed independently in Python from `genshin.py`'s exact formula
    /// (`hashlib.md5(f"salt={salt}&t={t}&r={r}")`) for this fixed input, so a
    /// typo in the salt, the field order, or the separators shows up here
    /// instead of as a silent 401 against the real API.
    func testDynamicSecretMatchesTheReferenceImplementation() {
        let secret = AbyssHoyolabClient.computeDynamicSecret(
            salt: "6s25p5ox5y14umn1p61aqyyvbvvl3lrt", timestamp: 1_700_000_000, random: "AbCdEf")
        XCTAssertEqual(secret, "1700000000,AbCdEf,52762c606b53f6830e4692f53664105e")
    }

    /// A live secret still has the right shape: real timestamp, a fresh random
    /// nonce each call (so two calls a second apart do not collide), three
    /// comma-separated fields.
    func testLiveDynamicSecretHasTheRightShape() {
        let secret = AbyssHoyolabClient.dynamicSecret()
        let parts = secret.split(separator: ",")
        XCTAssertEqual(parts.count, 3)
        XCTAssertNotNil(Int(parts[0]))
        XCTAssertEqual(parts[1].count, 6)
        XCTAssertEqual(parts[2].count, 32, "MD5 hex digest should be 32 characters")

        let again = AbyssHoyolabClient.dynamicSecret()
        XCTAssertNotEqual(secret, again, "two calls should not produce the same nonce")
    }

    // MARK: - UID -> server

    func testServerCodeMatchesTheDocumentedUIDPrefixes() {
        XCTAssertEqual(AbyssHoyolabClient.serverCode(forUID: "618285856"), "os_usa")
        XCTAssertEqual(AbyssHoyolabClient.serverCode(forUID: "712345678"), "os_euro")
        XCTAssertEqual(AbyssHoyolabClient.serverCode(forUID: "812345678"), "os_asia")
        XCTAssertEqual(AbyssHoyolabClient.serverCode(forUID: "912345678"), "os_cht")
        // The newer 10-digit Asia-server prefix.
        XCTAssertEqual(AbyssHoyolabClient.serverCode(forUID: "1812345678"), "os_asia")
    }

    func testServerCodeRejectsUnsupportedOrMalformedUIDs() {
        // Mainland China and the internal test server are not this app's
        // scope (developer.md: "current product scope is limited to global
        // Genshin"), and should not be silently mapped to some overseas guess.
        XCTAssertNil(AbyssHoyolabClient.serverCode(forUID: "112345678"))
        XCTAssertNil(AbyssHoyolabClient.serverCode(forUID: "512345678"))
        XCTAssertNil(AbyssHoyolabClient.serverCode(forUID: "012345678"))
        // A 10-digit UID with any prefix other than "18" is not a documented
        // server; guessing would be worse than refusing.
        XCTAssertNil(AbyssHoyolabClient.serverCode(forUID: "6123456789"))
        XCTAssertNil(AbyssHoyolabClient.serverCode(forUID: "12345"))
        XCTAssertNil(AbyssHoyolabClient.serverCode(forUID: ""))
    }

    // MARK: - Decoding and conversion

    private func library() -> AbyssDataLibrary { AbyssDataLibraryTests.library }

    /// Hu Tao (a normal character), the Traveler resolved purely from the
    /// element string HoYoLAB reports (no skill depot involved, unlike Enka),
    /// and one avatar id the data has never heard of.
    func testConvertsCharactersIncludingTheTravelerByElementName() throws {
        let map = library().gameIDs
        let huTaoID = try XCTUnwrap(Int(map.characters.first { $0.value == "hu-tao" }?.key ?? ""))
        let homaID = try XCTUnwrap(Int(map.weapons.first { $0.value == "staff-of-homa" }?.key ?? ""))

        let characters = [
            HoyolabCharacter(id: huTaoID, element: "Fire", actived_constellation_num: 2,
                             weapon: HoyolabWeapon(id: homaID, affix_level: 5)),
            // Traveler, Anemo — Enka needs a skill depot id for this; HoYoLAB
            // hands over the element name directly.
            HoyolabCharacter(id: 10_000_005, element: "Wind", actived_constellation_num: 0, weapon: nil),
            HoyolabCharacter(id: 99_999_999, element: "Fire", actived_constellation_num: 0, weapon: nil),
        ]

        let roster = AbyssHoyolabClient.convert(characters, uid: "618285856", map: map)

        XCTAssertEqual(roster.characters.map(\.characterID).sorted(), ["hu-tao", "traveler-anemo"])
        XCTAssertEqual(roster.unmappedIDs, ["character 99999999"])

        let huTao = try XCTUnwrap(roster.characters.first { $0.characterID == "hu-tao" })
        XCTAssertEqual(huTao.constellation, 2)
        XCTAssertEqual(huTao.weaponID, "staff-of-homa")
        // Passed straight through — see the comment on weaponRefinement in
        // AbyssHoyolabClient.convert about why this field is not offset by 1
        // the way Enka's affixMap is.
        XCTAssertEqual(huTao.weaponRefinement, 5)
    }

    func testAWeaponIDTheDataHasNeverHeardOfIsReportedNotDropped() throws {
        let map = library().gameIDs
        let huTaoID = try XCTUnwrap(Int(map.characters.first { $0.value == "hu-tao" }?.key ?? ""))
        let roster = AbyssHoyolabClient.convert(
            [HoyolabCharacter(id: huTaoID, element: "Fire", actived_constellation_num: 0,
                              weapon: HoyolabWeapon(id: 88_888_888, affix_level: 0))],
            uid: "618285856", map: map)

        let huTao = try XCTUnwrap(roster.characters.first)
        XCTAssertNil(huTao.weaponID, "an unmapped weapon should not silently attach to the character")
        XCTAssertEqual(roster.unmappedIDs, ["weapon 88888888"])
    }

    // MARK: - Response envelope

    func testDecodesTheHoyolabResponseEnvelope() throws {
        let json = """
        {"retcode":0,"message":"OK","data":{"list":[
            {"id":10000046,"element":"Fire","actived_constellation_num":1,
             "weapon":{"id":11509,"affix_level":2}}
        ]}}
        """
        let payload = try JSONDecoder().decode(HoyolabResponse<HoyolabCharacterList>.self,
                                               from: Data(json.utf8))
        XCTAssertEqual(payload.retcode, 0)
        XCTAssertEqual(payload.data?.list.count, 1)
        XCTAssertEqual(payload.data?.list.first?.weapon?.affix_level, 2)
    }

    /// Every retcode this client special-cases maps to a distinct, specific
    /// error — not a shared catch-all a user could not act on.
    func testRetcodesMapToDistinctErrors() {
        let cases: [(Int, AbyssHoyolabError)] = [
            (-100, .invalidCredentials),
            (10001, .invalidCredentials),
            (10101, .rateLimited),
            (10102, .dataNotPublic),
            (1009, .notFound),
            (12345, .server(retcode: 12345, message: "mystery")),
        ]
        for (retcode, expected) in cases {
            XCTAssertThrowsError(try AbyssHoyolabClient.throwForRetcode(retcode, message: "mystery")) { error in
                XCTAssertEqual(error as? AbyssHoyolabError, expected, "retcode \(retcode)")
            }
        }
        XCTAssertNoThrow(try AbyssHoyolabClient.throwForRetcode(0, message: "OK"))
    }

    // MARK: - Request shape

    /// `genshin.py`'s routing table has two hosts for this exact endpoint
    /// path shape: an overseas one (`sg-public-api.hoyolab.com`) and a
    /// mainland-China one (`api-takumi-record.mihoyo.com`) that looks
    /// deceptively similar. An overseas `ltuid_v2`/`ltoken_v2` session is
    /// rejected outright by the China host — wrong region entirely, not a bad
    /// credential — so this pins the client's default host and path rather
    /// than leaving it to only be caught by a real, live import failing.
    func testRequestsTheOverseasGameRecordHostAndPath() async throws {
        StubURLProtocol.capturedRequest = nil
        StubURLProtocol.responseJSON = #"{"retcode":0,"message":"OK","data":{"list":[]}}"#

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let client = AbyssHoyolabClient(session: URLSession(configuration: configuration))

        _ = try await client.fetchFullRoster(uid: "618285856", ltuid: "1", ltoken: "2", map: library().gameIDs)

        let url = try XCTUnwrap(StubURLProtocol.capturedRequest?.url)
        XCTAssertEqual(url.absoluteString,
                       "https://sg-public-api.hoyolab.com/event/game_record/genshin/api/character/list")
    }
}

/// Captures the outgoing request and answers with a canned envelope, so
/// `testRequestsTheOverseasGameRecordHostAndPath` can assert on the URL
/// without a real HoYoLAB session or reaching the network.
private final class StubURLProtocol: URLProtocol {
    // Test-only: `URLProtocol.startLoading()` runs on a session-internal
    // queue, but the one test that uses this awaits the request's completion
    // before reading `capturedRequest`, so the two accesses never race in
    // practice — the compiler just cannot see that ordering.
    nonisolated(unsafe) static var capturedRequest: URLRequest?
    nonisolated(unsafe) static var responseJSON = ""

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responseJSON.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
