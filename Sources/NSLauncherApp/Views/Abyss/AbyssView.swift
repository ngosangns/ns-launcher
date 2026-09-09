// AbyssView.swift
//
// Root of the Abyss tab: a sidebar (showcase import and the notices) and a
// detail pane whose own top row switches between Roster and Results, mirroring
// StoryView's split so the tab sits in the app's custom chrome rather than a
// native NavigationSplitView.

import AppKit
import SwiftUI

struct AbyssView: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 268)
                .frame(maxHeight: .infinity, alignment: .top)
                // Leading/trailing must clear WindowFrameOrnament's corner brackets, which occupy a
                // 16-40pt band from each window edge — see HomeView's matching comment.
                .padding(.leading, 44)
                .padding(.trailing, 18)
                .padding(.vertical, 28)

            detail
                .padding(.trailing, 44)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            cycleBanner

            if viewModel.library == nil {
                ProgressView(text.abyssLoadingLabel)
                    .tint(LauncherPalette.gold)
                    .foregroundStyle(LauncherPalette.mist)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        uidImport
                        hoyolabImport
                        unknownIDsWarning
                        methodologyNotice
                    }
                }
                .frame(maxHeight: .infinity)

                // Pinned below the scroll area rather than inside it, together
                // with the toggles that decide what it searches over: these are
                // the last things anyone touches before pressing it, and none
                // of the three should need scrolling past the showcase and
                // legal notices to reach.
                fullPoolToggles
                findTeamsButton
            }
        }
    }

    private var fullPoolToggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Searching and filtering belong to the roster grid, so they live
            // there; these change what the search *runs over*, which is an
            // action, not a filter — independent per kind, so "any weapon" can
            // be paired with "owned characters only", or the reverse.
            Toggle(text.abyssUseFullRoster, isOn: $viewModel.usesFullCharacterPool)
                .toggleStyle(.switch)
                .tint(LauncherPalette.gold)
            Toggle(text.abyssUseFullWeaponPool, isOn: $viewModel.usesFullWeaponPool)
                .toggleStyle(.switch)
                .tint(LauncherPalette.gold)
        }
        .font(.system(.caption, design: .rounded, weight: .semibold))
        .foregroundStyle(LauncherPalette.mist)
    }

    private var findTeamsButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.isSearching {
                GoldenProgressBar(value: viewModel.progress > 0 ? viewModel.progress : nil)
                Text(text.abyssRecomputing)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.7))
            }

            Button {
                viewModel.isSearching ? viewModel.cancelSearch() : viewModel.search()
            } label: {
                Label(viewModel.isSearching ? text.abyssCancel : text.abyssRecompute,
                      systemImage: viewModel.isSearching ? "stop.fill" : "sparkle.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .quest(.primary, disabled: !viewModel.canSearch && !viewModel.isSearching)
        }
        .padding(.top, 8)
    }

    /// Fetching a showcase needs nothing but the UID: its first digit is the
    /// region, so there is no server to choose.
    private var uidImport: some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider().overlay(LauncherPalette.gold.opacity(0.15))

            Text(text.abyssImportFromUID.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(LauncherPalette.gold.opacity(0.88))

            HStack(spacing: 6) {
                TextField(text.abyssUIDPlaceholder, text: $viewModel.uid)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LauncherPalette.parchment)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(LauncherPalette.night.opacity(0.42),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit { viewModel.importFromUID() }

                Button {
                    viewModel.isImporting ? viewModel.cancelImport() : viewModel.importFromUID()
                } label: {
                    Image(systemName: viewModel.isImporting ? "stop.fill" : "arrow.down.circle")
                }
                .quest(.quiet, disabled: !viewModel.canImport && !viewModel.isImporting)
            }

            if viewModel.isImporting {
                Text(text.abyssFetching)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.7))
            }

            if let status = viewModel.importStatus {
                HStack(alignment: .top, spacing: 5) {
                    Text(message(for: status))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(isFailure(status)
                            ? LauncherPalette.warning.opacity(0.9)
                            : LauncherPalette.success.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    if isFailure(status) {
                        CopyIconButton(value: message(for: status),
                                       tint: LauncherPalette.warning,
                                       help: text.abyssCopyErrorHelp)
                    }
                }
            }

            if let showcase = viewModel.showcase {
                Text(text.abyssShowcaseFetchedAt(Self.timestamp.string(from: showcase.fetchedAt)))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.5))

                if !showcase.unmappedIDs.isEmpty {
                    Text(text.abyssShowcaseUnmapped(showcase.unmappedIDs))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(LauncherPalette.warning.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(text.abyssUIDHint)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(LauncherPalette.mist.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The Showcase above is capped at eight and needs no login; this is the
    /// opposite trade — every character the player owns, at the cost of their
    /// own HoYoLAB session. Kept as its own block rather than folded into
    /// `uidImport` so that trade stays visible instead of looking like one
    /// more field the UID import happens to want.
    private var hoyolabImport: some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider().overlay(LauncherPalette.gold.opacity(0.15))

            Text(text.abyssImportFullRoster.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(LauncherPalette.gold.opacity(0.88))

            HStack(spacing: 6) {
                SecureField(text.abyssLtuidPlaceholder, text: $viewModel.hoyolabLtuid)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LauncherPalette.parchment)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(LauncherPalette.night.opacity(0.42),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                CopyIconButton(value: text.abyssLtuidPlaceholder,
                               help: text.abyssCopyTokenNameHelp(text.abyssLtuidPlaceholder))
            }

            HStack(spacing: 6) {
                SecureField(text.abyssLtokenPlaceholder, text: $viewModel.hoyolabLtoken)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LauncherPalette.parchment)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(LauncherPalette.night.opacity(0.42),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onSubmit { viewModel.importFullRosterFromHoyolab() }

                CopyIconButton(value: text.abyssLtokenPlaceholder,
                               help: text.abyssCopyTokenNameHelp(text.abyssLtokenPlaceholder))

                Button {
                    viewModel.isImportingFullRoster
                        ? viewModel.cancelFullRosterImport()
                        : viewModel.importFullRosterFromHoyolab()
                } label: {
                    Image(systemName: viewModel.isImportingFullRoster ? "stop.fill" : "arrow.down.circle")
                }
                .quest(.quiet, disabled: !viewModel.canImportFullRoster && !viewModel.isImportingFullRoster)
            }

            if viewModel.isImportingFullRoster {
                Text(text.abyssFetching)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.7))
            }

            if let status = viewModel.fullRosterImportStatus {
                HStack(alignment: .top, spacing: 5) {
                    Text(message(for: status))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(isFailure(status)
                            ? LauncherPalette.warning.opacity(0.9)
                            : LauncherPalette.success.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    if isFailure(status) {
                        CopyIconButton(value: message(for: status),
                                       tint: LauncherPalette.warning,
                                       help: text.abyssCopyErrorHelp)
                    }
                }
            }

            Text(text.abyssHoyolabHint)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(LauncherPalette.mist.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func message(for status: AbyssViewModel.FullRosterImportStatus) -> String {
        switch status {
        case .imported(let count):
            return text.abyssFullRosterImported(count)
        case .failed(let error):
            return text.abyssHoyolabError(error)
        case .failedOther(let message):
            return message
        }
    }

    private func isFailure(_ status: AbyssViewModel.FullRosterImportStatus) -> Bool {
        switch status {
        case .imported: return false
        case .failed, .failedOther: return true
        }
    }

    private func message(for status: AbyssViewModel.ImportStatus) -> String {
        switch status {
        case .imported(let nickname, let count):
            return text.abyssShowcaseSummary(nickname: nickname, count: count)
        case .tooSoon(let seconds):
            return text.abyssShowcaseTooSoon(seconds)
        case .failed(let error):
            return text.abyssEnkaError(error)
        case .failedOther(let message):
            return message
        }
    }

    private func isFailure(_ status: AbyssViewModel.ImportStatus) -> Bool {
        switch status {
        case .imported: return false
        case .tooSoon, .failed, .failedOther: return true
        }
    }

    private static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private var cycleBanner: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let cycle = viewModel.cycle {
                Text(text.abyssCyclePeriod(start: cycle.periodStart, end: cycle.periodEnd))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.82))

                Text(cycle.blessingOfTheAbyssalMoon.name)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(LauncherPalette.goldHighlight.opacity(0.85))

                if viewModel.isCycleExpired {
                    Label(text.abyssCycleExpired, systemImage: "clock.badge.exclamationmark.fill")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(LauncherPalette.warning)
                    Text(text.abyssCycleExpiredHint)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var unknownIDsWarning: some View {
        if !viewModel.unknownRosterIDs.isEmpty {
            Text(text.abyssRosterUnknownIDs(viewModel.unknownRosterIDs))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(LauncherPalette.warning.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var methodologyNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.abyssMethodologyNotice)
            Text(text.abyssDataNotice)
        }
        .font(.system(size: 10, design: .rounded))
        .foregroundStyle(LauncherPalette.mist.opacity(0.5))
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Detail

    private var detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionSwitcher

            if viewModel.library == nil {
                ProgressView(text.abyssLoadingLabel)
                    .tint(LauncherPalette.gold)
                    .foregroundStyle(LauncherPalette.mist)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewModel.section {
                case .roster:
                    AbyssRosterEditorView(viewModel: viewModel, text: text)
                case .results:
                    AbyssResultsView(viewModel: viewModel, text: text)
                }
            }
        }
    }

    /// Roster/Results plus the file menu, at the top of the panel both sections
    /// share — not in the sidebar, so it reads as switching what fills this
    /// pane rather than as roster-editing chrome that happens not to apply to
    /// Results.
    private var sectionSwitcher: some View {
        HStack(spacing: 8) {
            SidebarTabButton(title: text.abyssRosterSection,
                             systemImage: "person.3.fill",
                             isSelected: viewModel.section == .roster,
                             showsLabelWhenInactive: false) {
                viewModel.section = .roster
            }
            SidebarTabButton(title: text.abyssResultsSection,
                             systemImage: "trophy.fill",
                             isSelected: viewModel.section == .results,
                             showsLabelWhenInactive: false) {
                viewModel.section = .results
            }

            Spacer(minLength: 0)

            // Import/export are occasional, not the primary action, so they
            // move out of the button row and into an overflow menu rather than
            // competing with the tabs for attention.
            rosterFileMenu
        }
    }

    private var rosterFileMenu: some View {
        Menu {
            Button { importRoster() } label: { Label(text.abyssImport, systemImage: "square.and.arrow.down") }
            Button { exportRoster() } label: { Label(text.abyssExport, systemImage: "square.and.arrow.up") }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LauncherPalette.mist.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(LauncherPalette.night.opacity(0.34), in: Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .pointerOnHover()
    }

    // MARK: - Import/export

    private func importRoster() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importRoster(from: url)
        }
    }

    private func exportRoster() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        // The same filename the Python tool looks for, so an exported roster can
        // be dropped straight next to it.
        panel.nameFieldStringValue = "roster.json"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.exportRoster(to: url)
        }
    }
}
