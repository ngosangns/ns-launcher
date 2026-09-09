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
                // Both hug their labels. Only the weapons button did, so the
                // characters one grew to fill the row and the pair read as a
                // banner rather than as two tabs.
                SidebarTabButton(title: text.abyssCharactersTab, systemImage: "person.fill",
                                 isSelected: viewModel.rosterTab == .characters) {
                    viewModel.rosterTab = .characters
                }
                .fixedSize()
                SidebarTabButton(title: text.abyssWeaponsTab, systemImage: "wand.and.rays",
                                 isSelected: viewModel.rosterTab == .weapons) {
                    viewModel.rosterTab = .weapons
                }
                .fixedSize()

                Spacer(minLength: 0)

                // Whichever tab is open, not both counts at once: this used to
                // live in the sidebar as "X characters · Y weapons" regardless
                // of what was on screen, which said something about the tab
                // that was not showing.
                Text(viewModel.rosterTab == .characters
                        ? text.abyssOwnedCharacterCount(viewModel.roster.characters.count)
                        : text.abyssOwnedWeaponCount(viewModel.roster.weapons.count))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.62))
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

    /// Chips, sort and the owned switch on one line when they fit, and on two
    /// when they do not.
    ///
    /// They do not always fit: seven element chips plus a sort label plus its
    /// direction runs to roughly 540pt, and Vietnamese is the longer of the two
    /// languages ("Ngày ra mắt · mới nhất trước"). Measuring that budget by hand
    /// would only hold until the next string, so the row is asked to lay itself
    /// out instead.
    private var filterRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                typeChips
                sortPicker
                ownedOnlyToggle
                clearTabButton
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    typeChips
                    ownedOnlyToggle
                    clearTabButton
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    sortPicker
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Clears only the tab currently showing — a separate action per tab
    /// rather than one button that empties both, since a slip of the mouse on
    /// the weapons tab should not cost the whole character roster.
    private var clearTabButton: some View {
        let isEmpty = viewModel.rosterTab == .characters
            ? viewModel.roster.characters.isEmpty
            : viewModel.roster.weapons.isEmpty
        let label = viewModel.rosterTab == .characters ? text.abyssClearCharacters : text.abyssClearWeapons

        return Button {
            switch viewModel.rosterTab {
            case .characters: viewModel.clearCharacters()
            case .weapons: viewModel.clearWeapons()
            }
        } label: {
            Label(label, systemImage: "trash")
        }
        .quest(.quiet, disabled: isEmpty)
    }

    @ViewBuilder
    private var typeChips: some View {
        if viewModel.rosterTab == .characters {
            elementFilterChips
        } else {
            weaponTypeFilterChips
        }
    }

    private var ownedOnlyToggle: some View {
        Toggle(text.abyssOwnedOnly, isOn: $viewModel.showsOwnedOnly)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(LauncherPalette.gold)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(LauncherPalette.mist.opacity(0.8))
            .fixedSize()
    }

    /// The options differ per tab — a weapon has no element and a character has
    /// no base ATK — so the menu is rebuilt from whichever tab is showing, and
    /// switching tabs falls back to name order rather than leaving an option
    /// selected that no longer means anything.
    private var sortPicker: some View {
        let options = AbyssViewModel.RosterSort.options(for: viewModel.rosterTab)
        return HStack(spacing: 4) {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        viewModel.rosterSort = option
                    } label: {
                        if viewModel.rosterSort == option {
                            Label(text.abyssSortLabel(option), systemImage: "checkmark")
                        } else {
                            Text(text.abyssSortLabel(option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9, weight: .semibold))
                    Text(text.abyssSortLabel(viewModel.rosterSort))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(LauncherPalette.mist.opacity(0.85))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(LauncherPalette.night.opacity(0.36),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .pointerOnHover()

            // The direction reads as its two ends rather than as an abstract
            // "descending": 5★ → 1★ says what will happen, "descending" does not.
            Button {
                viewModel.sortDescending.toggle()
            } label: {
                Text(text.abyssSortDirection(viewModel.rosterSort, descending: viewModel.sortDescending))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.gold.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LauncherPalette.night.opacity(0.36),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .pointerOnHover()
            .help(text.abyssFlipSortDirection)
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
                    title: text.pick(en: character.name, vi: character.nameVI),
                    // Element and weapon type used to live here as text; the
                    // element now reads from the left border instead, and the
                    // weapon type was not worth a field of its own.
                    subtitle: measured ? text.abyssMeasuredBadge : "",
                    isSelected: owned,
                    level: owned
                        ? (value: viewModel.constellation(for: character.id), range: 0...6, label: "C")
                        : nil,
                    rarity: .genshin(character.rarity),
                    leadingAccent: character.element.accentColor,
                    icon: {
                        AbyssPortraitImage(url: viewModel.characterIconURL(character.id),
                                          systemImage: character.element.symbolName,
                                          tint: owned ? LauncherPalette.ink.opacity(0.75) : character.element.accentColor,
                                          size: 54, cornerRadius: 14)
                    },
                    onToggle: { viewModel.toggleCharacter(character.id) },
                    onLevelChange: { viewModel.setConstellation($0, for: character.id) })
            }
        }
    }

    private var weaponList: some View {
        // Flat, not grouped by weapon type: the type chips above already filter
        // to one type when that is what someone wants, and a flat list is what
        // lets the "sort by stars" default put every 5★ weapon together
        // regardless of type instead of scattering them across six headers.
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(viewModel.weapons, id: \.id) { weapon in
                let owned = viewModel.owns(weaponID: weapon.id)
                let rarity = RarityAppearance.genshin(weapon.rarity)
                RosterCard(
                    // The type no longer has a group header to live in, so it
                    // moves into the subtitle, the way a character's does.
                    title: text.pick(en: weapon.name, vi: weapon.nameVI),
                    subtitle: text.abyssWeaponTypeLabel(weapon.type),
                    isSelected: owned,
                    level: owned
                        ? (value: viewModel.refinement(for: weapon.id), range: 1...5, label: "R")
                        : nil,
                    rarity: rarity,
                    icon: {
                        AbyssPortraitImage(url: viewModel.weaponIconURL(weapon.id),
                                           systemImage: weapon.type.symbolName,
                                           tint: owned ? LauncherPalette.ink.opacity(0.75) : rarity.accent,
                                           size: 54, cornerRadius: 14)
                    },
                    onToggle: { viewModel.toggleWeapon(weapon.id) },
                    onLevelChange: { viewModel.setRefinement($0, for: weapon.id) })
            }
        }
    }
}
