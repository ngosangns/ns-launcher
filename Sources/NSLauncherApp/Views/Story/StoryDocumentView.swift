// StoryDocumentView.swift
//
// Renders one bundled chapter or quest-reference file top to bottom. Each
// section carries `.id(section.id)` so `StoryView` can scroll a specific
// section into view when a link names one (see `StoryViewModel.selection`).

import SwiftUI

struct StoryDocumentView: View {
    let document: StoryDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 10) {
                Image(systemName: document.kind.systemImage)
                    .foregroundStyle(LauncherPalette.goldHighlight)
                Text(document.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(LauncherPalette.parchment)
            }

            ForEach(document.sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    if !section.heading.isEmpty {
                        Text(section.heading)
                            .font(headingFont(for: section.level))
                            .foregroundStyle(LauncherPalette.goldHighlight)
                    }
                    StoryBlocksView(blocks: section.blocks)
                }
                .id(section.id)
            }
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 2: return .system(.title3, design: .rounded, weight: .bold)
        default: return .system(.headline, design: .rounded, weight: .semibold)
        }
    }
}
