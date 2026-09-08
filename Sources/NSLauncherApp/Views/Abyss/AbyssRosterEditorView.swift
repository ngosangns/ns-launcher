// AbyssRosterEditorView.swift
//
// Grid of everything the player might own, split into characters and weapons.
//
// Both grids are lazy: 125 characters and 246 weapons are far past the point
// where SwiftUI wants to lay them all out eagerly.

import SwiftUI

struct AbyssRosterEditorView: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.roster.isEmpty {
                emptyState
            }

            ScrollView(showsIndicators: false) {
                switch viewModel.rosterTab {
                case .characters: characterGrid
                case .weapons: weaponList
                }
            }
        }
        .frame(maxWidth: 900, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SidebarTabButton(title: text.abyssCharactersTab, systemImage: "person.fill",
                                 isSelected: viewModel.rosterTab == .characters) {
                    viewModel.rosterTab = .characters
                }
                SidebarTabButton(title: text.abyssWeaponsTab, systemImage: "wand.and.rays",
                                 isSelected: viewModel.rosterTab == .weapons) {
                    viewModel.rosterTab = .weapons
                }
                .fixedSize()

                Spacer()

                if viewModel.rosterTab == .weapons {
                    Button { viewModel.addEveryFourStarWeapon() } label: {
                        Label(text.abyssSelectAllFourStar, systemImage: "plus.circle")
                    }
                    .quest(.quiet)
                }
                Button { viewModel.clearRoster() } label: {
                    Label(text.abyssClearRoster, systemImage: "trash")
                }
                .quest(.quiet, disabled: viewModel.roster.isEmpty)
            }

            Text(text.abyssConstellationNotScored)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(LauncherPalette.warning.opacity(0.75))
        }
    }

    private var emptyState: some View {
        OrnamentalPanel(padding: 16, showsMark: false) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text.abyssEmptyRosterTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(LauncherPalette.parchment)
                Text(text.abyssEmptyRosterHint)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var characterGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(viewModel.characters, id: \.id) { character in
                let owned = viewModel.owns(characterID: character.id)
                RosterCard(
                    title: character.name,
                    subtitle: "\(text.abyssElementLabel(character.element)) · \(text.abyssWeaponTypeLabel(character.weaponType))",
                    systemImage: character.element.symbolName,
                    accent: character.element.accentColor,
                    isSelected: owned,
                    level: owned
                        ? (value: viewModel.roster.constellation(for: character.id) ?? 0, range: 0...6, label: "C")
                        : nil,
                    onToggle: { viewModel.toggleCharacter(character.id) },
                    onLevelChange: { viewModel.setConstellation($0, for: character.id) })
            }
        }
    }

    private var weaponList: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.weaponsByType, id: \.type) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(text.abyssWeaponTypeLabel(group.type).uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(LauncherPalette.gold.opacity(0.88))

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(group.weapons, id: \.id) { weapon in
                            let owned = viewModel.owns(weaponID: weapon.id)
                            RosterCard(
                                title: weapon.name,
                                subtitle: String(repeating: "★", count: weapon.rarity),
                                systemImage: weapon.type.symbolName,
                                accent: LauncherPalette.goldHighlight,
                                isSelected: owned,
                                level: owned
                                    ? (value: viewModel.roster.refinement(for: weapon.id), range: 1...5, label: "R")
                                    : nil,
                                onToggle: { viewModel.toggleWeapon(weapon.id) },
                                onLevelChange: { viewModel.setRefinement($0, for: weapon.id) })
                        }
                    }
                }
            }
        }
    }
}
