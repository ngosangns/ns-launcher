import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var packageURLText = ""
    @State private var partURLRows: [String] = []

    private var text: AppText { viewModel.text }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsHeader
                runtimeSection

                if let game = viewModel.selectedGame {
                    installSection(for: game)
                    packageSection(for: game)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: syncPackageFields)
    }

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
                    title: text.toolsSectionTitle,
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

    private var runtimeSection: some View {
        SettingsCard(title: text.toolsSectionTitle, subtitle: text.settingsDescription) {
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

                PathInputRow(
                    label: text.downloadCacheDirectory,
                    value: Binding(
                        get: { viewModel.settings.downloadCacheDirectory },
                        set: {
                            viewModel.settings.downloadCacheDirectory = $0
                            viewModel.persistSettings()
                        }
                    ),
                    buttonTitle: text.browse,
                    secondaryButtonTitle: text.open,
                    isSecondaryButtonDisabled: !directoryExists(at: viewModel.settings.downloadCacheDirectory),
                    secondaryAction: {
                        openDirectory(viewModel.settings.downloadCacheDirectory)
                    },
                    choose: chooseDirectoryPath
                )

                PathInputRow(
                    label: text.temporaryExtractionDirectory,
                    value: Binding(
                        get: { viewModel.settings.temporaryExtractionDirectory },
                        set: {
                            viewModel.settings.temporaryExtractionDirectory = $0
                            viewModel.persistSettings()
                        }
                    ),
                    buttonTitle: text.browse,
                    secondaryButtonTitle: text.open,
                    isSecondaryButtonDisabled: !directoryExists(at: viewModel.settings.temporaryExtractionDirectory),
                    secondaryAction: {
                        openDirectory(viewModel.settings.temporaryExtractionDirectory)
                    },
                    choose: chooseDirectoryPath
                )
            }
        }
    }

    private func installSection(for game: GameDefinition) -> some View {
        SettingsCard(title: text.selectedGame, subtitle: game.displayName) {
            LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                InfoRow(label: text.name, value: game.displayName)
                InfoRow(label: text.strategy, value: game.installerStrategy.rawValue)

                PathInputRow(
                    label: text.installRoot,
                    value: Binding(
                        get: { game.installDirectory.path },
                        set: { viewModel.setInstallDirectoryForSelectedGame(URL(fileURLWithPath: $0, isDirectory: true)) }
                    ),
                    buttonTitle: text.browse,
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

    private func packageSection(for game: GameDefinition) -> some View {
        SettingsCard(title: text.gamePackageSectionTitle, subtitle: text.packageLinksDescription) {
            if game.installerStrategy == .streamingManifest {
                LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                    InfoRow(label: text.selectedSource, value: text.officialStreamingSource)
                    InfoRow(label: text.strategy, value: text.installStrategyDescription(game.installerStrategy))
                }
            } else {
                settingField {
                    Picker(text.archiveFormat, selection: Binding(
                        get: { game.packageSource?.archiveFormat ?? .sevenZip },
                        set: { newFormat in
                            viewModel.setArchiveFormatForSelectedGame(newFormat)
                            syncPackageFields()
                        }
                    )) {
                        ForEach(ArchiveFormat.allCases) { format in
                            Text(format.fileExtensionHint).tag(format)
                        }
                    }
                    .pointerOnHover()
                } label: {
                    Text(text.archiveFormat)
                }

                if game.packageSource?.archiveFormat == .multipartZip {
                    LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                        InfoRow(
                            label: text.archiveFileName,
                            value: game.packageSource?.archiveFileName ?? text.noPackageConfigured,
                            monospaced: true
                        )

                        InfoRow(
                            label: text.selectedSource,
                            value: text.archiveTypeDescription(game.packageSource?.archiveFormat ?? .multipartZip)
                        )
                    }

                    Text(text.derivedFromFirstPart)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(partURLRows.enumerated()), id: \.offset) { index, _ in
                            settingField {
                                HStack(alignment: .top, spacing: 10) {
                                    TextField(
                                        "\(text.packageLinkRow) \(index + 1)",
                                        text: Binding(
                                            get: { partURLRows[index] },
                                            set: { newValue in
                                                partURLRows[index] = newValue
                                                persistPartRows()
                                            }
                                        )
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))

                                    Button(text.remove) {
                                        partURLRows.remove(at: index)
                                        persistPartRows()
                                    }
                                    .buttonStyle(.bordered)
                                    .pointerOnHover()
                                }
                            } label: {
                                Text("\(text.packageLinkRow) \(index + 1)")
                            }
                        }

                        Button(text.addLink) {
                            partURLRows.append("")
                        }
                        .buttonStyle(.bordered)
                        .pointerOnHover()
                    }

                    Text(text.multipartHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    settingField {
                        TextField(text.packageURL, text: Binding(
                            get: { game.packageSource?.remoteURL?.absoluteString ?? packageURLText },
                            set: {
                                packageURLText = $0
                                if $0.isEmpty {
                                    viewModel.clearPackageURLForSelectedGame()
                                } else if let url = URL(string: $0) {
                                    viewModel.setPackageURLForSelectedGame(url)
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    } label: {
                        Text(text.singlePackageLink)
                    }

                    LazyVGrid(columns: settingsColumns, alignment: .leading, spacing: 16) {
                        InfoRow(
                            label: text.selectedSource,
                            value: game.packageSource?.remoteURL == nil ? text.remoteNotConfigured : text.remoteConfigured
                        )

                        InfoRow(
                            label: text.archive,
                            value: text.archiveTypeDescription(game.packageSource?.archiveFormat ?? .sevenZip)
                        )
                    }

                    if game.packageSource?.remoteURL == nil {
                        Text(text.packageURLOptional)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var settingsColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 320), alignment: .top)
        ]
    }

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

    private func syncPackageFields() {
        packageURLText = viewModel.selectedGame?.packageSource?.remoteURL?.absoluteString ?? ""
        partURLRows = (viewModel.selectedGame?.packageSource?.partURLs ?? [])
            .map(\.absoluteString)
        if partURLRows.isEmpty,
           viewModel.selectedGame?.packageSource?.archiveFormat == .multipartZip {
            partURLRows = [""]
        }
    }

    private func persistPartRows() {
        let urls = partURLRows
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap(URL.init(string:))
        viewModel.setPartURLsForSelectedGame(urls)
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
