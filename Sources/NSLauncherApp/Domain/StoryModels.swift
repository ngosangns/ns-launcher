// StoryModels.swift
//
// Domain model for the in-app "Story" tab: bundled lore/quest reference content
// (`Resources/Story/`) parsed into a small block tree, plus a curated glossary of
// characters/events used to auto-link mentions across documents.
//
// Content authoring conventions live in `Resources/Story/README.md`. The parser
// only understands the markdown subset actually used there — see
// `StoryMarkdownParser`.

import Foundation

/// Which bundled sub-folder a document came from; drives sidebar grouping and
/// whether its paragraphs are eligible for entity auto-linking (both kinds are).
enum StoryDocumentKind: String, Codable, Equatable {
    case narrativeChapter
    case questReference
}

/// One bundled markdown file, parsed into an ordered list of sections.
struct StoryDocument: Identifiable, Equatable {
    /// Filename stem, e.g. "01-liyue". Unique across both bundled folders.
    let id: String
    let kind: StoryDocumentKind
    let title: String
    /// Leading numeric prefix in the filename; sort key within a kind.
    let order: Int
    let sections: [StorySection]
}

/// A heading (`##`/`###`) and the blocks under it, up to the next heading of
/// equal-or-shallower level. Content before the first heading lives in an
/// implicit section with an empty `heading`.
struct StorySection: Identifiable, Equatable {
    /// Slug of `heading`, unique within the owning document.
    let id: String
    let level: Int
    let heading: String
    let blocks: [StoryBlock]
}

/// The two callout labels used throughout the narrative chapters, plus a
/// catch-all for any other blockquote.
enum StoryCalloutKind: Equatable {
    case turningPoint
    case openMystery
    case note
}

enum StoryBlock: Equatable {
    case paragraph(StoryInlineText)
    case callout(kind: StoryCalloutKind, text: StoryInlineText)
    case table(headers: [String], rows: [[String]])
    case list(items: [StoryInlineText])
    /// A preformatted block (currently: the hangout-event ASCII quest trees).
    /// Rendered monospaced, verbatim, never entity-linked.
    case tree(lines: [String])
}

/// Markdown-flavored inline text. Entity mentions have already been rewritten
/// as `[matched text](story://entity/<id>)` links by `StoryEntityLinker`, so
/// this is ready for `AttributedString(markdown:)`.
struct StoryInlineText: Equatable {
    let markdown: String
}

/// A character, Archon, faction, nation, historical event, or cosmic concept
/// that mentions of its name/aliases should link to. Loaded from
/// `story-entities.json`; see `Resources/Story/README.md` for the authoring
/// format.
struct StoryEntity: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case character
        case archon
        case faction
        case nation
        case event
        case concept
    }

    let id: String
    let kind: Kind
    let displayName: String
    let aliases: [String]
    let summary: String?
    /// Document/heading where this entity's own profile lives; the entity
    /// detail view opens here first.
    let homeDocument: String
    let homeHeading: String?

    /// Every literal string that should resolve to this entity, longest first
    /// so the linker prefers e.g. "Kamisato Ayaka" over "Ayaka".
    var matchTerms: [String] {
        ([displayName] + aliases).sorted { $0.count > $1.count }
    }
}

/// One place an entity is mentioned, used to build its "appears in" list.
struct StoryOccurrence: Identifiable, Equatable {
    var id: String { "\(documentID)#\(sectionID)" }
    let documentID: String
    let documentTitle: String
    let documentKind: StoryDocumentKind
    let sectionID: String
    let sectionHeading: String
}

/// `story://entity/<id>` is the internal link scheme `StoryEntityLinker` emits
/// and `StoryView` intercepts via `openURL`.
enum StoryLink {
    static let scheme = "story"

    static func url(forEntity id: String) -> URL {
        URL(string: "\(scheme)://entity/\(id)")!
    }

    /// Returns the entity id encoded in a `story://entity/<id>` URL, if any.
    static func entityID(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == "entity" else { return nil }
        let path = url.path
        return path.isEmpty ? nil : String(path.dropFirst())
    }
}

/// Lowercase, diacritic-stripped, dash-joined slug used for section anchors.
/// Vietnamese headings fold to ASCII so anchors stay stable and URL-safe.
func storySlug(_ text: String) -> String {
    // "đ"/"Đ" has no combining-mark decomposition in Unicode, so
    // `.diacriticInsensitive` folding leaves it untouched; fold it by hand.
    let deDotted = text.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
    let folded = deDotted.folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi_VN"))
    let lowered = folded.lowercased()
    var slug = ""
    var lastWasDash = false
    for scalar in lowered.unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar) {
            slug.unicodeScalars.append(scalar)
            lastWasDash = false
        } else if !lastWasDash && !slug.isEmpty {
            slug.append("-")
            lastWasDash = true
        }
    }
    while slug.hasSuffix("-") {
        slug.removeLast()
    }
    return slug
}
