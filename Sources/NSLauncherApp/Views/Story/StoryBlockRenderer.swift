// StoryBlockRenderer.swift
//
// Renders `[StoryBlock]` (see `StoryMarkdownParser`) as SwiftUI views. Inline
// text has already had entity mentions rewritten as `story://entity/<id>`
// links by `StoryEntityLinker`; this file only needs to style them.

import SwiftUI

/// One block's markdown, ready for `Text`. Links are restyled gold/underlined
/// so they read as interactive against the celestial theme instead of the
/// system's default blue.
private func styledText(_ markdown: String) -> Text {
    var attributed = (try? AttributedString(
        markdown: markdown,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(markdown)

    for run in attributed.runs {
        if run.link != nil {
            attributed[run.range].foregroundColor = LauncherPalette.goldHighlight
            attributed[run.range].underlineStyle = .single
        } else if attributed[run.range].foregroundColor == nil {
            attributed[run.range].foregroundColor = LauncherPalette.parchment.opacity(0.92)
        }
    }
    return Text(attributed)
}

struct StoryBlocksView: View {
    let blocks: [StoryBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                StoryBlockView(block: block)
            }
        }
    }
}

private struct StoryBlockView: View {
    let block: StoryBlock

    var body: some View {
        switch block {
        case .paragraph(let text):
            styledText(text.markdown)
                .font(.system(.body, design: .rounded))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

        case .callout(let kind, let text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(kind.accentColor.opacity(0.85))
                    .frame(width: 3)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: kind.systemImage)
                        .font(.callout)
                        .foregroundStyle(kind.accentColor)
                        .padding(.top, 2)
                    styledText(text.markdown)
                        .font(.system(.callout, design: .rounded))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(LauncherPalette.ink.opacity(0.32), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        case .table(let headers, let rows):
            StoryTableView(headers: headers, rows: rows)

        case .list(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundStyle(LauncherPalette.gold)
                        styledText(item.markdown)
                            .font(.system(.callout, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .tree(let lines):
            Text(lines.joined(separator: "\n"))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(LauncherPalette.mist.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(LauncherPalette.ink.opacity(0.32), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// A minimal grid table — bundled quest tables are small enough (a handful
/// to a few dozen rows) that a full data-grid component would be overkill.
private struct StoryTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(LauncherPalette.gold)
                }
            }
            GridRow {
                Divider().gridCellColumns(max(headers.count, 1))
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        styledText(cell)
                            .font(.system(.callout, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .background(LauncherPalette.ink.opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
