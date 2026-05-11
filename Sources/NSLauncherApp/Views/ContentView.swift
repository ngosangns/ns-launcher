import AppKit
import SwiftUI

/// Main launcher screen with install actions and operation status.
struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var isShowingSettings = false

    /// Convenience accessor for localized copy.
    private var text: AppText { viewModel.text }

    var body: some View {
        NavigationStack {
            Group {
                if let game = viewModel.selectedGame {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            titleBlock(for: game)
                            installSummary
                            actionBar
                            footer
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ContentUnavailableView(text.noGameSelected, systemImage: "gamecontroller")
                }
            }
            .alert(text.error, isPresented: Binding(get: {
                viewModel.errorMessage != nil
            }, set: { show in
                if !show { viewModel.errorMessage = nil }
            })) {
                Button(text.ok, role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .navigationDestination(isPresented: $isShowingSettings) {
                SettingsView(viewModel: viewModel)
                    .navigationTitle(text.settingsTitle)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label(text.settingsTitle, systemImage: "gearshape")
                    }
                    .pointerOnHover()
                }
            }
        }
    }

    /// Top visual summary for the selected game.
    private func titleBlock(for game: GameDefinition) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.displayName)
                    .font(.largeTitle.bold())
                Text(text.nativeLauncherDescription)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color.orange.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    /// Reserved area for future install metadata without changing the main layout.
    private var installSummary: some View {
        EmptyView()
    }

    /// Builds the available user actions for the selected game.
    private var actionBar: some View {
        var buttons = [
            ActionButtonItem(
                title: text.updateGameTitle,
                icon: "arrow.triangle.2.circlepath",
                prominent: true,
                disabled: viewModel.isBusy || !viewModel.canUpdateSelectedGame
            ) {
                viewModel.updateSelectedGame()
            }
        ]

        buttons.append(
            contentsOf: [
                ActionButtonItem(
                    title: viewModel.isLaunchingWithWine ? text.stopTitle : text.playTitle,
                    icon: viewModel.isLaunchingWithWine ? "stop.circle" : "play.circle",
                    prominent: true,
                    disabled: viewModel.isBusy && !viewModel.isLaunchingWithWine
                ) {
                    if viewModel.isLaunchingWithWine {
                        viewModel.stopCurrentOperation()
                    } else {
                        viewModel.launchSelectedGame()
                    }
                }
            ]
        )

        return FlexFlowLayout(spacing: 12, rowSpacing: 10) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { _, item in
                ActionButton(
                    title: item.title,
                    icon: item.icon,
                    prominent: item.prominent,
                    disabled: item.disabled,
                    action: item.action
                )
            }
        }
    }

    /// Status panel that renders progress, pause/stop controls, and transfer details.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.status)
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: viewModel.isBusy ? "hourglass" : "checkmark.seal")
                        .foregroundStyle(viewModel.isBusy ? .orange : .green)
                        .font(.title3)
                    Text(viewModel.statusText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let progress = viewModel.operationProgress {
                    // Progress is split into overall and current Sophon asset bars.
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(text.totalProgressLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if progress.isIndeterminate || progress.fractionCompleted == nil {
                                ProgressView()
                                    .controlSize(.small)
                                Text(progress.detailText ?? text.waitingForProgress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ProgressView(value: progress.fractionCompleted ?? 0)
                                    .controlSize(.small)
                                Text(progress.detailText ?? text.waitingForProgress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if progress.partText != nil {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(text.currentPartProgressLabel)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                if progress.currentPartIsIndeterminate || progress.currentPartFractionCompleted == nil {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(progress.currentPartDetailText ?? text.waitingForProgress)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ProgressView(value: progress.currentPartFractionCompleted ?? 0)
                                        .controlSize(.small)
                                    Text(progress.currentPartDetailText ?? text.waitingForProgress)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if progress.speedText != nil || progress.totalKBText != nil || progress.currentPartKBText != nil {
                            transferDetailsGrid(progress: progress)
                        }

                        if !viewModel.isLaunchingWithWine {
                            HStack(spacing: 10) {
                                Button(viewModel.isPaused ? text.resumeTitle : text.pauseTitle) {
                                    viewModel.togglePause()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!viewModel.isBusy)
                                .pointerOnHover(enabled: viewModel.isBusy)

                                Button(text.stopTitle) {
                                    viewModel.stopCurrentOperation()
                                }
                                .buttonStyle(.bordered)
                                .disabled(!viewModel.isBusy)
                                .pointerOnHover(enabled: viewModel.isBusy)
                            }
                        }

                        statusInfoGrid(progress: progress)
                    }
                }

                logPanels
            }
            .padding(12)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Live diagnostics for update and Wine operations.
    private var logPanels: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.updateRunLog.isEmpty {
                logPanel(
                    title: text.updateRunLogTitle,
                    contents: viewModel.updateRunLog,
                    bottomID: "update-run-log-bottom"
                )
            }

            if !viewModel.wineRunLog.isEmpty {
                logPanel(
                    title: text.wineRunLogTitle,
                    contents: viewModel.wineRunLog,
                    bottomID: "wine-run-log-bottom"
                )
            }
        }
    }

    /// Live diagnostics from the current or latest Wine launch.
    private func logPanel(title: String, contents: String, bottomID: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(contents)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .onChange(of: contents.count) { _, _ in
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .frame(minHeight: 180, maxHeight: 280)
            .padding(10)
            .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// Renders current file/part details below the progress bars.
    private func statusInfoGrid(progress: OperationProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let itemPaths = progress.itemPaths, !itemPaths.isEmpty {
                statusListTile(label: text.currentItemsLabel, values: itemPaths, monospaced: true)
            } else if let itemPath = progress.itemPath {
                statusTile(label: text.currentItemLabel, value: itemPath, monospaced: true)
            }

            if let partText = progress.partText {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], alignment: .leading, spacing: 12) {
                    statusTile(label: text.currentPartLabel, value: partText, monospaced: false)
                }
            }
        }
    }

    /// Renders transfer speed and ETA information when available.
    private func transferDetailsGrid(progress: OperationProgress) -> some View {
        let warmupItem: StatusItem? = if progress.isETAWarmingUp, progress.etaText == nil {
            StatusItem(label: text.etaLabel, value: text.etaWarmupMessage, monospaced: false)
        } else {
            nil
        }

        let topItems = [
            progress.speedText.map { StatusItem(label: text.speedLabel, value: $0, monospaced: false) },
            progress.etaText.map { StatusItem(label: text.etaLabel, value: $0, monospaced: false) },
            warmupItem
        ].compactMap { $0 }

        return VStack(alignment: .leading, spacing: 8) {
            Text(text.transferDetailsLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if !topItems.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(topItems) { item in
                        statusTile(label: item.label, value: item.value, monospaced: item.monospaced)
                    }
                }
            }
        }
    }

    /// Small reusable labeled value tile for status metadata.
    private func statusTile(label: String, value: String, monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if monospaced {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Scrollable tile for the currently active Sophon asset list.
    private func statusListTile(label: String, values: [String], monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        if monospaced {
                            Text(value)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(value)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    /// Legacy compact status row kept for future detail layouts.
    private func statusRow(label: String, value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if monospaced {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.body)
            }
        }
    }

}

/// Identifiable labeled value for transfer detail grids.
private struct StatusItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let monospaced: Bool
}

/// Button wrapper used by the action bar.
private struct ActionButton: View {
    let title: String
    let icon: String
    var prominent = false
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if prominent {
                Button(action: action) {
                    Label(title, systemImage: icon)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: action) {
                    Label(title, systemImage: icon)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
        .disabled(disabled)
        .pointerOnHover(enabled: !disabled)
    }
}

/// Data model for action bar button construction.
private struct ActionButtonItem {
    let title: String
    let icon: String
    var prominent = false
    let disabled: Bool
    let action: () -> Void
}

/// Simple wrapping layout for action buttons on narrow windows.
private struct FlexFlowLayout: Layout {
    var spacing: CGFloat = 12
    var rowSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var requiredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedX = currentX == 0 ? size.width : currentX + spacing + size.width
            if proposedX > maxWidth, currentX > 0 {
                // Start a new row when the next button would overflow the proposed width.
                currentY += rowHeight + rowSpacing
                currentX = size.width
                rowHeight = size.height
            } else {
                currentX = proposedX
                rowHeight = max(rowHeight, size.height)
            }
            requiredWidth = max(requiredWidth, currentX)
        }

        return CGSize(width: requiredWidth, height: currentY + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextX = currentX == bounds.minX ? currentX + size.width : currentX + spacing + size.width

            if nextX > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + rowSpacing
                rowHeight = 0
            } else if currentX > bounds.minX {
                currentX += spacing
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}
