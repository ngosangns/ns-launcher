// StoryEntityDetailView.swift
//
// The "hub" page a `story://entity/<id>` link opens: the entity's own
// summary, then every narrative chapter section that mentions it rendered
// inline (chapters only ever hold paragraph/callout blocks, so this never
// dumps a quest table), plus a plain link list into the quest reference
// files that mention it.

import SwiftUI

struct StoryEntityDetailView: View {
    let entity: StoryEntity
    let occurrences: [StoryOccurrence]
    let library: StoryLibrary
    let text: AppText
    let onSelectDocument: (String, String?) -> Void

    private var chapterOccurrences: [StoryOccurrence] {
        occurrences.filter { $0.documentKind == .narrativeChapter }
    }

    private var questOccurrences: [StoryOccurrence] {
        occurrences.filter { $0.documentKind == .questReference }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            summary
            if !chapterOccurrences.isEmpty {
                sectionLabel(text.storyAppearsInLabel)
                ForEach(chapterOccurrences) { occurrence in
                    excerptCard(occurrence)
                }
            }
            if !questOccurrences.isEmpty {
                sectionLabel(text.storyRelatedQuestsLabel)
                VStack(spacing: 4) {
                    ForEach(questOccurrences) { occurrence in
                        questLinkRow(occurrence)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: entity.kind.systemImage)
                    .foregroundStyle(LauncherPalette.goldHighlight)
                Text(entity.displayName)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(LauncherPalette.parchment)
                Text(text.storyEntityKindLabel(entity.kind).uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(LauncherPalette.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LauncherPalette.gold.opacity(0.82), in: Capsule())
            }
            if !entity.aliases.isEmpty {
                Text("\(text.storyAlsoKnownAsLabel): \(entity.aliases.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.75))
            }
        }
    }

    private var summary: some View {
        Text(entity.summary?.isEmpty == false ? entity.summary! : text.storyNoSummaryLabel)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(LauncherPalette.parchment.opacity(0.92))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(LauncherPalette.gold.opacity(0.88))
            .padding(.top, 6)
    }

    private func excerptCard(_ occurrence: StoryOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onSelectDocument(occurrence.documentID, occurrence.sectionID)
            } label: {
                HStack(spacing: 6) {
                    Text(occurrence.documentTitle)
                    if !occurrence.sectionHeading.isEmpty {
                        Text("· \(occurrence.sectionHeading)")
                    }
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(LauncherPalette.goldHighlight)
            }
            .buttonStyle(.plain)
            .pointerOnHover()

            if let section = sectionBlocks(for: occurrence) {
                StoryBlocksView(blocks: section)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherPalette.ink.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private func questLinkRow(_ occurrence: StoryOccurrence) -> some View {
        Button {
            onSelectDocument(occurrence.documentID, occurrence.sectionID)
        } label: {
            InventoryRow(
                icon: occurrence.documentKind.systemImage,
                title: occurrence.documentTitle,
                subtitleLines: occurrence.sectionHeading.isEmpty ? [] : [occurrence.sectionHeading]
            ) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .pointerOnHover()
    }

    // Chapters only ever contain paragraph/callout blocks (see
    // `StoryMarkdownParser`), so no table/list/tree filtering is needed here.
    private func sectionBlocks(for occurrence: StoryOccurrence) -> [StoryBlock]? {
        library.documentsByID[occurrence.documentID]?
            .sections.first { $0.id == occurrence.sectionID }?
            .blocks
    }
}
