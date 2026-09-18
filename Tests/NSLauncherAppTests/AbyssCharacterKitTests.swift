import XCTest
@testable import NSLauncherApp

/// What `character-kits.json` claims, and whether anybody is listening.
///
/// The file exists because forty-eight facts about individual characters had
/// spread across three others in seven shapes, and six of the seven were read
/// without ever checking that the character existed. That is the failure mode
/// worth naming: a mistyped id does not crash and does not warn, it removes a
/// mechanic — and a Stellar Jubilee list with a typo is indistinguishable from a
/// roster where nobody has Stellar Jubilee. Phase 2 added the kit facts —
/// which rows one cast deals, what converts into ATK, what a talent buffs —
/// and every one of those is a reference into `talent-params.json` that can
/// go stale the same silent way.
///
/// So these tests are less about the values than about the joins. Every id has
/// to name a character, every reaction name a reaction, every label a row that
/// still exists, and every entry has to reach something the engine actually
/// reads.
final class AbyssCharacterKitTests: XCTestCase {

    private var library: AbyssDataLibrary { AbyssDataLibraryTests.library }

    private var kits: [AbyssCharacterKit] {
        library.kitsByCharacterID.values.sorted { $0.characterId < $1.characterId }
    }

    // MARK: - The joins

    /// The one that would have caught the bug the file was written for.
    func testNothingInTheFileReferencesSomethingThatDoesNotExist() {
        XCTAssertEqual(library.diagnostics.unknownKitCharacterIDs, [],
                       "character-kits.json names a character, a reaction, or a duplicate that "
                       + "the data cannot resolve — every one of those is a mechanic reaching nobody")
    }

    /// The Phase 2 counterpart: a `hits`, `conversions` or `resistanceShred`
    /// entry that names a row or a param the talent table does not have. Each
    /// is a claim about the character's damage that is currently worth zero.
    func testEveryKitReferenceResolvesAgainstTheTalentTables() {
        XCTAssertEqual(library.diagnostics.kitReferencesUnresolved, [],
                       "a kit names something talent-params.json does not have")
        XCTAssertEqual(library.diagnostics.talentBuffUnresolved, [],
                       "a kit buff no longer matches a row, or names a stat that is not one")
    }

    /// A kit's `hits` are read through `talent-params.json`; a character
    /// without an entry there (the Travelers) cannot carry them.
    func testEveryKitWithHitsHasStructuredTalentData() {
        for kit in kits where kit.hits != nil {
            XCTAssertNotNil(library.talentParams?.characters[kit.characterId],
                            "\(kit.characterId) has kit hits and no structured talents to read them from")
        }
    }

    /// Every reference is one row or one param, counted a positive number of
    /// times, and every slot a kit overrides reaches the profile — a kit that
    /// says "the combo is these rows" and produces no normal-attack term has
    /// lost the character's whole attack string.
    func testEveryHitReferenceIsWellFormedAndReachesTheProfile() throws {
        for kit in kits {
            guard let hits = kit.hits else { continue }
            XCTAssertFalse(hits.note.isEmpty, "\(kit.characterId): hits have no note")
            let profile = try XCTUnwrap(library.profilesByCharacterID[kit.characterId])
            for slot in AbyssCharacterKit.HitSlot.allCases {
                guard let references = hits[slot] else { continue }
                for reference in references {
                    XCTAssertTrue((reference.label == nil) != (reference.param == nil),
                                  "\(kit.characterId): a \(slot.rawValue) reference is a label or a param, not both")
                    XCTAssertGreaterThan(reference.count ?? 1, 0, "\(kit.characterId): a count of zero is a row not listed")
                    XCTAssertTrue(reference.basis == nil || reference.param != nil,
                                  "\(kit.characterId): a basis only means something on a bare param")
                }
                let categories = Set(references.map { $0.category ?? slot.defaultCategory })
                for category in categories {
                    XCTAssertTrue(profile.hits.contains { $0.category == category },
                                  "\(kit.characterId): \(slot.rawValue) names \(category.rawValue) rows and the profile has none")
                }
            }
        }
    }

    /// The two conversions the file was written for, and the sign of every
    /// other: a kit that converts must convert *something*, into ATK, at a
    /// positive rate — and the library must have read exactly as many as the
    /// file lists.
    func testEveryConversionResolvesToAPositiveRate() {
        for kit in kits {
            let listed = kit.conversions ?? []
            let resolved = library.conversionsByCharacterID[kit.characterId] ?? []
            XCTAssertEqual(resolved.count, listed.count, "\(kit.characterId): not every conversion resolved")
            for conversion in resolved {
                XCTAssertGreaterThan(conversion.rate, 0, "\(kit.characterId): a conversion worth nothing")
            }
        }
        XCTAssertEqual(library.conversionsByCharacterID["hu-tao"]?.map(\.from), [.hp])
        XCTAssertEqual(library.conversionsByCharacterID["noelle"]?.map(\.from), [.def])
    }

    func testTheFileIsLoadedAtAll() {
        XCTAssertFalse(kits.isEmpty,
                       "no traits loaded: every Moonsign, Hexerei and Stellar Jubilee team in the "
                       + "app is now scored as an ordinary one, and nothing else would say so")
        XCTAssertGreaterThan(kits.count, 30)
    }

    /// Each tag drives a mechanic somewhere else. An empty roster for one is not
    /// a data gap the engine can see — it just scores every team as if the
    /// mechanic did not exist.
    func testEveryTagHasSomebodyCarryingIt() {
        for tag in AbyssCharacterKit.Tag.allCases {
            XCTAssertFalse(kits.filter { $0.has(tag) }.isEmpty,
                           "no character carries \"\(tag.rawValue)\"")
        }
        XCTAssertEqual(Set(kits.filter { $0.has(.moonsign) }.map(\.characterId)),
                       library.moonsignIDs)
        XCTAssertEqual(Set(kits.filter { $0.has(.hexerei) }.map(\.characterId)),
                       library.hexereiIDs)
        XCTAssertEqual(Set(kits.filter { $0.has(.stellarJubilee) }.map(\.characterId)),
                       library.stellarJubileeIDs)
    }

    /// An entry that carries nothing is a character listed for no reason, which
    /// is how a file like this rots: it stops being a claim and becomes a list.
    func testNoEntryIsEmpty() {
        for entry in kits {
            XCTAssertFalse(entry.isEmpty, "\(entry.characterId) has an entry that says nothing")
        }
    }

    // MARK: - Reaction base damage

    /// The column this replaced was free text the engine never read, so every
    /// source raised every Lunar and Stellar reaction at once.
    func testABonusNamesTheReactionsItRaisesAndNoOthers() throws {
        let byID = library.reactionBaseDamageBonusByCharacterID
        XCTAssertFalse(byID.isEmpty)

        XCTAssertEqual(Set(try XCTUnwrap(byID["lauma"]).keys), [.lunarBloom])
        XCTAssertEqual(Set(try XCTUnwrap(byID["odette"]).keys), [.stellarConduct, .stellarSwirl])
        XCTAssertEqual(Set(try XCTUnwrap(byID["columbina"]).keys),
                       [.lunarCharged, .lunarBloom, .lunarCrystallize])

        for (id, bonuses) in byID {
            for (reaction, value) in bonuses {
                XCTAssertGreaterThan(value, 0, "\(id): \(reaction.rawValue) is worth nothing")
                XCTAssertNotNil(reaction.lunarStellarKey,
                                "\(id) raises \(reaction.rawValue), which the Lunar/Stellar block "
                                + "does not price — the bonus reaches a reaction with no coefficient")
            }
        }
    }

    /// Every source reaches the table; a `reactions` array the engine drops
    /// would leave a character listed and unread.
    func testEverySourceInTheFileReachesTheTable() {
        for entry in kits where !(entry.reactionBaseDamageBonus ?? []).isEmpty {
            let resolved = library.reactionBaseDamageBonusByCharacterID[entry.characterId] ?? [:]
            let named = Set((entry.reactionBaseDamageBonus ?? []).flatMap(\.reactions))
            XCTAssertEqual(resolved.count, named.count,
                           "\(entry.characterId): \(named.count) reactions named, \(resolved.count) read")
        }
    }

    // MARK: - Resistance shred

    /// The split between the two files is the point, so it should be checkable:
    /// a character-borne source is gated on the character, an artifact-set one
    /// on an element the team happens to have.
    func testCharacterShredIsGatedOnTheCharacterAndSetShredOnTheElement() throws {
        let tuning = try XCTUnwrap(library.tuning)
        for source in tuning.resistanceShred {
            XCTAssertNotNil(source.requiresElement,
                            "tuning.json's \"\(source.id)\" is gated on nothing; a shred every team "
                            + "gets for free is a change to the baseline, not a source")
        }

        let carriers = kits.filter { !($0.resistanceShred ?? []).isEmpty }.map(\.characterId)
        XCTAssertFalse(carriers.isEmpty, "no character strips resistance any more")
        for id in carriers {
            let alone = AbyssTeamContext.build(
                members: [try XCTUnwrap(library.charactersByID[id])], library: library)
            XCTAssertFalse(alone.resistanceShred.isEmpty, "\(id)'s shred reaches nothing")
        }
    }

    /// Every element a shred names has to be one, or `swirled`.
    func testEveryShredNamesRealElements() throws {
        let tuning = try XCTUnwrap(library.tuning)
        let named = tuning.resistanceShred.flatMap(\.elements)
            + kits.flatMap { ($0.resistanceShred ?? []).flatMap(\.elements) }
        XCTAssertFalse(named.isEmpty)
        for name in named where name != AbyssResistanceShredScope.swirled {
            XCTAssertNotNil(GenshinElement(rawValue: name), "\"\(name)\" is no element")
        }
    }

    // MARK: - Uptimes

    /// Every uptime in the file is a share of a rotation. One above 1 would be
    /// crediting a buff for more time than the rotation has.
    func testEveryUptimeIsAShareOfARotation() {
        for entry in kits {
            for buff in entry.buffs ?? [] {
                XCTAssertTrue((0...1).contains(buff.uptime),
                              "\(entry.characterId): buff uptime \(buff.uptime)")
            }
            for conversion in entry.conversions ?? [] {
                XCTAssertTrue((0...1).contains(conversion.uptime),
                              "\(entry.characterId): conversion uptime \(conversion.uptime)")
            }
            for shred in entry.resistanceShred ?? [] {
                XCTAssertTrue((0...1).contains(shred.uptime),
                              "\(entry.characterId): shred uptime \(shred.uptime)")
            }
            for shred in library.resistanceShredByCharacterID[entry.characterId] ?? [] {
                XCTAssertTrue((0...1).contains(shred.value),
                              "\(entry.characterId): shred value \(shred.value) is not a fraction")
            }
        }
    }

    /// The file's own convention: every subjective number carries the reasoning
    /// that produced it. An uptime with no note is a number nobody can check.
    func testEverySubjectiveNumberCarriesItsReasoning() {
        for entry in kits {
            for buff in entry.buffs ?? [] {
                XCTAssertFalse(buff.note.isEmpty, "\(entry.characterId): buff has no note")
            }
            for conversion in entry.conversions ?? [] {
                XCTAssertFalse(conversion.note.isEmpty, "\(entry.characterId): conversion has no note")
            }
            for shred in entry.resistanceShred ?? [] {
                XCTAssertFalse(shred.note.isEmpty, "\(entry.characterId): shred has no note")
            }
            if let charged = entry.chargedAttackLabels {
                XCTAssertFalse(charged.note.isEmpty,
                               "\(entry.characterId): chargedAttackLabels has no note")
            }
        }
    }
}
