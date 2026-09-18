// AbyssWeaponPopover.swift
//
// What a recommended weapon's passive actually does, shown on hover — the
// weapon equivalent of AbyssSetEffectPopover. The team panel only ever had
// room for the weapon's name and refinement badge; the passive text and its
// per-refinement numbers explain why the model picked it.

import SwiftUI

struct AbyssWeaponLabel: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText
    let weapon: AbyssWeapon
    /// The refinement the popover should price the passive at: the player's
    /// own copy if they own it, otherwise R1 — the same assumption the rest
    /// of the app makes for gear nobody has confirmed owning.
    let refinement: Int

    @State private var isShowingDetail = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        Text(text.pick(en: weapon.name, vi: weapon.nameVI))
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(RarityAppearance.genshin(weapon.rarity).accent.opacity(0.85))
            .lineLimit(1)
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
                AbyssWeaponCard(weapon: weapon, refinement: refinement, text: text)
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

private struct AbyssWeaponCard: View {
    let weapon: AbyssWeapon
    let refinement: Int
    let text: AppText

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(text.pick(en: weapon.name, vi: weapon.nameVI))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(RarityAppearance.genshin(weapon.rarity).accent)
                Text(text.abyssWeaponTypeLabel(weapon.type))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.6))
            }

            if let passive = weapon.passive {
                if let name = passive.name {
                    Text("\(name) · R\(refinement)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(LauncherPalette.gold.opacity(0.7))
                }
                Text(passive.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(LauncherPalette.parchment.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                if !passive.effects.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(passive.effects.enumerated()), id: \.offset) { _, effect in
                            if let line = text.abyssWeaponEffectLine(effect, refinement: refinement) {
                                Text(line)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LauncherPalette.success.opacity(0.85))
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 300, alignment: .leading)
        .padding(14)
        .background(LauncherPalette.night.opacity(0.96))
    }
}
