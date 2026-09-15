// AbyssDataLibrary.swift
//
// Loads `Resources/Abyss/` once and derives everything the scorer needs up
// front. Follows `StoryLibrary`: bundled static content, synchronous load,
// build one and hold onto it.
//
// Everything here is `let`. The original implementation kept four module-level mutable caches
// (`_PROFILE_CACHE`, `_BASIS_CACHE`, `PARSE`, and a `MOONSIGN_IDS` the CLI
// assigned into at runtime); under Swift 6 those would each need an escape
// hatch, and they are also what would stop the scorer from running in
// parallel. Computing them once in `init` removes both problems at once.
//
// A missing or malformed file degrades to empty rather than throwing, matching
// `StoryLibrary`. That choice only holds up because the tests load the real
// bundled data and pin its counts, so a broken file fails the build instead of
// quietly emptying the tab.

import CryptoKit
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
    /// `character-traits.json`'s `partyBuffs` against the character data.
    let talentPartyBuffsByCharacterID: [String: [AbyssTalentPartyBuff]]
    /// Everything `character-traits.json` says about each character, by id.
    let traitsByCharacterID: [String: AbyssCharacterTraits]
    /// How much each character adds to the base damage of the Lunar/Stellar
    /// reactions they name, by character id then reaction.
    let reactionBaseDamageBonusByCharacterID: [String: [AbyssReaction: Double]]
    let moonsignIDs: Set<String>
    let hexereiIDs: Set<String>
    let stellarJubileeIDs: Set<String>
    /// Numeric game ids -> slugs, for reading a player's showcase.
    let gameIDs: AbyssGameIDMap
    /// Bundled character/weapon portrait files.
    let icons: AbyssIconLibrary
    let diagnostics: AbyssParseDiagnostics
    /// SHA-256 over the bytes of every data file this library was built from,
    /// bundled and override cycles included.
    ///
    /// Exists for one caller: `AbyssSearchCacheKey`. A cached search is only
    /// still the right answer while the data it ran over is the data on disk,
    /// and the rotation's `periodStart` alone cannot say so — the change that
    /// first showed this was one that left `periodStart` exactly as it was and
    /// rewrote every floor-12 monster's resistance underneath it. Hashing the
    /// bytes as they are read costs nothing measurable next to parsing them.
    let dataDigest: String

    var latestCycle: AbyssCycle? { cycles.first }
    var isEmpty: Bool { characters.isEmpty || weapons.isEmpty || tuning == nil }

    // MARK: - Loading

    init(root: URL? = Self.resourceRootURL(),
         cycleOverrideDirectory: URL? = Self.defaultCycleOverrideDirectory) {
        var hasher = SHA256()
        let characters = Self.decodeArray([AbyssCharacter].self, in: root?.appendingPathComponent("characters"),
                                          hasher: &hasher)
        let weapons = Self.decodeArray([AbyssWeapon].self, in: root?.appendingPathComponent("weapons"),
                                       hasher: &hasher)
        let artifactSets: [AbyssArtifactSet] = Self.decode(from: root?.appendingPathComponent("artifact-sets.json"),
                                                           hasher: &hasher) ?? []

        self.characters = characters
        charactersByID = Dictionary(characters.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.weapons = weapons
        weaponsByID = Dictionary(weapons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.artifactSets = artifactSets
        artifactSetsByID = Dictionary(artifactSets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        fiveStarArtifactSets = artifactSets.filter(\.existsAtFiveStar)

        let teamBonus: AbyssTeamBonus? = Self.decode(from: root?.appendingPathComponent("team-bonus.json"),
                                                     hasher: &hasher)
        self.teamBonus = teamBonus
        damageFormula = Self.decode(from: root?.appendingPathComponent("damage-formula.json"), hasher: &hasher)
        let tuning: AbyssTuning? = Self.decode(from: root?.appendingPathComponent("tuning.json"), hasher: &hasher)
        self.tuning = tuning

        cycles = Self.loadCycles(bundled: root?.appendingPathComponent("abyss-monsters"),
                                 overrides: cycleOverrideDirectory, hasher: &hasher)

        gameIDs = Self.decode(from: root?.appendingPathComponent("game-ids.json"), hasher: &hasher) ?? .empty
        icons = AbyssIconLibrary(root: root)

        var diagnostics = AbyssParseDiagnostics()
        damageConstants = AbyssDamageConstants(formula: damageFormula,
                                               stellarConductRamp: tuning?.stellarConductRamp ?? 0.5,
                                               diagnostics: &diagnostics)

        // Everything the data says about one named character, in one pass and
        // checked. Six of the seven tables this replaces were read without ever
        // asking whether the id existed, so a typo removed a mechanic in silence
        // — a character missing from a list and a character the list does not
        // apply to are indistinguishable once the list has been read.
        let traitsFile: AbyssCharacterTraitsFile? =
            Self.decode(from: root?.appendingPathComponent("character-traits.json"), hasher: &hasher)
        dataDigest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        var traits: [String: AbyssCharacterTraits] = [:]
        for entry in traitsFile?.traits ?? [] {
            guard charactersByID[entry.characterId] != nil else {
                diagnostics.unknownTraitCharacterIDs.insert(entry.characterId)
                continue
            }
            guard traits[entry.characterId] == nil else {
                diagnostics.unknownTraitCharacterIDs.insert("\(entry.characterId): listed twice")
                continue
            }
            traits[entry.characterId] = entry
        }
        traitsByCharacterID = traits
        moonsignIDs = Set(traits.values.filter { $0.has(.moonsign) }.map(\.characterId))
        hexereiIDs = Set(traits.values.filter { $0.has(.hexerei) }.map(\.characterId))
        stellarJubileeIDs = Set(traits.values.filter { $0.has(.stellarJubilee) }.map(\.characterId))

        var reactionBonuses: [String: [AbyssReaction: Double]] = [:]
        for entry in traits.values {
            for bonus in entry.reactionBaseDamageBonus ?? [] {
                for name in bonus.reactions {
                    guard let reaction = AbyssReaction(rawValue: name) else {
                        diagnostics.unknownTraitCharacterIDs.insert(
                            "\(entry.characterId): \"\(name)\" is no reaction")
                        continue
                    }
                    reactionBonuses[entry.characterId, default: [:]][reaction] =
                        max(reactionBonuses[entry.characterId]?[reaction] ?? 0, bonus.value)
                }
            }
        }
        reactionBaseDamageBonusByCharacterID = reactionBonuses

        var profiles: [String: AbyssDamageProfile] = [:]
        var variants: [String: [AbyssTalentLevels: AbyssDamageProfile]] = [:]
        var boosts: [String: [Int: AbyssTalentSlot]] = [:]
        var sustain: [String: AbyssSustain] = [:]
        profiles.reserveCapacity(characters.count)
        variants.reserveCapacity(characters.count)
        sustain.reserveCapacity(characters.count)
        // Per character, the labels their data uses for a charged attack that
        // the generic vocabulary cannot see.
        let chargedLabels = traits.mapValues { $0.chargedAttackLabels?.labels ?? [] }

        for character in characters {
            let charged = chargedLabels[character.id] ?? []
            let base = Self.buildProfile(for: character, levels: .base,
                                         chargedLabels: charged, diagnostics: &diagnostics)
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
                                                  chargedLabels: charged,
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
        for (id, entry) in traits {
            guard let character = charactersByID[id] else { continue }
            for buff in entry.partyBuffs ?? [] {
                let talent = buff.talent == .skill ? character.elementalSkill : character.elementalBurst
                guard let value = AbyssTextParser.talentPercentage(in: talent, label: buff.label,
                                                                   index: buff.valueIndex ?? 0) else {
                    diagnostics.talentPartyBuffUnresolved.insert("\(id): \(buff.label)")
                    continue
                }
                let kind: AbyssTalentPartyBuff.Kind = buff.kind == .flatATKFromBaseATK
                    ? .flatATKFromBaseATK
                    : .elementalDMG
                talentBuffs[id, default: []].append(
                    AbyssTalentPartyBuff(kind: kind, value: value * buff.uptime))
            }
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
                                     chargedLabels: [String] = [],
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
        if let (multiplier, basis) = AbyssTextParser.chargedAttack(character,
                                                                   extraLabels: chargedLabels) {
            hits.append(.init(multiplier: multiplier, basis: basis, category: .charged))
        }
        diagnostics.normalAttackRowsUnclassified.formUnion(
            AbyssTextParser.unclassifiedNormalAttackRows(character, extraLabels: chargedLabels))

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
    private static func loadCycles(bundled: URL?, overrides: URL?,
                                   hasher: inout SHA256) -> [AbyssCycle] {
        var byPeriod: [String: AbyssCycle] = [:]
        for cycle in decodeArray([AbyssCycle].self, in: bundled, isArrayPerFile: false, hasher: &hasher) {
            byPeriod[cycle.periodStart] = cycle
        }
        for cycle in decodeArray([AbyssCycle].self, in: overrides, isArrayPerFile: false, hasher: &hasher) {
            byPeriod[cycle.periodStart] = cycle
        }
        return byPeriod.values.sorted { $0.periodStart > $1.periodStart }
    }

    // MARK: - File plumbing

    /// Every byte read goes through `hasher` on its way in — see `dataDigest`.
    private static func decode<T: Decodable>(from url: URL?, hasher: inout SHA256) -> T? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        hasher.update(data: data)
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Decodes every `.json` in a directory. `isArrayPerFile` distinguishes the
    /// two shapes in this data set: `characters/`/`weapons/` hold arrays that
    /// get concatenated, `abyss-monsters/` holds one object per file.
    private static func decodeArray<Element: Decodable>(_ type: [Element].Type,
                                                        in directory: URL?,
                                                        isArrayPerFile: Bool = true,
                                                        hasher: inout SHA256) -> [Element] {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }

        var collected: [Element] = []
        for url in files.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: url) else { continue }
            hasher.update(data: data)
            if isArrayPerFile {
                collected += (try? JSONDecoder().decode([Element].self, from: data)) ?? []
            } else if let one = try? JSONDecoder().decode(Element.self, from: data) {
                collected.append(one)
            }
        }
        return collected
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
