// AbyssOptimizer.swift
//
// Picks each character's gear, trims the candidate pool, then walks every
// 4-character combination scoring it against each floor. Ports `pick_gear` and
// the enumeration from the Python's `optimize_abyss.py`.
//
// Ordering is made explicit everywhere. The reference implementation leans on
// Python's stable sort; Swift's is not stable, and with near-ties being the
// normal case (two teams differing by 0.01%) an unstable sort would return a
// different top-5 order on each run and make the results look untrustworthy.

import Foundation

struct AbyssOptimizer: Sendable {
    let library: AbyssDataLibrary
    private let tuning: AbyssTuning
    private let assembler: AbyssBuildAssembler
    private let scorer: AbyssScorer

    /// How many weapons to keep per character. More than one because team
    /// members compete for the same weapon and need somewhere to fall back to.
    static let weaponAlternatives = 6
    /// Floor on how many teams reach the artifact pass, so a request for the
    /// single best team still gets a real shortlist to re-rank.
    private static let minimumRefinementCandidates = 20
    /// The only floor worth optimising for. Anything that clears 12 clears the
    /// floors below it, so the other three quarters of the search produced
    /// rankings nobody acted on.
    static let deepestFloor = 12

    init?(library: AbyssDataLibrary) {
        guard let tuning = library.tuning else { return nil }
        self.library = library
        self.tuning = tuning
        assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                        artifactSets: library.artifactSets,
                                        talentPartyBuffs: library.talentPartyBuffsByCharacterID)
        scorer = AbyssScorer(library: library, tuning: tuning)
    }

    // MARK: - Entry point

    func run(_ request: AbyssOptimizerRequest,
             progress: (@Sendable (Double) -> Void)? = nil) async -> AbyssOptimizerOutput {
        let roster = request.roster
        let unknownIDs = roster.map { unknownRosterIDs(in: $0) } ?? []

        // Each pool is gated independently, but `roster` itself is passed on
        // unchanged everywhere else (refinement, constellation) — a
        // full-character-pool search still credits a weapon the player actually
        // owns with its real refinement, it just is not the thing being
        // restricted.
        let characterRoster = request.usesFullCharacterPool ? nil : roster
        let weaponRoster = request.usesFullWeaponPool ? nil : roster

        // The id sets are built once and captured, not asked of the roster from
        // inside the filter: `characterIDs` builds a fresh `Set` from the whole
        // owned list on every read, which inside a `filter` is one per candidate.
        let characters = characterRoster.map { roster in
            let owned = roster.characterIDs
            return library.characters.filter { owned.contains($0.id) }
        } ?? library.characters

        let weapons = weaponRoster.map { roster in
            let owned = roster.weaponIDs
            return library.weapons.filter { owned.contains($0.id) }
        } ?? library.weapons

        // Every 5★ set, always. Artifacts are farmable — unlike a weapon, a set
        // the player does not have yet is a thing to go and get, so the useful
        // answer is the best one that exists rather than the best one already
        // owned. There is deliberately no artifact roster to narrow this.
        let sets = library.fiveStarArtifactSets

        guard characters.count >= 4 else {
            return AbyssOptimizerOutput(reports: [], consideredCharacterIDs: characters.map(\.id),
                                        unknownRosterIDs: unknownIDs)
        }

        let showcaseByID = Dictionary(request.showcase.map { ($0.characterID, $0) },
                                      uniquingKeysWith: { first, _ in first })

        // Talent levels follow the constellations the player actually has: C3
        // and C5 each raise one talent by three, and the data carries the level
        // 13 column for the characters whose constellations were transcribed
        // that far. A showcase knows the constellation for certain; the roster
        // is what the player typed in.
        let profiles = Dictionary(uniqueKeysWithValues: characters.compactMap {
            character -> (String, AbyssDamageProfile)? in
            let constellation = showcaseByID[character.id]?.constellation
                ?? roster?.constellation(for: character.id)
                ?? 0
            guard let profile = library.profile(for: character.id, constellation: constellation)
            else { return nil }
            return (character.id, profile)
        })

        // One task per character. Gear selection is now the second-heaviest part
        // of a run — every character is dressed in all 1081 artifact
        // configurations — and each character's answer depends on nothing but
        // that character, so there is nothing to coordinate.
        let options = await withTaskGroup(of: (String, [AbyssGearOption]).self) { group in
            for character in characters {
                group.addTask {
                    (character.id,
                     gearOptions(for: character, weapons: weapons, sets: sets,
                                 roster: roster, showcase: showcaseByID[character.id],
                                 profile: profiles[character.id]))
                }
            }
            var collected: [String: [AbyssGearOption]] = [:]
            collected.reserveCapacity(characters.count)
            for await (id, entry) in group { collected[id] = entry }
            return collected
        }

        // Characters far down on solo damage never appear in a winning team, and
        // C(n,4) grows fast enough that keeping them is pure cost.
        let pool = characters
            .enumerated()
            .sorted { lhs, rhs in
                let lhsScore = options[lhs.element.id]?.first?.soloScore ?? 0
                let rhsScore = options[rhs.element.id]?.first?.soloScore ?? 0
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
            .prefix(request.poolSize)

        let poolArray = Array(pool)
        guard let cycle = library.latestCycle else {
            return AbyssOptimizerOutput(reports: [], consideredCharacterIDs: poolArray.map(\.id),
                                        unknownRosterIDs: unknownIDs)
        }

        let floorNumbers = request.floors ?? Self.defaultFloors(in: cycle)
        var reports: [AbyssFloorReport] = []
        var diagnostics = AbyssParseDiagnostics()
        let charactersByID = Dictionary(poolArray.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // The artifact pass can promote a team past the ones that beat it on
        // neutral gear, so more candidates are carried into it than are shown.
        let candidateCount = request.refinesArtifacts
            ? max(request.topN * 4, Self.minimumRefinementCandidates)
            : request.topN

        for (index, floorNumber) in floorNumbers.enumerated() {
            if Task.isCancelled { break }
            guard let floor = AbyssFloorContext.build(cycle: cycle, floor: floorNumber,
                                                      diagnostics: &diagnostics) else { continue }
            var teams = await bestTeams(in: poolArray, options: options, profiles: profiles,
                                        floor: floor, topN: candidateCount)
            if request.refinesArtifacts {
                let advisor = AbyssArtifactAdvisor(library: library, assembler: assembler,
                                                   scorer: scorer)
                // One task per candidate team: each sweeps its four members
                // through every artifact configuration and touches nothing the
                // others touch. `trim` re-sorts, so the order the tasks finish
                // in cannot reach the result.
                let refined = await withTaskGroup(of: AbyssTeamResult.self) { group in
                    for team in teams {
                        group.addTask {
                            advisor.refine(team: team,
                                           members: team.memberIDs.compactMap { charactersByID[$0] },
                                           floor: floor, sets: sets, roster: roster,
                                           showcase: showcaseByID, profiles: profiles)
                        }
                    }
                    var collected: [AbyssTeamResult] = []
                    collected.reserveCapacity(teams.count)
                    for await result in group { collected.append(result) }
                    return collected
                }
                teams = Self.trim(refined, topN: request.topN)
            }
            reports.append(AbyssFloorReport(
                floor: floorNumber,
                monsterLevel: floor.monsterLevel,
                buffs: floor.buffs,
                shieldElements: floor.shieldElements,
                weakElements: floor.weakElements,
                teams: teams))
            progress?(Double(index + 1) / Double(max(floorNumbers.count, 1)))
        }

        return AbyssOptimizerOutput(reports: reports,
                                    consideredCharacterIDs: poolArray.map(\.id),
                                    unknownRosterIDs: unknownIDs)
    }

    /// Which floors a request with no explicit list runs.
    ///
    /// Floor 12 when the cycle has one, and the deepest floor it does have
    /// otherwise: the cycle file can be replaced by the user, and a rotation
    /// that stopped at 11 should still return teams rather than nothing.
    private static func defaultFloors(in cycle: AbyssCycle) -> [Int] {
        let numbers = cycle.floors.map(\.floor)
        if numbers.contains(deepestFloor) { return [deepestFloor] }
        return numbers.max().map { [$0] } ?? []
    }

    private func unknownRosterIDs(in roster: AbyssRoster) -> [String] {
        var unknown = roster.characterIDs.filter { library.charactersByID[$0] == nil }
        unknown.formUnion(roster.weaponIDs.filter { library.weaponsByID[$0] == nil })
        return unknown.sorted()
    }

    // MARK: - Team enumeration

    /// Scores every 4-character combination, keeping the best `topN`.
    ///
    /// Work is striped across cores; each stripe keeps its own top list and the
    /// merge re-sorts, so the result does not depend on which stripe finished
    /// first.
    private func bestTeams(in pool: [AbyssCharacter],
                           options: [String: [AbyssGearOption]],
                           profiles: [String: AbyssDamageProfile],
                           floor: AbyssFloorContext,
                           topN: Int) async -> [AbyssTeamResult] {
        let combinations = Self.combinationCount(pool.count, choose: 4)
        guard combinations > 0 else { return [] }

        let stripeCount = min(max(ProcessInfo.processInfo.activeProcessorCount, 1),
                              max(Int(combinations / 512), 1))
        if stripeCount <= 1 {
            return Self.trim(scoreRange(0..<combinations, pool: pool, options: options,
                                        profiles: profiles, floor: floor),
                             topN: topN)
        }

        let stride = combinations / Int64(stripeCount) + 1
        let results = await withTaskGroup(of: [AbyssTeamResult].self) { group -> [AbyssTeamResult] in
            for stripe in 0..<stripeCount {
                let lower = Int64(stripe) * stride
                let upper = min(lower + stride, combinations)
                guard lower < upper else { continue }
                group.addTask {
                    Self.trim(scoreRange(lower..<upper, pool: pool, options: options,
                                         profiles: profiles, floor: floor),
                              topN: topN)
                }
            }
            var merged: [AbyssTeamResult] = []
            for await partial in group { merged.append(contentsOf: partial) }
            return merged
        }
        return Self.trim(results, topN: topN)
    }

    private func scoreRange(_ range: Range<Int64>,
                            pool: [AbyssCharacter],
                            options: [String: [AbyssGearOption]],
                            profiles: [String: AbyssDamageProfile],
                            floor: AbyssFloorContext) -> [AbyssTeamResult] {
        var results: [AbyssTeamResult] = []
        var indices = [0, 1, 2, 3]
        guard Self.combination(at: range.lowerBound, n: pool.count, into: &indices) else { return [] }

        var position = range.lowerBound
        while position < range.upperBound {
            if position % 4096 == 0, Task.isCancelled { break }
            let members = indices.map { pool[$0] }
            if let result = scorer.score(members: members, options: options, floor: floor,
                                         profiles: profiles) {
                results.append(result)
            }
            position += 1
            if !Self.advance(&indices, n: pool.count) { break }
        }
        return results
    }

    /// Sorts by score, breaking ties on member ids so equal-scoring teams always
    /// come back in the same order.
    private static func trim(_ results: [AbyssTeamResult], topN: Int) -> [AbyssTeamResult] {
        results
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.id < rhs.id
            }
            .prefix(topN)
            .map { $0 }
    }

    // MARK: - Combination indexing

    /// Number of ways to choose `k` from `n`.
    ///
    /// `k == 0` is 1, not 0 — there is exactly one way to choose nothing. The
    /// rank-to-combination walk below relies on that for its innermost slot, and
    /// getting it wrong makes the walk fail on the very first team.
    static func combinationCount(_ n: Int, choose k: Int) -> Int64 {
        guard k >= 0, n >= k else { return 0 }
        guard k > 0 else { return 1 }
        var result: Int64 = 1
        for step in 0..<k {
            result = result * Int64(n - step) / Int64(step + 1)
        }
        return result
    }

    /// Fills `indices` with the `rank`-th combination in lexicographic order, so
    /// stripes can start anywhere without walking there.
    static func combination(at rank: Int64, n: Int, into indices: inout [Int]) -> Bool {
        var remaining = rank
        var current = 0
        for slot in 0..<4 {
            var candidate = current
            while candidate < n {
                let tail = combinationCount(n - candidate - 1, choose: 3 - slot)
                if remaining < tail {
                    indices[slot] = candidate
                    current = candidate + 1
                    break
                }
                remaining -= tail
                candidate += 1
            }
            if candidate >= n { return false }
        }
        return true
    }

    /// Steps to the next combination in lexicographic order.
    static func advance(_ indices: inout [Int], n: Int) -> Bool {
        var slot = 3
        while slot >= 0 {
            if indices[slot] < n - (4 - slot) {
                indices[slot] += 1
                for next in (slot + 1)..<4 {
                    indices[next] = indices[next - 1] + 1
                }
                return true
            }
            slot -= 1
        }
        return false
    }

    // MARK: - Gear selection

    /// Ranks a character's gear, best first.
    ///
    /// Weapon and artifacts are chosen in two passes rather than by trying every
    /// weapon × artifact pair: the two contribute almost additively, so the
    /// joint search costs ~25× more for a result that differs only at the
    /// margins. *Within* the artifact pass nothing is shortlisted — every set
    /// as a 4-piece and every pair of sets as 2+2 is built and scored.
    func gearOptions(for character: AbyssCharacter,
                     weapons: [AbyssWeapon],
                     sets: [AbyssArtifactSet],
                     roster: AbyssRoster?,
                     showcase: AbyssShowcaseBuild? = nil,
                     profile explicitProfile: AbyssDamageProfile? = nil) -> [AbyssGearOption] {
        guard let profile = explicitProfile ?? library.profilesByCharacterID[character.id] else {
            return []
        }
        let role = defaultRole(for: character)

        // The neutral yardstick every option here is measured against. Built
        // once: gear selection scores over a thousand stat sheets against it.
        let solo = scorer.soloContext(for: character, profile: profile)

        // An imported character needs no gear search: the app knows what they
        // are holding and what they rolled. One option, their own, and the
        // artifact pass then says what to change.
        if let showcase {
            let weapon = showcase.weaponID.flatMap { library.weaponsByID[$0] }
            let wornIDs = showcase.activeSetIDs
            let worn = wornIDs.compactMap { library.artifactSetsByID[$0] }
            var stats = assembler.showcaseStats(build: showcase, character: character,
                                                weapon: weapon, wornSets: worn)
            var diagnostics = AbyssParseDiagnostics()
            assembler.applySets(worn, character: character, to: &stats, diagnostics: &diagnostics)
            return [AbyssGearOption(stats: stats, weaponID: showcase.weaponID, setIDs: wornIDs,
                                    role: role,
                                    soloScore: scorer.soloScore(context: solo, stats: stats),
                                    statSource: .measured)]
        }

        let usable = weapons.filter { $0.type == character.weaponType }
        var diagnostics = AbyssParseDiagnostics()

        // The half of the sheet that does not depend on which sets are worn.
        // Split out because the artifact pass below dresses one weapon in over
        // a thousand configurations that all share it, and this is the
        // expensive half — the weapon passive is matched with regexes.
        func base(_ weapon: AbyssWeapon?) -> AbyssStats {
            assembler.statsWithoutSets(character: character, profile: profile, weapon: weapon,
                                       role: role,
                                       refinement: roster?.refinement(for: weapon?.id ?? "") ?? 1)
        }

        func wearing(_ chosenSets: [AbyssArtifactSet], over sheet: AbyssStats) -> AbyssStats {
            var stats = sheet
            assembler.applySets(chosenSets, character: character, to: &stats, diagnostics: &diagnostics)
            return stats
        }

        func build(_ weapon: AbyssWeapon?, _ chosenSets: [AbyssArtifactSet]) -> AbyssStats {
            wearing(chosenSets, over: base(weapon))
        }

        guard !usable.isEmpty else {
            let stats = build(nil, Array(sets.prefix(1)))
            return [AbyssGearOption(stats: stats, weaponID: nil, setIDs: sets.prefix(1).map(\.id),
                                    role: role, soloScore: scorer.soloScore(context: solo, stats: stats))]
        }
        guard let baseline = sets.first else {
            return usable.map { weapon in
                let stats = build(weapon, [])
                return AbyssGearOption(stats: stats, weaponID: weapon.id, setIDs: [], role: role,
                                       soloScore: scorer.soloScore(context: solo, stats: stats))
            }
            .sorted { $0.soloScore > $1.soloScore }
            .prefix(Self.weaponAlternatives)
            .map { $0 }
        }

        // Pass 1: rank weapons against one fixed set so they are comparable.
        let bases = usable.map { base($0) }
        let rankedWeapons = usable
            .enumerated()
            .map { (offset: $0.offset, weapon: $0.element,
                    score: scorer.soloScore(context: solo,
                                            stats: wearing([baseline], over: bases[$0.offset]))) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.offset < rhs.offset
            }
            .prefix(Self.weaponAlternatives)

        guard let top = rankedWeapons.first else { return [] }

        // Pass 2: every artifact configuration for that weapon — each set worn
        // as a 4-piece, and every pair of sets worn as 2+2. With 46 five-star
        // sets that is 1081 configurations; all of them are built and scored,
        // so no set is ruled out by a shortlist that was only ever a guess at
        // which ones could win.
        //
        // Strict `>` keeps the first maximum, so ties resolve to the earlier
        // set in file order and the pick is the same on every run.
        let topBase = bases[top.offset]
        var bestSets = [baseline]
        var bestScore = -Double.infinity
        for set in sets {
            let score = scorer.soloScore(context: solo, stats: wearing([set], over: topBase))
            if score > bestScore {
                bestScore = score
                bestSets = [set]
            }
        }
        for first in 0..<sets.count {
            for second in (first + 1)..<sets.count {
                let pair = [sets[first], sets[second]]
                let score = scorer.soloScore(context: solo, stats: wearing(pair, over: topBase))
                if score > bestScore {
                    bestScore = score
                    bestSets = pair
                }
            }
        }

        return rankedWeapons
            .map { entry -> AbyssGearOption in
                let stats = wearing(bestSets, over: bases[entry.offset])
                return AbyssGearOption(stats: stats, weaponID: entry.weapon.id,
                                       setIDs: bestSets.map(\.id), role: role,
                                       soloScore: scorer.soloScore(context: solo, stats: stats))
            }
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.soloScore != rhs.element.soloScore {
                    return lhs.element.soloScore > rhs.element.soloScore
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// The role a character is built for.
    ///
    /// Note this never returns `sub-dps` or `support`: the reference
    /// implementation only distinguishes healers and shielders from everyone
    /// else, and everyone else gets a damage build. The UI relabels off-field
    /// damage dealers as sub-DPS for display, but their *build* is the main-DPS
    /// one. Changing that here would move every score away from the fixture, so
    /// it has to change in both implementations together.
    func defaultRole(for character: AbyssCharacter) -> AbyssRole {
        let capability = AbyssTeamContext.capabilities(of: character)
        if capability.canHeal { return .healer }
        if capability.canShield { return .shield }
        return .mainDPS
    }
}
