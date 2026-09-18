// AbyssTeamMemberPopover.swift
//
// A team used to spend one full-width row per member — portrait, name, role,
// badges, damage share, weapon, artifact advice, and a progress bar, stacked
// down the panel. That is what made two teams side by side impossible: there
// was never room. This collapses a member to just the avatar, in a compact
// cell, and moves everything else into a popover shown on hover — the same
// hover-card idiom as AbyssWeaponLabel and AbyssArtifactSetLabel.

import SwiftUI

struct AbyssTeamMemberCell: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText
    let characterID: String
    let team: AbyssTeamResult

    @State private var isShowingDetail = false
    @State private var hoverTask: Task<Void, Never>?

    private var character: AbyssCharacter? { viewModel.character(characterID) }
    private var option: AbyssGearOption? { team.assignment[characterID] }
    private var isOnField: Bool { characterID == team.onFieldID }

    var body: some View {
        AbyssPortraitImage(url: viewModel.characterIconURL(characterID),
                           systemImage: character?.element.symbolName ?? "questionmark",
                           tint: character?.element.accentColor ?? LauncherPalette.mist,
                           size: 52, cornerRadius: 10)
            .overlay(alignment: .topTrailing) {
                if isOnField {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(LauncherPalette.goldHighlight)
                        .padding(3)
                        .background(LauncherPalette.night.opacity(0.9), in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(viewModel.displayRole(of: characterID, in: team).accentColor.opacity(0.55),
                                 lineWidth: 1.5))
            .contentShape(Rectangle())
            .onHover { hovering in
                hoverTask?.cancel()
                hoverTask = Task {
                    try? await Task.sleep(for: .milliseconds(hovering ? 200 : 160))
                    guard !Task.isCancelled else { return }
                    isShowingDetail = hovering
                }
            }
            .onDisappear { hoverTask?.cancel() }
            .popover(isPresented: $isShowingDetail, arrowEdge: .bottom) {
                detailCard
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

    private var detailCard: some View {
        let role = viewModel.displayRole(of: characterID, in: team)
        let share = viewModel.damageShare(of: characterID, in: team)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AbyssPortraitImage(url: viewModel.characterIconURL(characterID),
                                   systemImage: character?.element.symbolName ?? "questionmark",
                                   tint: character?.element.accentColor ?? LauncherPalette.mist,
                                   size: 34, cornerRadius: 8)

                Text(character.map { text.pick(en: $0.name, vi: $0.nameVI) } ?? characterID)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(character.map { RarityAppearance.genshin($0.rarity).accent }
                        ?? LauncherPalette.parchment)

                if isOnField {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(LauncherPalette.goldHighlight)
                        .help(text.abyssOnFieldLabel)
                }

                Text(text.abyssRoleLabel(role))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(role.accentColor.opacity(0.85))

                if option?.statSource == .measured {
                    Label(text.abyssMeasuredBadge, systemImage: "checkmark.seal.fill")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(LauncherPalette.success.opacity(0.9))
                }

                Spacer()

                Text("\(Int((share * 100).rounded()))%")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.7))
                    .help(text.abyssDamageShare)
            }

            let weapon = option?.weaponID.flatMap { viewModel.weapon($0) }
            HStack(spacing: 6) {
                AbyssPortraitImage(url: option?.weaponID.flatMap { viewModel.weaponIconURL($0) },
                                   systemImage: character?.weaponType.symbolName ?? "wand.and.rays",
                                   tint: LauncherPalette.mist.opacity(0.7),
                                   size: 20, cornerRadius: 5)
                if let weapon {
                    AbyssWeaponLabel(viewModel: viewModel, text: text, weapon: weapon,
                                     refinement: option?.weaponID.map { viewModel.refinement(for: $0) } ?? 1)
                } else {
                    Text("—")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.6))
                }
                if let weaponID = option?.weaponID, viewModel.owns(weaponID: weaponID) {
                    Text("R\(viewModel.refinement(for: weaponID))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.45))
                }
            }

            artifactBlock

            GoldenProgressBar(value: share)
        }
        .frame(width: 280, alignment: .leading)
        .padding(14)
        .background(LauncherPalette.night.opacity(0.96))
    }

    /// The artifact recommendation: which set, what it was worth here, which
    /// main stats, and what to wear instead if the set is not farmed yet.
    @ViewBuilder
    private var artifactBlock: some View {
        let advice = team.artifactAdvice[characterID]
        let setIDs = advice?.setIDs ?? option?.setIDs ?? []

        if !setIDs.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(LauncherPalette.gold.opacity(0.55))
                        .frame(width: 16)
                    AbyssArtifactSetLabel(viewModel: viewModel, text: text,
                                          title: setNames(setIDs), setIDs: setIDs)
                    if let gain = advice?.gainOverNeutralPick, gain > 0.0005 {
                        Text(text.abyssArtifactGain(gain))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(LauncherPalette.success.opacity(0.8))
                    }
                }

                if let advice {
                    Text(mainStatLine(advice))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.55))
                        .lineLimit(1)
                        .padding(.leading, 22)

                    // For an imported character the useful line is not "wear
                    // this" but "this beats what you have, by this much".
                    if !advice.currentSetIDs.isEmpty {
                        Text(text.abyssArtifactUpgrade(from: setNames(advice.currentSetIDs),
                                                       gain: advice.upgradeOverCurrent))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(LauncherPalette.goldHighlight.opacity(0.85))
                            .lineLimit(1)
                            .padding(.leading, 22)
                    } else if option?.statSource == .measured {
                        Text(text.abyssArtifactAlreadyBest(setNames(advice.setIDs)))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(LauncherPalette.success.opacity(0.8))
                            .lineLimit(1)
                            .padding(.leading, 22)
                    }

                    if !advice.alternativeSetIDs.isEmpty {
                        Text(text.abyssArtifactAlternative(setNames(advice.alternativeSetIDs),
                                                           gap: advice.alternativeGap))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.42))
                            .lineLimit(1)
                            .padding(.leading, 22)
                    }
                }
            }
        }
    }

    /// A 4-piece set reads as one name; two 2-piece sets read as a pair.
    private func setNames(_ ids: [String]) -> String {
        let names = ids.map { id in
            viewModel.artifactSet(id).map { text.pick(en: $0.name, vi: $0.nameVI) } ?? id
        }
        return ids.count == 1 ? names.joined() : names.joined(separator: " + ")
    }

    private func mainStatLine(_ advice: AbyssArtifactAdvice) -> String {
        let slots = [
            "\(text.abyssSandsSlot) \(text.abyssMainStatName(advice.sands))",
            "\(text.abyssGobletSlot) \(text.abyssMainStatName(advice.goblet))",
            "\(text.abyssCircletSlot) \(text.abyssMainStatName(advice.circlet))",
        ].joined(separator: " · ")
        let substats = advice.substatPriority.prefix(3).map { key -> String in
            let name = text.abyssSubstatName(key)
            guard let gain = advice.substatMarginalGain[key], gain > 0.0001 else { return name }
            return text.abyssSubstatWithGain(name, gain: gain)
        }.joined(separator: " > ")
        return substats.isEmpty ? slots : "\(slots)  ·  \(text.abyssSubstatsLabel) \(substats)"
    }
}
