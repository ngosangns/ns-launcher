// AbyssViewModel.swift
//
// UI state for the Abyss tab. `AbyssDataLibrary` parses ~950 KB of JSON with
// regexes, so it loads on a background task and `library` starts nil — the view
// shows a brief loading state rather than blocking app launch, the same way
// `StoryViewModel` handles the Story corpus.
//
// The search itself also runs off the main actor: even a fast run is hundreds of
// thousands of team evaluations, and the window has to stay responsive.

import Foundation

@MainActor
final class AbyssViewModel: ObservableObject {
    enum Section: Hashable {
        case roster
        case results
    }

    enum RosterTab: Hashable {
        case characters
        case weapons
    }

    /// How the roster grid is ordered.
    ///
    /// Only affects what is shown. The library's own order is load-bearing
    /// elsewhere — `AbyssOptimizer` breaks pool ties on it — so the sort is
    /// applied to a copy on its way to the view and never to `library`.
    enum RosterSort: String, Hashable, CaseIterable {
        case name
        /// Star rating: 5★ down to 1★ by default.
        case rarity
        /// Characters only.
        case element
        /// Characters only.
        case release
        /// Weapons only; base ATK at level 90.
        case attack
        case owned

        static func options(for tab: RosterTab) -> [RosterSort] {
            switch tab {
            case .characters: return [.name, .rarity, .element, .release, .owned]
            case .weapons: return [.name, .rarity, .attack, .owned]
            }
        }

        /// Which way round the sort starts.
        ///
        /// Every key has an obvious "interesting end" and it is not the same
        /// one: names want A first, stars want 5★ first, and a release date
        /// wants the newest. Picking a sort snaps back to its own default, so
        /// choosing "stars" never lands on 1★ weapons.
        var startsDescending: Bool {
            switch self {
            case .name, .element: return false
            case .rarity, .release, .attack, .owned: return true
            }
        }
    }

    @Published private(set) var library: AbyssDataLibrary? {
        didSet {
            rebuildSearchKeys()
            refreshVisibleRoster()
        }
    }
    @Published private(set) var roster: AbyssRoster = .empty {
        didSet { refreshRosterIndex() }
    }
    @Published private(set) var reports: [AbyssFloorReport] = []
    @Published private(set) var isSearching = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var unknownRosterIDs: [String] = []
    @Published var errorMessage: String?

    @Published var section: Section = .roster
    /// Switching tabs drops a sort the other tab has no meaning for — there is
    /// no "by element" order for weapons — rather than leaving a stale label on
    /// a control that is silently doing nothing.
    @Published var rosterTab: RosterTab = .characters {
        didSet {
            guard !RosterSort.options(for: rosterTab).contains(rosterSort) else { return }
            rosterSort = .name
        }
    }
    @Published var searchText: String = "" {
        didSet { refreshVisibleRoster() }
    }
    @Published var elementFilter: GenshinElement? {
        didSet { refreshVisibleRoster() }
    }
    @Published var weaponTypeFilter: WeaponType? {
        didSet { refreshVisibleRoster() }
    }
    /// By stars first: the grid's own file order groups characters by nation,
    /// which this screen never shows, and rarity is what most people scan a
    /// roster grid by.
    @Published var rosterSort: RosterSort = .rarity {
        didSet {
            guard rosterSort != oldValue else { return }
            // Assigning `sortDescending` reapplies the order on its own, so this
            // deliberately does not refresh a second time.
            sortDescending = rosterSort.startsDescending
        }
    }

    /// Direction of `rosterSort`. Reset to the sort's own natural end whenever
    /// the sort changes, and flippable from there.
    @Published var sortDescending = RosterSort.rarity.startsDescending {
        didSet { refreshVisibleRoster() }
    }
    @Published var showsOwnedOnly = false {
        didSet { refreshVisibleRoster() }
    }
    /// Search across every character instead of the owned roster — "what
    /// could I build in theory" — independent of `usesFullWeaponPool`, so
    /// either can widen without the other.
    @Published var usesFullCharacterPool = false
    /// Same, for weapons.
    @Published var usesFullWeaponPool = false

    // MARK: - Showcase import

    /// Outcome of the last import, structured rather than pre-worded so the
    /// view can render it in either language — the same reason `AbyssTeamNote`
    /// is an enum.
    enum ImportStatus: Equatable {
        case imported(nickname: String, count: Int)
        case tooSoon(seconds: Int)
        case failed(AbyssEnkaError)
        case failedOther(String)
    }

    @Published var uid: String = ""
    @Published private(set) var showcase: AbyssShowcase? {
        didSet { measuredCharacterIDs = Set((showcase?.builds ?? []).map(\.characterID)) }
    }
    @Published private(set) var isImporting = false
    @Published private(set) var importStatus: ImportStatus?

    // MARK: - Full roster import (HoYoLAB)

    /// Outcome of the last full-roster import, mirroring `ImportStatus` —
    /// structured for the same reason: the view renders it, not this type.
    enum FullRosterImportStatus: Equatable {
        case imported(count: Int)
        case failed(AbyssHoyolabError)
        case failedOther(String)
    }

    /// The player's own HoYoLAB login — pasted in by hand, kept in the
    /// Keychain (see `AbyssHoyolabCredentialStore`), never sent anywhere but
    /// HoYoLAB's own API. Loaded once at init; `saveHoyolabCredentials()`
    /// writes back only when the player actually uses them.
    @Published var hoyolabLtuid: String = ""
    @Published var hoyolabLtoken: String = ""
    @Published private(set) var isImportingFullRoster = false
    @Published private(set) var fullRosterImportStatus: FullRosterImportStatus?

    private let store: AbyssRosterStoring
    private let showcaseStore: AbyssShowcaseStoring
    private let enka: AbyssShowcaseFetching
    private let hoyolab: AbyssFullRosterFetching
    private let hoyolabCredentials: AbyssHoyolabCredentialStoring
    private var searchTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var fullRosterImportTask: Task<Void, Never>?

    init(store: AbyssRosterStoring = AbyssRosterStore(),
         showcaseStore: AbyssShowcaseStoring = AbyssShowcaseStore(),
         enka: AbyssShowcaseFetching = AbyssEnkaClient(),
         hoyolab: AbyssFullRosterFetching = AbyssHoyolabClient(),
         hoyolabCredentials: AbyssHoyolabCredentialStoring = AbyssHoyolabCredentialStore()) {
        self.store = store
        self.showcaseStore = showcaseStore
        self.enka = enka
        self.hoyolab = hoyolab
        self.hoyolabCredentials = hoyolabCredentials

        do {
            roster = try store.load()
        } catch {
            // A corrupt roster is worth saying out loud: it is hand-entered
            // data, and silently starting from empty would look like the app
            // lost it.
            errorMessage = String(describing: error)
        }

        showcase = try? showcaseStore.load()
        uid = showcase?.uid ?? ""

        if let credentials = hoyolabCredentials.load() {
            hoyolabLtuid = credentials.ltuid
            hoyolabLtoken = credentials.ltoken
        }

        // Property observers do not fire for the assignments above, which all
        // happen inside `init`, so the derived state is primed by hand once.
        measuredCharacterIDs = Set((showcase?.builds ?? []).map(\.characterID))
        refreshRosterIndex()

        Task.detached(priority: .userInitiated) { [weak self] in
            let library = AbyssDataLibrary()
            await MainActor.run {
                self?.library = library
            }
        }
    }

    deinit {
        searchTask?.cancel()
        importTask?.cancel()
    }

    var canImport: Bool { !isImporting && AbyssEnkaClient.isPlausibleUID(uid) && library != nil }

    func isMeasured(_ characterID: String) -> Bool {
        measuredCharacterIDs.contains(characterID)
    }

    /// Fetches the showcase and folds it into the roster.
    ///
    /// The import only ever *adds*: it marks the showcased characters and their
    /// weapons as owned and fills in the constellation and refinement it can
    /// see. Nothing the player ticked by hand is removed — the showcase is
    /// eight characters, not an inventory.
    func importFromUID() {
        guard let library, canImport else { return }
        let uid = uid.trimmingCharacters(in: .whitespacesAndNewlines)

        // Enka serves a cached snapshot until its ttl expires; asking again
        // before then returns the same bytes and still spends the rate limit.
        if let showcase, showcase.uid == uid, showcase.nextRefreshDate > Date() {
            let seconds = Int(showcase.nextRefreshDate.timeIntervalSinceNow.rounded(.up))
            importStatus = .tooSoon(seconds: max(seconds, 1))
            return
        }

        isImporting = true
        importStatus = nil
        let client = enka
        let map = library.gameIDs

        importTask = Task { [weak self] in
            let result: Result<AbyssShowcase, Error>
            do {
                result = .success(try await client.fetchShowcase(uid: uid, map: map))
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.isImporting = false
                switch result {
                case .success(let showcase):
                    self.apply(showcase)
                case .failure(let error):
                    self.importStatus = (error as? AbyssEnkaError).map(ImportStatus.failed)
                        ?? .failedOther(String(describing: error))
                }
            }
        }
    }

    private func apply(_ showcase: AbyssShowcase) {
        self.showcase = showcase
        try? showcaseStore.save(showcase)

        // Built up as a local copy and assigned once: every write to `roster`
        // reindexes ownership and refilters both grids, and an import touches it
        // once per imported character.
        var updated = roster
        for build in showcase.builds {
            if let index = updated.characters.firstIndex(where: { $0.id == build.characterID }) {
                updated.characters[index].constellation = build.constellation
            } else {
                updated.characters.append(.init(id: build.characterID, constellation: build.constellation))
            }
            guard let weaponID = build.weaponID else { continue }
            if let index = updated.weapons.firstIndex(where: { $0.id == weaponID }) {
                updated.weapons[index].refinement = build.weaponRefinement
            } else {
                updated.weapons.append(.init(id: weaponID, refinement: build.weaponRefinement))
            }
        }
        roster = updated
        persist()
        importStatus = .imported(nickname: showcase.nickname, count: showcase.builds.count)
    }

    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
    }

    var canImportFullRoster: Bool {
        !isImportingFullRoster && !hoyolabLtuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hoyolabLtoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && AbyssEnkaClient.isPlausibleUID(uid) && library != nil
    }

    /// Fetches the player's full character list from HoYoLAB and folds it
    /// into the roster — same "only ever adds" contract as the Enka import,
    /// and the same UID field, since it names the same account either way.
    ///
    /// Unlike Enka, these characters are not scored on measured stats: HoYoLAB's
    /// character list has no artifact detail, only identity, constellation, and
    /// the equipped weapon's refinement. They still get the standardised build,
    /// same as anyone else marked owned by hand.
    func importFullRosterFromHoyolab() {
        guard let library, canImportFullRoster else { return }
        let uid = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let ltuid = hoyolabLtuid.trimmingCharacters(in: .whitespacesAndNewlines)
        let ltoken = hoyolabLtoken.trimmingCharacters(in: .whitespacesAndNewlines)

        // Saved only now, not on every keystroke: the player may still be
        // editing, and a half-typed token is not worth persisting.
        try? hoyolabCredentials.save(ltuid: ltuid, ltoken: ltoken)

        isImportingFullRoster = true
        fullRosterImportStatus = nil
        let client = hoyolab
        let map = library.gameIDs

        fullRosterImportTask = Task { [weak self] in
            let result: Result<AbyssHoyolabRoster, Error>
            do {
                result = .success(try await client.fetchFullRoster(uid: uid, ltuid: ltuid, ltoken: ltoken, map: map))
            } catch {
                result = .failure(error)
            }

            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.isImportingFullRoster = false
                switch result {
                case .success(let hoyolabRoster):
                    self.apply(hoyolabRoster)
                case .failure(let error):
                    self.fullRosterImportStatus = (error as? AbyssHoyolabError).map(FullRosterImportStatus.failed)
                        ?? .failedOther(String(describing: error))
                }
            }
        }
    }

    private func apply(_ hoyolabRoster: AbyssHoyolabRoster) {
        // One assignment for the whole import — see `apply(_ showcase:)`.
        var updated = roster
        for character in hoyolabRoster.characters {
            if let index = updated.characters.firstIndex(where: { $0.id == character.characterID }) {
                updated.characters[index].constellation = character.constellation
            } else {
                updated.characters.append(.init(id: character.characterID, constellation: character.constellation))
            }
            guard let weaponID = character.weaponID else { continue }
            if let index = updated.weapons.firstIndex(where: { $0.id == weaponID }) {
                updated.weapons[index].refinement = character.weaponRefinement
            } else {
                updated.weapons.append(.init(id: weaponID, refinement: character.weaponRefinement))
            }
        }
        roster = updated
        persist()
        fullRosterImportStatus = .imported(count: hoyolabRoster.characters.count)
    }

    func cancelFullRosterImport() {
        fullRosterImportTask?.cancel()
        fullRosterImportTask = nil
        isImportingFullRoster = false
    }

    // MARK: - Derived data

    /// The grid contents, stored rather than recomputed on read.
    ///
    /// The view asks for these once per tile and again for the counter, and a
    /// single pass filters 246 entries and then sorts them through ICU
    /// collation — so computing them on read cost several passes over the whole
    /// library per body evaluation, on every keystroke and every hover. They are
    /// refreshed only when something they depend on actually changes.
    @Published private(set) var characters: [AbyssCharacter] = []
    @Published private(set) var weapons: [AbyssWeapon] = []

    /// Ownership, as a set rather than `AbyssRoster`'s arrays: the grid asks
    /// "do I own this" once per visible tile, which was a fresh `Set` built from
    /// the whole roster each time.
    @Published private(set) var ownedCharacterIDs: Set<String> = []
    @Published private(set) var ownedWeaponIDs: Set<String> = []
    /// Characters whose stats came from the player's own account.
    @Published private(set) var measuredCharacterIDs: Set<String> = []
    private var constellationByID: [String: Int] = [:]
    private var refinementByID: [String: Int] = [:]

    /// How many rows the filters are hiding, for the "12 of 125" counter.
    var visibleCount: Int { rosterTab == .characters ? characters.count : weapons.count }
    var totalCount: Int {
        guard let library else { return 0 }
        return rosterTab == .characters ? library.characters.count : library.weapons.count
    }

    var hasActiveFilter: Bool {
        !searchText.isEmpty || elementFilter != nil || weaponTypeFilter != nil || showsOwnedOnly
    }

    func clearFilters() {
        searchText = ""
        elementFilter = nil
        weaponTypeFilter = nil
        showsOwnedOnly = false
    }

    var cycle: AbyssCycle? { library?.latestCycle }

    /// True once the bundled rotation's window has passed. The data is only
    /// valid for two weeks, so a released build will reach this state.
    /// Parsing `periodEnd` needs a fixed format, and building a `DateFormatter`
    /// is expensive enough to matter for something the banner reads on every
    /// body evaluation.
    private static let cycleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    var isCycleExpired: Bool {
        guard let cycle else { return false }
        guard let end = Self.cycleDateFormatter.date(from: cycle.periodEnd) else { return false }
        return Date() > end.addingTimeInterval(24 * 60 * 60)
    }

    var canSearch: Bool {
        guard library != nil, !isSearching else { return false }
        return usesFullCharacterPool || roster.characters.count >= 4
    }

    /// Applies `rosterSort` in `sortDescending`'s direction, then falls through
    /// to the name and the id.
    ///
    /// The fall-through is what makes each ordering *total*. Swift's sort is
    /// unstable, so a comparator that stopped at "same rarity" would leave the
    /// order inside each star block up to the algorithm's internals, and the
    /// grid would look like it rearranges itself. The fall-through always runs
    /// ascending, whichever way the primary key points — a reversed sort should
    /// flip the blocks, not scramble the names inside them.
    private func ordered<T>(_ items: [T],
                            name: (T) -> String,
                            id: (T) -> String,
                            key: (T, T) -> ComparisonResult) -> [T] {
        items.sorted { lhs, rhs in
            let primary = key(lhs, rhs)
            if primary != .orderedSame {
                return sortDescending ? primary == .orderedDescending : primary == .orderedAscending
            }
            let byName = name(lhs).localizedCaseInsensitiveCompare(name(rhs))
            if byName != .orderedSame { return byName == .orderedAscending }
            return id(lhs) < id(rhs)
        }
    }

    /// Ascending order for a key, before the direction is applied.
    private static func compare<V: Comparable>(_ lhs: V, _ rhs: V) -> ComparisonResult {
        lhs == rhs ? .orderedSame : (lhs < rhs ? .orderedAscending : .orderedDescending)
    }

    private func sorted(_ characters: [AbyssCharacter]) -> [AbyssCharacter] {
        ordered(characters, name: \.name, id: \.id) { lhs, rhs in
            switch rosterSort {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            case .rarity:
                return Self.compare(lhs.rarity, rhs.rarity)
            case .element:
                return Self.compare(lhs.element.rawValue, rhs.element.rawValue)
            case .release:
                // A missing date sorts as the oldest rather than the newest: an
                // untranscribed entry is not a new release.
                return Self.compare(lhs.releaseDate ?? "", rhs.releaseDate ?? "")
            case .attack:
                return .orderedSame
            case .owned:
                // Bool is not Comparable in Swift; 0/1 keeps one comparison path.
                return Self.compare(ownedCharacterIDs.contains(lhs.id) ? 1 : 0,
                                    ownedCharacterIDs.contains(rhs.id) ? 1 : 0)
            }
        }
    }

    private func sorted(_ weapons: [AbyssWeapon]) -> [AbyssWeapon] {
        ordered(weapons, name: \.name, id: \.id) { lhs, rhs in
            switch rosterSort {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            case .rarity:
                return Self.compare(lhs.rarity, rhs.rarity)
            case .attack:
                return Self.compare(lhs.atkLv90 ?? 0, rhs.atkLv90 ?? 0)
            case .owned:
                return Self.compare(ownedWeaponIDs.contains(lhs.id) ? 1 : 0,
                                    ownedWeaponIDs.contains(rhs.id) ? 1 : 0)
            case .element, .release:
                return .orderedSame
            }
        }
    }

    // MARK: - Cached derivation

    private static let searchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    /// Separators stripped before matching, so "hutao", "hu tao" and "hu-tao"
    /// all find the same entry. A `static let` because building a `CharacterSet`
    /// is not free and this one never varies.
    private static let searchSeparators = CharacterSet(charactersIn: " -_'")

    /// One entry's precomputed haystacks, built once per library load.
    ///
    /// Stripping the separators is the expensive half of `matches` — several
    /// `components(separatedBy:).joined()` allocations per candidate — and the
    /// result only ever changes when the library does, not when the query does.
    private struct SearchKey {
        let name: String
        /// nil when the Vietnamese name is the same string as the English one.
        /// That is most characters — the game does not translate proper names —
        /// so the common case does not pay for a second pass over the same text.
        let nameVI: String?
        let flatID: String
        let flatName: String
        let flatNameVI: String?
    }

    /// The query, prepared once per pass instead of once per candidate.
    private struct SearchQuery {
        let text: String
        let flat: String
    }

    private var characterSearchKeys: [String: SearchKey] = [:]
    private var weaponSearchKeys: [String: SearchKey] = [:]

    private static func searchKey(name: String, nameVI: String, id: String) -> SearchKey {
        let translated = nameVI == name ? nil : nameVI
        return SearchKey(name: name,
                         nameVI: translated,
                         flatID: id.components(separatedBy: searchSeparators).joined(),
                         flatName: name.components(separatedBy: searchSeparators).joined(),
                         flatNameVI: translated?.components(separatedBy: searchSeparators).joined())
    }

    private func rebuildSearchKeys() {
        guard let library else {
            characterSearchKeys = [:]
            weaponSearchKeys = [:]
            return
        }
        characterSearchKeys = Dictionary(uniqueKeysWithValues: library.characters.map {
            ($0.id, Self.searchKey(name: $0.name, nameVI: $0.nameVI, id: $0.id))
        })
        weaponSearchKeys = Dictionary(uniqueKeysWithValues: library.weapons.map {
            ($0.id, Self.searchKey(name: $0.name, nameVI: $0.nameVI, id: $0.id))
        })
    }

    /// Ownership and levels, rebuilt whenever the roster changes rather than
    /// asked of `AbyssRoster`'s arrays once per tile.
    private func refreshRosterIndex() {
        ownedCharacterIDs = Set(roster.characters.map(\.id))
        ownedWeaponIDs = Set(roster.weapons.map(\.id))
        constellationByID = Dictionary(roster.characters.map { ($0.id, $0.constellation) },
                                       uniquingKeysWith: { _, last in last })
        refinementByID = Dictionary(roster.weapons.map { ($0.id, $0.refinement) },
                                    uniquingKeysWith: { _, last in last })
        refreshVisibleRoster()
    }

    /// Reapplies the filters and the sort to both grids.
    ///
    /// Both tabs are refreshed together even though only one is on screen:
    /// switching tabs is then free, and the work is the same either way since
    /// the filters that differ between them are already cheap.
    private func refreshVisibleRoster() {
        guard let library else {
            characters = []
            weapons = []
            return
        }
        let query = preparedQuery()
        characters = sorted(library.characters.filter { character in
            if showsOwnedOnly, !ownedCharacterIDs.contains(character.id) { return false }
            if let elementFilter, character.element != elementFilter { return false }
            if let weaponTypeFilter, character.weaponType != weaponTypeFilter { return false }
            return matches(characterSearchKeys[character.id], query: query)
        })
        weapons = sorted(library.weapons.filter { weapon in
            if showsOwnedOnly, !ownedWeaponIDs.contains(weapon.id) { return false }
            if let weaponTypeFilter, weapon.type != weaponTypeFilter { return false }
            return matches(weaponSearchKeys[weapon.id], query: query)
        })
    }

    private func preparedQuery() -> SearchQuery? {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return SearchQuery(text: text,
                           flat: text.components(separatedBy: Self.searchSeparators).joined())
    }

    /// Matches either display name, or the id.
    ///
    /// Both names, because the grid shows the Vietnamese one in the Vietnamese
    /// UI: matching only the English name meant typing the name that was on
    /// screen returned nothing. Ignoring accents matters in both directions —
    /// the Vietnamese names carry them and a keyboard often will not, and
    /// several English names carry them too.
    private func matches(_ key: SearchKey?, query: SearchQuery?) -> Bool {
        guard let query else { return true }
        guard let key else { return false }
        if key.name.range(of: query.text, options: Self.searchOptions) != nil { return true }
        if let nameVI = key.nameVI, nameVI.range(of: query.text, options: Self.searchOptions) != nil {
            return true
        }
        guard !query.flat.isEmpty else { return true }
        if key.flatID.range(of: query.flat, options: Self.searchOptions) != nil { return true }
        if key.flatName.range(of: query.flat, options: Self.searchOptions) != nil { return true }
        guard let flatNameVI = key.flatNameVI else { return false }
        return flatNameVI.range(of: query.flat, options: Self.searchOptions) != nil
    }

    // MARK: - Roster editing

    func owns(characterID: String) -> Bool { ownedCharacterIDs.contains(characterID) }
    func owns(weaponID: String) -> Bool { ownedWeaponIDs.contains(weaponID) }

    /// Level lookups for the grid's steppers, backed by the same index as
    /// `owns` — `AbyssRoster` stores arrays, so asking it directly is a linear
    /// scan per tile.
    func constellation(for characterID: String) -> Int { constellationByID[characterID] ?? 0 }
    func refinement(for weaponID: String) -> Int { refinementByID[weaponID] ?? 1 }

    func toggleCharacter(_ id: String) {
        if let index = roster.characters.firstIndex(where: { $0.id == id }) {
            roster.characters.remove(at: index)
        } else {
            roster.characters.append(.init(id: id))
        }
        persist()
    }

    func toggleWeapon(_ id: String) {
        if let index = roster.weapons.firstIndex(where: { $0.id == id }) {
            roster.weapons.remove(at: index)
        } else {
            roster.weapons.append(.init(id: id))
        }
        persist()
    }

    func setConstellation(_ constellation: Int, for characterID: String) {
        guard let index = roster.characters.firstIndex(where: { $0.id == characterID }) else { return }
        roster.characters[index].constellation = min(max(constellation, 0), 6)
        persist()
    }

    func setRefinement(_ refinement: Int, for weaponID: String) {
        guard let index = roster.weapons.firstIndex(where: { $0.id == weaponID }) else { return }
        roster.weapons[index].refinement = min(max(refinement, 1), 5)
        persist()
    }

    func clearCharacters() {
        roster.characters = []
        persist()
    }

    func clearWeapons() {
        roster.weapons = []
        persist()
    }

    func importRoster(from url: URL) {
        do {
            roster = try store.importRoster(from: url)
            try store.save(roster)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func exportRoster(to url: URL) {
        do {
            try store.exportRoster(roster, to: url)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persist() {
        do {
            try store.save(roster)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: - Searching

    func search() {
        guard let library, !isSearching else { return }
        guard let optimizer = AbyssOptimizer(library: library) else { return }

        let request = AbyssOptimizerRequest(roster: roster,
                                            usesFullCharacterPool: usesFullCharacterPool,
                                            usesFullWeaponPool: usesFullWeaponPool,
                                            topN: 5, showcase: showcase?.builds ?? [])
        isSearching = true
        progress = 0
        reports = []

        searchTask = Task { [weak self] in
            let output = await Task.detached(priority: .userInitiated) {
                await optimizer.run(request)
            }.value

            await MainActor.run {
                guard let self, !Task.isCancelled else { return }
                self.reports = output.reports
                self.unknownRosterIDs = output.unknownRosterIDs
                self.isSearching = false
                self.progress = 1
                if !output.reports.isEmpty {
                    self.section = .results
                }
            }
        }
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
    }

    // MARK: - Result helpers

    func character(_ id: String) -> AbyssCharacter? { library?.charactersByID[id] }
    func weapon(_ id: String) -> AbyssWeapon? { library?.weaponsByID[id] }
    func artifactSet(_ id: String) -> AbyssArtifactSet? { library?.artifactSetsByID[id] }
    func characterIconURL(_ id: String) -> URL? { library?.icons.characterIconURL(id) }
    func weaponIconURL(_ id: String) -> URL? { library?.icons.weaponIconURL(id) }

    /// Damage share within a team, used for the per-character bar. Computed
    /// against the sum of the members rather than the team score, because the
    /// score also carries the team-level multipliers.
    func damageShare(of characterID: String, in team: AbyssTeamResult) -> Double {
        let total = team.perCharacterDamage.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return (team.perCharacterDamage[characterID] ?? 0) / total
    }

    /// The role to *show*. The engine builds every non-sustain character as a
    /// main DPS; only one of them is actually on field, so the others are
    /// presented as sub-DPS.
    func displayRole(of characterID: String, in team: AbyssTeamResult) -> AbyssRole {
        let role = team.assignment[characterID]?.role ?? .subDPS
        if role == .mainDPS && characterID != team.onFieldID { return .subDPS }
        return role
    }
}
