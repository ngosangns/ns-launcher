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
                    VStack(alignment: .leading, spacing: 22) {
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
                Image(systemName: character?.element.symbolName ?? "questionmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(character?.element.accentColor ?? LauncherPalette.mist)
                    .frame(width: 16)

                Text(character?.name ?? characterID)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)

                if isOnField {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(LauncherPalette.goldHighlight)
                        .help(text.abyssOnFieldLabel)
                }

                Text(text.abyssRoleLabel(role))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(role.accentColor.opacity(0.85))

                Spacer()

                Text("\(Int((share * 100).rounded()))%")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.7))
                    .help(text.abyssDamageShare)
            }

            HStack(spacing: 6) {
                Text(gearSummary(option))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.6))
                    .lineLimit(1)
            }

            GoldenProgressBar(value: share)
        }
    }

    private func gearSummary(_ option: AbyssGearOption?) -> String {
        guard let option else { return "" }
        let weapon = option.weaponID.flatMap { viewModel.weapon($0)?.name } ?? "—"
        let sets = option.setIDs.compactMap { viewModel.artifactSet($0)?.name }.joined(separator: " + ")
        return sets.isEmpty ? weapon : "\(weapon)  ·  \(sets)"
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
