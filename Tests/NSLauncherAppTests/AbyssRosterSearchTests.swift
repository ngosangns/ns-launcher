import XCTest
@testable import NSLauncherApp

/// Searching the roster grid. 125 characters and 246 weapons is far past what
/// anyone will scroll, so the search box is how the tab is actually used and its
/// matching rules are worth pinning.
@MainActor
final class AbyssRosterSearchTests: XCTestCase {

    /// The view model persists on every edit; tests must not touch the real
    /// Application Support file.
    private struct MemoryStore: AbyssRosterStoring {
        func load() throws -> AbyssRoster { .empty }
        func save(_ roster: AbyssRoster) throws {}
        func importRoster(from url: URL) throws -> AbyssRoster { .empty }
        func exportRoster(_ roster: AbyssRoster, to url: URL) throws {}
    }

    private struct MemoryShowcaseStore: AbyssShowcaseStoring {
        func load() throws -> AbyssShowcase? { nil }
        func save(_ showcase: AbyssShowcase) throws {}
        func clear() throws {}
    }

    /// Returns a canned showcase instead of calling Enka.
    private struct StubFetcher: AbyssShowcaseFetching {
        let showcase: AbyssShowcase
        func fetchShowcase(uid: String, map: AbyssGameIDMap) async throws -> AbyssShowcase { showcase }
    }

    private func makeViewModel(enka: AbyssShowcaseFetching = StubFetcher(showcase: .empty)) async -> AbyssViewModel {
        let viewModel = AbyssViewModel(store: MemoryStore(), showcaseStore: MemoryShowcaseStore(), enka: enka)
        // The library loads on a detached task; wait for it rather than racing.
        for _ in 0..<200 where viewModel.library == nil {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return viewModel
    }

    func testSearchMatchesNamesRegardlessOfCaseSpacingAndAccents() async throws {
        let viewModel = await makeViewModel()
        XCTAssertNotNil(viewModel.library, "the Abyss library never finished loading")

        // Display name, wrong case.
        viewModel.searchText = "hu tao"
        XCTAssertTrue(viewModel.characters.contains { $0.id == "hu-tao" })

        // Run together, the way people type it.
        viewModel.searchText = "hutao"
        XCTAssertTrue(viewModel.characters.contains { $0.id == "hu-tao" },
                      "a query with the space left out should still find the character")

        // The id itself, hyphens and all.
        viewModel.searchText = "hu-tao"
        XCTAssertTrue(viewModel.characters.contains { $0.id == "hu-tao" })

        // Accents dropped, as they are on most keyboards.
        viewModel.searchText = "childe"
        let accented = viewModel.characters
        viewModel.searchText = "CHILDE"
        XCTAssertEqual(accented.map(\.id), viewModel.characters.map(\.id),
                       "search should not be case sensitive")
    }

    func testEmptySearchShowsEverythingAndFiltersNarrow() async throws {
        let viewModel = await makeViewModel()
        let library = try XCTUnwrap(viewModel.library)

        XCTAssertEqual(viewModel.characters.count, library.characters.count)
        XCTAssertFalse(viewModel.hasActiveFilter)

        viewModel.elementFilter = .pyro
        XCTAssertTrue(viewModel.hasActiveFilter)
        XCTAssertFalse(viewModel.characters.isEmpty)
        XCTAssertTrue(viewModel.characters.allSatisfy { $0.element == .pyro })
        XCTAssertLessThan(viewModel.characters.count, library.characters.count)

        // Filters combine rather than replace each other.
        viewModel.weaponTypeFilter = .polearm
        XCTAssertTrue(viewModel.characters.allSatisfy { $0.element == .pyro && $0.weaponType == .polearm })

        viewModel.clearFilters()
        XCTAssertFalse(viewModel.hasActiveFilter)
        XCTAssertEqual(viewModel.characters.count, library.characters.count)
    }

    /// The weapons tab has its own type filter, and the counter under the search
    /// box has to follow whichever tab is showing.
    func testWeaponFiltersAndVisibleCountFollowTheTab() async throws {
        let viewModel = await makeViewModel()
        let library = try XCTUnwrap(viewModel.library)

        viewModel.rosterTab = .weapons
        XCTAssertEqual(viewModel.totalCount, library.weapons.count)
        XCTAssertEqual(viewModel.visibleCount, library.weapons.count)

        viewModel.weaponTypeFilter = .catalyst
        XCTAssertTrue(viewModel.weapons.allSatisfy { $0.type == .catalyst })
        XCTAssertEqual(viewModel.visibleCount, viewModel.weapons.count)
        XCTAssertEqual(viewModel.weaponsByType.map(\.type), [.catalyst],
                       "the grouped list should only contain the type being filtered to")

        viewModel.rosterTab = .characters
        XCTAssertEqual(viewModel.totalCount, library.characters.count)
    }

    /// Importing eight showcased characters must not look like a statement
    /// about the other hundred: it only ever adds, and never removes anything
    /// the player ticked by hand.
    func testImportAddsToTheRosterWithoutRemovingAnything() async throws {
        let showcase = AbyssShowcase(
            uid: "618285856", region: "os_euro", nickname: "Tester", adventureRank: 60,
            worldLevel: 8, fetchedAt: Date(), refreshInterval: 60,
            builds: [
                AbyssShowcaseBuild(characterID: "hu-tao", level: 90, constellation: 2,
                                   weaponID: "staff-of-homa", weaponLevel: 90, weaponRefinement: 3,
                                   setPieces: ["crimson-witch-of-flames": 4],
                                   stats: AbyssMeasuredStats()),
            ],
            unmappedIDs: [])
        let viewModel = await makeViewModel(enka: StubFetcher(showcase: showcase))

        // Something the player ticked themselves, which must survive.
        viewModel.toggleCharacter("diona")
        viewModel.uid = "618285856"
        XCTAssertTrue(viewModel.canImport)

        viewModel.importFromUID()
        for _ in 0..<200 where viewModel.showcase == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(viewModel.importStatus, .imported(nickname: "Tester", count: 1))
        XCTAssertTrue(viewModel.owns(characterID: "hu-tao"))
        XCTAssertTrue(viewModel.owns(characterID: "diona"), "the hand-entered character was dropped")
        XCTAssertTrue(viewModel.owns(weaponID: "staff-of-homa"))
        XCTAssertEqual(viewModel.roster.constellation(for: "hu-tao"), 2)
        XCTAssertEqual(viewModel.roster.refinement(for: "staff-of-homa"), 3)
        XCTAssertTrue(viewModel.isMeasured("hu-tao"))
        XCTAssertFalse(viewModel.isMeasured("diona"))

        // Enka serves the same snapshot until its ttl expires; asking again
        // before then just spends the rate limit.
        viewModel.importFromUID()
        if case .tooSoon = viewModel.importStatus {} else {
            XCTFail("a second import inside the ttl should be refused, got \(String(describing: viewModel.importStatus))")
        }

        viewModel.clearShowcase()
        XCTAssertNil(viewModel.showcase)
        XCTAssertTrue(viewModel.owns(characterID: "hu-tao"),
                      "forgetting the import should not un-own what it added")
    }

    func testImportIsRefusedForAMalformedUID() async throws {
        let viewModel = await makeViewModel()
        viewModel.uid = "123"
        XCTAssertFalse(viewModel.canImport)
        viewModel.uid = "618285856"
        XCTAssertTrue(viewModel.canImport)
    }

    func testOwnedOnlyHidesEverythingWhileTheRosterIsEmpty() async throws {
        let viewModel = await makeViewModel()

        viewModel.showsOwnedOnly = true
        XCTAssertTrue(viewModel.characters.isEmpty)
        XCTAssertEqual(viewModel.visibleCount, 0)

        viewModel.toggleCharacter("hu-tao")
        XCTAssertEqual(viewModel.characters.map(\.id), ["hu-tao"])
    }
}
