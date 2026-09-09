import AppKit
import SwiftUI

private enum CutsceneSortOrder: CaseIterable {
    case sizeDescending
    case sizeAscending
    case nameAscending
    case nameDescending

    func title(_ text: AppText) -> String {
        switch self {
        case .sizeDescending: return text.cutsceneSortSizeDescending
        case .sizeAscending: return text.cutsceneSortSizeAscending
        case .nameAscending: return text.cutsceneSortNameAscending
        case .nameDescending: return text.cutsceneSortNameDescending
        }
    }

    func sort(_ files: [CutsceneFile]) -> [CutsceneFile] {
        switch self {
        case .sizeDescending: return files.sorted { $0.sizeBytes > $1.sizeBytes }
        case .sizeAscending: return files.sorted { $0.sizeBytes < $1.sizeBytes }
        case .nameAscending: return files.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        case .nameDescending: return files.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedDescending }
        }
    }
}

private enum SettingsTab: CaseIterable {
    case general
    case display
    case cache
    case cutscenes

    func title(_ text: AppText) -> String {
        switch self {
        case .general: return text.selectedGame
        case .display: return text.displayOptionsLabel
        case .cache: return text.cacheManagementTitle
        case .cutscenes: return text.cutscenesTitle
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gamecontroller.fill"
        case .display: return "display"
        case .cache: return "trash.fill"
        case .cutscenes: return "play.rectangle.on.rectangle"
        }
    }
}

/// Settings screen: a sidebar table of contents plus the selected section's panel, in place of
/// one long scroll through six stacked sections.
struct SettingsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var activeSection: SettingsTab = .general
    @State private var cutsceneSearchQuery: String = ""
    @State private var pendingCutsceneDelete: CutsceneFile?
    @State private var cutsceneGenderTab: TravelerGender = .aether
    @State private var cutsceneSortOrder: CutsceneSortOrder = .sizeDescending
    @State private var showClearAllCutscenesConfirm = false

    private var text: AppText { viewModel.text }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 232)
                // Leading/trailing must clear WindowFrameOrnament's corner brackets, which occupy a
                // 16-40pt band from each window edge — see HomeView's matching comment.
                .padding(.leading, 44)
                .padding(.trailing, 18)
                .padding(.vertical, 28)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if let game = viewModel.selectedGame {
                        sectionContent(for: game)
                    }
                }
                .frame(maxWidth: 860)
                .padding(.trailing, 44)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { viewModel.refreshCacheReport() }
        .onChange(of: activeSection) { _, newValue in
            if newValue == .cutscenes && viewModel.cutsceneFiles.isEmpty {
                viewModel.refreshCutsceneFiles()
            }
        }
        .alert(
            text.deleteCutsceneConfirmTitle,
            isPresented: Binding(
                get: { pendingCutsceneDelete != nil },
                set: { if !$0 { pendingCutsceneDelete = nil } }
            ),
            presenting: pendingCutsceneDelete
        ) { file in
            Button(text.deleteCutsceneTitle, role: .destructive) {
                viewModel.deleteCutsceneFile(file)
                pendingCutsceneDelete = nil
            }
            Button(text.cancel, role: .cancel) { pendingCutsceneDelete = nil }
        } message: { file in
            Text(text.deleteCutsceneConfirmMessage(file.relativePath))
        }
        .alert(
            text.clearAllCutscenesConfirmTitle,
            isPresented: $showClearAllCutscenesConfirm
        ) {
            Button(text.deleteCutsceneTitle, role: .destructive) {
                viewModel.deleteAllCutscenes(forGender: cutsceneGenderTab)
            }
            Button(text.cancel, role: .cancel) {}
        } message: {
            let files = viewModel.cutsceneFiles(forGender: cutsceneGenderTab)
            Text(text.clearAllCutscenesConfirmMessage(
                files.count,
                ByteCountFormatter.fileSize(files.reduce(0) { $0 + $1.sizeBytes }),
                text.travelerGenderShortName(cutsceneGenderTab)
            ))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarTabButton(
                    title: tab.title(text),
                    systemImage: tab.systemImage,
                    isSelected: activeSection == tab
                ) {
                    activeSection = tab
                }
            }
        }
    }

    @ViewBuilder
    private func sectionContent(for game: GameDefinition) -> some View {
        Group {
            switch activeSection {
            case .general:
                SettingsSection(title: SettingsTab.general.title(text)) {
                    pathFields(for: game)
                }
            case .display:
                SettingsSection(title: SettingsTab.display.title(text)) {
                    VStack(alignment: .leading, spacing: 14) {
                        displayModeField
                        playtimeReminderField
                    }
                }
            case .cache:
                cacheSection(for: game)
            case .cutscenes:
                cutscenesSection(for: game)
            }
        }
        .id(activeSection)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.18), value: activeSection)
    }

    private var displayModeField: some View {
        SettingField(label: text.displayModeLabel) {
            VStack(alignment: .leading, spacing: 6) {
                Picker(text.displayModeLabel, selection: Binding(
                    get: { viewModel.settings.launchDisplayMode },
                    set: { viewModel.update(\.launchDisplayMode, to: $0) }
                )) {
                    Text(text.windowedMode).tag(LaunchDisplayMode.windowed)
                    Text(text.fullscreenMode).tag(LaunchDisplayMode.fullscreen)
                }
                .pickerStyle(.segmented)
                .pointerOnHover()
                Text(text.fullscreenHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playtimeReminderField: some View {
        SettingField(label: text.playtimeReminderLabel) {
            VStack(alignment: .leading, spacing: 6) {
                Stepper(
                    text.playtimeReminderHoursValue(viewModel.settings.playtimeReminderHours),
                    value: Binding(
                        get: { viewModel.settings.playtimeReminderHours },
                        set: { viewModel.update(\.playtimeReminderHours, to: $0) }
                    ),
                    in: 0.5...12,
                    step: 0.5
                )
                .pointerOnHover()
                Text(text.playtimeReminderDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pathFields(for game: GameDefinition) -> some View {
        PathInputRow(
            label: text.installRoot,
            value: Binding(
                get: { game.installDirectory.path },
                set: { viewModel.setInstallDirectoryForSelectedGame(URL(fileURLWithPath: $0, isDirectory: true)) }
            ),
            buttonTitle: text.browse,
            secondaryButtonTitle: text.open,
            isSecondaryButtonDisabled: !directoryExists(at: game.installDirectory.path),
            secondaryAction: { openDirectory(game.installDirectory.path) },
            choose: chooseDirectoryPath
        )
    }

    private func cacheSection(for game: GameDefinition) -> some View {
        SettingsSection(title: text.cacheManagementTitle, subtitle: text.cacheManagementSubtitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(text.removableCacheLabel)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(LauncherPalette.gold.opacity(0.88))
                    Spacer()
                    Button(text.refreshVoicePacksTitle) {
                        viewModel.refreshCacheReport()
                    }
                    .quest(.quiet, disabled: viewModel.isManagingCache)
                }

                if viewModel.cacheReport.isEmpty {
                    Label(text.noRemovableCache, systemImage: "trash")
                        .font(.subheadline)
                        .foregroundStyle(LauncherPalette.mist.opacity(0.74))
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.cacheReport) { item in
                        cacheRow(item)
                    }
                    cacheTotalRow
                }
            }
        }
    }

    private func cacheRow(_ item: RemovableCache) -> some View {
        InventoryRow(
            icon: Self.cacheIcon(for: item.kind),
            title: text.cacheKindLabel(item.kind),
            subtitleLines: [text.cacheKindDescription(item.kind)]
        ) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(ByteCountFormatter.fileSize(item.sizeBytes))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                Button(text.clearCacheTitle) {
                    viewModel.clearCache(item.kind)
                }
                .quest(.quiet, disabled: viewModel.isManagingCache || item.sizeBytes == 0)
            }
        }
    }

    private var cacheTotalRow: some View {
        let total = viewModel.cacheReport.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return HStack {
            Text(text.totalRemovableCacheLabel)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(LauncherPalette.parchment)
            Spacer()
            Text(ByteCountFormatter.fileSize(total))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(LauncherPalette.goldHighlight)
        }
        .padding(.vertical, 10)
    }

    private func cutscenesSection(for game: GameDefinition) -> some View {
        SettingsSection(title: text.cutscenesTitle, subtitle: text.cutscenesSubtitle) {
            VStack(alignment: .leading, spacing: 14) {
                giCutscenesPathField
                travelerGenderField

                Picker("", selection: $cutsceneGenderTab) {
                    ForEach(TravelerGender.allCases) { gender in
                        Text(text.travelerGenderShortName(gender)).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                .pointerOnHover()
                .labelsHidden()

                clearAllCutscenesRow

                HStack {
                    TextField(text.cutsceneSearchPlaceholder, text: $cutsceneSearchQuery)
                        .textFieldStyle(.roundedBorder)

                    Picker(text.cutsceneSortLabel, selection: $cutsceneSortOrder) {
                        ForEach(CutsceneSortOrder.allCases, id: \.self) { order in
                            Text(order.title(text)).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()

                    Spacer()
                    Button(text.refreshCutscenesTitle) {
                        viewModel.refreshCutsceneFiles()
                    }
                    .quest(.quiet, disabled: viewModel.isManagingCutscenes)
                }

                if filteredCutsceneFiles.isEmpty {
                    Label(text.noCutscenesForGender(text.travelerGenderShortName(cutsceneGenderTab)), systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(LauncherPalette.mist.opacity(0.74))
                        .padding(.vertical, 8)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredCutsceneFiles) { file in
                            cutsceneRow(file)
                        }
                    }
                }
            }
        }
    }

    private var filteredCutsceneFiles: [CutsceneFile] {
        var genderFiles = viewModel.cutsceneFiles(forGender: cutsceneGenderTab)
        if !cutsceneSearchQuery.isEmpty {
            genderFiles = genderFiles.filter {
                $0.relativePath.localizedCaseInsensitiveContains(cutsceneSearchQuery)
            }
        }
        return cutsceneSortOrder.sort(genderFiles)
    }

    private var giCutscenesPathField: some View {
        SettingField(label: text.giCutscenesPathLabel) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    TextField(text.giCutscenesPathLabel, text: Binding(
                        get: { viewModel.settings.giCutscenesBinaryPath },
                        set: { viewModel.update(\.giCutscenesBinaryPath, to: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    Button(text.browse) {
                        if let chosen = chooseFilePath() {
                            viewModel.update(\.giCutscenesBinaryPath, to: chosen)
                        }
                    }
                    .quest(.quiet)
                }
                Text(text.giCutscenesPathHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var travelerGenderField: some View {
        SettingField(label: text.travelerGenderLabel) {
            VStack(alignment: .leading, spacing: 6) {
                Picker(text.travelerGenderLabel, selection: Binding(
                    get: { viewModel.settings.travelerGender },
                    set: { viewModel.update(\.travelerGender, to: $0) }
                )) {
                    ForEach(TravelerGender.allCases) { gender in
                        Text(text.travelerGenderName(gender)).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
                .pointerOnHover()
                Text(text.travelerGenderHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var clearAllCutscenesRow: some View {
        let genderShortName = text.travelerGenderShortName(cutsceneGenderTab)
        let files = viewModel.cutsceneFiles(forGender: cutsceneGenderTab)
        let totalBytes = files.reduce(Int64(0)) { $0 + $1.sizeBytes }
        return SettingField(label: text.clearAllCutscenesTitle(genderShortName)) {
            HStack {
                Text(text.clearAllCutscenesSummary(
                    files.count,
                    ByteCountFormatter.fileSize(totalBytes)
                ))
                .font(.subheadline)
                .foregroundStyle(LauncherPalette.mist.opacity(0.82))
                Spacer()
                Button(text.clearAllCutscenesTitle(genderShortName)) {
                    showClearAllCutscenesConfirm = true
                }
                .quest(.quiet, disabled: viewModel.isManagingCutscenes || files.isEmpty)
            }
        }
    }

    private func cutsceneRow(_ file: CutsceneFile) -> some View {
        InventoryRow(
            icon: "film",
            title: file.relativePath,
            subtitleLines: [ByteCountFormatter.fileSize(file.sizeBytes)]
        ) {
            HStack(spacing: 6) {
                Button(text.openCutsceneTitle) {
                    viewModel.openCutsceneFile(file)
                }
                .quest(.quiet, disabled: viewModel.isManagingCutscenes)

                Button(text.revealCutsceneTitle) {
                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                }
                .quest(.quiet, disabled: viewModel.isManagingCutscenes)

                Button(text.deleteCutsceneTitle) {
                    pendingCutsceneDelete = file
                }
                .quest(.quiet, disabled: viewModel.isManagingCutscenes)
            }
        }
    }

    private static func cacheIcon(for kind: RemovableCache.Kind) -> String {
        switch kind {
        case .cutsceneVideos: return "film"
        case .gameWebCache: return "globe"
        case .gameSDKCache: return "square.stack.3d.up"
        case .gameWorldAssetCache: return "globe.americas"
        case .winePrefixTemp: return "wineglass"
        case .launcherDownloadArchives: return "archivebox"
        }
    }

    private func chooseDirectoryPath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func chooseFilePath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func directoryExists(at path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func openDirectory(_ path: String) {
        guard directoryExists(at: path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        OrnamentalPanel(tone: LauncherPalette.night.opacity(0.66)) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(LauncherPalette.parchment)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(LauncherPalette.mist.opacity(0.74))
                    }
                }
                content
            }
        }
    }
}

private struct SettingField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(LauncherPalette.gold.opacity(0.88))
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherPalette.ink.opacity(0.30), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct PathInputRow: View {
    let label: String
    @Binding var value: String
    let buttonTitle: String
    var secondaryButtonTitle: String?
    var isSecondaryButtonDisabled = false
    var secondaryAction: (() -> Void)?
    let choose: () -> String?

    var body: some View {
        SettingField(label: label) {
            HStack(spacing: 10) {
                TextField(label, text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Button(buttonTitle) {
                    if let chosen = choose() {
                        value = chosen
                    }
                }
                .quest(.quiet)

                if let secondaryButtonTitle, let secondaryAction {
                    Button(secondaryButtonTitle, action: secondaryAction)
                        .quest(.quiet, disabled: isSecondaryButtonDisabled)
                }
            }
        }
    }
}
