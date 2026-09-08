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
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.roster.isEmpty {
                emptyState
            }

            if viewModel.visibleCount == 0 && viewModel.hasActiveFilter {
                noMatchesState
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

            searchRow
            filterRow

            Text(text.abyssConstellationNotScored)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(LauncherPalette.warning.opacity(0.75))
        }
    }

    /// 125 characters and 246 weapons: without a search box the grid is a
    /// scrolling wall, and the point of the tab is to mark the dozen you own.
    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.55))

                TextField(viewModel.rosterTab == .characters
                            ? text.abyssSearchCharacters
                            : text.abyssSearchWeapons,
                          text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(LauncherPalette.parchment)
                    .focused($isSearchFocused)
                    .onSubmit { isSearchFocused = false }

                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .pointerOnHover()
                    .help(text.abyssClearSearch)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(LauncherPalette.night.opacity(0.42),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSearchFocused
                                    ? LauncherPalette.gold.opacity(0.5)
                                    : LauncherPalette.gold.opacity(0.16),
                                  lineWidth: 1))
            .frame(maxWidth: 320)

            Text(text.abyssShowingCount(shown: viewModel.visibleCount, total: viewModel.totalCount))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(LauncherPalette.mist.opacity(0.55))

            if viewModel.hasActiveFilter {
                Button { viewModel.clearFilters() } label: {
                    Label(text.abyssClearFilters, systemImage: "line.3.horizontal.decrease.circle")
                }
                .quest(.quiet)
            }

            Spacer(minLength: 0)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            if viewModel.rosterTab == .characters {
                elementFilterChips
            } else {
                weaponTypeFilterChips
            }

            Toggle(text.abyssOwnedOnly, isOn: $viewModel.showsOwnedOnly)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(LauncherPalette.gold)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(LauncherPalette.mist.opacity(0.8))
                .fixedSize()

            Spacer(minLength: 0)
        }
    }

    private var elementFilterChips: some View {
        HStack(spacing: 5) {
            ForEach(GenshinElement.allCases, id: \.self) { element in
                let isSelected = viewModel.elementFilter == element
                Button {
                    viewModel.elementFilter = isSelected ? nil : element
                } label: {
                    Image(systemName: element.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? LauncherPalette.ink : element.accentColor.opacity(0.85))
                        .frame(width: 26, height: 22)
                        .background(isSelected ? element.accentColor : LauncherPalette.night.opacity(0.36),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .help(text.abyssElementLabel(element))
            }
        }
    }

    private var weaponTypeFilterChips: some View {
        HStack(spacing: 5) {
            ForEach(WeaponType.allCases, id: \.self) { type in
                let isSelected = viewModel.weaponTypeFilter == type
                Button {
                    viewModel.weaponTypeFilter = isSelected ? nil : type
                } label: {
                    Image(systemName: type.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? LauncherPalette.ink : LauncherPalette.gold.opacity(0.85))
                        .frame(width: 26, height: 22)
                        .background(isSelected ? LauncherPalette.goldHighlight : LauncherPalette.night.opacity(0.36),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .help(text.abyssWeaponTypeLabel(type))
            }
        }
    }

    private var noMatchesState: some View {
        OrnamentalPanel(padding: 14, showsMark: false) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(LauncherPalette.mist.opacity(0.6))
                Text(text.abyssNoMatches)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.78))
                Spacer(minLength: 0)
                Button { viewModel.clearFilters() } label: {
                    Text(text.abyssClearFilters)
                }
                .quest(.quiet)
            }
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
                let measured = viewModel.isMeasured(character.id)
                RosterCard(
                    title: character.name,
                    subtitle: measured
                        ? "\(text.abyssElementLabel(character.element)) · \(text.abyssMeasuredBadge)"
                        : "\(text.abyssElementLabel(character.element)) · \(text.abyssWeaponTypeLabel(character.weaponType))",
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
