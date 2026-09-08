import XCTest
@testable import NSLauncherApp

/// Loads the real bundled `Resources/Abyss/` data, like `StoryLibraryTests`
/// does for the Story tab. Decoding failures degrade to empty at runtime, so
/// without pinned counts here a malformed file would ship as a silently empty
/// tab instead of a red build.
final class AbyssDataLibraryTests: XCTestCase {

    /// Parsing 948 KB with regexes takes long enough that rebuilding it per
    /// test method is noticeable in `swift test`. Overrides are disabled so a
    /// file in the developer's own Application Support cannot change results.
    static let library = AbyssDataLibrary(cycleOverrideDirectory: nil)
    private var library: AbyssDataLibrary { Self.library }

    func testLoadsAllBundledRecords() {
        XCTAssertEqual(library.characters.count, 125, "expected 125 characters across Resources/Abyss/characters")
        XCTAssertEqual(library.weapons.count, 246, "expected 246 weapons across Resources/Abyss/weapons")
        XCTAssertEqual(library.artifactSets.count, 63, "expected 63 artifact sets")
        XCTAssertEqual(library.fiveStarArtifactSets.count, 46, "expected 46 sets that exist at 5-star")
        XCTAssertNotNil(library.tuning)
        XCTAssertNotNil(library.teamBonus)
        XCTAssertNotNil(library.damageFormula)
    }

    func testIdentifiersAreUnique() {
        XCTAssertEqual(library.charactersByID.count, library.characters.count, "duplicate character id")
        XCTAssertEqual(library.weaponsByID.count, library.weapons.count, "duplicate weapon id")
        XCTAssertEqual(library.artifactSetsByID.count, library.artifactSets.count, "duplicate artifact set id")
    }

    /// Gear selection ranks weapons against `fiveStarArtifactSets.first` as a
    /// fixed baseline, so this file's order feeds into every recommendation.
    /// Alphabetising `artifact-sets.json` would change results with nothing
    /// else to notice — hence pinning the first entry.
    func testFiveStarSetOrderIsStable() {
        XCTAssertEqual(library.fiveStarArtifactSets.first?.id, "viridescent-venerer")
    }

    func testLatestCycleIsTheNewestByPeriodStart() throws {
        let cycle = try XCTUnwrap(library.latestCycle)
        XCTAssertEqual(cycle.floors.map(\.floor), [9, 10, 11, 12])
        for other in library.cycles {
            XCTAssertLessThanOrEqual(other.periodStart, cycle.periodStart)
        }
    }

    /// A typo in `tuning.json` would silently zero out that set's bonus, which
    /// looks like "this set is bad" rather than "this line is broken".
    func testEverySetApproximationResolvesToARealSet() throws {
        let tuning = try XCTUnwrap(library.tuning)
        for approximation in tuning.setEffectApprox {
            XCTAssertNotNil(library.artifactSetsByID[approximation.setId],
                            "tuning.json references unknown artifact set \"\(approximation.setId)\"")
        }
    }

    func testTeamBonusCharacterIdsResolve() throws {
        let teamBonus = try XCTUnwrap(library.teamBonus)
        for id in teamBonus.moonsign.characterIds + teamBonus.hexerei.characterIds {
            XCTAssertNotNil(library.charactersByID[id], "team-bonus.json references unknown character \"\(id)\"")
        }
        for id in library.stellarJubileeIDs {
            XCTAssertNotNil(library.charactersByID[id], "tuning.json references unknown character \"\(id)\"")
        }
    }

    func testEveryCharacterHasADamageProfile() {
        for character in library.characters {
            XCTAssertNotNil(library.profilesByCharacterID[character.id], "no profile for \(character.id)")
        }
    }

    /// The aggregate is what the scorer actually runs over; it must be the same
    /// total as the individual hits it replaces.
    func testAggregateProfileSumsMatchIndividualHits() throws {
        for character in library.characters {
            let profile = try XCTUnwrap(library.profilesByCharacterID[character.id])
            let hitTotal = profile.hits.reduce(0) { $0 + $1.multiplier }
            let aggregateTotal = profile.aggregate.reduce(0) { $0 + $1.multiplier }
            XCTAssertEqual(hitTotal, aggregateTotal, accuracy: max(hitTotal, 1) * 1e-12,
                           "aggregate lost or gained damage for \(character.id)")
        }
    }

    func testCharacterWeaponTypesHaveUsableWeapons() {
        let availableTypes = Set(library.weapons.map(\.type))
        for character in library.characters {
            XCTAssertTrue(availableTypes.contains(character.weaponType),
                          "\(character.id) uses \(character.weaponType) but no such weapon exists in the data")
        }
    }
}
