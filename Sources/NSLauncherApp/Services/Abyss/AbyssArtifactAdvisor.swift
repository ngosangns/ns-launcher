// AbyssArtifactAdvisor.swift
//
// Second pass over the teams that survived the search: re-picks each member's
// artifacts for the floor they will actually fight and the three characters they
// will actually stand next to.
//
// The first pass cannot do this. It has to compare every character against every
// other before it knows which four end up together, so it ranks gear on neutral
// ground — level 95 enemies, baseline resistance, no team, no floor buff. That
// is the right yardstick for deciding *who plays*; it is the wrong one for
// deciding *what they wear*, because a set earns its slot from what the enemies
// resist and what the other three members enable. Running this over every team
// during the search would be unaffordable; running it over the handful that made
// the cut costs a few milliseconds.
//
// This pass has no counterpart in the Python reference, which is why the golden
// fixture runs with it switched off — see `AbyssOptimizerRequest.refinesArtifacts`.

import Foundation

struct AbyssArtifactAdvisor: Sendable {
    let library: AbyssDataLibrary
    let assembler: AbyssBuildAssembler
    let scorer: AbyssScorer

    /// Members buff each other, so moving one character's sets can change what
    /// the next one wants. A second sweep catches that; a third has never moved
    /// anything, and the loop stops early when a sweep changes nothing.
    private static let maxSweeps = 2

    // MARK: - Entry point

    /// Returns the team with its artifacts re-picked, its score recomputed, and
    /// per-character advice attached. Never returns a worse team than it was
    /// given: every swap has to beat the incumbent outright.
    func refine(team: AbyssTeamResult,
                members: [AbyssCharacter],
                floor: AbyssFloorContext,
                sets: [AbyssArtifactSet],
                roster: AbyssRoster?,
                showcase: [String: AbyssShowcaseBuild] = [:],
                profiles: [String: AbyssDamageProfile] = [:]) -> AbyssTeamResult {
        guard sets.count > 1, !members.isEmpty else { return team }

        let context = AbyssTeamContext.build(members: members, library: library)
        // Fixed for the whole sweep: the members, the floor and the team never
        // change while the artifacts move, so everything derived from them is
        // built once here instead of once per candidate.
        let damage = scorer.teamDamageContext(members: members, floor: floor, team: context,
                                              profiles: profiles)
        // Every set in the data, not just the candidates: this table only ever
        // resolves ids that are *already* chosen — the incumbent build, and what
        // a showcase says the player is wearing — and those can name a set that
        // is not 5★ and so is not among the candidates at all.
        let setsByID = library.artifactSetsByID

        // Per character, the half of the stat sheet that does not depend on the
        // sets. Computed once here rather than for each of the ~1000 candidates
        // the sweep below dresses them in.
        //
        // For an imported character this is their *real* gear with the set
        // effects lifted out, so a candidate set is compared against what they
        // actually rolled rather than against a standardised build.
        var bases: [String: AbyssStats] = [:]
        // Named apart from the `profiles` parameter on purpose: this one is the
        // resolved per-member map the rest of the pass works from, and letting
        // the two share a name would shadow the argument and silently drop every
        // constellation the caller resolved.
        var memberProfiles: [String: AbyssDamageProfile] = [:]
        for member in members {
            guard let profile = profiles[member.id] ?? library.profilesByCharacterID[member.id],
                  let option = team.assignment[member.id] else { continue }
            memberProfiles[member.id] = profile
            let weapon = option.weaponID.flatMap { library.weaponsByID[$0] }

            if let build = showcase[member.id] {
                bases[member.id] = assembler.showcaseStats(
                    build: build, character: member, weapon: weapon,
                    wornSets: build.activeSetIDs.compactMap { library.artifactSetsByID[$0] })
            } else {
                bases[member.id] = assembler.statsWithoutSets(
                    character: member,
                    profile: profile,
                    weapon: weapon,
                    role: option.role,
                    refinement: option.weaponID.map { roster?.refinement(for: $0) ?? 1 } ?? 1)
            }
        }
        guard bases.count == members.count else { return team }

        // Biggest contributor first: their sets move the team score most, and
        // whoever follows then optimises against a party that is already close
        // to its final shape.
        let order = members.enumerated()
            .sorted { lhs, rhs in
                let lhsDamage = team.perCharacterDamage[lhs.element.id] ?? 0
                let rhsDamage = team.perCharacterDamage[rhs.element.id] ?? 0
                if lhsDamage != rhsDamage { return lhsDamage > rhsDamage }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        var assignment = team.assignment
        var runnersUp: [String: (setIDs: [String], score: Double, best: Double)] = [:]
        // Index-aligned with `members`, so the hot scoring path can work on
        // arrays instead of rebuilding a dictionary for every candidate.
        var sheets = members.map { assignment[$0.id]?.stats ?? AbyssStats() }
        var worn = members.map { assignment[$0.id]?.setIDs ?? [] }
        var splits = [AbyssScorer.DamageSplit](repeating: .zero, count: members.count)

        for _ in 0..<Self.maxSweeps {
            var changed = false
            for member in order {
                guard let slot = members.firstIndex(where: { $0.id == member.id }),
                      let ranked = rankedConfigurations(for: member, at: slot,
                                                        assignment: assignment, sheets: &sheets,
                                                        worn: &worn, splits: &splits,
                                                        damage: damage, sets: sets,
                                                        setsByID: setsByID, bases: bases),
                      let best = ranked.first else { continue }

                runnersUp[member.id] = (
                    setIDs: ranked.count > 1 ? ranked[1].setIDs : best.setIDs,
                    score: ranked.count > 1 ? ranked[1].score : best.score,
                    best: best.score)

                let current = assignment[member.id]?.setIDs ?? []
                if best.setIDs != current {
                    assignment[member.id] = assignment[member.id]?.replacingSets(best.setIDs, stats: best.stats)
                    changed = true
                }
                sheets[slot] = best.stats
                worn[slot] = best.setIDs
            }
            if !changed { break }
        }

        guard let refined = scorer.evaluate(members: members, assignment: assignment,
                                            floor: floor, team: context, profiles: memberProfiles),
              refined.score > team.score else {
            // Nothing beat the neutral pick. Still attach advice, so the tab can
            // show the main stats and say the gain is zero rather than showing
            // nothing at all.
            return attachAdvice(to: team, members: members, floor: floor, context: context,
                                bases: bases, profiles: memberProfiles, setsByID: setsByID,
                                runnersUp: runnersUp, baseline: team, showcase: showcase)
        }

        var result = refined
        result.baseScore = team.baseScore > 0 ? team.baseScore : team.score
        return attachAdvice(to: result, members: members, floor: floor, context: context,
                            bases: bases, profiles: memberProfiles, setsByID: setsByID,
                            runnersUp: runnersUp, baseline: team, showcase: showcase)
    }

    // MARK: - Candidate configurations

    private struct Configuration {
        let setIDs: [String]
        let stats: AbyssStats
        let score: Double
    }

    /// Every configuration for one member, best team score first.
    ///
    /// Exhaustive: each set worn as a 4-piece and each pair worn as 2+2, every
    /// one of them scored on what the *whole team* does with it. There used to
    /// be a cheap first stage that shortlisted eight sets by this character's
    /// own damage, and that filter was wrong in exactly the case this pass
    /// exists for — a set can earn its slot from what it hands the other three
    /// members, which is invisible to a solo score. With one floor to plan and
    /// 46 five-star sets, scoring all 1081 outright costs a few milliseconds.
    private func rankedConfigurations(for member: AbyssCharacter,
                                      at slot: Int,
                                      assignment: [String: AbyssGearOption],
                                      sheets: inout [AbyssStats],
                                      worn: inout [[String]],
                                      splits: inout [AbyssScorer.DamageSplit],
                                      damage: AbyssScorer.TeamDamageContext,
                                      sets: [AbyssArtifactSet],
                                      setsByID: [String: AbyssArtifactSet],
                                      bases: [String: AbyssStats]) -> [Configuration]? {
        guard let base = bases[member.id], let option = assignment[member.id] else { return nil }

        let incumbentSheet = sheets[slot]
        let incumbentWorn = worn[slot]

        // Every 4-piece and every 2+2 pair, plus whatever the character is
        // already wearing — the incumbent is appended even when it duplicates
        // an enumerated candidate, because a showcase can have them in a set
        // that is not 5★ and so is not in `sets` at all. A duplicate costs one
        // extra evaluation and loses the tie-break to the enumerated copy.
        var candidates: [[AbyssArtifactSet]] = sets.map { [$0] }
        candidates.reserveCapacity(sets.count * (sets.count + 1) / 2 + 1)
        for first in 0..<sets.count {
            for second in (first + 1)..<sets.count {
                candidates.append([sets[first], sets[second]])
            }
        }
        let incumbent = option.setIDs.compactMap { setsByID[$0] }
        if !incumbent.isEmpty { candidates.append(incumbent) }

        // Scored on raw team damage, not the final team score: the team-level
        // multipliers depend only on who is in the team and which floor it is,
        // so they are the same constant for every candidate here and cannot
        // change which one wins.
        var scored: [(offset: Int, configuration: Configuration)] = []
        scored.reserveCapacity(candidates.count)
        for (offset, candidate) in candidates.enumerated() {
            let stats = statsWearing(candidate, base: base, member: member)
            sheets[slot] = stats
            worn[slot] = candidate.map(\.id)
            let total = scorer.teamDamage(context: damage, stats: sheets, setIDs: worn,
                                          splits: &splits).total
            scored.append((offset, Configuration(setIDs: worn[slot], stats: stats, score: total)))
        }
        sheets[slot] = incumbentSheet
        worn[slot] = incumbentWorn

        return scored
            .sorted { lhs, rhs in
                if lhs.configuration.score != rhs.configuration.score {
                    return lhs.configuration.score > rhs.configuration.score
                }
                return lhs.offset < rhs.offset
            }
            .map(\.configuration)
    }

    private func statsWearing(_ sets: [AbyssArtifactSet],
                              base: AbyssStats,
                              member: AbyssCharacter) -> AbyssStats {
        var stats = base
        var diagnostics = AbyssParseDiagnostics()
        assembler.applySets(sets, character: member, to: &stats, diagnostics: &diagnostics)
        return stats
    }

    // MARK: - Advice

    /// Fills in what to show for each member: the sets now chosen, the main
    /// stats and substats the model assumed, what the change was worth, and the
    /// runner-up for anyone who has not farmed the winner yet.
    private func attachAdvice(to team: AbyssTeamResult,
                              members: [AbyssCharacter],
                              floor: AbyssFloorContext,
                              context: AbyssTeamContext,
                              bases: [String: AbyssStats],
                              profiles: [String: AbyssDamageProfile],
                              setsByID: [String: AbyssArtifactSet],
                              runnersUp: [String: (setIDs: [String], score: Double, best: Double)],
                              baseline: AbyssTeamResult,
                              showcase: [String: AbyssShowcaseBuild]) -> AbyssTeamResult {
        var advice: [String: AbyssArtifactAdvice] = [:]
        advice.reserveCapacity(members.count)

        for member in members {
            guard let option = team.assignment[member.id],
                  let profile = profiles[member.id],
                  let base = bases[member.id] else { continue }

            let plan = assembler.mainStatPlan(role: option.role, basis: profile.basis,
                                              element: member.element)

            // What this character's change alone was worth: put their neutral
            // sets back, leave everyone else refined, and compare.
            var gain = 0.0
            let neutralSetIDs = baseline.assignment[member.id]?.setIDs ?? []
            if neutralSetIDs != option.setIDs {
                let neutralSets = neutralSetIDs.compactMap { setsByID[$0] }
                var reverted = team.assignment
                reverted[member.id] = option.replacingSets(
                    neutralSetIDs, stats: statsWearing(neutralSets, base: base, member: member))
                if let before = scorer.evaluate(members: members, assignment: reverted,
                                                floor: floor, team: context,
                                                profiles: profiles)?.score, before > 0 {
                    gain = team.score / before - 1
                }
            }

            let runnerUp = runnersUp[member.id]
            let alternativeIDs = runnerUp?.setIDs ?? option.setIDs
            let alternativeGap: Double
            if let runnerUp, runnerUp.best > 0, alternativeIDs != option.setIDs {
                alternativeGap = max((runnerUp.best - runnerUp.score) / runnerUp.best, 0)
            } else {
                alternativeGap = 0
            }

            // For an imported character, say what changing off the set they are
            // actually wearing is worth — the question they came with.
            var currentSetIDs: [String] = []
            var upgrade = 0.0
            if let build = showcase[member.id] {
                let equipped = build.activeSetIDs
                if equipped != option.setIDs, !equipped.isEmpty {
                    currentSetIDs = equipped
                    let wornSets = equipped.compactMap { setsByID[$0] }
                    var asEquipped = team.assignment
                    asEquipped[member.id] = option.replacingSets(
                        equipped, stats: statsWearing(wornSets, base: base, member: member))
                    if let before = scorer.evaluate(members: members, assignment: asEquipped,
                                                    floor: floor, team: context,
                                                    profiles: profiles)?.score, before > 0 {
                        upgrade = max(team.score / before - 1, 0)
                    }
                }
            }

            advice[member.id] = AbyssArtifactAdvice(
                setIDs: option.setIDs,
                sands: plan.sands,
                goblet: plan.goblet,
                circlet: plan.circlet,
                substatPriority: assembler.substatPlan(role: option.role, basis: profile.basis).map(\.key),
                gainOverNeutralPick: max(gain, 0),
                alternativeSetIDs: alternativeIDs == option.setIDs ? [] : alternativeIDs,
                alternativeGap: alternativeGap,
                currentSetIDs: currentSetIDs,
                upgradeOverCurrent: upgrade)
        }

        var result = team
        result.artifactAdvice = advice
        if result.baseScore <= 0 { result.baseScore = team.score }
        return result
    }
}
