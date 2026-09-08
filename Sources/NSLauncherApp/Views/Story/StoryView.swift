// StoryView.swift
//
// Root of the Story tab: a sidebar (search + chapters + character/event
// glossary + quest reference) and a detail pane, mirroring SettingsView's
// sidebar/ScrollView split rather than a native NavigationSplitView, to stay
// in the app's fully custom celestial chrome.
//
// `story://entity/<id>` links emitted by `StoryEntityLinker` are intercepted
// via `openURL` and turned into an in-app selection change; nothing else
// currently uses that scheme.

import SwiftUI

struct StoryView: View {
    @ObservedObject var viewModel: StoryViewModel
    let text: AppText

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 268)
                // Leading/trailing must clear WindowFrameOrnament's corner brackets, which occupy a
                // 16-40pt band from each window edge — see HomeView's matching comment.
                .padding(.leading, 44)
                .padding(.trailing, 18)
                .padding(.vertical, 28)

            detail
                .padding(.trailing, 44)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.openURL, OpenURLAction { url in
            viewModel.handleOpenURL(url) ? .handled : .systemAction
        })
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            copyrightNotice

            TextField(text.storySearchPlaceholder, text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(LauncherPalette.parchment)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(LauncherPalette.night.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if viewModel.library == nil {
                ProgressView(text.storyLoadingLabel)
                    .tint(LauncherPalette.gold)
                    .foregroundStyle(LauncherPalette.mist)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        documentGroup(title: text.storyChaptersLabel, documents: viewModel.chapters)
                        entityGroup
                        documentGroup(title: text.storyQuestsLabel, documents: viewModel.questDocuments)

                        if viewModel.chapters.isEmpty && viewModel.entitiesByKind.isEmpty && viewModel.questDocuments.isEmpty {
                            Text(text.storyEmptySearchResult)
                                .font(.caption)
                                .foregroundStyle(LauncherPalette.mist.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private var copyrightNotice: some View {
        Text(text.storyCopyrightNotice)
            .font(.caption2)
            .foregroundStyle(LauncherPalette.mist.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func documentGroup(title: String, documents: [StoryDocument]) -> some View {
        if !documents.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                groupLabel(title)
                ForEach(documents) { document in
                    SidebarTabButton(
                        title: document.title,
                        systemImage: document.kind.systemImage,
                        isSelected: isSelected(documentID: document.id)
                    ) {
                        viewModel.select(documentID: document.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var entityGroup: some View {
        if !viewModel.entitiesByKind.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                groupLabel(text.storyEntitiesLabel)
                ForEach(viewModel.entitiesByKind, id: \.kind) { group in
                    Text(text.storyEntityKindLabel(group.kind).uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(LauncherPalette.mist.opacity(0.55))
                        .padding(.top, 4)
                    ForEach(group.entities) { entity in
                        SidebarTabButton(
                            title: entity.displayName,
                            systemImage: entity.kind.systemImage,
                            isSelected: isSelected(entityID: entity.id)
                        ) {
                            viewModel.select(entityID: entity.id)
                        }
                    }
                }
            }
        }
    }

    private func groupLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(LauncherPalette.gold.opacity(0.88))
    }

    private func isSelected(documentID: String) -> Bool {
        if case .document(let id, _) = viewModel.selection { return id == documentID }
        return false
    }

    private func isSelected(entityID: String) -> Bool {
        if case .entity(let id) = viewModel.selection { return id == entityID }
        return false
    }

    // MARK: - Detail

    private var detail: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                Group {
                    if let document = viewModel.selectedDocument {
                        StoryDocumentView(document: document)
                    } else if let entity = viewModel.selectedEntity, let library = viewModel.library {
                        StoryEntityDetailView(
                            entity: entity,
                            occurrences: viewModel.selectedEntityOccurrences,
                            library: library,
                            text: text,
                            onSelectDocument: { documentID, sectionID in
                                viewModel.select(documentID: documentID, sectionID: sectionID)
                            }
                        )
                    } else if viewModel.library != nil {
                        Text(text.storySelectAPrompt)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(LauncherPalette.mist.opacity(0.75))
                    }
                }
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: viewModel.selectedSectionID) { _, sectionID in
                guard let sectionID else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(sectionID, anchor: .top)
                }
            }
        }
    }
}
