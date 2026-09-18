import Foundation
import XCTest
@testable import NSLauncherApp

/// Writes `Fixtures/abyss-golden.json` from the engine itself.
///
/// The fixture was originally produced by a Python implementation the Swift
/// engine was ported from; that Python is gone, and without a way to rewrite the
/// file the fixture would have become a wall — every deliberate model change
/// answered by hand-editing 230KB of JSON, which nobody does correctly. So the
/// generator moved here.
///
/// The fixture no longer means "what another implementation computes". It means
/// "what this engine computed on the day someone checked it", which is what a
/// regression baseline is. That makes regenerating it a decision, not a repair:
/// **never run this to make a red test green.** Run it when the model was
/// changed on purpose, and read the diff — a change meant for one character that
/// moves three hundred numbers is the diff telling you something.
///
///     ABYSS_DUMP_GOLDEN=Tests/NSLauncherAppTests/Fixtures/abyss-golden.json \
///         swift test --filter testRegenerateGoldenFixture
///
/// Two blocks the Python wrote are not written any more: `unmapped`, whose
/// numbers came from diagnostics the engine collects and discards inside gear
/// selection, and each team's `notes`, which the Python baked as Vietnamese
/// sentences and the Swift keeps as structured cases. Nothing read either.
final class AbyssGoldenDumpTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    func testRegenerateGoldenFixture() async throws {
        guard let path = ProcessInfo.processInfo.environment["ABYSS_DUMP_GOLDEN"] else {
            throw XCTSkip("set ABYSS_DUMP_GOLDEN=<path> to rewrite the golden fixture")
        }
        let optimizer = try XCTUnwrap(AbyssOptimizer(library: library))
        let cycle = try XCTUnwrap(library.latestCycle)
        let floorNumbers = cycle.floors.map(\.floor).sorted()

        var characters: [String: Any] = [:]
        for character in library.characters {
            guard let profile = library.profilesByCharacterID[character.id],
                  let best = optimizer.gearOptions(for: character, weapons: library.weapons,
                                                   sets: library.fiveStarArtifactSets,
                                                   roster: nil).first
            else { continue }
            characters[character.id] = [
                "scalingBasis": profile.basis.rawValue,
                "role": best.role.rawValue,
                "profile": profile.hits.map { hit -> [String: Any] in
                    var term: [String: Any] = ["multiplier": hit.multiplier, "basis": hit.basis.rawValue,
                                               "category": hit.category.rawValue, "action": hit.action.rawValue]
                    if let reaction = hit.reaction { term["reaction"] = reaction.rawValue }
                    return term
                },
                "topGear": [
                    "weaponId": best.weaponID as Any,
                    "setIds": best.setIDs,
                    "soloScore": best.soloScore,
                    "stats": Self.encode(best.stats),
                ],
            ]
        }

        var diagnostics = AbyssParseDiagnostics()
        var floors: [String: Any] = [:]
        for number in floorNumbers {
            // Whole-floor contexts, not halves: the fixture's job is the damage
            // model, and a floor read whole is the one shape that does not move
            // when the planner changes how it splits the fight up.
            guard let context = AbyssFloorContext.build(
                cycle: cycle, floor: number,
                ownElementResistance: try XCTUnwrap(library.tuning).enemyOwnElementResistance,
                enemyHP: library.enemyHP,
                diagnostics: &diagnostics) else { continue }
            floors[String(number)] = [
                "monsterLevel": context.monsterLevel,
                "enemyHP": context.enemyHP ?? NSNull(),
                "res": Dictionary(uniqueKeysWithValues:
                    context.resistances.map { ($0.key.rawValue, $0.value) }),
                "shieldElements": context.shieldElements.map(\.rawValue).sorted(),
                "buffs": context.buffs.map { buff in
                    [
                        "bonus": buff.bonus,
                        "elements": buff.elements.map(\.rawValue).sorted(),
                        "reactions": buff.reactions.map(\.rawValue).sorted(),
                        "normalAttackOnly": buff.normalAttackOnly,
                        "raw": buff.raw,
                    ]
                },
            ]
        }

        // The same request the golden test makes: no artifact refinement, no
        // half-splitting, ten teams per floor.
        let output = await optimizer.run(AbyssOptimizerRequest(
            roster: try AbyssGoldenFixture.exampleRoster(), floors: floorNumbers,
            topN: 10, poolSize: 40, refinesArtifacts: false, splitsHalves: false))
        var teams: [String: Any] = [:]
        for report in output.reports {
            // `splitsHalves: false` above, so every report is a whole floor.
            guard let ranked = report.wholeFloorTeams else { continue }
            teams[String(report.floor)] = ranked.map { team in
                [
                    "memberIds": team.memberIDs,
                    "onFieldId": team.onFieldID,
                    "score": team.score,
                    "perCharacter": team.perCharacterDamage,
                ]
            }
        }

        let fixture: [String: Any] = [
            "_doc": "Sinh từ chính engine Swift: ABYSS_DUMP_GOLDEN=<path> swift test "
                + "--filter testRegenerateGoldenFixture (xem AbyssGoldenDump.swift). "
                + "Đây là mốc hồi quy — sinh lại là một quyết định, không phải cách "
                + "chữa test đỏ.",
            "characters": characters,
            "floors": floors,
            "teams": teams,
        ]

        let data = try JSONSerialization.data(
            withJSONObject: fixture,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        print("wrote \(characters.count) characters, \(floors.count) floors, "
              + "\(teams.count) floors of teams to \(path)")
    }

    /// The stat sheet in the fixture's own snake_case spelling, kept from the
    /// original format so regenerating rewrites the file rather than replacing
    /// it with a differently shaped one.
    ///
    /// The scalar slots are written by walking `AbyssStatField.scalarCases`
    /// rather than by listing them: the spelling of each column is the slot's
    /// own `tuningKey`, so a slot added to the stat sheet appears here without
    /// anyone remembering to add it, and one that is renamed is renamed in one
    /// place. The three base stats are not modifier slots and the two elemental
    /// blocks are nested rather than scalar, so those five stay written out.
    private static func encode(_ stats: AbyssStats) -> [String: Any] {
        func elemental(_ lanes: SIMD8<Double>) -> [String: Double] {
            Dictionary(uniqueKeysWithValues: GenshinElement.allCases
                .map { ($0.rawValue, lanes[$0.simdIndex]) }
                .filter { $0.1 != 0 })
        }
        var sheet: [String: Any] = [
            "base_atk": stats.baseATK,
            "base_hp": stats.baseHP,
            "base_def": stats.baseDEF,
            "dmg_elemental": elemental(stats.elementalDMG),
            "party_elemental_dmg": elemental(stats.partyElementalDMG),
            "burst_party_flat_atk": stats.burstPartyFlatATK,
            "burst_party_elemental_dmg": elemental(stats.burstPartyElementalDMG),
            "derived": [
                "atk": stats.atk,
                "hp": stats.hp,
                "def": stats.def,
                "critMultiplier": stats.critMultiplier,
            ],
        ]
        for field in AbyssStatField.scalarCases {
            sheet[field.tuningKey] = stats.value(of: field)
        }
        return sheet
    }
}
