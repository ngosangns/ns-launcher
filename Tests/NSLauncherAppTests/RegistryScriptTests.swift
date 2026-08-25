import XCTest
@testable import NSLauncherApp

/// The batched `.reg` import replaced nine sequential `wine reg` processes on the launch path.
/// These cover the syntax that batching depends on — get it wrong and the values silently do not
/// land, which is invisible until a setting stops taking effect in-game.
final class RegistryScriptTests: XCTestCase {

    func testGroupsEntriesUnderEachKeyInFirstSeenOrder() {
        let macDriver = #"HKEY_CURRENT_USER\Software\Wine\Mac Driver"#
        let overrides = #"HKEY_CURRENT_USER\Software\Wine\DllOverrides"#
        let script = RegistryScript.render([
            RegistryEntry(key: macDriver, name: "RetinaMode", value: .string("y")),
            RegistryEntry(key: overrides, name: "d3d11", value: .remove),
            RegistryEntry(key: macDriver, name: "LeftCommandIsCtrl", value: .string("n"))
        ])

        XCTAssertTrue(script.hasPrefix("Windows Registry Editor Version 5.00"))
        // One section per key, and the Mac Driver section holds both of its values.
        XCTAssertEqual(script.components(separatedBy: "[\(macDriver)]").count - 1, 1)
        let macSection = try? XCTUnwrap(script.components(separatedBy: "[\(macDriver)]").last)
        XCTAssertEqual(macSection?.contains("\"RetinaMode\"=\"y\""), true)
        XCTAssertEqual(macSection?.contains("\"LeftCommandIsCtrl\"=\"n\""), true)
        XCTAssertLessThan(
            try XCTUnwrap(script.range(of: "[\(macDriver)]")).lowerBound,
            try XCTUnwrap(script.range(of: "[\(overrides)]")).lowerBound
        )
    }

    /// `"name"=-` is how a `.reg` import deletes a value. Without it the DLL-override removals
    /// DXMT depends on would silently become no-ops.
    func testRemovalUsesTheDeletionSyntax() {
        let script = RegistryScript.render([.removingDLLOverride("d3d11")])
        XCTAssertTrue(script.contains("\"d3d11\"=-"))
    }

    func testDWordsAreWrittenAsEightHexDigits() {
        let script = RegistryScript.render([
            RegistryEntry(key: "K", name: "zero", value: .dword(0)),
            RegistryEntry(key: "K", name: "width", value: .dword(1920))
        ])
        XCTAssertTrue(script.contains("\"zero\"=dword:00000000"))
        XCTAssertTrue(script.contains("\"width\"=dword:00000780"))
    }

    func testBackslashesAndQuotesInValuesAreEscaped() {
        let script = RegistryScript.render([
            RegistryEntry(key: "K", name: "path", value: .string(#"C:\windows\system32"#)),
            RegistryEntry(key: "K", name: "quoted", value: .string("say \"hi\""))
        ])
        XCTAssertTrue(script.contains(#""path"="C:\\windows\\system32""#))
        XCTAssertTrue(script.contains(#""quoted"="say \"hi\"""#))
    }

    /// Unity ignores an unknown PlayerPrefs key silently, so the hashed suffixes are load-bearing
    /// and must survive the move from `wine reg add` arguments into `.reg` syntax verbatim.
    func testGenshinPlayerPrefsKeepTheirHashedValueNames() {
        let script = RegistryScript.render([
            RegistryEntry(
                key: #"HKEY_CURRENT_USER\Software\miHoYo\Genshin Impact"#,
                name: "Screenmanager Is Fullscreen mode_h3981298716",
                value: .dword(0)
            )
        ])
        XCTAssertTrue(script.contains("\"Screenmanager Is Fullscreen mode_h3981298716\"=dword:00000000"))
    }

    func testNothingIsRenderedForAnEmptyBatch() {
        XCTAssertFalse(RegistryScript.render([]).contains("["))
    }

    /// DXMT selects its DLLs through WINEDLLPATH, so a leftover native override would shadow them;
    /// DXVK copies its DLLs into the prefix and needs the opposite.
    func testBridgesDeclareTheOverrideDirectionTheyDependOn() {
        let dxmt = DXMTBridge().registryEntries()
        XCTAssertEqual(dxmt.count, 6)
        XCTAssertTrue(dxmt.allSatisfy { if case .remove = $0.value { return true } else { return false } })

        let dxvk = DXVKBridge().registryEntries()
        XCTAssertEqual(dxvk.count, 2)
        XCTAssertTrue(dxvk.allSatisfy {
            if case let .string(value) = $0.value { return value == "native,builtin" } else { return false }
        })
    }
}
