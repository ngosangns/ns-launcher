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

    /// Not backed by the real Keychain: a view model test should not depend on
    /// or mutate whatever is actually saved on the machine running it.
    private final class MemoryCredentialStore: AbyssHoyolabCredentialStoring, @unchecked Sendable {
        var saved: (ltuid: String, ltoken: String)?
        func load() -> (ltuid: String, ltoken: String)? { saved }
        func save(ltuid: String, ltoken: String) throws { saved = (ltuid, ltoken) }
    }

    /// Returns a canned full roster instead of calling HoYoLAB.
    private struct StubHoyolabFetcher: AbyssFullRosterFetching {
        let roster: AbyssHoyolabRoster
        func fetchFullRoster(uid: String, ltuid: String, ltoken: String, map: AbyssGameIDMap) async throws
            -> AbyssHoyolabRoster { roster }
    }

    private func makeViewModel(enka: AbyssShowcaseFetching = StubFetcher(showcase: .empty),
                               hoyolab: AbyssFullRosterFetching = StubHoyolabFetcher(roster: .empty),
                               hoyolabCredentials: AbyssHoyolabCredentialStoring = MemoryCredentialStore())
        async -> AbyssViewModel {
        let viewModel = AbyssViewModel(store: MemoryStore(), showcaseStore: MemoryShowcaseStore(), enka: enka,
                                       hoyolab: hoyolab, hoyolabCredentials: hoyolabCredentials)
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

    /// The grid shows `nameVI` in the Vietnamese UI, so the name a player can
    /// see on screen has to be the name they can type. Most characters are
    /// unaffected — the game leaves proper names alone — but weapon and
    /// artifact-set names are translated in full, and so are the handful of
    /// characters named for what they are rather than who they are.
    func testSearchMatchesTheVietnameseNameTheGridIsShowing() async throws {
        let viewModel = await makeViewModel()
        XCTAssertNotNil(viewModel.library, "the Abyss library never finished loading")

        // A character whose Vietnamese name is nothing like the English one.
        viewModel.searchText = "Kẻ Lang Thang"
        XCTAssertTrue(viewModel.characters.contains { $0.id == "wanderer" },
                      "the Vietnamese name shown on the tile should find the character")

        // Typed without the accents, which is how most keyboards produce it.
        viewModel.searchText = "ke lang thang"
        XCTAssertTrue(viewModel.characters.contains { $0.id == "wanderer" })

        // The element qualifier the app appends is part of the shown name too.
        viewModel.searchText = "nhà lữ hành"
        XCTAssertTrue(viewModel.characters.contains { $0.id == "traveler-anemo" })

        // Weapons are translated in full, so this is the common case there.
        viewModel.rosterTab = .weapons
        viewModel.searchText = "Phong Ưng Kiếm"
        XCTAssertTrue(viewModel.weapons.contains { $0.id == "aquila-favonia" })

        viewModel.searchText = "phong ung kiem"
        XCTAssertTrue(viewModel.weapons.contains { $0.id == "aquila-favonia" },
                      "dropping the accents should still find the weapon")

        // The English name still matches, since the English UI still shows it.
        viewModel.searchText = "aquila"
        XCTAssertTrue(viewModel.weapons.contains { $0.id == "aquila-favonia" })
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

    }

    // MARK: - Sorting

    func testCharacterSortsOrderTheGrid() async throws {
        let viewModel = await makeViewModel()

        // Stars first is the default: the data's own order groups characters by
        // nation, which this screen never shows, and rarity is what people scan
        // a roster grid by.
        XCTAssertEqual(viewModel.rosterSort, .rarity)
        let rarities = viewModel.characters.map(\.rarity)
        XCTAssertEqual(rarities, rarities.sorted(by: >), "5★ should come before 4★")

        viewModel.rosterSort = .name
        let names = viewModel.characters.map(\.name)
        XCTAssertEqual(names, names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })

        viewModel.rosterSort = .release
        let dates = viewModel.characters.map { $0.releaseDate ?? "" }
        XCTAssertEqual(dates, dates.sorted(by: >), "newest first")

        viewModel.rosterSort = .owned
        viewModel.toggleCharacter("hu-tao")
        XCTAssertEqual(viewModel.characters.first?.id, "hu-tao",
                       "the only owned character should sort to the front")
    }

    func testWeaponSortsOrderTheGrid() async throws {
        let viewModel = await makeViewModel()
        viewModel.rosterTab = .weapons

        viewModel.rosterSort = .attack
        let attack = viewModel.weapons.map { $0.atkLv90 ?? 0 }
        XCTAssertEqual(attack, attack.sorted(by: >))

        viewModel.rosterSort = .rarity
        let rarities = viewModel.weapons.map(\.rarity)
        XCTAssertEqual(rarities, rarities.sorted(by: >))
    }

    /// Each key has its own interesting end — A first, but 5★ first — so
    /// picking a sort has to land on that end rather than on a shared default.
    func testEachSortStartsAtItsOwnInterestingEnd() async throws {
        let viewModel = await makeViewModel()

        viewModel.rosterSort = .rarity
        XCTAssertTrue(viewModel.sortDescending, "stars should open on 5★, not 1★")
        XCTAssertEqual(viewModel.characters.first?.rarity, 5)

        viewModel.rosterSort = .name
        XCTAssertFalse(viewModel.sortDescending, "names should open on A")

        viewModel.rosterTab = .weapons
        viewModel.rosterSort = .attack
        XCTAssertTrue(viewModel.sortDescending, "base ATK should open on the strongest")
    }

    /// Reversing flips the blocks; it must not scramble the names inside them.
    func testReversingFlipsTheKeyButKeepsNamesAscendingWithinTies() async throws {
        let viewModel = await makeViewModel()
        viewModel.rosterSort = .rarity

        let descending = viewModel.characters.map(\.rarity)
        viewModel.sortDescending = false
        let ascending = viewModel.characters.map(\.rarity)

        XCTAssertEqual(ascending, descending.reversed().sorted(), "reversing did not flip the star order")
        XCTAssertEqual(ascending.first, 4)
        XCTAssertEqual(ascending.last, 5)

        // Inside one star block the names still run A → Z.
        let fourStars = viewModel.characters.filter { $0.rarity == 4 }.map(\.name)
        XCTAssertEqual(fourStars,
                       fourStars.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
                       "reversing the key should not reverse the names inside a tie")

        // And flipping a name sort really does give Z → A.
        viewModel.rosterSort = .name
        viewModel.sortDescending = true
        let names = viewModel.characters.map(\.name)
        XCTAssertEqual(names,
                       names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending })
    }

    /// Every ordering has to be total, not just correct on its headline key.
    /// Swift's sort is unstable, so a comparator that stops at "same rarity"
    /// leaves the order within each rarity block up to the sort's internals —
    /// which is how a grid ends up looking like it rearranges itself. Each sort
    /// therefore has to fall through to the name, and that is what is asserted:
    /// inside every run of equal keys, names ascend.
    func testEveryOrderingFallsThroughToTheName() async throws {
        let viewModel = await makeViewModel()

        func assertNamesAscend<T>(_ items: [T], key: (T) -> String, name: (T) -> String,
                                  sort: AbyssViewModel.RosterSort) {
            for (previous, next) in zip(items, items.dropFirst()) where key(previous) == key(next) {
                XCTAssertTrue(
                    name(previous).localizedCaseInsensitiveCompare(name(next)) != .orderedDescending,
                    "\(sort): \(name(previous)) and \(name(next)) tie on the sort key but are not in name order")
            }
        }

        viewModel.rosterSort = .rarity
        assertNamesAscend(viewModel.characters, key: { String($0.rarity) }, name: \.name, sort: .rarity)

        viewModel.rosterSort = .element
        assertNamesAscend(viewModel.characters, key: { $0.element.rawValue }, name: \.name, sort: .element)

        viewModel.rosterSort = .owned
        assertNamesAscend(viewModel.characters, key: { _ in "unowned" }, name: \.name, sort: .owned)

        viewModel.rosterTab = .weapons
        viewModel.rosterSort = .rarity
        assertNamesAscend(viewModel.weapons, key: { String($0.rarity) }, name: \.name, sort: .rarity)

        viewModel.rosterSort = .attack
        assertNamesAscend(viewModel.weapons, key: { String($0.atkLv90 ?? 0) }, name: \.name, sort: .attack)
    }

    /// A weapon has no element, so carrying that sort across to the weapons tab
    /// would leave a control labelled with an order it is not applying.
    func testSwitchingTabsDropsASortTheOtherTabCannotUse() async throws {
        let viewModel = await makeViewModel()

        viewModel.rosterSort = .element
        viewModel.rosterTab = .weapons
        XCTAssertEqual(viewModel.rosterSort, .name)

        // One both tabs share survives the switch.
        viewModel.rosterSort = .rarity
        viewModel.rosterTab = .characters
        XCTAssertEqual(viewModel.rosterSort, .rarity)
    }

    func testImportIsRefusedForAMalformedUID() async throws {
        let viewModel = await makeViewModel()
        viewModel.uid = "123"
        XCTAssertFalse(viewModel.canImport)
        viewModel.uid = "618285856"
        XCTAssertTrue(viewModel.canImport)
    }

    // MARK: - Full roster import (HoYoLAB)

    /// Same "only ever adds" contract as the Showcase import, but for many
    /// more characters at once, and scored on the standard build rather than
    /// measured stats — HoYoLAB's character list has no artifact detail.
    func testFullRosterImportAddsOwnershipWithoutMeasuredStats() async throws {
        let hoyolabRoster = AbyssHoyolabRoster(
            uid: "618285856", fetchedAt: Date(),
            characters: [
                AbyssHoyolabCharacter(characterID: "hu-tao", constellation: 2,
                                      weaponID: "staff-of-homa", weaponRefinement: 3),
                AbyssHoyolabCharacter(characterID: "bennett", constellation: 6, weaponID: nil, weaponRefinement: 1),
            ],
            unmappedIDs: [])
        let viewModel = await makeViewModel(hoyolab: StubHoyolabFetcher(roster: hoyolabRoster))

        // Something the player ticked themselves, which must survive.
        viewModel.toggleCharacter("diona")
        viewModel.uid = "618285856"
        viewModel.hoyolabLtuid = "618285856"
        viewModel.hoyolabLtoken = "some-token"
        XCTAssertTrue(viewModel.canImportFullRoster)

        viewModel.importFullRosterFromHoyolab()
        for _ in 0..<200 where viewModel.fullRosterImportStatus == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(viewModel.fullRosterImportStatus, .imported(count: 2))
        XCTAssertTrue(viewModel.owns(characterID: "hu-tao"))
        XCTAssertTrue(viewModel.owns(characterID: "bennett"))
        XCTAssertTrue(viewModel.owns(characterID: "diona"), "the hand-entered character was dropped")
        XCTAssertTrue(viewModel.owns(weaponID: "staff-of-homa"))
        XCTAssertEqual(viewModel.roster.constellation(for: "hu-tao"), 2)
        XCTAssertEqual(viewModel.roster.refinement(for: "staff-of-homa"), 3)

        // Not `.measured` — HoYoLAB's character list carries no artifact
        // detail, so this import must not claim these characters were scored
        // on real stats the way an Enka Showcase import is.
        XCTAssertFalse(viewModel.isMeasured("hu-tao"))
        XCTAssertFalse(viewModel.isMeasured("bennett"))
    }

    /// Credentials are only written to the store on an actual import, not on
    /// every keystroke while the player is still typing.
    func testCredentialsPersistOnlyOnImportAndReloadOnNextLaunch() async throws {
        let credentialStore = MemoryCredentialStore()
        let viewModel = await makeViewModel(hoyolabCredentials: credentialStore)

        viewModel.hoyolabLtuid = "618285856"
        viewModel.hoyolabLtoken = "some-token"
        XCTAssertNil(credentialStore.saved, "typing into the fields should not touch storage yet")

        viewModel.uid = "618285856"
        viewModel.importFullRosterFromHoyolab()
        for _ in 0..<200 where viewModel.fullRosterImportStatus == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(credentialStore.saved?.ltuid, "618285856")
        XCTAssertEqual(credentialStore.saved?.ltoken, "some-token")

        // A fresh view model — the next launch — should come back pre-filled
        // from the same store.
        let relaunched = await makeViewModel(hoyolabCredentials: credentialStore)
        XCTAssertEqual(relaunched.hoyolabLtuid, "618285856")
        XCTAssertEqual(relaunched.hoyolabLtoken, "some-token")
    }

    func testFullRosterImportIsRefusedWithoutBothCredentials() async throws {
        let viewModel = await makeViewModel()
        viewModel.uid = "618285856"
        XCTAssertFalse(viewModel.canImportFullRoster, "no credentials at all")

        viewModel.hoyolabLtuid = "618285856"
        XCTAssertFalse(viewModel.canImportFullRoster, "ltoken_v2 is still missing")

        viewModel.hoyolabLtoken = "some-token"
        XCTAssertTrue(viewModel.canImportFullRoster)

        viewModel.uid = "not-a-uid"
        XCTAssertFalse(viewModel.canImportFullRoster, "the UID itself still has to be plausible")
    }

    func testFullRosterImportSurfacesUnmappedIDsWithoutFailingTheWholeImport() async throws {
        let hoyolabRoster = AbyssHoyolabRoster(
            uid: "618285856", fetchedAt: Date(),
            characters: [AbyssHoyolabCharacter(characterID: "hu-tao", constellation: 0,
                                               weaponID: nil, weaponRefinement: 1)],
            unmappedIDs: ["character 99999999"])
        let viewModel = await makeViewModel(hoyolab: StubHoyolabFetcher(roster: hoyolabRoster))
        viewModel.uid = "618285856"
        viewModel.hoyolabLtuid = "618285856"
        viewModel.hoyolabLtoken = "some-token"

        viewModel.importFullRosterFromHoyolab()
        for _ in 0..<200 where viewModel.fullRosterImportStatus == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(viewModel.fullRosterImportStatus, .imported(count: 1))
        XCTAssertTrue(viewModel.owns(characterID: "hu-tao"))
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
