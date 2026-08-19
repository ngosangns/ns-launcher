import XCTest
@testable import NSLauncherApp

final class QuestAssetAnalysisTests: XCTestCase {
    func testClassifiesSupportedRuntimeContainersCaseInsensitively() {
        XCTAssertEqual(
            QuestAssetContainerClassifier.kind(for: "StreamingAssets/312345.BLK"),
            .encryptedBlock
        )
        XCTAssertEqual(
            QuestAssetContainerClassifier.kind(for: "Bundles\\world.Cab"),
            .cabBundle
        )
        XCTAssertEqual(
            QuestAssetContainerClassifier.kind(for: "Bundles/scene.BUNDLE"),
            .assetBundle
        )
        XCTAssertEqual(
            QuestAssetContainerClassifier.kind(for: "Runtime/Asset_Index.bin"),
            .assetIndex
        )
    }

    func testDoesNotInferQuestOwnershipFromUnrelatedPaths() {
        XCTAssertNil(QuestAssetContainerClassifier.kind(for: "Video/opening.usm"))
        XCTAssertNil(QuestAssetContainerClassifier.kind(for: "Runtime/asset_index_backup.bin"))
        XCTAssertNil(QuestAssetContainerClassifier.kind(for: "Runtime/asset_indexed.bin"))
        XCTAssertNil(QuestAssetContainerClassifier.kind(for: "Runtime/QuestData.json"))
    }
}
