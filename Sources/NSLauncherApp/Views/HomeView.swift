import SwiftUI

/// Home tab: a fixed layout sized to the window — the game hero on top, the activity panel filling
/// the rest — where the diagnostics console is the only scrolling region. Nothing else moves off
/// screen, so the primary controls stay in the same place for the whole session.
struct HomeView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var logChannel: LogChannel = .update

    private var text: AppText { viewModel.text }

    /// Diagnostics streams the console can show. Only one is rendered at a time so the panel keeps a
    /// single, predictable scroll region instead of stacking two scrollers.
    private enum LogChannel: Hashable {
        case update
        case wine
    }

    private static let logBottomID = "log-bottom"

    var body: some View {
        Group {
            if let game = viewModel.selectedGame {
                gameHome(for: game)
            } else {
                ContentUnavailableView(text.noGameSelected, systemImage: "sparkles")
                    .foregroundStyle(LauncherPalette.parchment)
            }
        }
    }

    private func gameHome(for game: GameDefinition) -> some View {
        VStack(spacing: 12) {
            hero(for: game)
            activityPanel
        }
        .frame(maxWidth: 1_180, maxHeight: .infinity)
        // Horizontal and bottom padding must clear WindowFrameOrnament's corner brackets, which sit
        // 16-40pt in from every window edge — anything inside that band has a panel edge cutting
        // through the bracket lines. The top edge already clears it via the top bar's own height, so
        // it only needs a small gap of its own.
        .padding(.horizontal, 44)
        .padding(.top, 4)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hero

    private func hero(for game: GameDefinition) -> some View {
        OrnamentalPanel(padding: 18, tone: LauncherPalette.twilight.opacity(0.60)) {
            HStack(alignment: .center, spacing: 18) {
                playButton

                VStack(alignment: .leading, spacing: 8) {
                    Text(game.displayName)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(LauncherPalette.parchment)
                        .lineLimit(1)

                    statusLine
                    controlRow
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var playButton: some View {
        let gameIsRunning = viewModel.isLaunchingWithWine || viewModel.isGameRunning
        let isDisabled = viewModel.isBusy && !viewModel.isLaunchingWithWine
        return CircularActionButton(
            systemImage: gameIsRunning ? "stop.fill" : "play.fill",
            title: gameIsRunning ? text.stopTitle : text.playTitle,
            progress: nil,
            isActive: gameIsRunning
        ) {
            if gameIsRunning {
                if viewModel.isLaunchingWithWine {
                    viewModel.stopCurrentOperation()
                } else {
                    viewModel.stopRunningGame()
                }
            } else {
                viewModel.launchSelectedGame()
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            statusIndicator
                .frame(width: 16, height: 16)
            Text(viewModel.statusText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(LauncherPalette.mist.opacity(0.78))
                .lineLimit(1)
            playtimeReminderBadge
        }
    }

    @ViewBuilder
    private var playtimeReminderBadge: some View {
        if let remaining = viewModel.playtimeRemainingText {
            Text(viewModel.isPlaytimeReminderDue ? text.playtimeReminderDue : "· \(remaining)")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(viewModel.isPlaytimeReminderDue ? LauncherPalette.warning : LauncherPalette.mist.opacity(0.55))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if viewModel.isPaused {
            Image(systemName: "pause.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LauncherPalette.warning)
        } else if viewModel.isBusy || viewModel.isLaunchingWithWine {
            ProgressView()
                .controlSize(.small)
                .tint(LauncherPalette.warning)
        } else {
            Circle()
                .fill(viewModel.isGameRunning ? LauncherPalette.success : LauncherPalette.mist.opacity(0.45))
                .frame(width: 8, height: 8)
        }
    }

    /// Update plus the pause/stop pair for the running operation. They share the hero row because a
    /// fixed layout has no drawer to reveal them in, and stopping an update is a primary action.
    private var controlRow: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.updateSelectedGame()
            } label: {
                Label(text.updateGameTitle, systemImage: "arrow.triangle.2.circlepath")
            }
            .quest(.secondary, disabled: viewModel.isBusy || !viewModel.canUpdateSelectedGame)

            if viewModel.isBusy && !viewModel.isLaunchingWithWine {
                Button(viewModel.isPaused ? text.resumeTitle : text.pauseTitle) {
                    viewModel.togglePause()
                }
                .quest(.quiet)

                Button(text.stopTitle) {
                    viewModel.stopCurrentOperation()
                }
                .quest(.quiet)
            }
        }
    }

    // MARK: - Activity Panel

    private var activityPanel: some View {
        OrnamentalPanel(padding: 14, tone: LauncherPalette.night.opacity(0.66), showsMark: false) {
            VStack(alignment: .leading, spacing: 10) {
                // While a game is launching there is no meaningful overall progress to show (the
                // launch bar is always indeterminate), so the console gets the whole panel.
                if let progress = viewModel.operationProgress, !viewModel.isLaunchingWithWine {
                    progressSection(progress)
                }
                logSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
    }

    private func progressSection(_ progress: OperationProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            progressLine(
                title: text.totalProgressLabel,
                detail: progress.detailText ?? text.waitingForProgress,
                value: progress.fractionCompleted
            )

            if progress.partText != nil || progress.currentPartDetailText != nil {
                progressLine(
                    title: text.currentPartProgressLabel,
                    detail: progress.currentPartDetailText ?? progress.partText ?? text.waitingForProgress,
                    value: progress.currentPartFractionCompleted
                )
            }

            if progress.speedText != nil || progress.etaText != nil || progress.totalKBText != nil {
                metricsRow(progress)
            }

            if let paths = progress.itemPaths, !paths.isEmpty {
                activeItems(paths)
            } else if let path = progress.itemPath {
                activeItems([path])
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherPalette.ink.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// One progress row on a single line — label, detail, percentage — above its bar, so the section
    /// keeps a height the surrounding fixed layout can absorb.
    private func progressLine(title: String, detail: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.70))
                    .fixedSize()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.parchment.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if let value {
                    Text("\(Int((value * 100).rounded()))%")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(LauncherPalette.goldHighlight)
                }
            }
            GoldenProgressBar(value: value)
        }
    }

    private func metricsRow(_ progress: OperationProgress) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            metric(text.speedLabel, progress.speedText)
            metric(text.etaLabel, progress.etaText ?? (progress.isETAWarmingUp ? text.etaWarmupMessage : nil))
            metric(text.progressLabel, progress.totalKBText)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func metric(_ label: String, _ value: String?) -> some View {
        if let value {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.80))
                Text(value)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(LauncherPalette.parchment)
                    .lineLimit(1)
            }
        }
    }

    private func activeItems(_ paths: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text((paths.count > 1 ? text.currentItemsLabel : text.currentItemLabel).uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(LauncherPalette.mist.opacity(0.70))
            ForEach(paths.prefix(2), id: \.self) { path in
                Text(path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LauncherPalette.parchment.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Diagnostics Console

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(text.diagnosticsTitle.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(LauncherPalette.goldHighlight)
                Spacer(minLength: 0)
                if availableChannels.count > 1 {
                    channelTabs
                }
            }
            logConsole
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var channelTabs: some View {
        HStack(spacing: 8) {
            ForEach(availableChannels, id: \.self) { channel in
                SidebarTabButton(
                    title: title(for: channel),
                    systemImage: channel == .update ? "arrow.down.circle" : "terminal",
                    isSelected: activeChannel == channel
                ) {
                    logChannel = channel
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private var logConsole: some View {
        Group {
            if let contents = logContents {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(contents)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.88))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Color.clear.frame(height: 1).id(Self.logBottomID)
                    }
                    // Also on appear: switching tabs rebuilds this view, and a console that came
                    // back scrolled to the top of an old run would hide the live tail.
                    .onAppear {
                        proxy.scrollTo(Self.logBottomID, anchor: .bottom)
                    }
                    .onChange(of: viewModel.runLogVersion) { _, _ in
                        proxy.scrollTo(Self.logBottomID, anchor: .bottom)
                    }
                    .onChange(of: activeChannel) { _, _ in
                        proxy.scrollTo(Self.logBottomID, anchor: .bottom)
                    }
                }
            } else {
                emptyConsole
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(LauncherPalette.ink.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyConsole: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(LauncherPalette.mist.opacity(0.30))
            Text(text.noDiagnosticsYet)
                .font(.caption)
                .foregroundStyle(LauncherPalette.mist.opacity(0.58))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var availableChannels: [LogChannel] {
        var channels: [LogChannel] = []
        if !viewModel.updateRunLog.isEmpty { channels.append(.update) }
        if !viewModel.wineRunLog.isEmpty { channels.append(.wine) }
        return channels
    }

    /// The channel actually rendered: the user's pick while it still has content, otherwise whichever
    /// stream is live. Deriving it means a run that clears one log never needs `logChannel` reset.
    private var activeChannel: LogChannel? {
        let channels = availableChannels
        return channels.contains(logChannel) ? logChannel : channels.first
    }

    private var logContents: String? {
        guard let channel = activeChannel else { return nil }
        switch channel {
        case .update: return viewModel.updateRunLog
        case .wine: return viewModel.wineRunLog
        }
    }

    private func title(for channel: LogChannel) -> String {
        switch channel {
        case .update: return text.updateRunLogTitle
        case .wine: return text.wineRunLogTitle
        }
    }
}
