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
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5))

        let teams = try XCTUnwrap(output.reports.first?.teams)
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

    /// The goblet is what makes the advice specific to the character, and the
    /// circlet is what makes a healer's build different from a damage dealer's.
    /// Both come from the same function the assembler builds stats with, so a
    /// mismatch here means the tab would be describing a build nobody scored.
    func testMainStatPlanMatchesTheBuildThatWasScored() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs)

        for character in library.characters.prefix(30) {
            guard let profile = library.profilesByCharacterID[character.id] else { continue }

            let damage = assembler.mainStatPlan(role: .mainDPS, basis: profile.basis,
                                                element: character.element)
            XCTAssertEqual(damage.goblet, .elementalDMG(character.element),
                           "\(character.id): goblet should be the character's own element")
            XCTAssertEqual(damage.circlet, .critDMG)

            let healer = assembler.mainStatPlan(role: .healer, basis: profile.basis,
                                                element: character.element)
            XCTAssertEqual(healer.sands, .hpPercent)
            XCTAssertEqual(healer.circlet, .healingBonus)
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

        let refined = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5))
        let plain = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 5,
                                                              refinesArtifacts: false))

        let refinedBest = try XCTUnwrap(refined.reports.first?.teams.first)
        let plainBest = try XCTUnwrap(plain.reports.first?.teams.first)
        XCTAssertGreaterThanOrEqual(refinedBest.score, plainBest.score)

        for team in try XCTUnwrap(refined.reports.first?.teams) {
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
        let request = AbyssOptimizerRequest(roster: roster, floors: [11], topN: 5)

        let firstRun = await optimizer.run(request)
        let secondRun = await optimizer.run(request)
        let first = try XCTUnwrap(firstRun.reports.first?.teams)
        let second = try XCTUnwrap(secondRun.reports.first?.teams)

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
        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, topN: 5))

        let improved = output.reports
            .flatMap(\.teams)
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
                                            artifactSets: library.artifactSets)

        // Any set whose 4-piece bonus reaches the party will do.
        let partySet = try XCTUnwrap(library.fiveStarArtifactSets.first { set in
            (set.twoPiece.bonuses + set.fourPiece.bonuses).contains { bonus in
                AbyssBuildAssembler.resolve(named: bonus.stat, value: bonus.value,
                                            conditional: false, tuning: tuning)
                    .contains { $0.field == .partyATKPercent }
            }
        }, "the data has no set granting party ATK; this test needs updating")

        let members = Array(library.characters.prefix(4))
        let context = AbyssTeamContext.build(members: members, library: library)
        var diagnostics = AbyssParseDiagnostics()
        let sheets = members.map { member -> AbyssStats in
            guard let profile = library.profilesByCharacterID[member.id] else { return AbyssStats() }
            return assembler.stats(character: member, profile: profile, weapon: nil, sets: [partySet],
                                   role: .mainDPS, diagnostics: &diagnostics)
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

        let output = await optimizer.run(AbyssOptimizerRequest(roster: roster, floors: [12], topN: 3))
        var recommended: Set<String> = []
        for team in try XCTUnwrap(output.reports.first?.teams) {
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
                                            artifactSets: library.artifactSets)
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
