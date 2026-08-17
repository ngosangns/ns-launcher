// SettingsView.swift
//
// Settings screen: language + voice pack, and (for the selected game) install root,
// executable path, display mode, the three opt-in launch toggles, and a voice-pack
// storage overview with per-pack removal. There are intentionally no archive/cache/
// package controls — the product is Sophon-only.
//
// The opt-in launch toggles (cloud compatibility, AC patch, network block) show
// their ToS/ban warning inline via the localized descriptions.

import AppKit
import SwiftUI

/// Settings screen for Sophon-only Genshin configuration.
struct SettingsView: View {
    @ObservedObject var viewModel: LauncherViewModel

    /// Convenience accessor for localized copy.
    private var text: AppText { viewModel.text }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader
                generalSection

                if let game = viewModel.selectedGame {
                    installSection(for: game)
                    storageSection
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Header block summarizing the current settings context.
    private var settingsHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text.settingsTitle)
                    .font(.largeTitle.bold())

                Text(text.settingsDescription)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

            VStack(alignment: .trailing, spacing: 10) {
                SettingsBadge(
                    title: text.sophonSourceTitle,
                    tint: .blue
                )

                if let game = viewModel.selectedGame {
                    SettingsBadge(
                        title: game.displayName,
                        tint: .orange
                    )
                }
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

    /// General app settings shared across the single bundled game.
    private var generalSection: some View {
        SettingsCard(title: text.generalSectionTitle, subtitle: text.settingsDescription) {
            LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                settingField {
                    Picker(text.languageLabel, selection: Binding(
                        get: { viewModel.settings.language },
                        set: { viewModel.setLanguage($0) }
                    )) {
                        Text(text.english).tag(AppLanguage.english)
                        Text(text.vietnamese).tag(AppLanguage.vietnamese)
                    }
                    .pickerStyle(.segmented)
                    .pointerOnHover()
                } label: {
                    Text(text.languageLabel)
                }

                settingField {
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
                } label: {
                    Text(text.voiceLanguageLabel)
                }

                Text(text.voiceLanguageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Voice-pack storage overview with per-pack removal.
    private var storageSection: some View {
        SettingsCard(title: text.storageSectionTitle, subtitle: text.storageSectionSubtitle) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(text.voicePacksLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(text.refreshVoicePacksTitle) {
                        viewModel.refreshVoicePackages()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isManagingVoicePacks)
                    .pointerOnHover(enabled: !viewModel.isManagingVoicePacks)
                }

                if viewModel.voicePackages.isEmpty {
                    Text(text.noVoicePacksFound)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.voicePackages) { package in
                        voicePackageRow(package)
                    }
                }
            }
        }
    }

    /// One voice-pack row with size, file count, and a removal action for non-selected packs.
    private func voicePackageRow(_ package: VoicePackage) -> some View {
        let isSelected = package.voiceLanguage == viewModel.settings.voiceLanguage
        let name = package.voiceLanguage.map { text.voiceLanguageName($0) } ?? package.categoryName

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body.weight(.semibold))
                HStack(spacing: 12) {
                    Text("\(text.voicePackSizeLabel): \(ByteCountFormatter.string(fromByteCount: package.decompressedBytes, countStyle: .file))")
                    Text("\(text.voicePackFilesLabel): \(package.fileCount)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Text(text.selectedVoicePackBadge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button(text.removeVoicePackTitle) {
                    viewModel.removeVoicePack(package)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isManagingVoicePacks)
                .pointerOnHover(enabled: !viewModel.isManagingVoicePacks)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Selected-game install root, executable, and display settings.
    private func installSection(for game: GameDefinition) -> some View {
        SettingsCard(title: text.selectedGame, subtitle: game.displayName) {
            LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                InfoRow(label: text.name, value: game.displayName)
                InfoRow(label: text.selectedSource, value: text.officialSophonSource)

                settingField {
                    Picker(text.displayModeLabel, selection: Binding(
                        get: { viewModel.settings.launchDisplayMode },
                        set: { viewModel.setLaunchDisplayMode($0) }
                    )) {
                        Text(text.windowedMode).tag(LaunchDisplayMode.windowed)
                        Text(text.fullscreenMode).tag(LaunchDisplayMode.fullscreen)
                    }
                    .pickerStyle(.segmented)
                    .pointerOnHover()
                } label: {
                    Text(text.displayModeLabel)
                }

                settingField {
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.cloudCompatibilityMode },
                        set: { viewModel.setCloudCompatibilityMode($0) }
                    )) {
                        Text(text.cloudCompatibilityLabel)
                    }
                    .toggleStyle(.switch)
                    .pointerOnHover()
                } label: {
                    Text(text.cloudCompatibilityLabel)
                }

                Text(text.cloudCompatibilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                settingField {
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.acPatchMode },
                        set: { viewModel.setACPatchMode($0) }
                    )) {
                        Text(text.acPatchLabel)
                    }
                    .toggleStyle(.switch)
                    .pointerOnHover()
                } label: {
                    Text(text.acPatchLabel)
                }

                Text(text.acPatchDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                settingField {
                    Toggle(isOn: Binding(
                        get: { viewModel.settings.blockNetMode },
                        set: { viewModel.setBlockNetMode($0) }
                    )) {
                        Text(text.blockNetLabel)
                    }
                    .toggleStyle(.switch)
                    .pointerOnHover()
                } label: {
                    Text(text.blockNetLabel)
                }

                Text(text.blockNetDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                PathInputRow(
                    label: text.installRoot,
                    value: Binding(
                        get: { game.installDirectory.path },
                        set: { viewModel.setInstallDirectoryForSelectedGame(URL(fileURLWithPath: $0, isDirectory: true)) }
                    ),
                    buttonTitle: text.browse,
                    secondaryButtonTitle: text.open,
                    isSecondaryButtonDisabled: !directoryExists(at: game.installDirectory.path),
                    secondaryAction: {
                        openDirectory(game.installDirectory.path)
                    },
                    choose: chooseDirectoryPath
                )

                settingField {
                    TextField(text.executablePath, text: Binding(
                        get: { game.executableRelativePath },
                        set: { viewModel.setExecutableRelativePathForSelectedGame($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                } label: {
                    Text(text.executablePath)
                }
            }
        }
    }

    /// Adaptive grid columns used by the settings cards.
    private var settingsColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 320), alignment: .top)
        ]
    }

    /// Common labeled field container for settings controls.
    private func settingField<Content: View, Label: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label()
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Opens a folder picker and returns the selected path.
    private func chooseDirectoryPath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    /// Checks that a saved path still points to an existing directory.
    private func directoryExists(at path: String) -> Bool {
        guard !path.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Opens a valid directory in Finder.
    private func openDirectory(_ path: String) {
        guard directoryExists(at: path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
    }
}

/// Capsule-style badge used by the settings header.
private struct SettingsBadge: View {
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

/// Section container used by settings groups.
private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.24), in: RoundedRectangle(cornerRadius: 20))
    }
}

/// Read-only label/value row for selected-game metadata.
private struct InfoRow: View {
    let label: String
    let value: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if monospaced {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Editable path row with optional secondary action, such as opening the folder.
private struct PathInputRow: View {
    let label: String
    @Binding var value: String
    let buttonTitle: String
    var secondaryButtonTitle: String? = nil
    var isSecondaryButtonDisabled = false
    var secondaryAction: (() -> Void)? = nil
    let choose: () -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField(label, text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Button(buttonTitle) {
                    if let chosen = choose() {
                        value = chosen
                    }
                }
                .buttonStyle(.bordered)
                .pointerOnHover()

                if let secondaryButtonTitle, let secondaryAction {
                    Button(secondaryButtonTitle, action: secondaryAction)
                        .buttonStyle(.bordered)
                        .pointerOnHover()
                        .disabled(isSecondaryButtonDisabled)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
