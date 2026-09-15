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
    /// `character-kits.json`'s `buffs` against the character data.
    let talentBuffsByCharacterID: [String: [AbyssTalentBuff]]
    /// Stats each character's kit turns into ATK, by id — see `AbyssStatConversion`.
    let conversionsByCharacterID: [String: [AbyssStatConversion]]
    /// Enemy resistance each character strips, by id, with a talent-table
    /// value already read where the kit named a row.
    let resistanceShredByCharacterID: [String: [(elements: [String], value: Double, uptime: Double)]]
    /// Everything `character-kits.json` says about each character, by id.
    let kitsByCharacterID: [String: AbyssCharacterKit]
    /// `talent-params.json`: every talent's multipliers as the game's files
    /// state them. A character present here has their damage profile read by
    /// `AbyssTalentReader` from these; one absent (the seven Travelers) keeps
    /// the prose path through `AbyssTextParser`. Nil when the file is missing,
    /// in which case everyone keeps the prose path — the same degradation the
    /// rest of the data has.
    let talentParams: AbyssTalentParams?
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
        let kitsFile: AbyssCharacterKitsFile? =
            Self.decode(from: root?.appendingPathComponent("character-kits.json"), hasher: &hasher)
        let talentParams: AbyssTalentParams? =
            Self.decode(from: root?.appendingPathComponent("talent-params.json"), hasher: &hasher)
        self.talentParams = talentParams
        dataDigest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        var kits: [String: AbyssCharacterKit] = [:]
        for entry in kitsFile?.kits ?? [] {
            guard charactersByID[entry.characterId] != nil else {
                diagnostics.unknownKitCharacterIDs.insert(entry.characterId)
                continue
            }
            guard kits[entry.characterId] == nil else {
                diagnostics.unknownKitCharacterIDs.insert("\(entry.characterId): listed twice")
                continue
            }
            kits[entry.characterId] = entry
        }
        kitsByCharacterID = kits
        moonsignIDs = Set(kits.values.filter { $0.has(.moonsign) }.map(\.characterId))
        hexereiIDs = Set(kits.values.filter { $0.has(.hexerei) }.map(\.characterId))
        stellarJubileeIDs = Set(kits.values.filter { $0.has(.stellarJubilee) }.map(\.characterId))

        var reactionBonuses: [String: [AbyssReaction: Double]] = [:]
        for entry in kits.values {
            for bonus in entry.reactionBaseDamageBonus ?? [] {
                for name in bonus.reactions {
                    guard let reaction = AbyssReaction(rawValue: name) else {
                        diagnostics.unknownKitCharacterIDs.insert(
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
        let chargedLabels = kits.mapValues { $0.chargedAttackLabels?.labels ?? [] }

        for character in characters {
            let charged = chargedLabels[character.id] ?? []
            let structured = talentParams?.characters[character.id]
            let kit = kits[character.id]
            let base = Self.buildProfile(for: character, levels: .base, structured: structured,
                                         chargedLabels: charged, kit: kit, diagnostics: &diagnostics)
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
                table[levels] = Self.buildProfile(for: character, levels: levels, structured: structured,
                                                  chargedLabels: charged, kit: kit,
                                                  diagnostics: &throwaway)
            }
            variants[character.id] = table
        }
        profilesByCharacterID = profiles
        profileVariants = variants
        talentBoostsByCharacterID = boosts
        sustainByCharacterID = sustain

        // A kit names rows of the talent tables by label. Resolving them here
        // rather than at scoring time means the label matching happens once,
        // and a row that has been renamed shows up in `diagnostics` — and
        // fails a test — instead of quietly contributing nothing. Everything
        // is read at the base talent level: a C3/C5 boost moves these by a
        // few percent, and carrying every variant is not worth the table.
        var talentBuffs: [String: [AbyssTalentBuff]] = [:]
        var conversions: [String: [AbyssStatConversion]] = [:]
        var shreds: [String: [(elements: [String], value: Double, uptime: Double)]] = [:]
        let baseLevel = Self.talentLevel(AbyssTalentLevels.base.skill)
        for (id, kit) in kits {
            guard let character = charactersByID[id] else { continue }
            let structured = talentParams?.characters[id]

            /// One labelled row, summed over its bases — a buff or a shred is
            /// one number, and its suffix (" ATK", " DEF") is the game saying
            /// what it is a share of, not a second term.
            func rowValue(_ key: AbyssTalentParams.Key?, _ label: String, what: String) -> Double? {
                guard let key, let structured,
                      let totals = AbyssTalentReader.row(labelled: label, in: structured.talent(key),
                                                         level: baseLevel) else {
                    diagnostics.kitReferencesUnresolved.insert(
                        "\(id): \(what) \"\(label)\" — no such row in \(key?.rawValue ?? "an unnamed talent")")
                    return nil
                }
                return totals.values.reduce(0, +)
            }

            for buff in kit.buffs ?? [] {
                let value: Double?
                switch (buff.label, buff.value) {
                case (let label?, nil): value = rowValue(buff.talent, label, what: "buff")
                case (nil, let literal?): value = literal
                default:
                    diagnostics.talentBuffUnresolved.insert("\(id): a buff is a label or a value, not both or neither")
                    continue
                }
                guard let value else { diagnostics.talentBuffUnresolved.insert("\(id): \(buff.label ?? "")"); continue }
                let kind: AbyssTalentBuff.Kind
                switch (buff.scope, buff.kind) {
                case (.party, .flatATKFromBaseATK): kind = .flatATKFromBaseATK
                case (.party, .elementalDMG): kind = .elementalDMG
                case (.self, .stat):
                    if buff.stat == "elemental_dmg" {
                        kind = .ownStat(.elemental(character.element))
                    } else if let field = buff.stat.flatMap(AbyssStatField.init(tuningKey:)), !field.isPartyScoped {
                        kind = .ownStat(field)
                    } else {
                        diagnostics.talentBuffUnresolved.insert("\(id): \"\(buff.stat ?? "")\" is no stat of the caster's own sheet")
                        continue
                    }
                default:
                    diagnostics.talentBuffUnresolved.insert(
                        "\(id): \(buff.kind.rawValue) is not a \(buff.scope.rawValue) buff kind")
                    continue
                }
                talentBuffs[id, default: []].append(AbyssTalentBuff(kind: kind, value: value * buff.uptime))
            }

            for conversion in kit.conversions ?? [] {
                guard let structured,
                      let totals = AbyssTalentReader.row(labelled: conversion.label,
                                                         in: structured.talent(conversion.talent),
                                                         level: baseLevel),
                      totals.count == 1, let (basis, rate) = totals.first, basis == .hp || basis == .def else {
                    diagnostics.kitReferencesUnresolved.insert(
                        "\(id): conversion \"\(conversion.label)\" is not one share of HP or DEF in \(conversion.talent.rawValue)")
                    continue
                }
                conversions[id, default: []].append(AbyssStatConversion(from: basis, rate: rate * conversion.uptime))
            }

            for shred in kit.resistanceShred ?? [] {
                let value: Double?
                switch (shred.label, shred.value) {
                case (let label?, nil): value = rowValue(shred.talent, label, what: "shred")
                case (nil, let literal?): value = literal
                default:
                    diagnostics.kitReferencesUnresolved.insert("\(id): a shred is a label or a value, not both or neither")
                    continue
                }
                guard let value else { continue }
                shreds[id, default: []].append((shred.elements, value, shred.uptime))
            }
        }
        talentBuffsByCharacterID = talentBuffs
        conversionsByCharacterID = conversions
        resistanceShredByCharacterID = shreds

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

    /// The hits a character's talents deal, from the game's own tables when
    /// `structured` is present and from the transcribed prose otherwise. The
    /// two are read by the same rules — see `AbyssTalentReader`'s header — so
    /// a character can move from one to the other without the meaning of a
    /// profile changing, only its accuracy.
    ///
    /// A kit's `hits` replace the reader's inference slot by slot — the kit
    /// says which rows one cast really deals, the reader still says what each
    /// row is worth. Kit hits need the structured tables; a kit on a
    /// prose-only character is reported, not silently ignored.
    static func hits(for character: AbyssCharacter,
                     levels: AbyssTalentLevels,
                     structured: AbyssTalentParams.Character?,
                     chargedLabels: [String],
                     kit: AbyssCharacterKit? = nil,
                     diagnostics: inout AbyssParseDiagnostics) -> [AbyssDamageProfile.Term] {
        if let structured {
            let skillLevel = Self.talentLevel(levels.skill), burstLevel = Self.talentLevel(levels.burst)
            // Normal attacks are read at their base level on both paths: no
            // constellation in the data raises the rows the model uses.
            let normalLevel = Self.talentLevel(AbyssTalentLevels.base.skill)
            let level: (AbyssTalentParams.Key) -> Int = { key in
                switch key {
                case .normalAttack: return normalLevel
                case .elementalSkill: return skillLevel
                case .elementalBurst: return burstLevel
                }
            }
            func fromKit(_ slot: AbyssCharacterKit.HitSlot,
                         diagnostics: inout AbyssParseDiagnostics) -> [AbyssDamageProfile.Term]? {
                guard let references = kit?.hits?[slot] else { return nil }
                return AbyssTalentReader.kitTerms(references, slot: slot, structured: structured, level: level,
                                                  characterID: character.id, diagnostics: &diagnostics)
            }

            var hits = fromKit(.skill, diagnostics: &diagnostics)
                ?? AbyssTalentReader.abilityTerms(structured.elementalSkill, level: skillLevel,
                                                  category: .skill, characterID: character.id,
                                                  diagnostics: &diagnostics)
            hits += fromKit(.burst, diagnostics: &diagnostics)
                ?? AbyssTalentReader.abilityTerms(structured.elementalBurst, level: burstLevel,
                                                  category: .burst, characterID: character.id,
                                                  diagnostics: &diagnostics)
            hits += fromKit(.combo, diagnostics: &diagnostics)
                ?? AbyssTalentReader.comboTerms(structured.normalAttack, level: normalLevel)
            hits += fromKit(.charged, diagnostics: &diagnostics)
                ?? AbyssTalentReader.chargedTerms(structured.normalAttack, level: normalLevel,
                                                  extraLabels: chargedLabels)
            // A kit that says what the attack string is has, by saying so,
            // classified the rest of the table as not part of it.
            if kit?.hits?.combo == nil, kit?.hits?.charged == nil {
                diagnostics.normalAttackRowsUnclassified.formUnion(
                    AbyssTalentReader.unclassifiedRows(structured.normalAttack, level: normalLevel,
                                                       characterID: character.id, extraLabels: chargedLabels))
            }
            return hits
        }
        if let hits = kit?.hits {
            for slot in AbyssCharacterKit.HitSlot.allCases where hits[slot] != nil {
                diagnostics.kitReferencesUnresolved.insert(
                    "\(character.id): \(slot.rawValue) hits need talent-params.json, which has no entry for them")
            }
        }

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
        return hits
    }

    /// `"lv10"` → 10. The prose keys and the structured levels name the same
    /// thing; this is the seam between the two spellings.
    static func talentLevel(_ key: String) -> Int {
        Int(key.dropFirst(2)) ?? 10
    }

    /// The stat a set of hits mostly scales off — the structured counterpart
    /// of `AbyssTextParser.scalingBasis`, same rule: the non-ATK basis with the
    /// most skill and burst hits wins only if it beats ATK outright, ties
    /// between non-ATK bases through `ScalingBasis.tieBreakOrder`.
    static func dominantBasis(of hits: [AbyssDamageProfile.Term]) -> ScalingBasis {
        var counts: [ScalingBasis: Int] = [:]
        for hit in hits where hit.category == .skill || hit.category == .burst {
            counts[hit.basis, default: 0] += 1
        }
        let atkCount = counts[.atk] ?? 0
        var bestBasis: ScalingBasis?
        var bestCount = 0
        for basis in ScalingBasis.tieBreakOrder where (counts[basis] ?? 0) > bestCount {
            bestBasis = basis
            bestCount = counts[basis] ?? 0
        }
        guard let bestBasis, bestCount > atkCount else { return .atk }
        return bestBasis
    }

    private static func buildProfile(for character: AbyssCharacter,
                                     levels: AbyssTalentLevels,
                                     structured: AbyssTalentParams.Character? = nil,
                                     chargedLabels: [String] = [],
                                     kit: AbyssCharacterKit? = nil,
                                     diagnostics: inout AbyssParseDiagnostics) -> AbyssDamageProfile {
        let hits = Self.hits(for: character, levels: levels, structured: structured,
                             chargedLabels: chargedLabels, kit: kit, diagnostics: &diagnostics)

        // Collapse to one term per (basis, category, action). Every hit in a
        // group shares the same stat, the same bonus and the same count per
        // rotation, so factoring the multipliers out is exact — it just turns
        // 10-20 multiplies per character per team into 3-5. First-appearance
        // order is kept so the sum is reproducible run to run.
        struct Slot: Hashable {
            let basis: ScalingBasis; let category: HitCategory; let action: AbyssDamageProfile.Action
        }
        var totals: [Slot: Double] = [:]
        var order: [Slot] = []
        for hit in hits {
            let key = Slot(basis: hit.basis, category: hit.category, action: hit.action)
            if totals[key] == nil { order.append(key) }
            totals[key, default: 0] += hit.multiplier
        }
        let aggregate = order.map {
            AbyssDamageProfile.Term(multiplier: totals[$0] ?? 0, basis: $0.basis, category: $0.category,
                                    action: $0.action)
        }

        return AbyssDamageProfile(
            hits: hits,
            aggregate: aggregate,
            basis: structured != nil
                ? Self.dominantBasis(of: hits)
                : AbyssTextParser.scalingBasis(for: character, diagnostics: &diagnostics))
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
