import XCTest
@testable import NSLauncherApp

/// The prose path and the structured path, read over the same characters.
///
/// Not a pass/fail on agreement — they are *expected* to disagree, and each
/// disagreement is a transcription error, a parser bug, or a reader bug. What
/// this pins is the shape of the disagreement: which characters, which
/// category, how far. The printed table is the review artefact for Phase 1;
/// the assertions below are the floor that must hold whatever the table says.
final class AbyssTalentSourceComparisonTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private struct Slot: Hashable { let category: HitCategory; let basis: ScalingBasis }

    private func aggregate(_ hits: [AbyssDamageProfile.Term]) -> [Slot: Double] {
        var totals: [Slot: Double] = [:]
        for hit in hits { totals[Slot(category: hit.category, basis: hit.basis), default: 0] += hit.multiplier }
        return totals
    }

    /// Both readings of every structured character, side by side.
    private func readings() throws -> [(id: String, prose: [Slot: Double], structured: [Slot: Double])] {
        let params = try XCTUnwrap(library.talentParams)
        var out: [(String, [Slot: Double], [Slot: Double])] = []
        for character in library.characters {
            guard let structured = params.characters[character.id] else { continue }
            let charged = library.traitsByCharacterID[character.id]?.chargedAttackLabels?.labels ?? []
            var scratch = AbyssParseDiagnostics()
            let prose = AbyssDataLibrary.hits(for: character, levels: .base, structured: nil,
                                              chargedLabels: charged, diagnostics: &scratch)
            let real = AbyssDataLibrary.hits(for: character, levels: .base, structured: structured,
                                             chargedLabels: charged, diagnostics: &scratch)
            out.append((character.id, aggregate(prose), aggregate(real)))
        }
        return out
    }

    func testReportDisagreementsBetweenProseAndStructured() throws {
        let all = try readings()
        var lines: [String] = []
        var agreeing = 0
        for (id, prose, structured) in all.sorted(by: { $0.id < $1.id }) {
            var diffs: [String] = []
            for slot in Set(prose.keys).union(structured.keys).sorted(by: {
                ($0.category.rawValue, $0.basis.rawValue) < ($1.category.rawValue, $1.basis.rawValue) }) {
                let a = prose[slot] ?? 0, b = structured[slot] ?? 0
                guard abs(a - b) > 0.005 * max(a, b, 1) else { continue }
                diffs.append(String(format: "%@/%@ prose %.3f → real %.3f", slot.category.rawValue,
                                    slot.basis.rawValue, a, b))
            }
            if diffs.isEmpty { agreeing += 1 } else { lines.append("\(id): " + diffs.joined(separator: "; ")) }
        }
        print("=== prose vs structured: \(agreeing)/\(all.count) characters agree within 0.5% on every slot")
        for line in lines { print("  " + line) }
        XCTAssertFalse(all.isEmpty)
    }

    /// Whatever the table says, the structured reading must never come out
    /// empty for a character whose prose reading was not — a character with a
    /// profile the reader could not see at all would be scored as dealing no
    /// damage.
    func testNoStructuredCharacterLosesTheirWholeProfile() throws {
        for (id, prose, structured) in try readings() where !prose.isEmpty {
            XCTAssertFalse(structured.isEmpty, "\(id): prose has hits, structured has none")
        }
    }

    /// The finding the first comparison made: the prose path reads *no*
    /// normal-attack damage at all for a whole cohort of characters — 30 of
    /// 118, every Sumeru and Natlan release among them — because their
    /// transcription labels the hits in a form the combo regex never matched.
    /// The structured path reads a combo for every character that has one.
    func testEveryStructuredCharacterHasACombo() throws {
        var proseZero: [String] = []
        for (id, prose, structured) in try readings() {
            XCTAssertGreaterThan(structured[Slot(category: .normal, basis: .atk)] ?? 0, 0,
                                 "\(id): no normal-attack combo read from the game's own table")
            if (prose[Slot(category: .normal, basis: .atk)] ?? 0) == 0 { proseZero.append(id) }
        }
        print("=== characters the prose path scored with zero normal-attack damage: \(proseZero.count)")
        print("  " + proseZero.sorted().joined(separator: ", "))
    }
}
