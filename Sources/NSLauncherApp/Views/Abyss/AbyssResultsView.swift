// AbyssResultsView.swift
//
// The suggested teams, grouped by floor. Each team is one panel: its members in
// damage order, the gear the engine picked for them, and the notes explaining
// why the score came out where it did.

import SwiftUI

struct AbyssResultsView: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText

    var body: some View {
        Group {
            if viewModel.reports.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    // Lazy: a full run is four floors of five teams of four
                    // members, and every member row carries two portraits and a
                    // handful of formatted strings. Building all of them to show
                    // the first screenful is what made opening this section
                    // hitch.
                    LazyVStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(text.abyssArtifactAdviceNotice, systemImage: "seal")
                            if viewModel.showcase != nil {
                                Label(text.abyssShowcaseNotice, systemImage: "checkmark.seal")
                            }
                        }
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)

                        ForEach(viewModel.reports) { report in
                            floorSection(report)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 900, alignment: .leading)
    }

    private var emptyState: some View {
        OrnamentalPanel(padding: 16, showsMark: false) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text.abyssNoResultsYet)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(LauncherPalette.parchment)
                Text(text.abyssNoResultsHint)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.75))
            }
        }
    }

    private func floorSection(_ report: AbyssFloorReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(text.abyssFloorTitle(report.floor))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(LauncherPalette.goldHighlight)
                Text(text.abyssMonsterLevel(report.monsterLevel))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.7))
                Spacer()
            }

            // The floor's own modifiers, so a surprising ranking can be traced
            // back to the sentence that caused it.
            if !report.buffs.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(report.buffs.enumerated()), id: \.offset) { _, buff in
                        Text("+\(Int((buff.bonus * 100).rounded()))%  \(buff.raw)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.55))
                            .lineLimit(2)
                    }
                }
            }

            ForEach(Array(report.teams.enumerated()), id: \.element.id) { index, team in
                teamPanel(rank: index + 1, team: team)
            }
        }
    }

    private func teamPanel(rank: Int, team: AbyssTeamResult) -> some View {
        OrnamentalPanel(padding: 16, showsMark: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("#\(rank)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(LauncherPalette.goldHighlight)

                    // What re-picking the artifacts for this floor was worth.
                    if team.artifactGain > 0.0005 {
                        Text(text.abyssTeamArtifactGain(team.artifactGain))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(LauncherPalette.success.opacity(0.85))
                    }

                    Spacer()
                    Text(Self.scoreFormatter.string(from: NSNumber(value: team.score)) ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.7))
                }

                // Members in damage order rather than team order: the reader
                // wants to know who is carrying.
                ForEach(orderedMembers(of: team), id: \.self) { characterID in
                    memberRow(characterID: characterID, team: team)
                }

                if !team.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(team.notes.enumerated()), id: \.offset) { _, note in
                            Label(text.abyssTeamNote(note), systemImage: note.symbolName)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(note.accentColor.opacity(0.85))
                        }
                    }
                }
            }
        }
    }

    private func memberRow(characterID: String, team: AbyssTeamResult) -> some View {
        let character = viewModel.character(characterID)
        let option = team.assignment[characterID]
        let role = viewModel.displayRole(of: characterID, in: team)
        let share = viewModel.damageShare(of: characterID, in: team)
        let isOnField = characterID == team.onFieldID

        return VStack(alignment: .leading, spacing: 4) {
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

                // Measured or modelled. Never left implicit: the same number
                // means something different depending on which it is.
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

            // The weapon is tinted by its rarity too: "which of my 5★ is this
            // team asking for" is the first thing anyone checks.
            let weapon = option?.weaponID.flatMap { viewModel.weapon($0) }
            HStack(spacing: 6) {
                AbyssPortraitImage(url: option?.weaponID.flatMap { viewModel.weaponIconURL($0) },
                                   systemImage: character?.weaponType.symbolName ?? "wand.and.rays",
                                   tint: LauncherPalette.mist.opacity(0.7),
                                   size: 20, cornerRadius: 5)
                Text(weapon.map { text.pick(en: $0.name, vi: $0.nameVI) } ?? "—")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(weapon.map { RarityAppearance.genshin($0.rarity).accent.opacity(0.85) }
                        ?? LauncherPalette.mist.opacity(0.6))
                    .lineLimit(1)
                // Only for a weapon the player actually owns: `refinement(for:)`
                // answers R1 for anything it has never seen, and printing that
                // next to a weapon from a full-roster search would read as a
                // claim about their account.
                if let weaponID = option?.weaponID, viewModel.owns(weaponID: weaponID) {
                    Text("R\(viewModel.refinement(for: weaponID))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.45))
                }
            }

            artifactBlock(characterID: characterID, team: team)

            GoldenProgressBar(value: share)
        }
    }

    /// The artifact recommendation: which set, what it was worth here, which
    /// main stats, and what to wear instead if the set is not farmed yet.
    @ViewBuilder
    private func artifactBlock(characterID: String, team: AbyssTeamResult) -> some View {
        let advice = team.artifactAdvice[characterID]
        let setIDs = advice?.setIDs ?? team.assignment[characterID]?.setIDs ?? []

        if !setIDs.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(LauncherPalette.gold.opacity(0.55))
                        .frame(width: 16)
                    Text(setNames(setIDs))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(LauncherPalette.parchment.opacity(0.82))
                        .lineLimit(1)
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
                    } else if team.assignment[characterID]?.statSource == .measured {
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
        let substats = advice.substatPriority.prefix(3).map { text.abyssSubstatName($0) }.joined(separator: " > ")
        return substats.isEmpty ? slots : "\(slots)  ·  \(text.abyssSubstatsLabel) \(substats)"
    }

    private func orderedMembers(of team: AbyssTeamResult) -> [String] {
        team.memberIDs.sorted {
            (team.perCharacterDamage[$0] ?? 0) > (team.perCharacterDamage[$1] ?? 0)
        }
    }

    private static let scoreFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
