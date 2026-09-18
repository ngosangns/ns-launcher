// StoryLibrary.swift
//
// Loads and parses `Resources/Story/` once, applies entity auto-linking, and
// builds the reverse index ("what mentions this entity") that the entity
// detail view reads from. Everything here is bundled, static content, so
// loading is synchronous — callers should build one `StoryLibrary` and hold
// onto it (see `StoryViewModel`) rather than constructing it repeatedly.

import Foundation

struct StoryLibrary {
    let documents: [StoryDocument]
    let documentsByID: [String: StoryDocument]
    let entities: [StoryEntity]
    let entitiesByID: [String: StoryEntity]
    /// Entity id -> every section that mentions it. The entity's own home
    /// section is always first, even on the rare page where the auto-linker
    /// didn't literally repeat the name (e.g. a portrait bullet that opens
    /// with the bolded name itself still counts as a mention, but if it
    /// didn't, the home section is still worth showing first).
    let occurrences: [String: [StoryOccurrence]]

    init() {
        let entities = Self.loadEntities()
        let parsed = Self.loadDocuments()
        let linked = parsed
            .map { StoryEntityLinker.link(document: $0, entities: entities) }
            .sorted { $0.order < $1.order }

        documents = linked
        documentsByID = Dictionary(uniqueKeysWithValues: linked.map { ($0.id, $0) })
        self.entities = entities.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
        entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0) })
        occurrences = Self.buildOccurrences(documents: linked, documentsByID: documentsByID, entities: entities)
    }

    // MARK: - Loading

    private static func loadEntities() -> [StoryEntity] {
        guard let url = storyRootURL()?.appendingPathComponent("story-entities.json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([StoryEntity].self, from: data)) ?? []
    }

    private static func loadDocuments() -> [StoryDocument] {
        guard let root = storyRootURL() else { return [] }
        return loadDocuments(in: root.appendingPathComponent("chapters"), kind: .narrativeChapter)
            + loadDocuments(in: root.appendingPathComponent("quests"), kind: .questReference)
    }

    private static func loadDocuments(in directory: URL, kind: StoryDocumentKind) -> [StoryDocument] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> StoryDocument? in
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let id = url.deletingPathExtension().lastPathComponent
                return StoryMarkdownParser.parseDocument(id: id, kind: kind, order: leadingNumber(in: id), rawText: text)
            }
    }

    private static func leadingNumber(in id: String) -> Int {
        Int(id.prefix { $0.isNumber }) ?? 0
    }

    /// `.copy("Resources/Story")` in Package.swift places the folder at the
    /// bundle's top level, but the exact layout has shifted between SwiftPM
    /// versions, so this tries the documented location first and falls back
    /// to resolving it manually under `resourceURL`.
    private static func storyRootURL() -> URL? {
        let candidates = ["Story", "Resources/Story"]
        for name in candidates {
            if let url = Bundle.module.url(forResource: name, withExtension: nil) {
                return url
            }
        }
        guard let resourceURL = Bundle.module.resourceURL else { return nil }
        for name in candidates {
            let candidate = resourceURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    // MARK: - Reverse index

    private static func buildOccurrences(
        documents: [StoryDocument],
        documentsByID: [String: StoryDocument],
        entities: [StoryEntity]
    ) -> [String: [StoryOccurrence]] {
        var map: [String: [StoryOccurrence]] = [:]

        for document in documents {
            for (entityID, sectionID) in StoryEntityLinker.occurrences(in: document) {
                guard let section = document.sections.first(where: { $0.id == sectionID }) else { continue }
                map[entityID, default: []].append(
                    StoryOccurrence(
                        documentID: document.id,
                        documentTitle: document.title,
                        documentKind: document.kind,
                        sectionID: section.id,
                        sectionHeading: section.heading
                    )
                )
            }
        }

        for entity in entities {
            guard let homeDocument = documentsByID[entity.homeDocument] else { continue }
            let homeSection = entity.homeHeading.flatMap { heading in
                homeDocument.sections.first { $0.heading == heading }
            } ?? homeDocument.sections.first
            guard let section = homeSection else { continue }

            let homeOccurrence = StoryOccurrence(
                documentID: homeDocument.id,
                documentTitle: homeDocument.title,
                documentKind: homeDocument.kind,
                sectionID: section.id,
                sectionHeading: section.heading
            )
            var list = map[entity.id] ?? []
            list.removeAll { $0.id == homeOccurrence.id }
            list.insert(homeOccurrence, at: 0)
            map[entity.id] = list
        }

        return map
    }
}
