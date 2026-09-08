// StoryEntityLinker.swift
//
// Rewrites narrative paragraph/callout text so mentions of a known entity's
// display name or alias become `story://entity/<id>` markdown links, matched
// once at load time and cached — not re-scanned on every render.
//
// Tables, flat lists, and preformatted trees are left untouched on purpose:
// quest-title tables would turn into a wall of links otherwise. See
// `Resources/Story/README.md`.

import Foundation

enum StoryEntityLinker {
    /// Returns a copy of `document` with every paragraph/callout auto-linked
    /// against `entities`. Other block kinds pass through unchanged.
    static func link(document: StoryDocument, entities: [StoryEntity]) -> StoryDocument {
        guard let regex = buildRegex(entities: entities) else { return document }
        let lookup = buildLookup(entities: entities)

        let sections = document.sections.map { section -> StorySection in
            let blocks = section.blocks.map { block -> StoryBlock in
                switch block {
                case .paragraph(let text):
                    return .paragraph(StoryInlineText(markdown: linkedMarkdown(text.markdown, regex: regex, lookup: lookup)))
                case .callout(let kind, let text):
                    return .callout(kind: kind, text: StoryInlineText(markdown: linkedMarkdown(text.markdown, regex: regex, lookup: lookup)))
                case .table, .list, .tree:
                    return block
                }
            }
            return StorySection(id: section.id, level: section.level, heading: section.heading, blocks: blocks)
        }
        return StoryDocument(id: document.id, kind: document.kind, title: document.title, order: document.order, sections: sections)
    }

    /// Every `story://entity/<id>` occurring in `document`, one entry per
    /// section the id appears in (deduplicated). Powers each entity's
    /// "appears in" list without a second registry to maintain.
    static func occurrences(in document: StoryDocument) -> [(entityID: String, sectionID: String)] {
        var found: [(String, String)] = []
        for section in document.sections {
            var idsInSection = Set<String>()
            for block in section.blocks {
                switch block {
                case .paragraph(let text), .callout(_, let text):
                    idsInSection.formUnion(entityIDs(in: text.markdown))
                case .table, .list, .tree:
                    continue
                }
            }
            for id in idsInSection {
                found.append((id, section.id))
            }
        }
        return found
    }

    private static func entityIDs(in markdown: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "story://entity/([a-z0-9-]+)") else { return [] }
        let nsText = markdown as NSString
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return nsText.substring(with: match.range(at: 1))
        }
    }

    // MARK: - Matching

    private static func buildRegex(entities: [StoryEntity]) -> NSRegularExpression? {
        let terms = entities.flatMap { $0.matchTerms }.sorted { $0.count > $1.count }
        guard !terms.isEmpty else { return nil }
        let escaped = terms.map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "\\b(" + escaped.joined(separator: "|") + ")\\b"
        return try? NSRegularExpression(pattern: pattern)
    }

    /// First entity wins if two ever declare the exact same term; the JSON
    /// registry is expected to keep terms unique.
    private static func buildLookup(entities: [StoryEntity]) -> [String: String] {
        var map: [String: String] = [:]
        for entity in entities {
            for term in entity.matchTerms where map[term] == nil {
                map[term] = entity.id
            }
        }
        return map
    }

    private static func linkedMarkdown(_ text: String, regex: NSRegularExpression, lookup: [String: String]) -> String {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)
        guard !matches.isEmpty else { return text }

        var result = ""
        var lastEnd = 0
        for match in matches {
            let range = match.range
            guard range.location >= lastEnd else { continue }
            result += nsText.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
            let matchedText = nsText.substring(with: range)
            if let id = lookup[matchedText] {
                result += "[\(matchedText)](\(StoryLink.url(forEntity: id).absoluteString))"
            } else {
                result += matchedText
            }
            lastEnd = range.location + range.length
        }
        result += nsText.substring(from: lastEnd)
        return result
    }
}
