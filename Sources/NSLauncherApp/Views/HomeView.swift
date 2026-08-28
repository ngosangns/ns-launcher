import SwiftUI

/// Home tab: the game hero, the primary Play/Update action, and a status drawer that only takes
/// up space while an operation is running or diagnostics are explicitly requested.
struct HomeView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var isShowingDiagnostics = false

    private var text: AppText { viewModel.text }

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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                hero(for: game)
                if isDrawerVisible {
                    statusDrawer
                }
            }
            .animation(.easeOut(duration: 0.22), value: isDrawerVisible)
            .frame(maxWidth: 1_180)
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }

    private var isDrawerVisible: Bool {
        viewModel.isBusy || viewModel.isLaunchingWithWine || isShowingDiagnostics
    }

    private func hero(for game: GameDefinition) -> some View {
        OrnamentalPanel(padding: 34, tone: LauncherPalette.twilight.opacity(0.60)) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(game.displayName)
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(LauncherPalette.parchment)
                        Text(viewModel.statusText)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.78))
                    }

                    Spacer(minLength: 20)

                    CelestialMark()
                        .scaleEffect(1.55)
                        .padding(8)
                }

                Divider()
                    .overlay(LauncherPalette.gold.opacity(0.40))

                actionRow
            }
        }
    }

    private var actionRow: some View {
        HStack(alignment: .center, spacing: 24) {
            let playDisabled = viewModel.isBusy && !viewModel.isLaunchingWithWine
            CircularActionButton(
                systemImage: viewModel.isLaunchingWithWine ? "stop.fill" : "play.fill",
                title: viewModel.isLaunchingWithWine ? text.stopTitle : text.playTitle,
                progress: nil,
                isActive: viewModel.isLaunchingWithWine
            ) {
                if viewModel.isLaunchingWithWine {
                    viewModel.stopCurrentOperation()
                } else {
                    viewModel.launchSelectedGame()
                }
            }
            .disabled(playDisabled)
            .opacity(playDisabled ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 10) {
                let updateDisabled = viewModel.isBusy || !viewModel.canUpdateSelectedGame
                Button {
                    viewModel.updateSelectedGame()
                } label: {
                    Label(text.updateGameTitle, systemImage: "arrow.triangle.2.circlepath")
                }
                .quest(.secondary, disabled: updateDisabled)

                if !viewModel.isLaunchingWithWine {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isShowingDiagnostics.toggle()
                        }
                    } label: {
                        Label(
                            isShowingDiagnostics ? text.hideDiagnostics : text.showDiagnostics,
                            systemImage: isShowingDiagnostics ? "chevron.up" : "chevron.down"
                        )
                    }
                    .quest(.quiet)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var statusDrawer: some View {
        OrnamentalPanel(padding: 24, tone: LauncherPalette.night.opacity(0.66)) {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isBusy || viewModel.isLaunchingWithWine {
                    statusHeader
                }

                // While a game is launching there is no meaningful overall progress to show
                // (the launch bar is always indeterminate), so skip the progress section and
                // surface only the diagnostics log.
                if let progress = viewModel.operationProgress, !viewModel.isLaunchingWithWine {
                    progressDetails(progress)
                }

                if viewModel.isBusy && !viewModel.isLaunchingWithWine {
                    pauseStopRow
                }

                if isShowingDiagnostics || viewModel.isLaunchingWithWine {
                    logsSection
                }
            }
        }
        .transition(.opacity)
    }

    private var statusHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.14))
                    .frame(width: 42, height: 42)
                if viewModel.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(statusTint)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(statusTint)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(text.status.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(LauncherPalette.goldHighlight)
                Text(viewModel.statusText)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(LauncherPalette.parchment)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)
        }
    }

    private var statusTint: Color {
        viewModel.isBusy || viewModel.isLaunchingWithWine ? LauncherPalette.warning : LauncherPalette.success
    }

    private var pauseStopRow: some View {
        HStack(spacing: 10) {
            Button(viewModel.isPaused ? text.resumeTitle : text.pauseTitle) {
                viewModel.togglePause()
            }
            .quest(.quiet)

            Button(text.stopTitle) {
                viewModel.stopCurrentOperation()
            }
            .quest(.quiet)

            Spacer(minLength: 0)
        }
    }

    private func progressDetails(_ progress: OperationProgress) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            progressLine(
                title: text.totalProgressLabel,
                detail: progress.detailText ?? text.waitingForProgress,
                value: progress.fractionCompleted
            )

            if progress.partText != nil || progress.currentPartDetailText != nil {
                Divider()
                    .overlay(LauncherPalette.mist.opacity(0.12))
                progressLine(
                    title: text.currentPartProgressLabel,
                    detail: progress.currentPartDetailText ?? progress.partText ?? text.waitingForProgress,
                    value: progress.currentPartFractionCompleted
                )
            }

            if progress.speedText != nil || progress.etaText != nil || progress.totalKBText != nil {
                transferMetricsStrip(progress)
            }

            if let paths = progress.itemPaths, !paths.isEmpty {
                activeItemList(paths)
            } else if let path = progress.itemPath {
                activeItemList([path])
            }
        }
    }

    private func progressLine(title: String, detail: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.70))
                Spacer()
                if let value {
                    Text("\(Int((value * 100).rounded()))%")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(LauncherPalette.goldHighlight)
                }
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(LauncherPalette.parchment.opacity(0.92))
                .lineLimit(2)
            GoldenProgressBar(value: value)
        }
    }

    private func transferMetricsStrip(_ progress: OperationProgress) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) { transferMetrics(progress) }
            VStack(alignment: .leading, spacing: 12) { transferMetrics(progress) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherPalette.ink.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func transferMetrics(_ progress: OperationProgress) -> some View {
        metric(text.speedLabel, progress.speedText)
        metric(text.etaLabel, progress.etaText ?? (progress.isETAWarmingUp ? text.etaWarmupMessage : nil))
        metric(text.progressLabel, progress.totalKBText)
    }

    @ViewBuilder
    private func metric(_ label: String, _ value: String?) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.80))
                Text(value)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .foregroundStyle(LauncherPalette.parchment)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func activeItemList(_ paths: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(paths.count > 1 ? text.currentItemsLabel : text.currentItemLabel)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(LauncherPalette.mist.opacity(0.70))
            ForEach(paths.prefix(3), id: \.self) { path in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(LauncherPalette.gold.opacity(0.82))
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(LauncherPalette.parchment.opacity(0.88))
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(14)
        .background(LauncherPalette.ink.opacity(0.20), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !viewModel.updateRunLog.isEmpty {
                logPanel(title: text.updateRunLogTitle, contents: viewModel.updateRunLog, bottomID: "update-log")
            }
            if !viewModel.wineRunLog.isEmpty {
                logPanel(title: text.wineRunLogTitle, contents: viewModel.wineRunLog, bottomID: "wine-log")
            }
            if viewModel.updateRunLog.isEmpty && viewModel.wineRunLog.isEmpty {
                Text(text.waitingForProgress)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
            }
        }
    }

    private func logPanel(title: String, contents: String, bottomID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(LauncherPalette.gold.opacity(0.86))

            ScrollViewReader { proxy in
                ScrollView {
                    Text(contents)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.88))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .onChange(of: viewModel.runLogVersion) { _, _ in
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .frame(minHeight: 130, maxHeight: 230)
            .padding(12)
            .background(LauncherPalette.ink.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
