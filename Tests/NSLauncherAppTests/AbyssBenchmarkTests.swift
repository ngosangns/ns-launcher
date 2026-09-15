import Foundation
import XCTest
@testable import NSLauncherApp

/// The planner's team order against gcsim's.
///
/// `abyss-golden.json` holds the engine to its own past output; nothing held it
/// to the game, and a set-bonus bug that made one set the best choice for 95 of
/// 125 characters went unnoticed for that reason. `Fixtures/gcsim-benchmark.json`
/// (written by `scripts/sync-abyss-benchmark.py`) is the best simulated DPS of
/// every four-character team in gcsim.app's public database, single target.
///
/// The numbers are not expected to match — the database's builds, rotations and
/// constellations are its submitters', the planner's are modelled — but the
/// *order* should roughly agree, and where it does not, the residual per
/// character says who the model over- or under-rates. That list is the output.
///
/// Opt-in, because it dresses ~1,000 builds and scores ~3,000 teams:
///
///     ABYSS_BENCHMARK=1 swift test --filter AbyssBenchmarkTests
///
/// `ABYSS_BENCHMARK_REPORT=<path>` also writes the report as JSON.
final class AbyssBenchmarkTests: XCTestCase {

    struct Fixture: Decodable {
        struct Member: Decodable {
            let id: String
            let constellation: Int
            let weapon: String
            let refinement: Int
        }
        struct Team: Decodable {
            let dbId: String
            let dps: Double
            let members: [Member]
            let entries: Int
        }
        let fetchedOn: String
        let teams: [Team]
    }

    struct Build: Hashable {
        let id: String
        let constellation: Int
        let weapon: String
        let refinement: Int
    }

    struct Report: Encodable {
        struct Bias: Encodable {
            let character: String
            let teams: Int
            /// Mean of log(model / gcsim) over the teams containing the
            /// character, minus the median over all teams. Positive: the model
            /// rates teams with this character higher than gcsim does.
            let logBias: Double
        }
        let teams: Int
        let spearman: Double
        let overRated: [Bias]
        let underRated: [Bias]
        /// The same log bias, averaged over teams grouped by the transformative
        /// reaction they are priced on ("T:Hyperbloom") and by the amplifying
        /// reaction their elements allow ("A:Melt") — where a reaction model is
        /// over- or under-crediting a whole kind of team.
        let byReaction: [Bias]
    }

    /// Spearman's rank correlation, ties given their average rank.
    static func spearman(_ xs: [Double], _ ys: [Double]) -> Double {
        func ranks(_ values: [Double]) -> [Double] {
            let order = values.indices.sorted { values[$0] < values[$1] }
            var result = [Double](repeating: 0, count: values.count)
            var start = 0
            while start < order.count {
                var end = start
                while end + 1 < order.count, values[order[end + 1]] == values[order[start]] { end += 1 }
                let rank = Double(start + end) / 2 + 1
                for position in start...end { result[order[position]] = rank }
                start = end + 1
            }
            return result
        }
        let rx = ranks(xs), ry = ranks(ys)
        let n = Double(xs.count)
        let mx = rx.reduce(0, +) / n, my = ry.reduce(0, +) / n
        var covariance = 0.0, vx = 0.0, vy = 0.0
        for index in xs.indices {
            covariance += (rx[index] - mx) * (ry[index] - my)
            vx += (rx[index] - mx) * (rx[index] - mx)
            vy += (ry[index] - my) * (ry[index] - my)
        }
        return covariance / (vx * vy).squareRoot()
    }

    func testSpearmanIsRankCorrelation() {
        XCTAssertEqual(Self.spearman([1, 2, 3, 4], [10, 20, 30, 40]), 1, accuracy: 1e-12)
        XCTAssertEqual(Self.spearman([1, 2, 3, 4], [40, 30, 20, 10]), -1, accuracy: 1e-12)
        XCTAssertEqual(Self.spearman([1, 2, 3, 4], [1, 100, 1000, 10000]), 1, accuracy: 1e-12)
    }

    func testFixtureLoadsAndMapsToTheData() throws {
        let fixture = try Self.loadFixture()
        let library = AbyssDataLibraryTests.library
        XCTAssertGreaterThan(fixture.teams.count, 1000)
        for team in fixture.teams.prefix(200) {
            for member in team.members {
                XCTAssertNotNil(library.charactersByID[member.id], "\(member.id) is not a character")
                XCTAssertNotNil(library.weaponsByID[member.weapon], "\(member.weapon) is not a weapon")
            }
        }
    }

    func testModelOrderAgainstGcsim() throws {
        guard ProcessInfo.processInfo.environment["ABYSS_BENCHMARK"] == "1" else {
            throw XCTSkip("set ABYSS_BENCHMARK=1 to run the gcsim benchmark")
        }
        let report = try Self.run()
        print(String(format: "BENCHMARK teams=%d spearman=%.3f", report.teams, report.spearman))
        for bias in report.overRated { print(String(format: "  OVER  %+.3f  %-22@ (%d teams)", bias.logBias, bias.character, bias.teams)) }
        for bias in report.underRated { print(String(format: "  UNDER %+.3f  %-22@ (%d teams)", bias.logBias, bias.character, bias.teams)) }
        for bias in report.byReaction { print(String(format: "  GROUP %+.3f  %-22@ (%d teams)", bias.logBias, bias.character, bias.teams)) }
        if let path = ProcessInfo.processInfo.environment["ABYSS_BENCHMARK_REPORT"] {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: path))
        }
        XCTAssertGreaterThan(report.spearman, 0, "the model's team order is unrelated to the simulator's")
    }

    static func loadFixture() throws -> Fixture {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures/gcsim-benchmark", withExtension: "json")
                ?? Bundle.module.url(forResource: "gcsim-benchmark", withExtension: "json"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    /// Scores every comparable team on the neutral floor with the planner's own
    /// gear search, constrained to the team's weapons and constellations.
    ///
    /// Comparable means every five-star member is C0: the model prices no
    /// constellation effects beyond talent levels, and a C6 five-star's gcsim
    /// DPS is measuring something the model cannot see. Four-star
    /// constellations are kept — the database is mostly C6 four-stars, and
    /// excluding them would leave little.
    static func run() throws -> Report {
        let library = AbyssDataLibraryTests.library
        let tuning = try XCTUnwrap(library.tuning)
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))
        let scorer = AbyssScorer(library: library, tuning: tuning)
        let sets = library.fiveStarArtifactSets

        let teams = try loadFixture().teams.filter { team in
            team.members.allSatisfy { member in
                guard let character = library.charactersByID[member.id],
                      library.weaponsByID[member.weapon] != nil else { return false }
                return character.rarity < 5 || member.constellation == 0
            }
        }
        let builds = Array(Set(teams.flatMap { $0.members.map {
            Build(id: $0.id, constellation: $0.constellation, weapon: $0.weapon, refinement: $0.refinement)
        } }))

        let lock = NSLock()
        var options: [Build: [AbyssGearOption]] = [:]
        var profiles: [Build: AbyssDamageProfile] = [:]
        DispatchQueue.concurrentPerform(iterations: builds.count) { index in
            let build = builds[index]
            guard let character = library.charactersByID[build.id],
                  let weapon = library.weaponsByID[build.weapon],
                  let profile = library.profile(for: build.id, constellation: build.constellation) else { return }
            let roster = AbyssRoster(characters: [.init(id: build.id, constellation: build.constellation)],
                                     weapons: [.init(id: build.weapon, refinement: build.refinement)])
            let dressed = optimizer.gearOptions(for: character, weapons: [weapon], sets: sets,
                                                roster: roster, profile: profile)
            lock.lock()
            options[build] = dressed
            profiles[build] = profile
            lock.unlock()
        }

        var model: [Double] = []
        var gcsim: [Double] = []
        var members: [[String]] = []
        for team in teams {
            let teamBuilds = team.members.map {
                Build(id: $0.id, constellation: $0.constellation, weapon: $0.weapon, refinement: $0.refinement)
            }
            let characters = teamBuilds.compactMap { library.charactersByID[$0.id] }
            var teamOptions: [String: [AbyssGearOption]] = [:]
            var teamProfiles: [String: AbyssDamageProfile] = [:]
            for build in teamBuilds {
                teamOptions[build.id] = options[build]
                teamProfiles[build.id] = profiles[build]
            }
            guard characters.count == 4,
                  let result = scorer.score(members: characters, options: teamOptions, floor: .neutral,
                                            profiles: teamProfiles),
                  result.score > 0 else { continue }
            model.append(result.score)
            gcsim.append(team.dps)
            members.append(characters.map(\.id))
        }

        let logRatios = zip(model, gcsim).map { log($0 / $1) }
        let median = logRatios.sorted()[logRatios.count / 2]
        var sums: [String: (total: Double, count: Int)] = [:]
        for (index, ids) in members.enumerated() {
            for id in ids {
                sums[id, default: (0, 0)].total += logRatios[index] - median
                sums[id, default: (0, 0)].count += 1
            }
        }
        let scorer2 = scorer
        var groups: [String: (total: Double, count: Int)] = [:]
        for (index, ids) in members.enumerated() {
            let characters = ids.compactMap { library.charactersByID[$0] }
            let team = AbyssTeamContext.build(members: characters, library: library)
            let transformative = scorer2.transformative(for: team, floor: .neutral)?.reaction.rawValue ?? "none"
            let amplifying = team.enabledReactions.intersection([.vaporize, .melt]).map(\.rawValue).sorted()
            for key in ["T:" + transformative, "A:" + (amplifying.isEmpty ? "none" : amplifying.joined(separator: "+"))] {
                groups[key, default: (0, 0)].total += logRatios[index] - median
                groups[key, default: (0, 0)].count += 1
            }
        }
        let byReaction = groups.filter { $0.value.count >= 15 }
            .map { Report.Bias(character: $0.key, teams: $0.value.count, logBias: $0.value.total / Double($0.value.count)) }
            .sorted { $0.character < $1.character }
        let biases = sums.filter { $0.value.count >= 10 }
            .map { Report.Bias(character: $0.key, teams: $0.value.count, logBias: $0.value.total / Double($0.value.count)) }
            .sorted { $0.logBias > $1.logBias }
        return Report(teams: model.count, spearman: spearman(model, gcsim),
                      overRated: Array(biases.prefix(15)),
                      underRated: Array(biases.suffix(15).reversed()),
                      byReaction: byReaction)
    }
}
