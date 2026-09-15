import XCTest
@testable import NSLauncherApp

/// `AbyssViewModel.search()` reading a cached result end to end, through the
/// real optimizer rather than a stub — the digest tests in
/// `AbyssSearchCacheTests` pin the key in isolation, this pins that the view
/// model actually consults it at the right moment.
@MainActor
final class AbyssSearchCachingTests: XCTestCase {

    private struct MemoryStore: AbyssRosterStoring {
        let roster: AbyssRoster
        func load() throws -> AbyssRoster { roster }
        func save(_ roster: AbyssRoster) throws {}
        func importRoster(from url: URL) throws -> AbyssRoster { .empty }
        func exportRoster(_ roster: AbyssRoster, to url: URL) throws {}
    }

    private struct MemoryShowcaseStore: AbyssShowcaseStoring {
        func load() throws -> AbyssShowcase? { nil }
        func save(_ showcase: AbyssShowcase) throws {}
        func clear() throws {}
    }

    private struct StubFetcher: AbyssShowcaseFetching {
        func fetchShowcase(uid: String, map: AbyssGameIDMap) async throws -> AbyssShowcase { .empty }
    }

    private final class MemoryCredentialStore: AbyssHoyolabCredentialStoring, @unchecked Sendable {
        func load() -> (ltuid: String, ltoken: String)? { nil }
        func save(ltuid: String, ltoken: String) throws {}
    }

    private struct StubHoyolabFetcher: AbyssFullRosterFetching {
        func fetchFullRoster(uid: String, ltuid: String, ltoken: String, map: AbyssGameIDMap) async throws
            -> AbyssHoyolabRoster { .empty }
    }

    /// Counts writes so a test can tell "read the cache" apart from "ran the
    /// search again and happened to get the same answer" without depending on
    /// timing.
    private final class MemorySearchCacheStore: AbyssSearchCacheStoring, @unchecked Sendable {
        var stored: AbyssSearchCache?
        var saveCount = 0
        func load() -> AbyssSearchCache? { stored }
        func save(_ cache: AbyssSearchCache) throws {
            stored = cache
            saveCount += 1
        }
        func clear() throws { stored = nil }
    }

    private func makeViewModel(cacheStore: AbyssSearchCacheStoring) async throws -> AbyssViewModel {
        let roster = try AbyssGoldenFixture.exampleRoster()
        let viewModel = AbyssViewModel(store: MemoryStore(roster: roster), showcaseStore: MemoryShowcaseStore(),
                                       searchCacheStore: cacheStore, enka: StubFetcher(),
                                       hoyolab: StubHoyolabFetcher(), hoyolabCredentials: MemoryCredentialStore())
        for _ in 0..<200 where viewModel.library == nil {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return viewModel
    }

    private func waitForSearch(_ viewModel: AbyssViewModel) async {
        for _ in 0..<1500 where viewModel.isSearching {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// The behaviour this whole feature is for: asking the same question twice
    /// answers the second time without redoing the work.
    func testASecondIdenticalSearchReadsTheCacheInsteadOfRerunning() async throws {
        let cacheStore = MemorySearchCacheStore()
        let viewModel = try await makeViewModel(cacheStore: cacheStore)

        viewModel.search()
        XCTAssertTrue(viewModel.isSearching,
                      "a first run over 15 characters should not resolve synchronously — if it does, "
                      + "nothing below is actually testing a cache hit against a real search")
        await waitForSearch(viewModel)
        XCTAssertFalse(viewModel.reports.isEmpty)
        let firstComputedAt = try XCTUnwrap(viewModel.resultsComputedAt)
        let firstReportIDs = viewModel.reports.map(\.id)
        XCTAssertEqual(cacheStore.saveCount, 1, "a fresh run should write exactly one cache entry")

        // Same roster, same toggles, same rotation.
        viewModel.search()
        XCTAssertFalse(viewModel.isSearching,
                       "a cache hit returns synchronously; isSearching flipping true means it re-ran")
        XCTAssertEqual(viewModel.resultsComputedAt, firstComputedAt,
                       "the timestamp should still be the first run's")
        XCTAssertEqual(viewModel.reports.map(\.id), firstReportIDs)
        XCTAssertEqual(cacheStore.saveCount, 1, "reading a cache hit must not write to it again")
    }

    /// The cache is scoped to the exact question asked — a roster edit is a
    /// different question, and must not read back a stale answer.
    func testChangingTheRosterMissesTheCache() async throws {
        let cacheStore = MemorySearchCacheStore()
        let viewModel = try await makeViewModel(cacheStore: cacheStore)

        viewModel.search()
        await waitForSearch(viewModel)
        XCTAssertEqual(cacheStore.saveCount, 1)

        viewModel.toggleCharacter("aloy") // not in the example roster
        viewModel.search()
        XCTAssertTrue(viewModel.isSearching, "the roster changed; this must run fresh, not hit the cache")
        await waitForSearch(viewModel)
        XCTAssertEqual(cacheStore.saveCount, 2, "the new roster's result should overwrite the single slot")
    }

    /// A cache written by an earlier launch is exactly as usable as one from
    /// earlier in the same session — this is what makes the feature save
    /// anything across app restarts rather than only within one.
    func testAPreExistingCacheIsUsedOnTheFirstSearchOfTheSession() async throws {
        let roster = try AbyssGoldenFixture.exampleRoster()
        let request = AbyssOptimizerRequest(roster: roster, usesFullCharacterPool: false,
                                            usesFullWeaponPool: false, topN: 5, showcase: [])
        let cyclePeriodStart = AbyssDataLibraryTests.library.latestCycle?.periodStart
        let key = AbyssSearchCacheKey(request: request, cyclePeriodStart: cyclePeriodStart,
                                      dataDigest: AbyssDataLibraryTests.library.dataDigest).digest
        let seeded = AbyssSearchCache(
            key: key, computedAt: Date().addingTimeInterval(-3600),
            output: AbyssOptimizerOutput(reports: [], consideredCharacterIDs: [], unknownRosterIDs: ["ghost"]))

        let cacheStore = MemorySearchCacheStore()
        cacheStore.stored = seeded
        let viewModel = try await makeViewModel(cacheStore: cacheStore)

        viewModel.search()
        XCTAssertFalse(viewModel.isSearching, "a cache seeded before the view model existed should still hit")
        XCTAssertEqual(viewModel.unknownRosterIDs, ["ghost"], "the seeded cache's own output should come back")
        XCTAssertEqual(cacheStore.saveCount, 0)
    }
}
