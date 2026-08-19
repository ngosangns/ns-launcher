import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var isShowingSettings = false
    @State private var isShowingDiagnostics = false

    private var text: AppText { viewModel.text }

    var body: some View {
        NavigationStack {
            ZStack {
                CelestialBackdrop()

                Group {
                    if let game = viewModel.selectedGame {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 22) {
                                topBar
                                hero(for: game)
                                statusDeck
                            }
                            .frame(maxWidth: 1_180)
                            .padding(.horizontal, 34)
                            .padding(.vertical, 28)
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        ContentUnavailableView(text.noGameSelected, systemImage: "sparkles")
                            .foregroundStyle(LauncherPalette.parchment)
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
        .alert(text.error, isPresented: Binding(get: {
            viewModel.errorMessage != nil
        }, set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        })) {
            Button(text.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LauncherPalette.gold.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LauncherPalette.goldHighlight)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("NS LAUNCHER")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(LauncherPalette.parchment)
                Text(text.nativeLauncherDescription)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.78))
            }

            Spacer()

            StatusPill(
                title: viewModel.isBusy ? viewModel.statusText : text.ready,
                tint: viewModel.isBusy ? LauncherPalette.warning : LauncherPalette.success
            )
            .lineLimit(1)

            Button {
                isShowingSettings = true
            } label: {
                Label(text.settingsTitle, systemImage: "gearshape")
            }
            .buttonStyle(QuestButtonStyle(role: .quiet))
            .pointerOnHover()
        }
    }

    private func hero(for game: GameDefinition) -> some View {
        OrnamentalPanel(padding: 30, tone: LauncherPalette.twilight.opacity(0.60)) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(text.sophonSourceTitle.uppercased(), systemImage: "moon.stars.fill")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(LauncherPalette.goldHighlight)

                        Text(game.displayName)
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .foregroundStyle(LauncherPalette.parchment)

                        Text(text.installPlannerDescription)
                            .font(.subheadline)
                            .foregroundStyle(LauncherPalette.mist.opacity(0.88))
                            .frame(maxWidth: 560, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 20)

                    VStack(alignment: .trailing, spacing: 10) {
                        CelestialMark()
                            .scaleEffect(1.55)
                            .padding(8)
                        Text("MACOS · WINE")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                    }
                }

                Divider()
                    .overlay(LauncherPalette.gold.opacity(0.40))

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        actionButtons
                        Spacer(minLength: 20)
                        journeyNote
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        actionButtons
                        journeyNote
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                if viewModel.isLaunchingWithWine {
                    viewModel.stopCurrentOperation()
                } else {
                    viewModel.launchSelectedGame()
                }
            } label: {
                Label(
                    viewModel.isLaunchingWithWine ? text.stopTitle : text.playTitle,
                    systemImage: viewModel.isLaunchingWithWine ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(QuestButtonStyle(role: .primary))
            .disabled(viewModel.isBusy && !viewModel.isLaunchingWithWine)
            .pointerOnHover(enabled: !(viewModel.isBusy && !viewModel.isLaunchingWithWine))

            Button {
                viewModel.updateSelectedGame()
            } label: {
                Label(text.updateGameTitle, systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(QuestButtonStyle(role: .secondary))
            .disabled(viewModel.isBusy || !viewModel.canUpdateSelectedGame)
            .pointerOnHover(enabled: !viewModel.isBusy && viewModel.canUpdateSelectedGame)
        }
    }

    private var journeyNote: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(viewModel.isBusy ? text.status : text.ready)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1)
                .foregroundStyle(LauncherPalette.goldHighlight)
            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(LauncherPalette.mist.opacity(0.86))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private var statusDeck: some View {
        OrnamentalPanel(tone: LauncherPalette.night.opacity(0.66)) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text.status.uppercased())
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(LauncherPalette.goldHighlight)
                        Text(viewModel.statusText)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(LauncherPalette.parchment)
                    }
                    Spacer()
                    Image(systemName: statusSymbol)
                        .font(.title2)
                        .foregroundStyle(viewModel.isBusy ? LauncherPalette.warning : LauncherPalette.success)
                }

                if let progress = viewModel.operationProgress {
                    progressDetails(progress)
                } else {
                    idleState
                }

                diagnostics
            }
        }
    }

    private var idleState: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(LauncherPalette.success)
            Text(text.nativeLauncherDescription)
                .font(.subheadline)
                .foregroundStyle(LauncherPalette.mist.opacity(0.84))
        }
        .padding(.vertical, 6)
    }

    private func progressDetails(_ progress: OperationProgress) -> some View {
        VStack(alignment: .leading, spacing: 18) {
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
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { transferMetrics(progress) }
                    VStack(alignment: .leading, spacing: 10) { transferMetrics(progress) }
                }
            }

            if let paths = progress.itemPaths, !paths.isEmpty {
                activeItemList(paths)
            } else if let path = progress.itemPath {
                activeItemList([path])
            }

            if !viewModel.isLaunchingWithWine {
                HStack(spacing: 10) {
                    Button(viewModel.isPaused ? text.resumeTitle : text.pauseTitle) {
                        viewModel.togglePause()
                    }
                    .buttonStyle(QuestButtonStyle(role: .quiet))
                    .disabled(!viewModel.isBusy)
                    .pointerOnHover(enabled: viewModel.isBusy)

                    Button(text.stopTitle) {
                        viewModel.stopCurrentOperation()
                    }
                    .buttonStyle(QuestButtonStyle(role: .quiet))
                    .disabled(!viewModel.isBusy)
                    .pointerOnHover(enabled: viewModel.isBusy)
                }
            }
        }
    }

    private func progressLine(title: String, detail: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                Spacer()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.parchment.opacity(0.88))
                    .lineLimit(1)
            }
            GoldenProgressBar(value: value)
        }
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
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.80))
                Text(value)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(LauncherPalette.parchment)
            }
        }
    }

    private func activeItemList(_ paths: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(paths.count > 1 ? text.currentItemsLabel : text.currentItemLabel)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(LauncherPalette.mist.opacity(0.72))
            ForEach(paths.prefix(3), id: \.self) { path in
                Text(path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LauncherPalette.parchment.opacity(0.88))
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }
        .padding(.top, 2)
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            .buttonStyle(QuestButtonStyle(role: .quiet))
            .pointerOnHover()

            if isShowingDiagnostics {
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
        .padding(.top, 2)
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
                .onChange(of: contents.count) { _, _ in
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .frame(minHeight: 130, maxHeight: 230)
            .padding(12)
            .background(LauncherPalette.ink.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var statusSymbol: String {
        if viewModel.isLaunchingWithWine { return "play.circle.fill" }
        if viewModel.isBusy { return "arrow.triangle.2.circlepath.circle.fill" }
        return "checkmark.seal.fill"
    }
}
