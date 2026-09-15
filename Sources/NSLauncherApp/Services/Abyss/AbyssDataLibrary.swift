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
    /// The wiki's particle notes — see `AbyssParticles`.
    let particles: AbyssParticles?
    /// Each character's energy economy, by id — see `AbyssEnergyProfile`.
    /// Every character has one; `diagnostics.particlesEstimated` names those
    /// whose particle count is the median stand-in.
    let energyByCharacterID: [String: AbyssEnergyProfile]
    /// The particle count characters without their own stand in with.
    let medianParticlesPerCast: Double
    /// gcsim's frame counts — see `AbyssFrames`.
    let frames: AbyssFrames?
    /// Yatta's per-hit gauge and ICD — see `AbyssGauge`.
    let gauge: AbyssGauge?
    /// Each weapon's passive as structured buffs, by weapon id — see
    /// `AbyssPassives.swift`. A weapon with no entry has no priced passive.
    let weaponBuffsByID: [String: [AbyssBuff]]
    /// Each artifact set's bonuses as structured buffs, by set id.
    let setBuffsByID: [String: (twoPiece: [AbyssBuff], fourPiece: [AbyssBuff])]
    /// Monster HP by level — see `AbyssEnemyHP.swift`. Nil when the file is
    /// missing, which leaves every fight without HP.
    let enemyHP: AbyssEnemyHPTable?
    /// How often each character applies their element — see
    /// `AbyssApplicationProfile`.
    let applicationsByCharacterID: [String: AbyssApplicationProfile]
    /// Median cast seconds of a skill and a burst, for solo stand-ins.
    let medianSkillSeconds: Double
    let medianBurstSeconds: Double
    /// How much each character adds to the base damage of the Lunar/Stellar
    /// reactions they name, by character id then reaction.
    let reactionBaseDamageBonusByCharacterID: [String: [AbyssReaction: Double]]
    let moonsignIDs: Set<String>
    /// Characters tagged `bond-of-life` in `character-kits.json`.
    let bondOfLifeIDs: Set<String>
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
        let particles: AbyssParticles? =
            Self.decode(from: root?.appendingPathComponent("particles.json"), hasher: &hasher)
        self.particles = particles
        let frames: AbyssFrames? =
            Self.decode(from: root?.appendingPathComponent("frames.json"), hasher: &hasher)
        self.frames = frames
        let gauge: AbyssGauge? =
            Self.decode(from: root?.appendingPathComponent("gauge.json"), hasher: &hasher)
        self.gauge = gauge
        enemyHP = Self.decode(from: root?.appendingPathComponent("enemy-hp.json"), hasher: &hasher)
        let passiveText: AbyssPassiveText? =
            Self.decode(from: root?.appendingPathComponent("passive-text.json"), hasher: &hasher)
        let passiveKnowledge: AbyssPassiveKnowledge? =
            Self.decode(from: root?.appendingPathComponent("passives.json"), hasher: &hasher)
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
        bondOfLifeIDs = Set(kits.values.filter { $0.has(.bondOfLife) }.map(\.characterId))
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
                let fromBurst = buff.talent == .elementalBurst
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
                talentBuffs[id, default: []].append(
                    AbyssTalentBuff(kind: kind, value: value * buff.uptime, fromBurst: fromBurst))
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

        let energy = Self.energyProfiles(characters: characters, talentParams: talentParams,
                                         particles: particles, frames: frames, kits: kits,
                                         rotationSeconds: tuning?.rotationSeconds ?? 20,
                                         maxSkillCasts: tuning?.energy.maxSkillCastsPerRotation ?? 1,
                                         diagnostics: &diagnostics)
        energyByCharacterID = energy.profiles
        medianParticlesPerCast = energy.median
        medianSkillSeconds = energy.medianSkillSeconds
        medianBurstSeconds = energy.medianBurstSeconds
        applicationsByCharacterID = Self.applicationProfiles(
            characters: characters, gauge: gauge, talentParams: talentParams, kits: kits,
            energy: energy.profiles, rotationSeconds: tuning?.rotationSeconds ?? 20, diagnostics: &diagnostics)

        if let passiveText, let passiveKnowledge {
            let passives = AbyssPassiveResolver.resolve(knowledge: passiveKnowledge, text: passiveText)
            weaponBuffsByID = passives.weapons
            setBuffsByID = passives.sets
            diagnostics.passiveReferencesUnresolved = passives.unresolved
        } else {
            weaponBuffsByID = [:]
            setBuffsByID = [:]
            diagnostics.passiveReferencesUnresolved = ["passive-text.json or passives.json could not be read"]
        }

        self.diagnostics = diagnostics
    }

    /// Every character's energy economy.
    ///
    /// Particles per cast come from the wiki note, read through the kit: a
    /// numeric note is per press (or per hold, if the kit plays hold), a
    /// per-event note needs the kit's `eventsPerCast`, and a page with no note
    /// needs the kit's `particlesPerCast`. Anything that does not resolve is
    /// named in `particlesEstimated` and given the median of everything that
    /// did — a stand-in computed from the data, never a number written down
    /// for the purpose. Cooldowns and costs come from the game's tables, or
    /// for the Travelers (no structured talents) from the transcription.
    static func energyProfiles(characters: [AbyssCharacter],
                               talentParams: AbyssTalentParams?,
                               particles: AbyssParticles?,
                               frames: AbyssFrames? = nil,
                               kits: [String: AbyssCharacterKit],
                               rotationSeconds: Double,
                               maxSkillCasts: Double = 1,
                               diagnostics: inout AbyssParseDiagnostics)
        -> (profiles: [String: AbyssEnergyProfile], median: Double,
            medianSkillSeconds: Double, medianBurstSeconds: Double) {
        func perCast(_ id: String) -> Double? {
            let kit = kits[id]?.energy
            if let literal = kit?.particlesPerCast { return literal }
            guard let reading = particles?.characters[id]?.readings.first else { return nil }
            if let event = reading.perEvent {
                guard let events = kit?.eventsPerCast else { return nil }
                return event.count * events
            }
            let count = kit?.variant == .hold ? reading.hold : reading.press
            return count.map { $0 * (kit?.eventsPerCast ?? 1) }
        }

        var resolved: [String: Double] = [:]
        for character in characters {
            if let value = perCast(character.id) { resolved[character.id] = value }
        }
        let sorted = resolved.values.sorted()
        let median = sorted.isEmpty ? 0
            : sorted.count % 2 == 1 ? sorted[sorted.count / 2]
            : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2

        func medianOf(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            guard !sorted.isEmpty else { return 0 }
            return sorted.count % 2 == 1 ? sorted[sorted.count / 2]
                : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        }
        let timings = frames?.characters.values ?? [:].values
        let medianCombo = medianOf(timings.compactMap { $0.comboFrames.map { Double($0.reduce(0, +)) / 60 } })
        let medianCharged = medianOf(timings.compactMap { $0.chargedFrames.map { Double($0) / 60 } })
        let medianSkill = medianOf(timings.compactMap { $0.skillFrames.map { Double($0) / 60 } })
        let medianBurst = medianOf(timings.compactMap { $0.burstFrames.map { Double($0) / 60 } })

        func share(_ cooldown: Double, cap: Double = 1) -> Double {
            cooldown > 0 ? min(cap, rotationSeconds / cooldown) : 1
        }

        var profiles: [String: AbyssEnergyProfile] = [:]
        for character in characters {
            let kit = kits[character.id]
            let structured = talentParams?.characters[character.id]
            let skillCooldown = structured?.elementalSkill.cooldown
                ?? Self.seconds(character.elementalSkill.cooldown) ?? 0
            let burstCooldown = structured?.elementalBurst.cooldown
                ?? Self.seconds(character.elementalBurst.cooldown) ?? 0
            let burstCost = structured?.elementalBurst.energyCost ?? character.elementalBurst.energyCost ?? 0

            let own = resolved[character.id]
            if own == nil { diagnostics.particlesEstimated.insert(character.id) }
            let skillCasts = kit?.energy?.skillCastsPerRotation ?? share(skillCooldown, cap: maxSkillCasts)
            let collector = kit?.energy?.collectedBy ?? .caster
            let window: AbyssEnergyProfile.Window
            switch kit?.stance?.talent {
            case .elementalBurst?: window = .burst
            case .elementalSkill?: window = .skill
            default: window = .none
            }
            let timing = frames?.characters[character.id]
            func seconds(_ frames: Int?, _ field: String, _ median: Double) -> Double {
                guard let frames else {
                    diagnostics.framesEstimated.insert("\(character.id): \(field)")
                    return median
                }
                return Double(frames) / 60
            }
            let attack = kit?.attack
            let comboSeconds = attack?.comboSeconds
                ?? seconds(timing?.comboFrames.map { $0.reduce(0, +) }, "combo", medianCombo)
            let chargedSeconds = attack?.chargedSeconds
                ?? seconds(timing?.chargedFrames, "charged", medianCharged)
            var loops = AbyssEnergyProfile.AttackLoops(combo: true, mixed: true,
                                                       charged: character.weaponType == .bow)
            switch attack?.loop {
            case .combo?: loops = .init(combo: true, mixed: false, charged: false)
            case .charged?: loops = .init(combo: false, mixed: false, charged: true)
            case nil: break
            }
            profiles[character.id] = AbyssEnergyProfile(
                element: character.element,
                // A summon's events were counted over the whole rotation in the
                // kit, so recasting it does not add particles; an instant skill's
                // particles come with every cast.
                particlesPerRotation: (own ?? median) * (collector == .field ? min(1, skillCasts) : skillCasts),
                collector: collector,
                skillCastsPerRotation: skillCasts,
                burstCost: burstCost,
                burstCastsCap: share(burstCooldown),
                window: window,
                comboSeconds: comboSeconds,
                chargedSeconds: chargedSeconds,
                skillSeconds: seconds(timing?.skillFrames, "skill", medianSkill),
                burstSeconds: seconds(timing?.burstFrames, "burst", medianBurst),
                attackLoops: loops,
                isEstimated: own == nil)
        }
        return (profiles, median, medianSkill, medianBurst)
    }

    /// Element applications per action for every character.
    ///
    /// Normal and charged attacks count only when they deal the character's
    /// element: a catalyst's, a bow's fully charged shot, or a kit marked
    /// `attack.infused`. A skill or burst row that keeps hitting — a summon, a
    /// field — is where one row stands for many hits: a summon takes its event
    /// count from the kit's `energy.eventsPerCast` (a second apart), a field
    /// with a time-based cooldown applies once per cooldown across the
    /// talent's longest Duration row, capped at a rotation. Every other row is
    /// one hit per cast.
    static func applicationProfiles(characters: [AbyssCharacter],
                                    gauge: AbyssGauge?,
                                    talentParams: AbyssTalentParams?,
                                    kits: [String: AbyssCharacterKit],
                                    energy: [String: AbyssEnergyProfile],
                                    rotationSeconds: Double,
                                    diagnostics: inout AbyssParseDiagnostics) -> [String: AbyssApplicationProfile] {
        typealias Counting = AbyssApplicationCounting
        var profiles: [String: AbyssApplicationProfile] = [:]
        for character in characters {
            guard let rows = gauge?.characters[character.id] else {
                diagnostics.gaugeMissing.insert(character.id)
                continue
            }
            let kit = kits[character.id]
            let timing = energy[character.id]
            let infused = kit?.attack?.infused ?? false
            let catalyst = character.weaponType == .catalyst
            var profile = AbyssApplicationProfile()

            if catalyst || infused {
                let combo = rows.normalAttack.filter { $0.name.hasPrefix("Normal Attack") && Counting.isHit($0) }
                profile.combo = Counting.action(combo, seconds: timing?.comboSeconds ?? 0)
            }
            let chargedRows = rows.normalAttack.filter { row in
                guard Counting.isHit(row) else { return false }
                if character.weaponType == .bow { return row.name.hasPrefix("Fully-Charged Aimed Shot") }
                return row.name.contains("Charged Attack")
            }
            if catalyst || infused || character.weaponType == .bow {
                profile.charged = Counting.action(chargedRows, seconds: 0)
            }

            func duration(_ key: AbyssTalentParams.Key) -> Double {
                guard let talent = talentParams?.characters[character.id]?.talent(key),
                      let params = talent.params(atLevel: 10) else { return 0 }
                var longest = 0.0
                let seconds = try? NSRegularExpression(pattern: #"^\{param(\d+):[A-Z0-9]+\}s$"#)
                for line in talent.lines(atLevel: 10) {
                    guard let (label, expression) = AbyssTalentReader.split(line),
                          label.contains("Duration"),
                          let match = seconds?.firstMatch(in: expression,
                                                          range: NSRange(expression.startIndex..., in: expression)),
                          let digits = Range(match.range(at: 1), in: expression),
                          let index = Int(expression[digits]),
                          index >= 1, index <= params.count else { continue }
                    longest = max(longest, params[index - 1])
                }
                return min(longest, rotationSeconds)
            }

            func ability(_ talentRows: [AbyssGauge.Row], key: AbyssTalentParams.Key,
                         events: Double?) -> AbyssApplicationProfile.Action {
                // Press and hold are two ways to cast, not two casts: when the
                // table has a Press row, the hold and charge-level rows are the
                // other way (Bennett, Kazuha). Kits play press by default.
                let pressed = talentRows.contains { $0.name.contains("Press") }
                let hits = talentRows.filter(Counting.isHit).filter { row in
                    !pressed || !(row.name.contains("Hold") || row.name.contains("Charge Level")
                                  || row.name.contains("Explosion"))
                }
                guard !hits.isEmpty else { return .none }
                // The row that keeps hitting: a cooldown-tagged row, last one wins.
                let repeating = hits.lastIndex { $0.icdTag != nil } ?? (events != nil ? hits.count - 1 : nil)
                var action = Counting.action(hits.enumerated().filter { $0.offset != repeating }.map(\.element),
                                             seconds: 0)
                guard let repeating else { return action }
                let row = hits[repeating]
                let field = duration(key)
                let count: Double
                let seconds: Double
                if let events, events > 1 {
                    count = events
                    seconds = events
                } else if let every = row.icdSeconds, field > 0 {
                    // A field: as many hits as it can land, and at least one per
                    // cooldown window across its duration.
                    count = max(1, (field / every).rounded(.down) * Double(row.icdHits ?? 1) + 1)
                    seconds = field
                } else {
                    count = 1
                    seconds = 0
                }
                let applications = Counting.applications(hits: count, hitsPerApplication: row.icdHits,
                                                         secondsPerApplication: row.icdSeconds, seconds: seconds)
                action.hits += count
                action.applications += applications
                action.units += applications * row.units
                return action
            }
            let events = kit?.energy?.collectedBy == .field ? kit?.energy?.eventsPerCast : nil
            profile.skill = ability(rows.elementalSkill, key: .elementalSkill, events: events)
            profile.burst = ability(rows.elementalBurst, key: .elementalBurst, events: nil)
            profiles[character.id] = profile
        }
        return profiles
    }

    /// `"18s"` → 18. The transcription's cooldown column; nil for anything
    /// that is not one plain number of seconds.
    static func seconds(_ text: String?) -> Double? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix("s") else { return nil }
        return Double(trimmed.dropLast())
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
            let reaction: AbyssReaction?
        }
        var totals: [Slot: Double] = [:]
        var order: [Slot] = []
        for hit in hits {
            let key = Slot(basis: hit.basis, category: hit.category, action: hit.action, reaction: hit.reaction)
            if totals[key] == nil { order.append(key) }
            totals[key, default: 0] += hit.multiplier
        }
        let aggregate = order.map {
            AbyssDamageProfile.Term(multiplier: totals[$0] ?? 0, basis: $0.basis, category: $0.category,
                                    action: $0.action, reaction: $0.reaction)
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
