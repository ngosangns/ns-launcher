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
    /// Set pairs are tried across the best few sets only; the tail never wins.
    private static let setPairCandidates = 8

    init?(library: AbyssDataLibrary) {
        guard let tuning = library.tuning else { return nil }
        self.library = library
        self.tuning = tuning
        assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs)
        scorer = AbyssScorer(library: library, tuning: tuning)
    }

    // MARK: - Entry point

    func run(_ request: AbyssOptimizerRequest,
             progress: (@Sendable (Double) -> Void)? = nil) async -> AbyssOptimizerOutput {
        let roster = request.roster
        let unknownIDs = roster.map { unknownRosterIDs(in: $0) } ?? []

        let characters = roster.map { roster in
            library.characters.filter { roster.characterIDs.contains($0.id) }
        } ?? library.characters

        let weapons = roster.map { roster in
            library.weapons.filter { roster.weaponIDs.contains($0.id) }
        } ?? library.weapons

        let ownedSets = roster?.artifactSets ?? []
        let sets = ownedSets.isEmpty
            ? library.fiveStarArtifactSets
            : library.fiveStarArtifactSets.filter { ownedSets.contains($0.id) }

        guard characters.count >= 4 else {
            return AbyssOptimizerOutput(reports: [], consideredCharacterIDs: characters.map(\.id),
                                        unknownRosterIDs: unknownIDs)
        }

        var options: [String: [AbyssGearOption]] = [:]
        options.reserveCapacity(characters.count)
        for character in characters {
            options[character.id] = gearOptions(for: character, weapons: weapons, sets: sets, roster: roster)
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

        let floorNumbers = request.floors ?? cycle.floors.map(\.floor)
        var reports: [AbyssFloorReport] = []
        var diagnostics = AbyssParseDiagnostics()

        for (index, floorNumber) in floorNumbers.enumerated() {
            if Task.isCancelled { break }
            guard let floor = AbyssFloorContext.build(cycle: cycle, floor: floorNumber,
                                                      diagnostics: &diagnostics) else { continue }
            let teams = await bestTeams(in: poolArray, options: options, floor: floor, topN: request.topN)
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

    private func unknownRosterIDs(in roster: AbyssRoster) -> [String] {
        var unknown = roster.characterIDs.filter { library.charactersByID[$0] == nil }
        unknown.formUnion(roster.weaponIDs.filter { library.weaponsByID[$0] == nil })
        unknown.formUnion(roster.artifactSets.filter { library.artifactSetsByID[$0] == nil })
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
                           floor: AbyssFloorContext,
                           topN: Int) async -> [AbyssTeamResult] {
        let combinations = Self.combinationCount(pool.count, choose: 4)
        guard combinations > 0 else { return [] }

        let stripeCount = min(max(ProcessInfo.processInfo.activeProcessorCount, 1),
                              max(Int(combinations / 512), 1))
        if stripeCount <= 1 {
            return Self.trim(scoreRange(0..<combinations, pool: pool, options: options, floor: floor),
                             topN: topN)
        }

        let stride = combinations / Int64(stripeCount) + 1
        let results = await withTaskGroup(of: [AbyssTeamResult].self) { group -> [AbyssTeamResult] in
            for stripe in 0..<stripeCount {
                let lower = Int64(stripe) * stride
                let upper = min(lower + stride, combinations)
                guard lower < upper else { continue }
                group.addTask {
                    Self.trim(scoreRange(lower..<upper, pool: pool, options: options, floor: floor),
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
                            floor: AbyssFloorContext) -> [AbyssTeamResult] {
        var results: [AbyssTeamResult] = []
        var indices = [0, 1, 2, 3]
        guard Self.combination(at: range.lowerBound, n: pool.count, into: &indices) else { return [] }

        var position = range.lowerBound
        while position < range.upperBound {
            if position % 4096 == 0, Task.isCancelled { break }
            let members = indices.map { pool[$0] }
            if let result = scorer.score(members: members, options: options, floor: floor) {
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
    /// pair: the two contribute almost additively, so the pairwise search costs
    /// ~25× more for a result that differs only at the margins.
    func gearOptions(for character: AbyssCharacter,
                     weapons: [AbyssWeapon],
                     sets: [AbyssArtifactSet],
                     roster: AbyssRoster?) -> [AbyssGearOption] {
        guard let profile = library.profilesByCharacterID[character.id] else { return [] }
        let role = defaultRole(for: character)
        let usable = weapons.filter { $0.type == character.weaponType }
        var diagnostics = AbyssParseDiagnostics()

        func build(_ weapon: AbyssWeapon?, _ chosenSets: [AbyssArtifactSet]) -> AbyssStats {
            assembler.stats(character: character, profile: profile, weapon: weapon, sets: chosenSets,
                            role: role, refinement: roster?.refinement(for: weapon?.id ?? "") ?? 1,
                            diagnostics: &diagnostics)
        }

        guard !usable.isEmpty else {
            let stats = build(nil, Array(sets.prefix(1)))
            return [AbyssGearOption(stats: stats, weaponID: nil, setIDs: sets.prefix(1).map(\.id),
                                    role: role, soloScore: scorer.soloScore(for: character, stats: stats))]
        }
        guard let baseline = sets.first else {
            return usable.map { weapon in
                let stats = build(weapon, [])
                return AbyssGearOption(stats: stats, weaponID: weapon.id, setIDs: [], role: role,
                                       soloScore: scorer.soloScore(for: character, stats: stats))
            }
            .sorted { $0.soloScore > $1.soloScore }
            .prefix(Self.weaponAlternatives)
            .map { $0 }
        }

        // Pass 1: rank weapons against one fixed set so they are comparable.
        let rankedWeapons = usable
            .enumerated()
            .map { (offset: $0.offset, weapon: $0.element,
                    score: scorer.soloScore(for: character, stats: build($0.element, [baseline]))) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.offset < rhs.offset
            }
            .prefix(Self.weaponAlternatives)

        guard let topWeapon = rankedWeapons.first?.weapon else { return [] }

        // Pass 2: find the best artifact configuration for that weapon.
        var bestSets = [baseline]
        var bestScore = -Double.infinity
        var scoredSets: [(offset: Int, set: AbyssArtifactSet, score: Double)] = []
        for (offset, set) in sets.enumerated() {
            let score = scorer.soloScore(for: character, stats: build(topWeapon, [set]))
            scoredSets.append((offset, set, score))
            if score > bestScore {
                bestScore = score
                bestSets = [set]
            }
        }
        let topSets = scoredSets
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.offset < rhs.offset
            }
            .prefix(Self.setPairCandidates)
            .map(\.set)
        for first in 0..<topSets.count {
            for second in (first + 1)..<topSets.count {
                let pair = [topSets[first], topSets[second]]
                let score = scorer.soloScore(for: character, stats: build(topWeapon, pair))
                if score > bestScore {
                    bestScore = score
                    bestSets = pair
                }
            }
        }

        return rankedWeapons
            .map { entry -> AbyssGearOption in
                let stats = build(entry.weapon, bestSets)
                return AbyssGearOption(stats: stats, weaponID: entry.weapon.id,
                                       setIDs: bestSets.map(\.id), role: role,
                                       soloScore: scorer.soloScore(for: character, stats: stats))
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
