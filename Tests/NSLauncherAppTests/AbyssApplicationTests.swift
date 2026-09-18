import XCTest
@testable import NSLauncherApp

/// Phase 4: reactions from element applications instead of two constants.
///
/// `amplifyingUptime = 0.55` credited Vaporize and Melt on every hit, and
/// `transformativeReactionsPerRotation = 6` gave Hyperbloom and Overloaded the
/// same count. The gcsim benchmark measured both: Melt teams +0.25, Vaporize
/// +0.16, and Dendro+Electro teams −0.28 because Aggravate and Spread were not
/// priced at all. These tests pin the rules that replaced them.
final class AbyssApplicationTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func scorer() throws -> AbyssScorer {
        AbyssScorer(library: library, tuning: try XCTUnwrap(library.tuning))
    }

    private func characters(_ ids: [String]) throws -> [AbyssCharacter] {
        try ids.map { try XCTUnwrap(library.charactersByID[$0], "\($0) is not in the data") }
    }

    // MARK: - The game's cooldown rule

    /// First hit applies, then every third or once 2.5 s have passed.
    func testTheStandardInternalCooldownRule() {
        typealias C = AbyssApplicationCounting
        XCTAssertEqual(C.applications(hits: 1, hitsPerApplication: 3, secondsPerApplication: 2.5, seconds: 0), 1)
        XCTAssertEqual(C.applications(hits: 6, hitsPerApplication: 3, secondsPerApplication: 2.5, seconds: 0), 2)
        XCTAssertEqual(C.applications(hits: 7, hitsPerApplication: 3, secondsPerApplication: 2.5, seconds: 0), 3)
        XCTAssertEqual(C.applications(hits: 6, hitsPerApplication: 3, secondsPerApplication: 2.5, seconds: 10), 5,
                       "time resets the counter")
        XCTAssertEqual(C.applications(hits: 4, hitsPerApplication: nil, secondsPerApplication: nil, seconds: 0), 4,
                       "no cooldown: every hit applies")
    }

    /// A physical normal attack applies nothing; a catalyst's and an infused
    /// one's do. Summons and fields hit many times per cast.
    func testWhoseAttacksApplyTheirElement() throws {
        let xiangling = try XCTUnwrap(library.applicationsByCharacterID["xiangling"])
        XCTAssertEqual(xiangling.combo.applications, 0, "Xiangling's spear is Physical")
        XCTAssertGreaterThan(xiangling.burst.applications, 3, "Pyronado keeps applying across its duration")

        let nahida = try XCTUnwrap(library.applicationsByCharacterID["nahida"])
        XCTAssertGreaterThan(nahida.combo.applications, 0, "a catalyst's attacks apply")

        let huTao = try XCTUnwrap(library.applicationsByCharacterID["hu-tao"])
        XCTAssertGreaterThan(huTao.combo.applications, 0, "Paramita converts her attacks to Pyro")

        let fischl = try XCTUnwrap(library.applicationsByCharacterID["fischl"])
        XCTAssertGreaterThan(fischl.skill.hits, 5, "Oz attacks many times per cast")

        let bennett = try XCTUnwrap(library.applicationsByCharacterID["bennett"])
        XCTAssertEqual(bennett.skill.hits, 1, "a press is one hit; hold and charge levels are the other way to cast")
        XCTAssertEqual(library.diagnostics.gaugeMissing.filter { !$0.hasPrefix("traveler-") }, [])
    }

    // MARK: - Reactions

    /// Amplifying takes aura the other side lays down, not a flat share: a
    /// Pyro carry with a heavy Hydro applicator finds more of it than with a
    /// light one, and never more than all of their applying hits.
    func testAmplifyingUptimeFollowsTheAuraSupply() throws {
        let scorer = try scorer()
        func uptime(_ ids: [String], carry: String) throws -> Double {
            let members = try characters(ids)
            let team = AbyssTeamContext.build(members: members, library: library)
            let context = scorer.teamDamageContext(members: members, floor: .neutral, team: team)
            let index = try XCTUnwrap(ids.firstIndex(of: carry))
            return context.variants[index].amplifying[index]
        }
        let heavy = try uptime(["hu-tao", "xingqiu", "yelan", "bennett"], carry: "hu-tao")
        let light = try uptime(["hu-tao", "barbara", "diona", "bennett"], carry: "hu-tao")
        XCTAssertGreaterThan(heavy, light)
        XCTAssertLessThanOrEqual(heavy, 1)
        XCTAssertEqual(try uptime(["hu-tao", "bennett", "sucrose", "xiao"], carry: "hu-tao"), 0,
                       "no Hydro or Cryo, nothing to amplify off")
    }

    /// Aggravate and Spread were never priced; a Quicken team now adds damage
    /// per application, and a team without Dendro does not.
    func testCatalyzeIsPricedOnlyWithQuicken() throws {
        let scorer = try scorer()
        var sheet = AbyssStats()
        sheet.baseATK = 900
        sheet.elementalMastery = 200
        let quicken = try characters(["fischl", "nahida"])
        let withDendro = scorer.teamDamageContext(members: quicken, floor: .neutral,
                                                  team: AbyssTeamContext.build(members: quicken, library: library))
        let split = scorer.damageSplit(context: withDendro.members[0], stats: sheet, partyBuffs: .none)
        XCTAssertGreaterThan(split.catalyzePerApplication, 0)

        let plain = try characters(["fischl", "bennett"])
        let without = scorer.teamDamageContext(members: plain, floor: .neutral,
                                               team: AbyssTeamContext.build(members: plain, library: library))
        XCTAssertEqual(scorer.damageSplit(context: without.members[0], stats: sheet, partyBuffs: .none)
            .catalyzePerApplication, 0)
    }

    /// A transformative reaction goes off as often as the scarcer side applies.
    func testTransformativeCountsFollowApplications() {
        let applications: [GenshinElement: Double] = [.electro: 12, .pyro: 5, .dendro: 8, .hydro: 20]
        XCTAssertEqual(AbyssScorer.reactionCount(.overloaded, applications: applications), 5)
        XCTAssertEqual(AbyssScorer.reactionCount(.bloom, applications: applications), 8)
        XCTAssertEqual(AbyssScorer.reactionCount(.hyperbloom, applications: applications), 8)
        XCTAssertEqual(AbyssScorer.reactionCount(.burgeon, applications: applications), 5)
        XCTAssertEqual(AbyssScorer.reactionCount(.swirl, applications: applications), 0, "no Anemo")
    }

    /// A talent row that is Lunar reaction damage carries the reaction, and is
    /// priced by the Lunar coefficient rather than as a plain hit.
    func testLunarRowsArePricedAsLunarDamage() throws {
        let flins = try XCTUnwrap(library.profilesByCharacterID["flins"])
        XCTAssertTrue(flins.hits.contains { $0.reaction == .lunarCharged })
        let scorer = try scorer()
        // Flins is Electro and Moonsign on his own, but Lunar-Charged still
        // needs a Hydro teammate to pair with — a talent row that *is* Lunar
        // damage only fires when the team's own elements actually trigger
        // that reaction.
        let members = try characters(["flins", "xingqiu"])
        let context = scorer.teamDamageContext(members: members, floor: .neutral,
                                               team: AbyssTeamContext.build(members: members, library: library))
        var sheet = AbyssStats()
        sheet.baseATK = 1000
        var mastery = sheet
        mastery.elementalMastery = 500
        XCTAssertGreaterThan(scorer.damageSplit(context: context.members[0], stats: mastery, partyBuffs: .none).burst,
                             scorer.damageSplit(context: context.members[0], stats: sheet, partyBuffs: .none).burst,
                             "Lunar damage scales with Elemental Mastery")
    }
}
