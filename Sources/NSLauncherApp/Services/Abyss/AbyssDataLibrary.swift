// AbyssDataLibrary.swift
//
// Loads `Resources/Abyss/` once and derives everything the scorer needs up
// front. Follows `StoryLibrary`: bundled static content, synchronous load,
// build one and hold onto it.
//
// Everything here is `let`. The Python kept four module-level mutable caches
// (`_PROFILE_CACHE`, `_BASIS_CACHE`, `PARSE`, and a `MOONSIGN_IDS` the CLI
// assigned into at runtime); under Swift 6 those would each need an escape
// hatch, and they are also what would stop the scorer from running in
// parallel. Computing them once in `init` removes both problems at once.
//
// A missing or malformed file degrades to empty rather than throwing, matching
// `StoryLibrary`. That choice only holds up because the tests load the real
// bundled data and pin its counts, so a broken file fails the build instead of
// quietly emptying the tab.

import Foundation

struct AbyssDataLibrary: Sendable {
    let characters: [AbyssCharacter]
    let charactersByID: [String: AbyssCharacter]
    let weapons: [AbyssWeapon]
    let weaponsByID: [String: AbyssWeapon]
    let artifactSets: [AbyssArtifactSet]
    let artifactSetsByID: [String: AbyssArtifactSet]

    /// Sets that exist at 5★, in **file order**.
    ///
    /// The order is load-bearing: gear selection ranks weapons against
    /// `first` as a fixed baseline, so re-sorting `artifact-sets.json` would
    /// silently change every recommendation in the app. A test pins it.
    let fiveStarArtifactSets: [AbyssArtifactSet]

    let teamBonus: AbyssTeamBonus?
    let damageFormula: AbyssDamageFormula?
    let tuning: AbyssTuning?
    /// Newest first.
    let cycles: [AbyssCycle]

    /// Damage profiles at base talent levels. Constellation-aware callers go
    /// through `profile(for:constellation:)` instead.
    let profilesByCharacterID: [String: AbyssDamageProfile]
    /// Every talent-level combination a constellation can reach, per character.
    /// At most four entries each, all built at load: the scorer must never parse
    /// a talent table while it is running.
    private let profileVariants: [String: [AbyssTalentLevels: AbyssDamageProfile]]
    /// Which talent each constellation level raises by three.
    let talentBoostsByCharacterID: [String: [Int: AbyssTalentSlot]]
    /// Numbers read out of `damage-formula.json`, or the port's own values when
    /// the file could not be read — see `diagnostics.damageFormulaUnread`.
    let damageConstants: AbyssDamageConstants
    /// Whether each character can heal or shield the party. Derived by regex
    /// over their talent text, and needed for every team the scorer looks at —
    /// which is hundreds of thousands of times per run, so it is resolved once
    /// here instead.
    let sustainByCharacterID: [String: AbyssSustain]
    /// Party-wide buffs each character's talents grant, resolved from
    /// `tuning.json`'s `talentPartyBuff` against the character data.
    let talentPartyBuffsByCharacterID: [String: [AbyssTalentPartyBuff]]
    let moonsignIDs: Set<String>
    let hexereiIDs: Set<String>
    let stellarJubileeIDs: Set<String>
    /// Numeric game ids -> slugs, for reading a player's showcase.
    let gameIDs: AbyssGameIDMap
    /// Bundled character/weapon portrait files.
    let icons: AbyssIconLibrary
    let diagnostics: AbyssParseDiagnostics

    var latestCycle: AbyssCycle? { cycles.first }
    var isEmpty: Bool { characters.isEmpty || weapons.isEmpty || tuning == nil }

    // MARK: - Loading

    init(root: URL? = Self.resourceRootURL(),
         cycleOverrideDirectory: URL? = Self.defaultCycleOverrideDirectory) {
        let characters = Self.decodeArray([AbyssCharacter].self, in: root?.appendingPathComponent("characters"))
        let weapons = Self.decodeArray([AbyssWeapon].self, in: root?.appendingPathComponent("weapons"))
        let artifactSets: [AbyssArtifactSet] = Self.decode(from: root?.appendingPathComponent("artifact-sets.json")) ?? []

        self.characters = characters
        charactersByID = Dictionary(characters.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.weapons = weapons
        weaponsByID = Dictionary(weapons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.artifactSets = artifactSets
        artifactSetsByID = Dictionary(artifactSets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        fiveStarArtifactSets = artifactSets.filter(\.existsAtFiveStar)

        let teamBonus: AbyssTeamBonus? = Self.decode(from: root?.appendingPathComponent("team-bonus.json"))
        self.teamBonus = teamBonus
        damageFormula = Self.decode(from: root?.appendingPathComponent("damage-formula.json"))
        let tuning: AbyssTuning? = Self.decode(from: root?.appendingPathComponent("tuning.json"))
        self.tuning = tuning

        cycles = Self.loadCycles(bundled: root?.appendingPathComponent("abyss-monsters"),
                                 overrides: cycleOverrideDirectory)

        gameIDs = Self.decode(from: root?.appendingPathComponent("game-ids.json")) ?? .empty
        icons = AbyssIconLibrary(root: root)
        moonsignIDs = Set(teamBonus?.moonsign.characterIds ?? [])
        hexereiIDs = Set(teamBonus?.hexerei.characterIds ?? [])
        stellarJubileeIDs = Set(tuning?.stellarJubileeCharacterIds ?? [])

        var diagnostics = AbyssParseDiagnostics()
        damageConstants = AbyssDamageConstants(formula: damageFormula, diagnostics: &diagnostics)

        var profiles: [String: AbyssDamageProfile] = [:]
        var variants: [String: [AbyssTalentLevels: AbyssDamageProfile]] = [:]
        var boosts: [String: [Int: AbyssTalentSlot]] = [:]
        var sustain: [String: AbyssSustain] = [:]
        profiles.reserveCapacity(characters.count)
        variants.reserveCapacity(characters.count)
        sustain.reserveCapacity(characters.count)
        for character in characters {
            let base = Self.buildProfile(for: character, levels: .base, diagnostics: &diagnostics)
            profiles[character.id] = base
            sustain[character.id] = AbyssTeamContext.capabilities(of: character)

            var boosted: [Int: AbyssTalentSlot] = [:]
            for constellation in character.constellations {
                if let slot = AbyssTextParser.boostedTalent(byConstellation: constellation.description,
                                                            of: character) {
                    boosted[constellation.level] = slot
                }
            }
            boosts[character.id] = boosted

            // The reachable combinations only, so a character whose data has no
            // lv13 column costs nothing beyond the base profile they already had.
            var table: [AbyssTalentLevels: AbyssDamageProfile] = [.base: base]
            for slots in [[AbyssTalentSlot.skill], [.burst], [.skill, .burst]] {
                var levels = AbyssTalentLevels.base
                for slot in slots { levels.raise(slot) }
                guard table[levels] == nil else { continue }
                var throwaway = AbyssParseDiagnostics()
                table[levels] = Self.buildProfile(for: character, levels: levels,
                                                  diagnostics: &throwaway)
            }
            variants[character.id] = table
        }
        profilesByCharacterID = profiles
        profileVariants = variants
        talentBoostsByCharacterID = boosts
        sustainByCharacterID = sustain

        // The party-buff table names a character and one of their scaling rows
        // by label. Resolving it here rather than at scoring time means the
        // label matching happens once, and a row that has been renamed shows up
        // in `diagnostics` — and fails a test — instead of quietly contributing
        // nothing.
        var talentBuffs: [String: [AbyssTalentPartyBuff]] = [:]
        for entry in tuning?.talentPartyBuff ?? [] {
            guard let character = charactersByID[entry.characterId] else {
                diagnostics.talentPartyBuffUnresolved.insert("\(entry.characterId): no such character")
                continue
            }
            let talent = entry.talent == .skill ? character.elementalSkill : character.elementalBurst
            guard let value = AbyssTextParser.talentPercentage(in: talent, label: entry.label,
                                                               index: entry.valueIndex ?? 0) else {
                diagnostics.talentPartyBuffUnresolved.insert("\(entry.characterId): \(entry.label)")
                continue
            }
            let kind: AbyssTalentPartyBuff.Kind = entry.kind == .flatATKFromBaseATK
                ? .flatATKFromBaseATK
                : .elementalDMG
            talentBuffs[entry.characterId, default: []].append(
                AbyssTalentPartyBuff(kind: kind, value: value * entry.uptime))
        }
        talentPartyBuffsByCharacterID = talentBuffs

        self.diagnostics = diagnostics
    }

    /// The talent levels a character reads at, given how many constellations
    /// they have unlocked.
    ///
    /// C3 and C5 each raise one talent by three; which one is written in the
    /// constellation text and resolved at load. A character whose data carries
    /// no `lv13` column falls back to `lv10` inside the parser, so this is safe
    /// to ask for whatever the data holds.
    func talentLevels(for characterID: String, constellation: Int) -> AbyssTalentLevels {
        guard constellation > 0, let boosts = talentBoostsByCharacterID[characterID] else {
            return .base
        }
        var levels = AbyssTalentLevels.base
        for (level, slot) in boosts where level <= constellation {
            levels.raise(slot)
        }
        return levels
    }

    func profile(for characterID: String, constellation: Int) -> AbyssDamageProfile? {
        guard let table = profileVariants[characterID] else { return nil }
        return table[talentLevels(for: characterID, constellation: constellation)] ?? table[.base]
    }

    private static func buildProfile(for character: AbyssCharacter,
                                     levels: AbyssTalentLevels,
                                     diagnostics: inout AbyssParseDiagnostics) -> AbyssDamageProfile {
        var hits: [AbyssDamageProfile.Term] = []
        for (multiplier, basis) in AbyssTextParser.talentDamageEntries(
            character.elementalSkill, levelKey: levels.skill, diagnostics: &diagnostics) {
            hits.append(.init(multiplier: multiplier, basis: basis, category: .skill))
        }
        for (multiplier, basis) in AbyssTextParser.talentDamageEntries(
            character.elementalBurst, levelKey: levels.burst, diagnostics: &diagnostics) {
            hits.append(.init(multiplier: multiplier, basis: basis, category: .burst))
        }
        for (multiplier, basis) in AbyssTextParser.normalAttackCombo(character) {
            hits.append(.init(multiplier: multiplier, basis: basis, category: .normal))
        }
        if let (multiplier, basis) = AbyssTextParser.chargedAttack(character) {
            hits.append(.init(multiplier: multiplier, basis: basis, category: .charged))
        }

        // Collapse to one term per (basis, category). Every hit in a pair shares
        // the same stat and the same bonus, so factoring the multipliers out is
        // exact — it just turns 10-20 multiplies per character per team into 3-5.
        // First-appearance order is kept so the sum is reproducible run to run.
        struct Slot: Hashable { let basis: ScalingBasis; let category: HitCategory }
        var totals: [Slot: Double] = [:]
        var order: [Slot] = []
        for hit in hits {
            let key = Slot(basis: hit.basis, category: hit.category)
            if totals[key] == nil { order.append(key) }
            totals[key, default: 0] += hit.multiplier
        }
        let aggregate = order.map {
            AbyssDamageProfile.Term(multiplier: totals[$0] ?? 0, basis: $0.basis, category: $0.category)
        }

        return AbyssDamageProfile(
            hits: hits,
            aggregate: aggregate,
            basis: AbyssTextParser.scalingBasis(for: character, diagnostics: &diagnostics))
    }

    /// Bundled cycles, with any user-supplied file of the same `periodStart`
    /// replacing the bundled one.
    ///
    /// The bundled cycle expires roughly two weeks after it is authored, so a
    /// released build would otherwise recommend teams for a rotation that is no
    /// longer live. Dropping a fresh file into Application Support fixes that
    /// without waiting for a new release.
    private static func loadCycles(bundled: URL?, overrides: URL?) -> [AbyssCycle] {
        var byPeriod: [String: AbyssCycle] = [:]
        for cycle in decodeArray([AbyssCycle].self, in: bundled, isArrayPerFile: false) {
            byPeriod[cycle.periodStart] = cycle
        }
        for cycle in decodeArray([AbyssCycle].self, in: overrides, isArrayPerFile: false) {
            byPeriod[cycle.periodStart] = cycle
        }
        return byPeriod.values.sorted { $0.periodStart > $1.periodStart }
    }

    // MARK: - File plumbing

    private static func decode<T: Decodable>(from url: URL?) -> T? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Decodes every `.json` in a directory. `isArrayPerFile` distinguishes the
    /// two shapes in this data set: `characters/`/`weapons/` hold arrays that
    /// get concatenated, `abyss-monsters/` holds one object per file.
    private static func decodeArray<Element: Decodable>(_ type: [Element].Type,
                                                        in directory: URL?,
                                                        isArrayPerFile: Bool = true) -> [Element] {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }

        return files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .flatMap { url -> [Element] in
                guard let data = try? Data(contentsOf: url) else { return [] }
                if isArrayPerFile {
                    return (try? JSONDecoder().decode([Element].self, from: data)) ?? []
                }
                return (try? JSONDecoder().decode(Element.self, from: data)).map { [$0] } ?? []
            }
    }

    /// `.copy("Resources/Abyss")` puts the folder in the resource bundle, but
    /// the exact layout has shifted between SwiftPM versions — same reason
    /// `StoryLibrary.storyRootURL()` tries more than one path.
    static func resourceRootURL() -> URL? {
        let candidates = ["Abyss", "Resources/Abyss"]
        for name in candidates {
            if let url = Bundle.module.url(forResource: name, withExtension: nil) { return url }
        }
        guard let resourceURL = Bundle.module.resourceURL else { return nil }
        for name in candidates {
            let candidate = resourceURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// Where a user can drop a newer Abyss rotation. Alongside `settings.json`
    /// rather than inside it, so updating it is a file copy.
    static let defaultCycleOverrideDirectory: URL? = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NSLauncher/abyss-cycles", isDirectory: true)
}
