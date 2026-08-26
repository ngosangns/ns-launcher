import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: LauncherViewModel

    private var text: AppText { viewModel.text }

    var body: some View {
        ZStack {
            CelestialBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    settingsHeader

                    if let game = viewModel.selectedGame {
                        gameSection(for: game)
                        storageSection
                        cacheSection(for: game)
                    }
                    d3dMetalSetupSection
                }
                .frame(maxWidth: 1_080)
                .padding(.horizontal, 34)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(text.settingsTitle)
    }

    private var settingsHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label(text.settingsTitle.uppercased(), systemImage: "gearshape.2.fill")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(LauncherPalette.goldHighlight)
                Text(text.settingsTitle)
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(LauncherPalette.parchment)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func gameSection(for game: GameDefinition) -> some View {
        SettingsSection(title: text.selectedGame) {
            VStack(alignment: .leading, spacing: 14) {
                displayModeField
                pathFields(for: game)
                voicePackageManagement
                macDriverOptions
                launchOptions
            }
        }
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

    private var macDriverOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.displayOptionsLabel)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1)
                .foregroundStyle(LauncherPalette.gold.opacity(0.88))

            SettingToggle(
                title: text.retinaLabel,
                detail: text.retinaDescription,
                isOn: Binding(
                    get: { viewModel.settings.macDriverRetina },
                    set: { viewModel.update(\.macDriverRetina, to: $0) }
                )
            )
            SettingToggle(
                title: text.leftCommandLabel,
                detail: text.leftCommandDescription,
                isOn: Binding(
                    get: { viewModel.settings.leftCommandIsCtrl },
                    set: { viewModel.update(\.leftCommandIsCtrl, to: $0) }
                )
            )
            SettingToggle(
                title: text.metalHUDLabel,
                detail: text.metalHUDDescription,
                isOn: Binding(
                    get: { viewModel.settings.showMetalHUD },
                    set: { viewModel.update(\.showMetalHUD, to: $0) }
                )
            )
            SettingToggle(
                title: text.hdrLabel,
                detail: text.hdrDescription,
                isOn: Binding(
                    get: { viewModel.settings.enableHDR },
                    set: { viewModel.update(\.enableHDR, to: $0) }
                )
            )

            SettingToggle(
                title: text.metalFXUpscalingLabel,
                detail: text.metalFXUpscalingDescription,
                isOn: Binding(
                    get: { viewModel.settings.metalFXUpscaling },
                    set: { viewModel.update(\.metalFXUpscaling, to: $0) }
                )
            )
            if viewModel.settings.metalFXUpscaling, !viewModel.settings.resolutionCustom {
                Text(text.metalFXNeedsCustomResolutionWarning)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var launchOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.launchOptionsTitle)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1)
                .foregroundStyle(LauncherPalette.gold.opacity(0.88))

            LaunchOption(
                title: text.cloudCompatibilityLabel,
                detail: text.cloudCompatibilityDescription,
                isOn: Binding(
                    get: { viewModel.settings.cloudCompatibilityMode },
                    set: { viewModel.update(\.cloudCompatibilityMode, to: $0) }
                )
            )
            LaunchOption(
                title: text.acPatchLabel,
                detail: text.acPatchDescription,
                isOn: Binding(
                    get: { viewModel.settings.acPatchMode },
                    set: { viewModel.update(\.acPatchMode, to: $0) }
                )
            )
            LaunchOption(
                title: text.blockNetLabel,
                detail: text.blockNetDescription,
                isOn: Binding(
                    get: { viewModel.settings.blockNetMode },
                    set: { viewModel.update(\.blockNetMode, to: $0) }
                )
            )
            LaunchOption(
                title: text.timeoutFixLabel,
                detail: text.timeoutFixDescription,
                isOn: Binding(
                    get: { viewModel.settings.timeoutFix },
                    set: { viewModel.update(\.timeoutFix, to: $0) }
                )
            )
            LaunchOption(
                title: text.steamPatchLabel,
                detail: text.steamPatchDescription,
                isOn: Binding(
                    get: { viewModel.settings.steamPatch },
                    set: { viewModel.update(\.steamPatch, to: $0) }
                )
            )
            LaunchOption(
                title: text.resolutionCustomLabel,
                detail: text.resolutionCustomDescription,
                isOn: Binding(
                    get: { viewModel.settings.resolutionCustom },
                    set: { viewModel.update(\.resolutionCustom, to: $0) }
                )
            )
            if viewModel.settings.resolutionCustom {
                HStack(spacing: 12) {
                    numericField(label: text.resolutionWidthLabel, value: viewModel.settings.resolutionWidth, set: viewModel.setResolutionWidth)
                    numericField(label: text.resolutionHeightLabel, value: viewModel.settings.resolutionHeight, set: viewModel.setResolutionHeight)
                }
            }
            LaunchOption(
                title: text.proxyEnabledLabel,
                detail: text.proxyEnabledDescription,
                isOn: Binding(
                    get: { viewModel.settings.proxyEnabled },
                    set: { viewModel.update(\.proxyEnabled, to: $0) }
                )
            )
            if viewModel.settings.proxyEnabled {
                SettingField(label: text.proxyHostLabel) {
                    TextField(text.proxyHostLabel, text: Binding(
                        get: { viewModel.settings.proxyHost },
                        set: { viewModel.update(\.proxyHost, to: $0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    private func numericField(label: String, value: Int, set: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(LauncherPalette.gold.opacity(0.88))
            TextField(label, value: Binding(
                get: { value },
                set: { set($0) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: 160)
        }
    }

    private var voicePackageManagement: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(text.voicePacksLabel)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.88))
                Spacer()
                Button(text.refreshVoicePacksTitle) {
                    viewModel.refreshVoicePackages()
                }
                .buttonStyle(QuestButtonStyle(role: .quiet))
                .disabled(viewModel.isManagingVoicePacks)
                .pointerOnHover(enabled: !viewModel.isManagingVoicePacks)
            }

            if viewModel.voicePackages.isEmpty {
                Label(text.noVoicePacksFound, systemImage: "tray")
                    .font(.subheadline)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.74))
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.voicePackages) { package in
                    voicePackageRow(package)
                }
            }
        }
    }

    private var storageSection: some View {
        SettingsSection(title: text.storageSectionTitle) {
            VStack(alignment: .leading, spacing: 12) {
                Text(text.installedContentLabel)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.88))

                if viewModel.storageInventory.contentGroups.isEmpty {
                    Label(text.noStorageContentFound, systemImage: "externaldrive")
                        .font(.subheadline)
                        .foregroundStyle(LauncherPalette.mist.opacity(0.74))
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.storageInventory.contentGroups) { group in
                        storageGroupRow(group)
                    }
                }

                Divider().overlay(LauncherPalette.mist.opacity(0.14))
                questAssetAnalysis(viewModel.storageInventory.questAssetAnalysis)
            }
        }
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
                    .buttonStyle(QuestButtonStyle(role: .quiet))
                    .disabled(viewModel.isManagingCache)
                    .pointerOnHover(enabled: !viewModel.isManagingCache)
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
        .onAppear { viewModel.refreshCacheReport() }
    }

    private func cacheRow(_ item: RemovableCache) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: Self.cacheIcon(for: item.kind))
                .font(.title3)
                .foregroundStyle(LauncherPalette.goldHighlight)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(text.cacheKindLabel(item.kind))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
                Text(text.cacheKindDescription(item.kind))
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 6) {
                Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                Button(text.clearCacheTitle) {
                    viewModel.clearCache(item.kind)
                }
                .buttonStyle(QuestButtonStyle(role: .quiet))
                .disabled(viewModel.isManagingCache || item.sizeBytes == 0)
                .pointerOnHover(enabled: !viewModel.isManagingCache && item.sizeBytes > 0)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LauncherPalette.mist.opacity(0.12)).frame(height: 1)
        }
    }

    private var d3dMetalSetupSection: some View {
        SettingsSection(title: text.d3dMetalSetupTitle) {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isCrossOverInstalled {
                    Label(text.d3dMetalAlreadyInstalled, systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(LauncherPalette.mist.opacity(0.82))
                } else {
                    Text(text.d3dMetalSetupDescription)
                        .font(.caption)
                        .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    Button(text.installCrossOverButtonTitle) {
                        viewModel.installCrossOverViaHomebrew()
                    }
                    .buttonStyle(QuestButtonStyle(role: .primary))
                    .disabled(viewModel.isInstallingCrossOver)
                    .pointerOnHover(enabled: !viewModel.isInstallingCrossOver)
                    if viewModel.isInstallingCrossOver {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(viewModel.statusText)
                                .font(.caption)
                                .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                        }
                    }
                }
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
            Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(LauncherPalette.goldHighlight)
        }
        .padding(.vertical, 10)
    }

    private static func cacheIcon(for kind: RemovableCache.Kind) -> String {
        switch kind {
        case .cutsceneVideos: return "film"
        case .gameWebCache: return "globe"
        case .gameSDKCache: return "square.stack.3d.up"
        case .winePrefixTemp: return "wineglass"
        case .launcherDownloadArchives: return "archivebox"
        }
    }

    private func storageGroupRow(_ group: StorageContentGroup) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "speaker.wave.2")
                .font(.title3)
                .foregroundStyle(LauncherPalette.goldHighlight)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(text.audioStorageLabel)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
                Text("\(text.localStorageLabel): \(ByteCountFormatter.string(fromByteCount: group.localBytes, countStyle: .file))  ·  \(text.storageFilesLabel): \(group.localFileCount)")
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                Text("\(text.availableStorageLabel): \(ByteCountFormatter.string(fromByteCount: group.availableBytes, countStyle: .file))  ·  \(text.storageFilesLabel): \(group.availableFileCount)")
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LauncherPalette.mist.opacity(0.12)).frame(height: 1)
        }
    }

    private func questAssetAnalysis(_ analysis: QuestAssetAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(text.questResourceAnalysisLabel, systemImage: "questionmark.folder")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(1)
                .foregroundStyle(LauncherPalette.gold.opacity(0.88))
            Text(text.questResourceMappingUnavailable)
                .font(.caption)
                .foregroundStyle(LauncherPalette.warning.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            if !analysis.containerGroups.isEmpty {
                Text(text.runtimeContainersLabel)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.74))
                    .padding(.top, 2)
                ForEach(analysis.containerGroups) { group in
                    HStack(spacing: 8) {
                        Text(text.questAssetContainerLabel(group.kind))
                            .font(.caption)
                            .foregroundStyle(LauncherPalette.parchment.opacity(0.92))
                        Spacer(minLength: 8)
                        Text("\(ByteCountFormatter.string(fromByteCount: group.localBytes, countStyle: .file)) · \(group.localFileCount)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func voicePackageRow(_ package: VoicePackage) -> some View {
        let name = package.voiceLanguage.map { text.voiceLanguageName($0) } ?? package.categoryName

        return HStack(spacing: 14) {
            Image(systemName: "waveform.circle")
                .font(.title3)
                .foregroundStyle(LauncherPalette.mist.opacity(0.72))
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
                Text("\(text.voicePackSizeLabel): \(ByteCountFormatter.string(fromByteCount: package.localBytes, countStyle: .file))  ·  \(text.voicePackFilesLabel): \(package.localFileCount)")
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
            }
            Spacer()
            Button(text.removeVoicePackTitle) {
                viewModel.removeVoicePack(package)
            }
            .buttonStyle(QuestButtonStyle(role: .quiet))
            .disabled(viewModel.isManagingVoicePacks)
            .pointerOnHover(enabled: !viewModel.isManagingVoicePacks)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(LauncherPalette.mist.opacity(0.12)).frame(height: 1)
        }
    }

    private func chooseDirectoryPath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
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

private struct LaunchOption: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
            }
            .toggleStyle(.switch)
            .tint(LauncherPalette.gold)
            .pointerOnHover()

            Text(detail)
                .font(.caption)
                .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LauncherPalette.warning.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(LauncherPalette.warning.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct SettingToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
            }
            .toggleStyle(.switch)
            .tint(LauncherPalette.gold)
            .pointerOnHover()

            Text(detail)
                .font(.caption)
                .foregroundStyle(LauncherPalette.mist.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
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
                .buttonStyle(QuestButtonStyle(role: .quiet))
                .pointerOnHover()

                if let secondaryButtonTitle, let secondaryAction {
                    Button(secondaryButtonTitle, action: secondaryAction)
                        .buttonStyle(QuestButtonStyle(role: .quiet))
                        .disabled(isSecondaryButtonDisabled)
                        .pointerOnHover(enabled: !isSecondaryButtonDisabled)
                }
            }
        }
    }
}
