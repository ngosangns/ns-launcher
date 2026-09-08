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

    private let store: AbyssRosterStoring
    private var searchTask: Task<Void, Never>?

    init(store: AbyssRosterStoring = AbyssRosterStore()) {
        self.store = store

        do {
            roster = try store.load()
        } catch {
            // A corrupt roster is worth saying out loud: it is hand-entered
            // data, and silently starting from empty would look like the app
            // lost it.
            errorMessage = String(describing: error)
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            let library = AbyssDataLibrary()
            await MainActor.run {
                self?.library = library
            }
        }
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Derived data

    var characters: [AbyssCharacter] {
        guard let library else { return [] }
        return filter(library.characters)
    }

    var weaponsByType: [(type: WeaponType, weapons: [AbyssWeapon])] {
        guard let library else { return [] }
        let matching = library.weapons.filter { weapon in
            if showsOwnedOnly, !roster.weaponIDs.contains(weapon.id) { return false }
            if let weaponTypeFilter, weapon.type != weaponTypeFilter { return false }
            guard !searchText.isEmpty else { return true }
            return weapon.name.localizedCaseInsensitiveContains(searchText)
        }
        return WeaponType.allCases.compactMap { type in
            let weapons = matching.filter { $0.type == type }
            return weapons.isEmpty ? nil : (type, weapons)
        }
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
            guard !searchText.isEmpty else { return true }
            return character.name.localizedCaseInsensitiveContains(searchText)
        }
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

        let request = AbyssOptimizerRequest(roster: usesFullRoster ? nil : roster, topN: 5)
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
