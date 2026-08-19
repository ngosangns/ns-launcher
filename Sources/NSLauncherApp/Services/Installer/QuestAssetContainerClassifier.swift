// QuestAssetContainerClassifier.swift
//
// Classifies runtime container paths for read-only storage reporting. A container
// format is not evidence that the file belongs to any quest or chapter.

import Foundation

enum QuestAssetContainerClassifier {
    static func kind(for relativePath: String) -> QuestAssetContainerKind? {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard let fileName = normalized.split(separator: "/").last, !fileName.isEmpty else {
            return nil
        }

        let lowercasedName = fileName.lowercased()
        let baseName = URL(fileURLWithPath: lowercasedName).deletingPathExtension().lastPathComponent
        if baseName == "asset_index" {
            return .assetIndex
        }

        guard let dot = lowercasedName.lastIndex(of: ".") else { return nil }
        switch lowercasedName[lowercasedName.index(after: dot)...] {
        case "blk": return .encryptedBlock
        case "cab": return .cabBundle
        case "bundle": return .assetBundle
        default: return nil
        }
    }
}
