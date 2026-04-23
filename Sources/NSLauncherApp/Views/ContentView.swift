import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var isShowingSettings = false

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

    private func titleBlock(for game: GameDefinition) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.displayName)
                    .font(.largeTitle.bold())
                Text(text.launcherStrategyDescription(game.installerStrategy))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                HeaderBadge(
                    title: viewModel.canDownloadSelectedGame ? text.downloadReady : text.localOnly,
                    tint: viewModel.canDownloadSelectedGame ? .green : .orange
                )
                HeaderBadge(
                    title: text.experimentalBadge,
                    tint: .orange
                )
            }
        }
    }

    private var installSummary: some View {
        EmptyView()
    }

    private var actionBar: some View {
        let buttons = [
            ActionButtonItem(
                title: text.downloadInstallTitle,
                icon: "arrow.down.circle",
                prominent: true,
                disabled: viewModel.isBusy || !viewModel.canDownloadSelectedGame
            ) {
                viewModel.installSelectedGame()
            },
            ActionButtonItem(
                title: text.localArchiveTitle,
                icon: "externaldrive.badge.plus",
                disabled: viewModel.isBusy
            ) {
                if let archiveURL = chooseArchiveURL() {
                    viewModel.installSelectedGame(archiveOverrideURL: archiveURL)
                }
            },
            ActionButtonItem(
                title: text.importTitle,
                icon: "folder.badge.plus",
                disabled: viewModel.isBusy
            ) {
                if let directoryURL = chooseDirectoryURL(title: text.chooseExistingGameFolder) {
                    viewModel.importSelectedGame(from: directoryURL)
                }
            },
            ActionButtonItem(
                title: text.rescanTitle,
                icon: "arrow.clockwise.circle",
                disabled: viewModel.isBusy
            ) {
                viewModel.rescanSelectedGame()
            },
            ActionButtonItem(
                title: text.chooseFolderTitle,
                icon: "folder",
                disabled: viewModel.isBusy
            ) {
                if let directoryURL = chooseDirectoryURL(title: text.chooseInstallFolder) {
                    viewModel.setInstallDirectoryForSelectedGame(directoryURL)
                }
            },
            ActionButtonItem(
                title: text.launchTitle,
                icon: "play.circle",
                disabled: viewModel.isBusy
            ) {
                viewModel.launchSelectedGame()
            }
        ]

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
                    VStack(alignment: .leading, spacing: 10) {
                        statusInfoGrid(progress: progress)

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
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statusInfoGrid(progress: OperationProgress) -> some View {
        let items = [
            progress.itemPath.map { StatusItem(label: text.currentItemLabel, value: $0, monospaced: true) },
            progress.partText.map { StatusItem(label: text.currentPartLabel, value: $0, monospaced: false) }
        ].compactMap { $0 }

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                statusTile(label: item.label, value: item.value, monospaced: item.monospaced)
            }
        }
    }

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

        let sizeItems = [
            progress.totalKBText.map { StatusItem(label: text.totalSizeKBLabel, value: $0, monospaced: true) },
            progress.currentPartKBText.map { StatusItem(label: text.partSizeKBLabel, value: $0, monospaced: true) }
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

            if !sizeItems.isEmpty {
                let sizeColumns = Array(repeating: GridItem(.flexible(minimum: 220), spacing: 12), count: min(sizeItems.count, 2))
                LazyVGrid(columns: sizeColumns, alignment: .leading, spacing: 12) {
                    ForEach(sizeItems) { item in
                        statusTile(label: item.label, value: item.value, monospaced: item.monospaced)
                    }
                }
            }
        }
    }

    private func statusTile(label: String, value: String, monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if monospaced {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

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

    private func chooseArchiveURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = text.chooseArchivePackage
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "7z"),
            .zip,
            UTType(filenameExtension: "001"),
            UTType(filenameExtension: "tar"),
            UTType(filenameExtension: "gz")
        ].compactMap { $0 }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseDirectoryURL(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

private struct StatusItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let monospaced: Bool
}

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

private struct ActionButtonItem {
    let title: String
    let icon: String
    var prominent = false
    let disabled: Bool
    let action: () -> Void
}

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

private struct HeaderBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}
