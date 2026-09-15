import XCTest
@testable import NSLauncherApp

/// One spelling for a stat, checked in both directions.
///
/// `tuning.json` names stats in snake_case — `artifactMainStats`,
/// `substatRollValue`, `substatPriority`, `scalingBasisSwap` — and every one of
/// those lookups is a dictionary subscript whose miss is `nil`, which the
/// callers turn into zero. So a key that does not exist and a stat worth nothing
/// are the same thing from the inside: a mistyped `crit_dmg` does not crash, it
/// quietly builds every character without CRIT DMG and still produces a
/// confident recommendation.
///
/// `AbyssStatField.tuningKey` is now the only place those names are written, and
/// these tests are what makes that mean something: they walk the data and
/// require each key to land on a slot.
final class AbyssStatVocabularyTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private func tuning() throws -> AbyssTuning { try XCTUnwrap(library.tuning) }

    // MARK: - The keys in the data

    func testEverySubstatKeyInTuningNamesASlot() throws {
        let tuning = try tuning()
        for key in tuning.substatRollValue.keys {
            XCTAssertNotNil(AbyssStatField(tuningKey: key),
                            "substatRollValue.\(key) reaches no slot, so its rolls are spent on nothing")
        }
        for (role, priority) in tuning.substatPriority {
            for key in priority.keys {
                XCTAssertNotNil(AbyssStatField(tuningKey: key),
                                "substatPriority.\(role).\(key) reaches no slot")
                XCTAssertNotNil(tuning.substatRollValue[key],
                                "substatPriority.\(role).\(key) has no roll value, so its share of "
                                + "the budget is spent for zero")
            }
        }
    }

    func testEveryScalingBasisSwapNamesSlotsOnBothSides() throws {
        for (basis, swaps) in try tuning().scalingBasisSwap {
            XCTAssertNotNil(ScalingBasis(rawValue: basis), "scalingBasisSwap.\(basis) is no basis")
            for (source, destination) in swaps {
                XCTAssertNotNil(AbyssStatField(tuningKey: source),
                                "scalingBasisSwap.\(basis).\(source) reaches no slot")
                XCTAssertNotNil(AbyssStatField(tuningKey: destination),
                                "scalingBasisSwap.\(basis) -> \(destination) reaches no slot")
            }
        }
    }

    /// Both directions, because each one hides a different mistake: a main stat
    /// with no value is scored as worth nothing, and a value no main stat asks
    /// for is a row nobody will ever notice is wrong.
    func testMainStatValuesAndMainStatsCoverEachOther() throws {
        let tuning = try tuning()
        let assembler = AbyssBuildAssembler(tuning: tuning, moonsignIDs: library.moonsignIDs,
                                            talentBuffs: library.talentBuffsByCharacterID)

        var asked = Set(AbyssMainStatPlan.fixedSlots.map(\.tuningKey))
        for key in asked {
            XCTAssertNotNil(tuning.artifactMainStats[key],
                            "the Flower/Plume slot \(key) has no value, so every build is missing it")
        }
        for role in AbyssRole.allCases {
            for element in GenshinElement.allCases {
                let candidates = assembler.mainStatCandidates(role: role, element: element)
                for stat in candidates.sands + candidates.goblet + candidates.circlet {
                    asked.insert(stat.statField.tuningKey)
                    XCTAssertNotNil(tuning.artifactMainStats[stat.statField.tuningKey],
                                    "\(role.rawValue) can be offered \(stat), which has no value "
                                    + "in artifactMainStats — the search would score it as zero")
                }
            }
        }
        XCTAssertEqual(Set(tuning.artifactMainStats.keys), asked,
                       "artifactMainStats carries a key no slot the search offers ever asks for")
    }

    // MARK: - The vocabulary itself

    /// A key that two slots claim would silently send one slot's rolls to the
    /// other, because the lookup keeps the first match.
    func testEverySlotHasItsOwnKeyAndFindsItsWayBack() {
        var seen: [String: AbyssStatField] = [:]
        for field in AbyssStatField.scalarCases {
            XCTAssertNil(seen[field.tuningKey],
                         "\(field) and \(seen[field.tuningKey].map(String.init(describing:)) ?? "")"
                         + " share the key \"\(field.tuningKey)\"")
            seen[field.tuningKey] = field
            XCTAssertEqual(AbyssStatField(tuningKey: field.tuningKey), field)
        }
    }

    /// The one key that deliberately does not resolve, and why: it names a kind
    /// of stat rather than a slot, and choosing a lane would mean guessing an
    /// element that only the character knows.
    func testTheElementalKeyIsAKindRatherThanASlot() {
        XCTAssertEqual(AbyssStatField.elemental(.pyro).tuningKey, "elemental_dmg")
        XCTAssertEqual(AbyssStatField.elemental(.cryo).tuningKey, "elemental_dmg")
        XCTAssertNil(AbyssStatField(tuningKey: "elemental_dmg"))
    }

    /// `add` and `value(of:)` have to stay inverses over every slot, or the
    /// golden fixture would be writing a column that reads back as another
    /// slot's number.
    func testWritingASlotIsWhatReadsBack() {
        for (index, field) in AbyssStatField.allCases.enumerated() {
            var stats = AbyssStats()
            // Energy Recharge starts at 1 and CRIT at 5%/50%, so compare against
            // where the slot actually started rather than against zero.
            let before = stats.value(of: field)
            let amount = Double(index + 1) * 0.125
            stats.add(amount, to: field)
            XCTAssertEqual(stats.value(of: field), before + amount, accuracy: 1e-12,
                           "\(field) did not read back what was written to it")

            for other in AbyssStatField.allCases where other != field {
                XCTAssertEqual(stats.value(of: other), AbyssStats().value(of: other), accuracy: 1e-12,
                               "writing \(field) also moved \(other)")
            }
        }
    }

    /// `allCases` is hand-written, because the element-carrying cases stop the
    /// compiler from synthesising it. This is what says nothing was left out.
    func testAllCasesCoversTheWholeSheet() {
        XCTAssertEqual(AbyssStatField.allCases.count,
                       AbyssStatField.scalarCases.count + 2 * GenshinElement.allCases.count + 2 * HitCategory.allCases.count)
        XCTAssertEqual(Set(AbyssStatField.allCases).count, AbyssStatField.allCases.count,
                       "allCases lists a slot twice")
        XCTAssertEqual(AbyssStatField.allCases.filter(\.isPartyScoped).count,
                       4 + GenshinElement.allCases.count,
                       "the party-scoped slots are what a measured sheet must not be credited with")
    }
}
