// AbyssView.swift
//
// Root of the Abyss tab: a sidebar (roster/results switch, search, filters,
// actions) and a detail pane, mirroring StoryView's split so the tab sits in the
// app's custom chrome rather than a native NavigationSplitView.

import AppKit
import SwiftUI

struct AbyssView: View {
    @ObservedObject var viewModel: AbyssViewModel
    let text: AppText

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 268)
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

            HStack(spacing: 8) {
                SidebarTabButton(title: text.abyssRosterSection,
                                 systemImage: "person.3.fill",
                                 isSelected: viewModel.section == .roster) {
                    viewModel.section = .roster
                }
                SidebarTabButton(title: text.abyssResultsSection,
                                 systemImage: "trophy.fill",
                                 isSelected: viewModel.section == .results) {
                    viewModel.section = .results
                }
            }

            if viewModel.library == nil {
                ProgressView(text.abyssLoadingLabel)
                    .tint(LauncherPalette.gold)
                    .foregroundStyle(LauncherPalette.mist)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        actions
                        uidImport
                        methodologyNotice
                    }
                }
            }
        }
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
                Text(message(for: status))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(isFailure(status)
                        ? LauncherPalette.warning.opacity(0.9)
                        : LauncherPalette.success.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
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

                Button { viewModel.clearShowcase() } label: {
                    Label(text.abyssClearShowcase, systemImage: "trash")
                }
                .quest(.quiet)
            }

            Text(text.abyssUIDHint)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(LauncherPalette.mist.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
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

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Searching and filtering belong to the roster grid, so they live
            // there; this toggle changes what the search *runs over*, which is
            // an action, not a filter.
            Toggle(text.abyssUseFullRoster, isOn: $viewModel.usesFullRoster)
                .toggleStyle(.switch)
                .tint(LauncherPalette.gold)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(LauncherPalette.mist)

            HStack(spacing: 8) {
                Button {
                    viewModel.isSearching ? viewModel.cancelSearch() : viewModel.search()
                } label: {
                    Label(viewModel.isSearching ? text.abyssCancel : text.abyssRecompute,
                          systemImage: viewModel.isSearching ? "stop.fill" : "sparkle.magnifyingglass")
                }
                .quest(.primary, disabled: !viewModel.canSearch && !viewModel.isSearching)
            }

            if viewModel.isSearching {
                GoldenProgressBar(value: viewModel.progress > 0 ? viewModel.progress : nil)
                Text(text.abyssRecomputing)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.7))
            }

            HStack(spacing: 8) {
                Button { importRoster() } label: { Label(text.abyssImport, systemImage: "square.and.arrow.down") }
                    .quest(.quiet)
                Button { exportRoster() } label: { Label(text.abyssExport, systemImage: "square.and.arrow.up") }
                    .quest(.quiet)
            }

            Text(text.abyssOwnedCount(characters: viewModel.roster.characters.count,
                                      weapons: viewModel.roster.weapons.count))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(LauncherPalette.mist.opacity(0.62))

            if !viewModel.unknownRosterIDs.isEmpty {
                Text(text.abyssRosterUnknownIDs(viewModel.unknownRosterIDs))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(LauncherPalette.warning.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    @ViewBuilder
    private var detail: some View {
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
