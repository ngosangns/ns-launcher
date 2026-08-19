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
                    generalSection

                    if let game = viewModel.selectedGame {
                        gameSection(for: game)
                        storageSection
                    }
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
                Text(text.settingsDescription)
                    .font(.subheadline)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.82))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                StatusPill(title: text.sophonSourceTitle, tint: LauncherPalette.gold)
                if let game = viewModel.selectedGame {
                    StatusPill(title: game.displayName, tint: LauncherPalette.success)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var generalSection: some View {
        SettingsSection(title: text.generalSectionTitle, subtitle: text.settingsDescription) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    languageField
                    voiceLanguageField
                }
                VStack(spacing: 14) {
                    languageField
                    voiceLanguageField
                }
            }
        }
    }

    private var languageField: some View {
        SettingField(label: text.languageLabel) {
            Picker(text.languageLabel, selection: Binding(
                get: { viewModel.settings.language },
                set: { viewModel.setLanguage($0) }
            )) {
                Text(text.english).tag(AppLanguage.english)
                Text(text.vietnamese).tag(AppLanguage.vietnamese)
            }
            .pickerStyle(.segmented)
            .pointerOnHover()
        }
    }

    private var voiceLanguageField: some View {
        SettingField(label: text.voiceLanguageLabel) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(text.voiceLanguageLabel, selection: Binding(
                    get: { viewModel.settings.voiceLanguage },
                    set: { viewModel.setVoiceLanguage($0) }
                )) {
                    ForEach(VoiceLanguage.allCases) { language in
                        Text(text.voiceLanguageName(language)).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .pointerOnHover()

                Text(text.voiceLanguageDescription)
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
            }
        }
    }

    private func gameSection(for game: GameDefinition) -> some View {
        SettingsSection(title: text.selectedGame, subtitle: game.displayName) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        gameFacts(for: game)
                        displayModeField
                    }
                    VStack(spacing: 14) {
                        gameFacts(for: game)
                        displayModeField
                    }
                }

                pathFields(for: game)
                launchOptions
            }
        }
    }

    private func gameFacts(for game: GameDefinition) -> some View {
        SettingField(label: text.name) {
            VStack(alignment: .leading, spacing: 8) {
                Text(game.displayName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
                Label(text.officialSophonSource, systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.success)
            }
        }
    }

    private var displayModeField: some View {
        SettingField(label: text.displayModeLabel) {
            Picker(text.displayModeLabel, selection: Binding(
                get: { viewModel.settings.launchDisplayMode },
                set: { viewModel.setLaunchDisplayMode($0) }
            )) {
                Text(text.windowedMode).tag(LaunchDisplayMode.windowed)
                Text(text.fullscreenMode).tag(LaunchDisplayMode.fullscreen)
            }
            .pickerStyle(.segmented)
            .pointerOnHover()
        }
    }

    private func pathFields(for game: GameDefinition) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
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
                executableField(for: game)
            }
            VStack(spacing: 14) {
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
                executableField(for: game)
            }
        }
    }

    private func executableField(for game: GameDefinition) -> some View {
        SettingField(label: text.executablePath) {
            TextField(text.executablePath, text: Binding(
                get: { game.executableRelativePath },
                set: { viewModel.setExecutableRelativePathForSelectedGame($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
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
                    set: { viewModel.setCloudCompatibilityMode($0) }
                )
            )
            LaunchOption(
                title: text.acPatchLabel,
                detail: text.acPatchDescription,
                isOn: Binding(
                    get: { viewModel.settings.acPatchMode },
                    set: { viewModel.setACPatchMode($0) }
                )
            )
            LaunchOption(
                title: text.blockNetLabel,
                detail: text.blockNetDescription,
                isOn: Binding(
                    get: { viewModel.settings.blockNetMode },
                    set: { viewModel.setBlockNetMode($0) }
                )
            )
        }
    }

    private var storageSection: some View {
        SettingsSection(title: text.storageSectionTitle, subtitle: text.storageSectionSubtitle) {
            VStack(alignment: .leading, spacing: 14) {
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
                        .padding(.vertical, 12)
                } else {
                    ForEach(viewModel.voicePackages) { package in
                        voicePackageRow(package)
                    }
                }
            }
        }
    }

    private func voicePackageRow(_ package: VoicePackage) -> some View {
        let isSelected = package.voiceLanguage == viewModel.settings.voiceLanguage
        let name = package.voiceLanguage.map { text.voiceLanguageName($0) } ?? package.categoryName

        return HStack(spacing: 14) {
            Image(systemName: isSelected ? "waveform.circle.fill" : "waveform.circle")
                .font(.title3)
                .foregroundStyle(isSelected ? LauncherPalette.success : LauncherPalette.mist.opacity(0.72))
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(LauncherPalette.parchment)
                Text("\(text.voicePackSizeLabel): \(ByteCountFormatter.string(fromByteCount: package.decompressedBytes, countStyle: .file))  ·  \(text.voicePackFilesLabel): \(package.fileCount)")
                    .font(.caption)
                    .foregroundStyle(LauncherPalette.mist.opacity(0.72))
            }
            Spacer()
            if isSelected {
                StatusPill(title: text.selectedVoicePackBadge, tint: LauncherPalette.success)
            } else {
                Button(text.removeVoicePackTitle) {
                    viewModel.removeVoicePack(package)
                }
                .buttonStyle(QuestButtonStyle(role: .quiet))
                .disabled(viewModel.isManagingVoicePacks)
                .pointerOnHover(enabled: !viewModel.isManagingVoicePacks)
            }
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
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
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
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(LauncherPalette.mist.opacity(0.74))
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
        .background(LauncherPalette.warning.opacity(0.09), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(LauncherPalette.warning.opacity(0.28), lineWidth: 1)
        }
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
