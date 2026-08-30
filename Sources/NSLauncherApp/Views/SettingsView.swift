import AppKit
import SwiftUI

private enum SettingsTab: CaseIterable {
    case general
    case display
    case launchOptions
    case cache

    func title(_ text: AppText) -> String {
        switch self {
        case .general: return text.selectedGame
        case .display: return text.displayOptionsLabel
        case .launchOptions: return text.launchOptionsTitle
        case .cache: return text.cacheManagementTitle
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gamecontroller.fill"
        case .display: return "display"
        case .launchOptions: return "flag.checkered"
        case .cache: return "trash.fill"
        }
    }
}

/// Settings screen: a sidebar table of contents plus the selected section's panel, in place of
/// one long scroll through six stacked sections.
struct SettingsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var activeSection: SettingsTab = .general

    private var text: AppText { viewModel.text }

    /// The display a fullscreen launch would stretch the configured custom resolution onto, or nil
    /// when the two have the same shape (or the launch would not be fullscreen at all).
    private var stretchingDisplay: RenderSize? {
        guard viewModel.settings.resolutionCustom,
              viewModel.settings.launchDisplayMode == .fullscreen,
              let display = DisplayGeometry.mainDisplaySize(retina: viewModel.settings.macDriverRetina) else {
            return nil
        }
        let configured = RenderSize(
            width: viewModel.settings.resolutionWidth,
            height: viewModel.settings.resolutionHeight
        )
        return configured.isStretched(onto: display) ? display : nil
    }

    private var selectedRenderBackend: RuntimeBackend {
        guard let game = viewModel.selectedGame else { return .plainWine }
        return RenderBridges.resolveBackend(
            requirements: game.runtimeRequirements,
            preferred: viewModel.settings.metalRenderBackend
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 232)
                .padding(.leading, 34)
                .padding(.trailing, 18)
                .padding(.vertical, 28)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if let game = viewModel.selectedGame {
                        sectionContent(for: game)
                    }
                }
                .frame(maxWidth: 860)
                .padding(.trailing, 34)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { viewModel.refreshCacheReport() }
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
                        macDriverOptions
                    }
                }
            case .launchOptions:
                SettingsSection(title: SettingsTab.launchOptions.title(text)) {
                    launchOptions
                }
            case .cache:
                cacheSection(for: game)
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

            // Offer only backends the selected game declares, and only when there is a choice.
            if let requirements = viewModel.selectedGame?.runtimeRequirements,
               [RuntimeRequirement.d3dMetal, .dxmt].filter({ requirements.contains($0) }).count > 1 {
                SettingField(label: text.renderBackendLabel) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Picker(text.renderBackendLabel, selection: Binding(
                                get: { selectedRenderBackend },
                                set: { viewModel.update(\.metalRenderBackend, to: $0) }
                            )) {
                                if requirements.contains(.d3dMetal) {
                                    Text(text.renderBackendD3DMetal).tag(RuntimeBackend.d3dMetal)
                                }
                                if requirements.contains(.dxmt) {
                                    Text(text.renderBackendDXMT).tag(RuntimeBackend.dxmt)
                                }
                            }
                            .pickerStyle(.segmented)
                            .fixedSize()
                            .pointerOnHover()

                            Spacer(minLength: 0)
                        }
                        Text(text.renderBackendDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SettingToggle(
                title: text.metalFXUpscalingLabel,
                detail: text.metalFXUpscalingDescription,
                isOn: Binding(
                    get: { viewModel.settings.metalFXUpscaling },
                    set: { viewModel.update(\.metalFXUpscaling, to: $0) }
                )
            )
            if viewModel.settings.metalFXUpscaling, selectedRenderBackend != .d3dMetal {
                Text(text.metalFXUnsupportedBackendWarning)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.settings.metalFXUpscaling, !viewModel.settings.resolutionCustom {
                Text(text.metalFXNeedsCustomResolutionWarning)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.gold.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingToggle(
                title: text.d3dMetalAsyncCommitLabel,
                detail: text.d3dMetalAsyncCommitDescription,
                isOn: Binding(
                    get: { viewModel.settings.d3dMetalAsyncCommit },
                    set: { viewModel.update(\.d3dMetalAsyncCommit, to: $0) }
                )
            )
            SettingToggle(
                title: text.d3dMetalMultithreadedInterfaceLabel,
                detail: text.d3dMetalMultithreadedInterfaceDescription,
                isOn: Binding(
                    get: { viewModel.settings.d3dMetalMultithreadedInterface },
                    set: { viewModel.update(\.d3dMetalMultithreadedInterface, to: $0) }
                )
            )
            d3dMetalShaderCompatibilityOptions
        }
    }

    /// D3DMetal's float-behaviour overrides, grouped under one heading because they are diagnostic
    /// switches rather than preferences: they exist to be tried one at a time against a model that
    /// renders wrong, and mean nothing on any other backend.
    @ViewBuilder
    private var d3dMetalShaderCompatibilityOptions: some View {
        if selectedRenderBackend == .d3dMetal {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(text.d3dMetalShaderCompatibilityTitle)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(LauncherPalette.gold.opacity(0.88))
                    Text(text.d3dMetalShaderCompatibilityDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SettingToggle(
                    title: text.d3dMetalSampleNaNToZeroLabel,
                    detail: text.d3dMetalSampleNaNToZeroDescription,
                    isOn: Binding(
                        get: { viewModel.settings.d3dMetalSampleNaNToZero },
                        set: { viewModel.update(\.d3dMetalSampleNaNToZero, to: $0) }
                    )
                )
                SettingToggle(
                    title: text.d3dMetalFlushPositiveInfinityToNaNLabel,
                    detail: text.d3dMetalFlushPositiveInfinityToNaNDescription,
                    isOn: Binding(
                        get: { viewModel.settings.d3dMetalFlushPositiveInfinityToNaN },
                        set: { viewModel.update(\.d3dMetalFlushPositiveInfinityToNaN, to: $0) }
                    )
                )
                SettingToggle(
                    title: text.d3dMetalForceRTZTextureWriteLabel,
                    detail: text.d3dMetalForceRTZTextureWriteDescription,
                    isOn: Binding(
                        get: { viewModel.settings.d3dMetalForceRTZTextureWrite },
                        set: { viewModel.update(\.d3dMetalForceRTZTextureWrite, to: $0) }
                    )
                )
                SettingToggle(
                    title: text.d3dMetalPositionInvarianceLabel,
                    detail: text.d3dMetalPositionInvarianceDescription,
                    isOn: Binding(
                        get: { viewModel.settings.d3dMetalPositionInvariance },
                        set: { viewModel.update(\.d3dMetalPositionInvariance, to: $0) }
                    )
                )
            }
        }
    }

    private var launchOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                // The one stretched-image case the launcher cannot resolve on the user's behalf:
                // fullscreen fills the screen by scaling, so a custom size of a different shape is
                // distorted by definition. Say so here rather than letting it be discovered in-game.
                if let display = stretchingDisplay {
                    Text(text.resolutionAspectMismatchWarning(displayWidth: display.width, displayHeight: display.height))
                        .font(.caption)
                        .foregroundStyle(LauncherPalette.gold.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
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
                Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
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
        case .gameWorldAssetCache: return "globe.americas"
        case .winePrefixTemp: return "wineglass"
        case .launcherDownloadArchives: return "archivebox"
        case .d3dMetalShaderCache: return "cpu"
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
        .hoverLift()
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
        .hoverLift()
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
