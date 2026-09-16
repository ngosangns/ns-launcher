import XCTest
@testable import NSLauncherApp

/// The artifact pass is the one part of the engine with no reference
/// implementation behind it, so the golden fixture says nothing about it. These
/// are the properties it has to hold on its own.
final class AbyssArtifactAdvisorTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func makeOptimizer() throws -> AbyssOptimizer {
        try XCTUnwrap(AbyssOptimizer(library: library))
    }

    /// Every recommendation has to be actionable: a set the player can look up,
    /// and a full slot-by-slot build rather than just a set name.
    func testAdviceIsCompleteAndResolvable() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                               splitsHalves: false))

        let teams = try XCTUnwrap(output.reports.first?.wholeFloorTeams)
        XCTAssertFalse(teams.isEmpty)

        for team in teams {
            XCTAssertEqual(team.artifactAdvice.count, team.memberIDs.count,
                           "team \(team.id) is missing advice for some members")
            for memberID in team.memberIDs {
                let advice = try XCTUnwrap(team.artifactAdvice[memberID])
                XCTAssertTrue((1...2).contains(advice.setIDs.count),
                              "\(memberID): a build is one 4-piece set or two 2-piece sets")
                for setID in advice.setIDs + advice.alternativeSetIDs {
                    XCTAssertNotNil(library.artifactSetsByID[setID],
                                    "\(memberID): recommended set \(setID) is not in the data")
                }
                XCTAssertFalse(advice.substatPriority.isEmpty, "\(memberID): no substat priority")
                XCTAssertEqual(advice.setIDs, team.assignment[memberID]?.setIDs,
                               "\(memberID): advice disagrees with the sets that were scored")
            }
        }
    }

    /// The marginal gain is computed only for keys the static priority table
    /// already names, and re-evaluating the team with one roll added should
    /// never produce a number that reads as more than the roll itself, or as
    /// a meaningful loss — the roll can be added and ignored, never subtracted.
    func testSubstatMarginalGainMatchesThePriorityKeysAndIsSane() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 3,
                                                               splitsHalves: false))
        let teams = try XCTUnwrap(output.reports.first?.wholeFloorTeams)
        XCTAssertFalse(teams.isEmpty)

        var sawPositiveGain = false
        for team in teams {
            for memberID in team.memberIDs {
                let advice = try XCTUnwrap(team.artifactAdvice[memberID])
                XCTAssertTrue(Set(advice.substatMarginalGain.keys).isSubset(of: Set(advice.substatPriority)),
                              "\(memberID): marginal gain has a key outside substatPriority")
                for (key, gain) in advice.substatMarginalGain {
                    XCTAssertTrue(gain.isFinite, "\(memberID): \(key) marginal gain is not finite")
                    XCTAssertLessThan(gain, 1, "\(memberID): \(key) marginal gain from one roll looks too large")
                    XCTAssertGreaterThan(gain, -0.01, "\(memberID): \(key) marginal gain is meaningfully negative")
                    if gain > 0.0001 { sawPositiveGain = true }
                }
            }
        }
        XCTAssertTrue(sawPositiveGain, "no member showed any positive substat marginal gain across the search")
    }

    /// What each slot is allowed to hold.
    ///
    /// Two of the lists are cut down and both cuts have to stay honest. The
    /// goblet offers one element because the other six contribute exactly zero
    /// to a character who deals their own. The healer's circlet and the
    /// support's sands are *pinned*, and that is not the search giving up: the
    /// score is damage and has no term for a heal landing or a burst being up,
    /// so a free search would strip Healing Bonus and Energy Recharge from every
    /// support and call it an improvement.
    func testWhatEachSlotIsAllowedToHold() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs)

        for character in library.characters.prefix(30) {
            let damage = assembler.mainStatCandidates(role: .mainDPS, element: character.element)
            XCTAssertTrue(damage.goblet.contains(.elementalDMG(character.element)),
                          "\(character.id): the character's own element is not a goblet option")
            for other in GenshinElement.allCases where other != character.element {
                XCTAssertFalse(damage.goblet.contains(.elementalDMG(other)),
                               "\(character.id): a \(other.rawValue) goblet is worth nothing here")
            }
            XCTAssertTrue(damage.circlet.contains(.critDMG))
            XCTAssertTrue(damage.circlet.contains(.elementalMastery),
                          "EM has to be reachable, or a reaction carry can never be built")
            XCTAssertGreaterThan(damage.sands.count, 1, "the sands should be a choice")

            let healer = assembler.mainStatCandidates(role: .healer, element: character.element)
            XCTAssertEqual(healer.circlet, [.healingBonus],
                           "the model cannot value healing, so it must not trade it away")
            // A shielder's sands used to be pinned to Energy Recharge because
            // the model could not value energy; since Phase 3 it can.
            let shield = assembler.mainStatCandidates(role: .shield, element: character.element)
            XCTAssertTrue(shield.sands.contains(.energyRecharge) && shield.sands.count > 1,
                          "a shielder's sands should be searched, Energy Recharge among the options")
        }
    }

    /// The line the tab prints and the sheet that produced the number next to it
    /// have to be the same build. They used to be by construction, because both
    /// came from one rule; now the plan is searched, so it is carried on the
    /// option and this is what says the two did not come apart.
    func testTheAdvisedMainStatsAreTheOnesThatWereScored() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 3,
                                                               splitsHalves: false))
        let team = try XCTUnwrap(output.reports.first?.wholeFloorTeams?.first)
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                            talentBuffs: library.talentBuffsByCharacterID,
                                            weaponBuffs: library.weaponBuffsByID, setBuffs: library.setBuffsByID)

        for memberID in team.memberIDs {
            let option = try XCTUnwrap(team.assignment[memberID])
            let advice = try XCTUnwrap(team.artifactAdvice[memberID],
                                       "\(memberID): no advice attached")
            XCTAssertEqual(advice.sands, option.mainStats.sands, "\(memberID): sands differ")
            XCTAssertEqual(advice.goblet, option.mainStats.goblet, "\(memberID): goblet differs")
            XCTAssertEqual(advice.circlet, option.mainStats.circlet, "\(memberID): circlet differs")

            // And the sheet really carries them: rebuilding it from the advised
            // plan reproduces the stats the score was computed from.
            let character = try XCTUnwrap(library.charactersByID[memberID])
            let profile = try XCTUnwrap(library.profilesByCharacterID[memberID])
            var rebuilt = assembler.statsWithoutSets(
                character: character, profile: profile,
                weapon: option.weaponID.flatMap { library.weaponsByID[$0] },
                role: option.role,
                refinement: option.weaponID.map { roster.refinement(for: $0) } ?? 1,
                mainStats: option.mainStats)
            var diagnostics = AbyssParseDiagnostics()
            assembler.applySets(option.setIDs.compactMap { library.artifactSetsByID[$0] },
                                character: character, to: &rebuilt, diagnostics: &diagnostics)
            XCTAssertEqual(rebuilt.critDMG, option.stats.critDMG, accuracy: 1e-9,
                           "\(memberID): the scored sheet is not the advised build")
            XCTAssertEqual(rebuilt.elementalMastery, option.stats.elementalMastery, accuracy: 1e-9,
                           "\(memberID): the scored sheet is not the advised build")
        }
    }

    /// A DEF-scaling character must not be told to roll ATK%.
    func testSubstatPlanFollowsTheScalingBasis() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs)

        let atk = assembler.substatPlan(role: .mainDPS, basis: .atk).map(\.key)
        let def = assembler.substatPlan(role: .mainDPS, basis: .def).map(\.key)
        XCTAssertTrue(atk.contains("atk_pct"))
        XCTAssertFalse(def.contains("atk_pct"), "a DEF-scaling build should not be spending rolls on ATK%")
        XCTAssertTrue(def.contains("def_pct"))

        // Ordered richest-share first, so the UI can print it as a priority list.
        let shares = assembler.substatPlan(role: .mainDPS, basis: .atk).map(\.share)
        XCTAssertEqual(shares, shares.sorted(by: >))
    }

    /// The pass only ever swaps a set when the swap beats the incumbent, so it
    /// cannot hand back a worse team than the search found.
    func testRefinementNeverLowersTheScore() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()

        let refined = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                                splitsHalves: false))
        let plain = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                              refinesArtifacts: false,
                                                              splitsHalves: false))

        let refinedBest = try XCTUnwrap(refined.reports.first?.wholeFloorTeams?.first)
        let plainBest = try XCTUnwrap(plain.reports.first?.wholeFloorTeams?.first)
        XCTAssertGreaterThanOrEqual(refinedBest.score, plainBest.score)

        for team in try XCTUnwrap(refined.reports.first?.wholeFloorTeams) {
            XCTAssertGreaterThanOrEqual(team.score, team.baseScore,
                                        "team \(team.id) came back worse than it went in")
            XCTAssertGreaterThan(team.baseScore, 0, "team \(team.id) has no pre-refinement score to compare against")
        }
    }

    /// Same coordinate-ascent sweep, same order, same answer — otherwise the
    /// recommended artifacts would change every time the user pressed the button.
    func testRefinementIsDeterministic() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let request = AbyssOptimizerRequest(roster: roster, floors: [11], topN: 5,
                                            splitsHalves: false)

        let firstRun = await optimizer.run(request)
        let secondRun = await optimizer.run(request)
        let first = try XCTUnwrap(firstRun.reports.first?.wholeFloorTeams)
        let second = try XCTUnwrap(secondRun.reports.first?.wholeFloorTeams)

        XCTAssertEqual(first.map(\.id), second.map(\.id))
        for (lhs, rhs) in zip(first, second) {
            XCTAssertEqual(lhs.score, rhs.score, accuracy: 1e-12)
            for memberID in lhs.memberIDs {
                XCTAssertEqual(lhs.artifactAdvice[memberID]?.setIDs,
                               rhs.artifactAdvice[memberID]?.setIDs,
                               "\(memberID): recommended sets changed between runs")
            }
        }
    }

    /// The whole point of the pass: the sets it picks are chosen against a
    /// specific floor and team, so at least somewhere in a rotation it should
    /// disagree with the context-free pick. If it never did, the feature would
    /// be decoration.
    func testRefinementActuallyChangesSomeRecommendations() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, topN: 5,
                                                               splitsHalves: false))

        let improved = output.reports
            .flatMap(\.allTeams)
            .flatMap { team in team.artifactAdvice.values.map(\.gainOverNeutralPick) }
            .filter { $0 > 0 }
        XCTAssertFalse(improved.isEmpty,
                       "no character anywhere in the rotation preferred different artifacts in context")

        // A gain has to be a plausible artifact-swap gain, not a modelling
        // blow-up: a set is worth tens of percent at most.
        for gain in improved {
            XCTAssertLessThan(gain, 1.0, "an artifact swap doubled a team's score, which is not credible")
        }
    }

    /// An artifact set's party buff does not stack with itself.
    ///
    /// This is not a hypothetical: before it was fixed, the artifact pass found
    /// that dressing three characters in Tenacity of the Millelith "granted"
    /// +60% party ATK, and duly recommended it. Any search that optimises a team
    /// score will find a buff the model lets it double-count, so the rule is
    /// pinned here rather than left to the recommendation that exposed it.
    func testArtifactPartyBuffsAreCountedOncePerSet() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                            weaponBuffs: library.weaponBuffsByID, setBuffs: library.setBuffsByID)

        // Any set whose 4-piece bonus reaches the party will do.
        let partySet = try XCTUnwrap(library.fiveStarArtifactSets.first { set in
            (library.setBuffsByID[set.id]?.fourPiece ?? []).contains { buff in
                buff.scope == .party && buff.stat == .atkPercent
                    && buff.conditions.allSatisfy { if case .cast = $0 { return true } else { return false } }
            }
        }, "the data has no set granting party ATK; this test needs updating")

        let members = Array(library.characters.prefix(4))
        let context = AbyssTeamContext.build(members: members, library: library)
        var diagnostics = AbyssParseDiagnostics()
        let sheets = members.map { member -> AbyssStats in
            guard let profile = library.profilesByCharacterID[member.id] else { return AbyssStats() }
            return assembler.stats(character: member, profile: profile, weapon: nil, sets: [partySet],
                                   role: .mainDPS, mainStats: .damage(for: member),
                                   diagnostics: &diagnostics)
        }

        let one = scorer.partyBuffs(stats: [sheets[0]], setIDs: [[partySet.id]], team: context)
        let all = scorer.partyBuffs(stats: sheets, setIDs: members.map { _ in [partySet.id] },
                                    team: context)

        XCTAssertGreaterThan(one.atkPercent, 0, "the chosen set should grant party ATK at all")
        XCTAssertEqual(all.atkPercent, one.atkPercent, accuracy: 1e-9,
                       "four characters wearing the same set granted the buff four times")

        // Two *different* sets are two sources and do stack.
        let otherSet = try XCTUnwrap(library.fiveStarArtifactSets.first { $0.id != partySet.id })
        let mixed = scorer.partyBuffs(stats: [sheets[0], sheets[1]],
                                      setIDs: [[partySet.id], [otherSet.id]], team: context)
        XCTAssertGreaterThanOrEqual(mixed.atkPercent, one.atkPercent)
    }

    /// Artifacts are farmable, so the search is over every 5★ set and a roster
    /// cannot narrow it. The recommendation is "the best set that exists", and
    /// the only constraint on it is that the set is real and reachable.
    func testEverySetIsSearchedRegardlessOfWhatTheRosterHolds() async throws {
        let optimizer = try makeOptimizer()
        let roster = try AbyssGoldenFixture.exampleRoster()
        let fiveStarIDs = Set(library.fiveStarArtifactSets.map(\.id))

        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 3,
                                                               splitsHalves: false))
        var recommended: Set<String> = []
        for team in try XCTUnwrap(output.reports.first?.wholeFloorTeams) {
            for advice in team.artifactAdvice.values {
                for setID in advice.setIDs + advice.alternativeSetIDs {
                    XCTAssertTrue(fiveStarIDs.contains(setID),
                                  "recommended \(setID), which is not a 5★ set")
                    recommended.insert(setID)
                }
            }
        }
        XCTAssertFalse(recommended.isEmpty, "the refinement pass recommended nothing at all")
    }

    /// The pass used to shortlist eight sets by the character's own damage
    /// before scoring any of them as a team, which could not see a set that
    /// earns its slot by buffing the other three. It is exhaustive now, so
    /// every 5★ set and every 2+2 pair really is reachable.
    func testRefinementConsidersEverySetAndEveryPair() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                            weaponBuffs: library.weaponBuffsByID, setBuffs: library.setBuffsByID)
        let advisor = AbyssArtifactAdvisor(library: library, assembler: assembler,
                                           scorer: AbyssScorer(library: library, tuning: tuning))
        let optimizer = try makeOptimizer()
        let sets = library.fiveStarArtifactSets
        let members = ["hu-tao", "xingqiu", "bennett", "zhongli"].compactMap { library.charactersByID[$0] }
        XCTAssertEqual(members.count, 4)

        var options: [String: [AbyssGearOption]] = [:]
        for member in members {
            options[member.id] = optimizer.gearOptions(for: member, weapons: library.weapons,
                                                       sets: sets, roster: nil)
        }
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let team = try XCTUnwrap(scorer.score(members: members, options: options, floor: .neutral))
        let refined = advisor.refine(team: team, members: members, floor: .neutral, sets: sets,
                                     roster: nil)

        // Refinement never returns a worse team, and it reports advice for
        // everyone rather than only for whoever the shortlist happened to fit.
        XCTAssertGreaterThanOrEqual(refined.score, team.score)
        XCTAssertEqual(Set(refined.artifactAdvice.keys), Set(members.map(\.id)))
        for advice in refined.artifactAdvice.values {
            XCTAssertTrue((1...2).contains(advice.setIDs.count),
                          "a build is one 4-piece or two 2-pieces, got \(advice.setIDs)")
        }
    }
}
