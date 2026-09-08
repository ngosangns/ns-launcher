// StoryViewModel.swift
//
// UI state for the Story tab. `StoryLibrary` parses ~20 bundled files plus
// entity auto-linking (a few hundred ms), so it loads on a background task
// and `library` starts `nil` — `StoryView` shows a brief loading state
// instead of blocking app launch on it.

import Foundation

@MainActor
final class StoryViewModel: ObservableObject {
    enum Selection: Equatable {
        case document(id: String, sectionID: String? = nil)
        case entity(String)
    }

    @Published private(set) var library: StoryLibrary?
    @Published var searchText: String = ""
    @Published var selection: Selection?

    init() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let library = StoryLibrary()
            await MainActor.run {
                guard let self else { return }
                self.library = library
                if self.selection == nil {
                    let firstChapter = library.documents.first { $0.kind == .narrativeChapter }
                    self.selection = firstChapter.map { .document(id: $0.id) }
                }
            }
        }
    }

    var chapters: [StoryDocument] {
        documents(kind: .narrativeChapter)
    }

    var questDocuments: [StoryDocument] {
        documents(kind: .questReference)
    }

    var entitiesByKind: [(kind: StoryEntity.Kind, entities: [StoryEntity])] {
        guard let library else { return [] }
        let filtered = filteredEntities(in: library)
        return StoryEntity.Kind.sidebarOrder.compactMap { kind in
            let matches = filtered.filter { $0.kind == kind }
            return matches.isEmpty ? nil : (kind, matches)
        }
    }

    var selectedDocument: StoryDocument? {
        guard let library, case .document(let id, _) = selection else { return nil }
        return library.documentsByID[id]
    }

    var selectedSectionID: String? {
        guard case .document(_, let sectionID) = selection else { return nil }
        return sectionID
    }

    var selectedEntity: StoryEntity? {
        guard let library, case .entity(let id) = selection else { return nil }
        return library.entitiesByID[id]
    }

    var selectedEntityOccurrences: [StoryOccurrence] {
        guard let library, case .entity(let id) = selection else { return [] }
        return library.occurrences[id] ?? []
    }

    func select(documentID: String, sectionID: String? = nil) {
        selection = .document(id: documentID, sectionID: sectionID)
    }

    func select(entityID: String) {
        selection = .entity(entityID)
    }

    /// Intercepts `story://entity/<id>` links emitted by `StoryEntityLinker`;
    /// anything else (there is currently nothing else) falls through to the
    /// system.
    func handleOpenURL(_ url: URL) -> Bool {
        guard let entityID = StoryLink.entityID(from: url) else { return false }
        select(entityID: entityID)
        return true
    }

    private func documents(kind: StoryDocumentKind) -> [StoryDocument] {
        guard let library else { return [] }
        let all = library.documents.filter { $0.kind == kind }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private func filteredEntities(in library: StoryLibrary) -> [StoryEntity] {
        guard !searchText.isEmpty else { return library.entities }
        return library.entities.filter { entity in
            entity.displayName.localizedCaseInsensitiveContains(searchText)
                || entity.aliases.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
}
