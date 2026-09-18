// AbyssResonancePopover.swift
//
// What an elemental resonance actually does, shown on hover — the same reason
// AbyssSetEffectPopover exists for artifact sets: the team panel can only ever
// afford the resonance's name, and "High Voltage" says nothing about what it
// grants without opening the game's own team menu.

import SwiftUI

/// Wraps a team note's resonance label with the same hover-debounce +
/// `.popover` mechanism `AbyssArtifactSetLabel` uses, so leaving/entering the
/// label or the popover itself behaves identically across the app.
struct AbyssResonanceLabel: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText
    let id: String
    let name: String
    let nameVI: String

    @State private var isShowingDetail = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Label(text.pick(en: "Resonance: \(name)", vi: "Cộng hưởng: \(nameVI)"),
              systemImage: "circle.hexagongrid.fill")
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(LauncherPalette.goldHighlight.opacity(0.85))
            .onHover { hovering in
                hoverTask?.cancel()
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(hovering ? 260 : 160))
                    guard !Task.isCancelled else { return }
                    isShowingDetail = hovering
                }
            }
            .onDisappear { hoverTask?.cancel() }
            .popover(isPresented: $isShowingDetail, arrowEdge: .bottom) {
                if let resonance = viewModel.resonance(id) {
                    AbyssResonanceCard(resonance: resonance, text: text)
                        .onHover { hovering in
                            hoverTask?.cancel()
                            guard !hovering else { return }
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(160))
                                guard !Task.isCancelled else { return }
                                isShowingDetail = false
                            }
                        }
                }
            }
    }
}

private struct AbyssResonanceCard: View {
    let resonance: AbyssTeamBonus.Resonance
    let text: AppText

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(text.pick(en: resonance.name, vi: resonance.nameVI))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(LauncherPalette.goldHighlight)

            Text(requirement)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(LauncherPalette.mist.opacity(0.6))

            Text(resonance.description)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(LauncherPalette.parchment.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if !resonance.bonuses.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(resonance.bonuses.enumerated()), id: \.offset) { _, bonus in
                        Text(text.abyssResonanceBonusLine(bonus))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(LauncherPalette.success.opacity(0.85))
                    }
                }
            }
        }
        .frame(width: 300, alignment: .leading)
        .padding(14)
        .background(LauncherPalette.night.opacity(0.96))
    }

    private var requirement: String {
        if resonance.requiresUniqueElements == true {
            return text.abyssResonanceRequirementUnique
        }
        guard let element = resonance.elements.first else { return "" }
        return text.abyssResonanceRequirement(element: element, count: resonance.requiredCount)
    }
}
