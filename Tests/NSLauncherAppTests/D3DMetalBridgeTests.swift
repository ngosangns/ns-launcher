import XCTest
@testable import NSLauncherApp

final class D3DMetalBridgeTests: XCTestCase {
    /// The directory D3DMetal's own shader cache lives under, keyed by executable name — see
    /// `D3DMetalBridge.shaderCacheDirectory`. Confirmed against a real cache directory found on
    /// disk at `$(confstr DARWIN_USER_CACHE_DIR)/d3dm/GenshinImpact.exe/shaders.cache/`.
    func testShaderCacheDirectoryIsKeyedByExecutableNameUnderTheDarwinUserCacheDirectory() {
        guard let directory = D3DMetalBridge.shaderCacheDirectory(forExecutable: "GenshinImpact.exe") else {
            return XCTFail("Darwin user cache directory should always resolve on macOS")
        }
        XCTAssertEqual(directory.lastPathComponent, "GenshinImpact.exe")
        XCTAssertEqual(directory.deletingLastPathComponent().lastPathComponent, "d3dm")
    }

    func testShaderCacheDirectoryDiffersPerExecutable() {
        let genshin = D3DMetalBridge.shaderCacheDirectory(forExecutable: "GenshinImpact.exe")
        let other = D3DMetalBridge.shaderCacheDirectory(forExecutable: "ZFGameBrowser.exe")
        XCTAssertNotEqual(genshin, other)
    }
}
