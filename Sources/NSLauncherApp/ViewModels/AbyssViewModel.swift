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

    @Published private(set) var library: AbyssDataLibrary?
    @Published private(set) var roster: AbyssRoster = .empty
    @Published private(set) var reports: [AbyssFloorReport] = []
    @Published private(set) var isSearching = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var unknownRosterIDs: [String] = []
    @Published var errorMessage: String?

    @Published var section: Section = .roster
    @Published var rosterTab: RosterTab = .characters
    @Published var searchText: String = ""
    @Published var elementFilter: GenshinElement?
    @Published var weaponTypeFilter: WeaponType?
    @Published var showsOwnedOnly = false
    /// Search across every character instead of the roster — "what could I
    /// build in theory".
    @Published var usesFullRoster = false

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
    @Published private(set) var showcase: AbyssShowcase?
    @Published private(set) var isImporting = false
    @Published private(set) var importStatus: ImportStatus?

    private let store: AbyssRosterStoring
    private let showcaseStore: AbyssShowcaseStoring
    private let enka: AbyssShowcaseFetching
    private var searchTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?

    init(store: AbyssRosterStoring = AbyssRosterStore(),
         showcaseStore: AbyssShowcaseStoring = AbyssShowcaseStore(),
         enka: AbyssShowcaseFetching = AbyssEnkaClient()) {
        self.store = store
        self.showcaseStore = showcaseStore
        self.enka = enka

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

    /// Characters whose stats came from the player's own account.
    var measuredCharacterIDs: Set<String> {
        Set((showcase?.builds ?? []).map(\.characterID))
    }

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

        for build in showcase.builds {
            if let index = roster.characters.firstIndex(where: { $0.id == build.characterID }) {
                roster.characters[index].constellation = build.constellation
            } else {
                roster.characters.append(.init(id: build.characterID, constellation: build.constellation))
            }
            guard let weaponID = build.weaponID else { continue }
            if let index = roster.weapons.firstIndex(where: { $0.id == weaponID }) {
                roster.weapons[index].refinement = build.weaponRefinement
            } else {
                roster.weapons.append(.init(id: weaponID, refinement: build.weaponRefinement))
            }
        }
        persist()
        importStatus = .imported(nickname: showcase.nickname, count: showcase.builds.count)
    }

    func clearShowcase() {
        showcase = nil
        importStatus = nil
        try? showcaseStore.clear()
    }

    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
    }

    // MARK: - Derived data

    var characters: [AbyssCharacter] {
        guard let library else { return [] }
        return filter(library.characters)
    }

    var weapons: [AbyssWeapon] {
        guard let library else { return [] }
        return library.weapons.filter { weapon in
            if showsOwnedOnly, !roster.weaponIDs.contains(weapon.id) { return false }
            if let weaponTypeFilter, weapon.type != weaponTypeFilter { return false }
            return matches(name: weapon.name, id: weapon.id)
        }
    }

    var weaponsByType: [(type: WeaponType, weapons: [AbyssWeapon])] {
        let matching = weapons
        return WeaponType.allCases.compactMap { type in
            let weapons = matching.filter { $0.type == type }
            return weapons.isEmpty ? nil : (type, weapons)
        }
    }

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
    var isCycleExpired: Bool {
        guard let cycle else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let end = formatter.date(from: cycle.periodEnd) else { return false }
        return Date() > end.addingTimeInterval(24 * 60 * 60)
    }

    var canSearch: Bool {
        guard library != nil, !isSearching else { return false }
        return usesFullRoster || roster.characters.count >= 4
    }

    private func filter(_ characters: [AbyssCharacter]) -> [AbyssCharacter] {
        characters.filter { character in
            if showsOwnedOnly, !roster.characterIDs.contains(character.id) { return false }
            if let elementFilter, character.element != elementFilter { return false }
            if let weaponTypeFilter, character.weaponType != weaponTypeFilter { return false }
            return matches(name: character.name, id: character.id)
        }
    }

    /// Matches the display name or the id.
    ///
    /// Ignoring accents matters in both directions: the Vietnamese UI has them
    /// and a keyboard often will not, and several names carry them in English
    /// too. The id is matched with separators stripped, so "hutao", "hu tao" and
    /// "hu-tao" all find the same character.
    private func matches(name: String, id: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        if name.range(of: query, options: options) != nil { return true }

        let separators = CharacterSet(charactersIn: " -_'")
        let flatQuery = query.components(separatedBy: separators).joined()
        guard !flatQuery.isEmpty else { return true }
        let flatID = id.components(separatedBy: separators).joined()
        let flatName = name.components(separatedBy: separators).joined()
        return flatID.range(of: flatQuery, options: options) != nil
            || flatName.range(of: flatQuery, options: options) != nil
    }

    // MARK: - Roster editing

    func owns(characterID: String) -> Bool { roster.characterIDs.contains(characterID) }
    func owns(weaponID: String) -> Bool { roster.weaponIDs.contains(weaponID) }

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

    /// Nobody fills in 371 toggles by hand; the 4★ weapons are the ones almost
    /// every account has several of.
    func addEveryFourStarWeapon() {
        guard let library else { return }
        let owned = roster.weaponIDs
        for weapon in library.weapons where weapon.rarity == 4 && !owned.contains(weapon.id) {
            roster.weapons.append(.init(id: weapon.id))
        }
        persist()
    }

    func clearRoster() {
        roster = .empty
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

        let request = AbyssOptimizerRequest(roster: usesFullRoster ? nil : roster, topN: 5,
                                            showcase: showcase?.builds ?? [])
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
