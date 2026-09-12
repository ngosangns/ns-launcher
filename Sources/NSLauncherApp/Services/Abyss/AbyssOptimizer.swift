// AbyssOptimizer.swift
//
// Picks each character's gear, trims the candidate pool, then walks every
// 4-character combination scoring it against each floor.
//
// Ordering is made explicit everywhere, never left to the sort. Swift's sort is
// not stable, and with near-ties being the normal case — two teams differing by
// 0.01% — an unstable sort would return a different top-5 order on each run and
// make the results look untrustworthy.

import Foundation

struct AbyssOptimizer: Sendable {
    let library: AbyssDataLibrary
    private let tuning: AbyssTuning
    private let assembler: AbyssBuildAssembler
    private let scorer: AbyssScorer

    /// How many weapons to keep per character. More than one because team
    /// members compete for the same weapon and need somewhere to fall back to.
    static let weaponAlternatives = 6
    /// How many times gear selection walks weapon → sets → main stats before
    /// giving up. The second round is usually a no-op; a third has never moved
    /// anything.
    private static let gearRounds = 2
    /// Floor on how many teams reach the artifact pass, so a request for the
    /// single best team still gets a real shortlist to re-rank.
    private static let minimumRefinementCandidates = 20
    /// How many teams per half are carried into the pairing pass.
    ///
    /// Far more than the number of plans shown, and the number matters. Both
    /// halves rank the same characters, so the top of the two lists is built
    /// from the same dozen people: over a 40-character pool the best 400 teams
    /// of each half are drawn from about twelve characters, and eight distinct
    /// ones are hard to find among them — at 400 the search came back with a
    /// single legal plan. A few thousand reaches down to teams built on the
    /// pool's second rank, which is exactly where the second half has to shop
    /// once the first has taken its four. Cheap: these are already-scored teams
    /// being kept, not new ones being enumerated.
    private static let pairingCandidates = 4000
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
                                 roster: roster,
                                 showcase: request.usesMeasuredStats
                                     ? showcaseByID[character.id] : nil,
                                 profile: profiles[character.id]))
                }
            }
            var collected: [String: [AbyssGearOption]] = [:]
            collected.reserveCapacity(characters.count)
            for await (id, entry) in group { collected[id] = entry }
            return collected
        }

        guard let cycle = library.latestCycle else {
            return AbyssOptimizerOutput(reports: [], consideredCharacterIDs: characters.map(\.id),
                                        unknownRosterIDs: unknownIDs)
        }

        // The fights to plan, resolved before the pool is trimmed: the trim is
        // measured against them.
        var diagnostics = AbyssParseDiagnostics()
        let floorNumbers = request.floors ?? Self.defaultFloors(in: cycle)
        var fights: [Fight] = []
        for floorNumber in floorNumbers {
            guard let data = cycle.floors.first(where: { $0.floor == floorNumber }) else { continue }
            // Two teams, not one: every chamber of the floor is fought twice and
            // nobody can be in both teams.
            if request.splitsHalves, AbyssFloorContext.splitsIntoHalves(data),
               let first = AbyssFloorContext.build(
                   cycle: cycle, floor: floorNumber, half: 1,
                   ownElementResistance: tuning.enemyOwnElementResistance,
                   diagnostics: &diagnostics),
               let second = AbyssFloorContext.build(
                   cycle: cycle, floor: floorNumber, half: 2,
                   ownElementResistance: tuning.enemyOwnElementResistance,
                   diagnostics: &diagnostics) {
                fights.append(.halves(first, second))
            } else if let floor = AbyssFloorContext.build(
                cycle: cycle, floor: floorNumber,
                ownElementResistance: tuning.enemyOwnElementResistance,
                diagnostics: &diagnostics) {
                fights.append(.whole(floor))
            }
        }

        let poolArray = trimmedPool(characters, options: options, profiles: profiles,
                                    contexts: fights.flatMap(\.contexts), size: request.poolSize)
        var reports: [AbyssFloorReport] = []
        let charactersByID = Dictionary(poolArray.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // The artifact pass can promote a team past the ones that beat it on
        // neutral gear, so more candidates are carried into it than are shown.
        let candidateCount = request.refinesArtifacts
            ? max(request.topN * 4, Self.minimumRefinementCandidates)
            : request.topN

        // Refinement is a closure over everything it needs, so the whole-floor
        // path and the two-halves path below re-pick artifacts the same way.
        // Nil when the pass is off, which is what makes it a no-op rather than a
        // second code path.
        let advisor = request.refinesArtifacts
            ? AbyssArtifactAdvisor(library: library, assembler: assembler, scorer: scorer)
            : nil
        let refine: @Sendable (AbyssTeamResult, AbyssFloorContext) -> AbyssTeamResult = {
            team, floor in
            guard let advisor else { return team }
            return advisor.refine(team: team,
                                  members: team.memberIDs.compactMap { charactersByID[$0] },
                                  floor: floor, sets: sets, roster: roster,
                                  showcase: showcaseByID,
                                  measuresStats: request.usesMeasuredStats,
                                  profiles: profiles)
        }

        for (index, fight) in fights.enumerated() {
            if Task.isCancelled { break }

            if case .halves(let first, let second) = fight {
                reports.append(await planHalves(first: first, second: second, pool: poolArray,
                                                options: options, profiles: profiles,
                                                topN: request.topN, candidates: candidateCount,
                                                refine: refine))
                progress?(Double(index + 1) / Double(max(fights.count, 1)))
                continue
            }
            guard case .whole(let floor) = fight else { continue }
            var teams = await bestTeams(in: poolArray, options: options, profiles: profiles,
                                        floor: floor, topN: candidateCount)
            if request.refinesArtifacts {
                // One task per candidate team: each sweeps its four members
                // through every artifact configuration and touches nothing the
                // others touch. `trim` re-sorts, so the order the tasks finish
                // in cannot reach the result.
                let refined = await withTaskGroup(of: AbyssTeamResult.self) { group in
                    for team in teams {
                        group.addTask { refine(team, floor) }
                    }
                    var collected: [AbyssTeamResult] = []
                    collected.reserveCapacity(teams.count)
                    for await result in group { collected.append(result) }
                    return collected
                }
                teams = Self.trim(refined, topN: request.topN)
            }
            reports.append(AbyssFloorReport(
                floor: floor.floor,
                monsterLevel: floor.monsterLevel,
                buffs: floor.buffs,
                shieldElements: floor.shieldElements,
                weakElements: floor.weakElements,
                teams: teams))
            progress?(Double(index + 1) / Double(max(fights.count, 1)))
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

    // MARK: - The pool

    /// One fight to plan: a floor taken whole, or its two halves.
    private enum Fight {
        case whole(AbyssFloorContext)
        case halves(AbyssFloorContext, AbyssFloorContext)

        var contexts: [AbyssFloorContext] {
            switch self {
            case .whole(let floor): return [floor]
            case .halves(let first, let second): return [first, second]
            }
        }
    }

    /// Cuts the candidate list down to `size`, best first.
    ///
    /// Somebody has to be cut — C(n,4) grows fast enough that keeping a whole
    /// account is pure cost — but the yardstick matters more than it looks,
    /// because being cut here means never being considered at all. It used to be
    /// a *solo* score: the character alone, on a neutral floor, with nobody
    /// around them. A character alone triggers no reaction, gets no elemental
    /// resonance, receives no party buff and collects no floor bonus. Every
    /// reason a support earns a slot was invisible to the thing deciding whether
    /// the support got to audition. On a real 49-character roster it cut
    /// Bennett.
    ///
    /// So each candidate auditions in a team instead — the same anchors for
    /// everybody, drawn from four different elements so reactions can actually
    /// fire, scored against each fight being planned and keeping their best. It
    /// costs one team scoring per candidate per fight, which is nothing beside
    /// the hundreds of thousands the enumeration then does.
    ///
    /// The anchors are still chosen by solo score, and that bootstrap is still
    /// blind in the same way. It decides four seats, not forty, and every
    /// candidate is then measured against the same four.
    func trimmedPool(_ characters: [AbyssCharacter],
                     options: [String: [AbyssGearOption]],
                     profiles: [String: AbyssDamageProfile],
                     contexts: [AbyssFloorContext],
                     size: Int) -> [AbyssCharacter] {
        func solo(_ character: AbyssCharacter) -> Double {
            options[character.id]?.first?.soloScore ?? 0
        }
        let bySolo = characters
            .enumerated()
            .sorted { lhs, rhs in
                let lhsScore = solo(lhs.element), rhsScore = solo(rhs.element)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        guard characters.count > size, !contexts.isEmpty else { return Array(bySolo.prefix(size)) }

        // Four, so that a candidate who is themselves an anchor still has three
        // to play with.
        var anchors: [AbyssCharacter] = []
        var elements: Set<GenshinElement> = []
        for character in bySolo where elements.insert(character.element).inserted {
            anchors.append(character)
            if anchors.count == 4 { break }
        }
        if anchors.count < 4 { anchors = Array(bySolo.prefix(4)) }
        guard anchors.count == 4 else { return Array(bySolo.prefix(size)) }

        return bySolo
            .enumerated()
            .map { entry -> (offset: Int, character: AbyssCharacter, score: Double) in
                let mates = anchors.filter { $0.id != entry.element.id }.prefix(3)
                let members = [entry.element] + mates
                let best = contexts.compactMap {
                    scorer.score(members: members, options: options, floor: $0,
                                 profiles: profiles)?.score
                }.max()
                return (entry.offset, entry.element, best ?? solo(entry.element))
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.offset < rhs.offset
            }
            .prefix(size)
            .map(\.character)
    }

    // MARK: - Planning a floor as two halves

    /// Ranks plans for a floor fought by two teams.
    ///
    /// Each half is enumerated on its own — different enemies, and on this
    /// rotation a different Ley Line Disorder, so the same four characters score
    /// differently in the two — and the two rankings are then paired under the
    /// rule that nobody plays twice.
    ///
    /// Artifacts are re-picked after pairing rather than before. The pass costs
    /// a full artifact sweep per team, and pairing first means paying it for the
    /// teams that actually appear in a plan instead of for the top of two
    /// rankings that a disjointness constraint is about to rearrange anyway.
    private func planHalves(first: AbyssFloorContext,
                            second: AbyssFloorContext,
                            pool: [AbyssCharacter],
                            options: [String: [AbyssGearOption]],
                            profiles: [String: AbyssDamageProfile],
                            topN: Int,
                            candidates: Int,
                            refine: @escaping @Sendable (AbyssTeamResult, AbyssFloorContext)
                                -> AbyssTeamResult) async -> AbyssFloorReport {
        let firstTeams = await bestTeams(in: pool, options: options, profiles: profiles,
                                         floor: first, topN: Self.pairingCandidates)
        let secondTeams = await bestTeams(in: pool, options: options, profiles: profiles,
                                          floor: second, topN: Self.pairingCandidates)

        var plans = Self.pair(first: firstTeams, second: secondTeams, count: candidates)

        // One task per team rather than per plan: a plan's two halves are
        // independent sweeps, and every team in the list is distinct, so there
        // is nothing to share and nothing to wait for.
        let refined = await withTaskGroup(of: (Int, Int, AbyssTeamResult).self) { group in
            for (index, plan) in plans.enumerated() {
                group.addTask { (index, 1, refine(plan.firstHalf, first)) }
                group.addTask { (index, 2, refine(plan.secondHalf, second)) }
            }
            var collected: [Int: (first: AbyssTeamResult?, second: AbyssTeamResult?)] = [:]
            for await (index, half, team) in group {
                var entry = collected[index] ?? (nil, nil)
                if half == 1 { entry.first = team } else { entry.second = team }
                collected[index] = entry
            }
            return collected
        }

        plans = plans.enumerated().map { index, plan in
            guard let entry = refined[index], let one = entry.first, let two = entry.second
            else { return plan }
            return AbyssFloorPlan(firstHalf: one, secondHalf: two,
                                  score: AbyssFloorPlan.combine(one.score, two.score))
        }
        // Re-picked artifacts move scores, and a plan that was fourth on the
        // neutral pick can win on its own gear. Ties break on the plan id so the
        // order does not depend on which sweep finished first.
        plans.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.id < rhs.id
        }

        // Buffs both halves share belong to the floor; only what sets a half
        // apart is worth repeating next to its teams.
        let shared = first.buffs.filter { second.buffs.contains($0) }
        func half(_ index: Int, _ context: AbyssFloorContext) -> AbyssHalfReport {
            AbyssHalfReport(half: index,
                            buffs: context.buffs.filter { !shared.contains($0) },
                            shieldElements: context.shieldElements,
                            weakElements: context.weakElements)
        }

        return AbyssFloorReport(
            floor: first.floor,
            monsterLevel: first.monsterLevel,
            buffs: shared,
            shieldElements: Set(first.shieldElements + second.shieldElements)
                .sorted { $0.rawValue < $1.rawValue },
            weakElements: Set(first.weakElements + second.weakElements)
                .sorted { $0.rawValue < $1.rawValue },
            teams: [],
            halves: [half(1, first), half(2, second)],
            plans: Array(plans.prefix(topN)))
    }

    /// Pairs two halves' rankings into plans that share no character.
    ///
    /// Rank 1 is the best such pair in the two lists, which is not in general
    /// each half's own best team: the two halves usually want the same four
    /// people, and which half gives way — and by how much — is the whole
    /// question. It is found by branch and bound rather than by trying every
    /// pair: both lists descend by score and `combine` rises with both of its
    /// arguments, so once the best conceivable partner for a team cannot beat
    /// the plan already in hand, neither can anything below it.
    ///
    /// Later ranks are the best pair among the teams no higher-ranked plan has
    /// used. Re-using a team would fill the list with five variations on one
    /// idea; barring it makes the five plans five genuinely different answers,
    /// at the cost of rank 2 not being the second-best pair in the strict sense.
    ///
    /// "Sharing nothing" covers weapons as well as characters, and it has to.
    /// Both halves are fought in one run, so a weapon on someone in the first
    /// team cannot also be on someone in the second — the first version of this
    /// checked only characters and every one of the five plans it produced put
    /// the same Wolf's Gravestone in both halves. Nothing here re-arms a team to
    /// dodge a clash: the alternative was re-picking the second half's weapons
    /// after the pair was chosen, which would rank pairs on scores that then
    /// change underneath the ranking.
    static func pair(first: [AbyssTeamResult],
                     second: [AbyssTeamResult],
                     count: Int) -> [AbyssFloorPlan] {
        // "Do these two teams share anything" is asked millions of times, so
        // each id — character or weapon — becomes a bit in a word and the
        // question becomes one AND. A pool too large to fit in a word falls back
        // to comparing sets, which is the same answer more slowly; no roster
        // comes close.
        // Weapon ids are namespaced: the two id spaces come from different
        // files and a name that appeared in both would otherwise make a legal
        // pair look illegal.
        func held(_ team: AbyssTeamResult) -> Set<String> {
            Set(team.memberIDs)
                .union(team.memberIDs.compactMap { team.assignment[$0]?.weaponID }.map { "w:" + $0 })
        }
        let held = first.map(held) + second.map(held)
        let ids = Array(held.reduce(into: Set<String>()) { $0.formUnion($1) })
        let bits = ids.count <= UInt64.bitWidth
            ? Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, UInt64(1) << UInt64($0)) })
            : [:]
        let firstHeld = Array(held[..<first.count])
        let secondHeld = Array(held[first.count...])
        func mask(_ ids: Set<String>) -> UInt64 {
            bits.isEmpty ? 0 : ids.reduce(0) { $0 | (bits[$1] ?? 0) }
        }
        let firstMasks = firstHeld.map(mask)
        let secondMasks = secondHeld.map(mask)
        func shareNothing(_ candidate: Int, _ partner: Int) -> Bool {
            bits.isEmpty
                ? firstHeld[candidate].isDisjoint(with: secondHeld[partner])
                : firstMasks[candidate] & secondMasks[partner] == 0
        }

        var usedFirst = Set<Int>()
        var usedSecond = Set<Int>()
        var plans: [AbyssFloorPlan] = []

        while plans.count < count {
            // The best score still available in the second half, which bounds
            // what any first-half team can reach.
            guard let ceiling = second.indices.first(where: { !usedSecond.contains($0) })
                .map({ second[$0].score }) else { break }

            var best: (first: Int, second: Int, score: Double)?
            for candidate in first.indices where !usedFirst.contains(candidate) {
                if let best, AbyssFloorPlan.combine(first[candidate].score, ceiling) <= best.score {
                    break
                }
                for partner in second.indices where !usedSecond.contains(partner) {
                    let score = AbyssFloorPlan.combine(first[candidate].score, second[partner].score)
                    if let best, score <= best.score { break }
                    guard shareNothing(candidate, partner) else { continue }
                    best = (candidate, partner, score)
                    break
                }
            }

            // Nothing left that can field two teams at once — a roster of seven
            // has no answer here, and saying so beats inventing one.
            guard let best else { break }
            usedFirst.insert(best.first)
            usedSecond.insert(best.second)
            plans.append(AbyssFloorPlan(firstHalf: first[best.first],
                                        secondHalf: second[best.second],
                                        score: best.score))
        }
        return plans
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

        let usable = weapons.filter { $0.type == character.weaponType }
        var diagnostics = AbyssParseDiagnostics()

        // The half of the sheet that does not depend on which sets are worn.
        // Split out because the artifact pass below dresses one weapon in over
        // a thousand configurations that all share it, and this is the
        // expensive half — the weapon passive is matched with regexes.
        func base(_ weapon: AbyssWeapon?) -> AbyssStats {
            assembler.statsWithoutArtifactMainStats(
                character: character, profile: profile, weapon: weapon, role: role,
                refinement: roster?.refinement(for: weapon?.id ?? "") ?? 1)
        }

        let candidates = assembler.mainStatCandidates(role: role, element: character.element)
        let plans = candidates.sands.flatMap { sands in
            candidates.goblet.flatMap { goblet in
                candidates.circlet.map {
                    AbyssMainStatPlan(sands: sands, goblet: goblet, circlet: $0)
                }
            }
        }

        func wearing(_ chosenSets: [AbyssArtifactSet], over sheet: AbyssStats) -> AbyssStats {
            var stats = sheet
            assembler.applySets(chosenSets, character: character, to: &stats, diagnostics: &diagnostics)
            return stats
        }

        /// Best plan across a set of candidate sheets, measured against one
        /// fixed artifact set so the three slots and the weapon are the only
        /// things moving. Ties keep the earlier candidate, so the pick is the
        /// same on every run.
        ///
        /// Several sheets rather than one because the three slots and the weapon
        /// are not separable: a CRIT Rate circlet wins on a weapon that has none
        /// and loses on one that does, and picking the circlet against the wrong
        /// weapon leaves the pair worse than either choice made on its own. The
        /// shortlist is small, so looking at all of them costs little.
        func bestPlan(over candidates: [AbyssStats], wearing chosenSets: [AbyssArtifactSet])
            -> AbyssMainStatPlan {
            var best = (plan: plans[0], score: -Double.infinity)
            for sheet in candidates {
                for plan in plans {
                    let score = scorer.soloScore(
                        context: solo,
                        stats: wearing(chosenSets, over: assembler.applying(plan, to: sheet)))
                    if score > best.score { best = (plan, score) }
                }
            }
            return best.plan
        }

        func build(_ weapon: AbyssWeapon?,
                   _ chosenSets: [AbyssArtifactSet],
                   _ plan: AbyssMainStatPlan) -> AbyssStats {
            wearing(chosenSets, over: assembler.applying(plan, to: base(weapon)))
        }

        // An imported character needs no gear search: the app knows what they
        // are holding and what they rolled. One option, their own, and the
        // artifact pass then says what to change.
        //
        // The main stats are the exception. Enka reports the character screen's
        // totals, not which stat sits in which slot, so there is nothing to read
        // back — the plan attached here is what the search *recommends* for
        // them, which is what the tab has always shown next to an imported
        // build and the only useful thing it can show.
        if let showcase {
            let weapon = showcase.weaponID.flatMap { library.weaponsByID[$0] }
            let wornIDs = showcase.activeSetIDs
            let worn = wornIDs.compactMap { library.artifactSetsByID[$0] }
            var stats = assembler.showcaseStats(build: showcase, character: character,
                                                weapon: weapon, wornSets: worn)
            assembler.applySets(worn, character: character, to: &stats, diagnostics: &diagnostics)
            return [AbyssGearOption(stats: stats, weaponID: showcase.weaponID, setIDs: wornIDs,
                                    mainStats: bestPlan(over: [base(weapon)],
                                                        wearing: Array(sets.prefix(1))),
                                    role: role,
                                    soloScore: scorer.soloScore(context: solo, stats: stats),
                                    statSource: .measured)]
        }

        guard !usable.isEmpty else {
            let chosen = Array(sets.prefix(1))
            let plan = bestPlan(over: [base(nil)], wearing: chosen)
            let stats = build(nil, chosen, plan)
            return [AbyssGearOption(stats: stats, weaponID: nil, setIDs: chosen.map(\.id),
                                    mainStats: plan, role: role,
                                    soloScore: scorer.soloScore(context: solo, stats: stats))]
        }
        guard let baseline = sets.first else {
            return usable.map { weapon in
                let sheet = base(weapon)
                let plan = bestPlan(over: [sheet], wearing: [])
                let stats = assembler.applying(plan, to: sheet)
                return AbyssGearOption(stats: stats, weaponID: weapon.id, setIDs: [],
                                       mainStats: plan, role: role,
                                       soloScore: scorer.soloScore(context: solo, stats: stats))
            }
            .sorted { $0.soloScore > $1.soloScore }
            .prefix(Self.weaponAlternatives)
            .map { $0 }
        }

        let bases = usable.map { base($0) }

        // Weapon, sets and main stats are picked one at a time and then walked
        // round again, because each is only best given the other two.
        //
        // The round has to start somewhere, and the start must not be a
        // disguised rule about which main stats are good. So it is not one: the
        // weapons are ranked first with the three slots *empty*, which is a
        // comparison the slots cannot bias because they are not there, and the
        // three are then chosen against whichever weapon that put on top. The
        // loop re-picks them against the weapon and sets that actually won and
        // stops when a round changes nothing.
        let opening = Self.rankWeapons(usable, sheets: bases, baseline: baseline,
                                       solo: solo, scorer: scorer, wearing: wearing)
        guard !opening.isEmpty else { return [] }

        var plan = bestPlan(over: opening.map { bases[$0.offset] }, wearing: [baseline])
        // The best complete build any round produced, not the last round's. A
        // round can walk downhill — the three slots are re-picked against one
        // weapon and then the weapon ranking moves under them — and there is no
        // reason to keep the worse answer once it has been paid for.
        var best: (plan: AbyssMainStatPlan, sets: [AbyssArtifactSet], score: Double)?

        for _ in 0..<Self.gearRounds {
            let sheets = bases.map { assembler.applying(plan, to: $0) }
            let rankedWeapons = Self.rankWeapons(usable, sheets: sheets, baseline: baseline,
                                                 solo: solo, scorer: scorer, wearing: wearing)
            guard let top = rankedWeapons.first else { break }

            // Every artifact configuration for that weapon — each set worn as a
            // 4-piece, and every pair of sets worn as 2+2. With 46 five-star
            // sets that is 1081 configurations; all of them are built and
            // scored, so no set is ruled out by a shortlist that was only ever a
            // guess at which ones could win.
            //
            // Strict `>` keeps the first maximum, so ties resolve to the earlier
            // set in file order and the pick is the same on every run.
            let topSheet = sheets[top.offset]
            var bestSets = [baseline]
            var bestScore = -Double.infinity
            for set in sets {
                let score = scorer.soloScore(context: solo, stats: wearing([set], over: topSheet))
                if score > bestScore {
                    bestScore = score
                    bestSets = [set]
                }
            }
            for first in 0..<sets.count {
                for second in (first + 1)..<sets.count {
                    let pair = [sets[first], sets[second]]
                    let score = scorer.soloScore(context: solo, stats: wearing(pair, over: topSheet))
                    if score > bestScore {
                        bestScore = score
                        bestSets = pair
                    }
                }
            }

            if best == nil || bestScore > best!.score {
                best = (plan, bestSets, bestScore)
            }

            // Now that the sets are real, ask the three slots again — and ask
            // across the whole weapon shortlist, not just the winner. The sets
            // are what makes this worth repeating: a set that hands out CRIT
            // Rate turns a CRIT Rate circlet into a wasted slot, and the weapon
            // that then wants the build is not the one that won under the
            // opening guess. Unchanged means the round found a fixed point and
            // there is nothing left to walk.
            let revised = bestPlan(over: rankedWeapons.map { bases[$0.offset] },
                                   wearing: bestSets)
            if revised == plan { break }
            plan = revised
        }

        guard let best else { return [] }
        let bestSets = best.sets
        let sheets = bases.map { assembler.applying(best.plan, to: $0) }
        let rankedWeapons = Self.rankWeapons(usable, sheets: sheets, baseline: baseline,
                                             solo: solo, scorer: scorer, wearing: wearing)

        return rankedWeapons
            .map { entry -> AbyssGearOption in
                let stats = wearing(bestSets, over: sheets[entry.offset])
                return AbyssGearOption(stats: stats, weaponID: entry.weapon.id,
                                       setIDs: bestSets.map(\.id), mainStats: best.plan, role: role,
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

    /// Ranks weapons against one fixed set so they are comparable, best first.
    ///
    /// The set is a constant here, not a recommendation: every weapon is dressed
    /// in the same one, so it cancels out of the comparison. Ties keep file
    /// order, so the shortlist is the same on every run.
    private static func rankWeapons(_ usable: [AbyssWeapon],
                                    sheets: [AbyssStats],
                                    baseline: AbyssArtifactSet,
                                    solo: AbyssScorer.DamageContext,
                                    scorer: AbyssScorer,
                                    wearing: ([AbyssArtifactSet], AbyssStats) -> AbyssStats)
        -> ArraySlice<(offset: Int, weapon: AbyssWeapon, score: Double)> {
        usable
            .enumerated()
            .map { (offset: $0.offset, weapon: $0.element,
                    score: scorer.soloScore(context: solo,
                                            stats: wearing([baseline], sheets[$0.offset]))) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.offset < rhs.offset
            }
            .prefix(weaponAlternatives)
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
