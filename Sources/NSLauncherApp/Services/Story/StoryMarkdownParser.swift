// StoryMarkdownParser.swift
//
// Turns one bundled `.md` file into a `StoryDocument`. Deliberately not a
// general CommonMark parser: it only understands the five block shapes that
// actually occur under `Resources/Story/` (see the README there) — heading,
// paragraph, blockquote callout, table, flat list — plus one ad-hoc shape,
// the box-drawing quest trees in `09-hangout-events.md`, kept verbatim and
// never entity-linked.
//
// Entity auto-linking is a separate pass (`StoryEntityLinker`) applied after
// parsing, so this file has no knowledge of the entity registry.

import Foundation

enum StoryMarkdownParser {
    /// Parses one file's raw text into a document. `id` is the filename stem
    /// (must be unique across both bundled folders); `order` is the file's
    /// leading numeric prefix, used for sidebar sort order.
    static func parseDocument(id: String, kind: StoryDocumentKind, order: Int, rawText: String) -> StoryDocument {
        var lines = rawText.components(separatedBy: "\n")
        var title = id

        var leadingIndex = 0
        while leadingIndex < lines.count, lines[leadingIndex].trimmingCharacters(in: .whitespaces).isEmpty {
            leadingIndex += 1
        }
        if leadingIndex < lines.count, let (level, text) = headingInfo(lines[leadingIndex]), level == 1 {
            title = text
            leadingIndex += 1
        }
        lines = Array(lines[leadingIndex...])

        return StoryDocument(id: id, kind: kind, title: title, order: order, sections: parseSections(lines))
    }

    // MARK: - Sections

    static func parseSections(_ lines: [String]) -> [StorySection] {
        var sections: [StorySection] = []
        var usedSlugs = Set<String>()
        var currentHeading = ""
        var currentLevel = 1
        var body: [String] = []

        func flush() {
            let blocks = parseBlocks(body)
            guard !blocks.isEmpty else {
                body = []
                return
            }
            let base = currentHeading.isEmpty ? "mo-dau" : storySlug(currentHeading)
            var slug = base
            var suffix = 2
            while usedSlugs.contains(slug) {
                slug = "\(base)-\(suffix)"
                suffix += 1
            }
            usedSlugs.insert(slug)
            sections.append(StorySection(id: slug, level: currentLevel, heading: currentHeading, blocks: blocks))
            body = []
        }

        for line in lines {
            if let (level, text) = headingInfo(line), level <= 3 {
                flush()
                currentHeading = text
                currentLevel = level
            } else {
                body.append(line)
            }
        }
        flush()
        return sections
    }

    private static func headingInfo(_ line: String) -> (level: Int, text: String)? {
        let chars = Array(line)
        var count = 0
        while count < chars.count, chars[count] == "#" {
            count += 1
        }
        guard count > 0, count < chars.count, chars[count] == " " else { return nil }
        let text = String(chars[(count + 1)...]).trimmingCharacters(in: .whitespaces)
        return (count, text)
    }

    // MARK: - Blocks

    private enum LineKind: Equatable {
        case blank, blockquote, table, list, tree, plain
    }

    private static func classify(_ line: String) -> LineKind {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .blank }
        if trimmed.hasPrefix(">") { return .blockquote }
        if trimmed.hasPrefix("|") { return .table }
        if trimmed.hasPrefix("- ") { return .list }
        if let first = trimmed.first, "├└│".contains(first) { return .tree }
        return .plain
    }

    static func parseBlocks(_ lines: [String]) -> [StoryBlock] {
        var blocks: [StoryBlock] = []
        var buffer: [String] = []
        var bufferKind: LineKind = .blank

        func flush() {
            defer { buffer = [] }
            guard !buffer.isEmpty else { return }
            switch bufferKind {
            case .blockquote:
                blocks.append(makeCallout(buffer))
            case .table:
                if let table = makeTable(buffer) {
                    blocks.append(table)
                }
            case .list:
                blocks.append(makeList(buffer))
            case .tree:
                blocks.append(.tree(lines: buffer))
            case .plain:
                blocks.append(makeParagraph(buffer))
            case .blank:
                break
            }
        }

        for rawLine in lines {
            let kind = classify(rawLine)
            if kind == .blank {
                flush()
                bufferKind = .blank
                continue
            }
            if kind != bufferKind {
                flush()
                bufferKind = kind
            }
            buffer.append(rawLine)
        }
        flush()
        return blocks
    }

    private static func makeParagraph(_ lines: [String]) -> StoryBlock {
        let joined = lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        return .paragraph(StoryInlineText(markdown: joined))
    }

    private static func stripQuotePrefix(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        guard text.hasPrefix(">") else { return text }
        text.removeFirst()
        if text.hasPrefix(" ") {
            text.removeFirst()
        }
        return text
    }

    private static func makeCallout(_ lines: [String]) -> StoryBlock {
        let joined = lines.map(stripQuotePrefix).joined(separator: " ")
        let kind: StoryCalloutKind
        if joined.hasPrefix("**Bước ngoặt.**") {
            kind = .turningPoint
        } else if joined.hasPrefix("**Bí ẩn còn bỏ ngỏ.**") {
            kind = .openMystery
        } else {
            kind = .note
        }
        return .callout(kind: kind, text: StoryInlineText(markdown: joined))
    }

    private static func parseRow(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") { text.removeLast() }
        return text.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Assumes a leading `|---|---|` separator row, as every bundled table has.
    private static func makeTable(_ lines: [String]) -> StoryBlock? {
        guard lines.count >= 2 else { return nil }
        let headers = parseRow(lines[0])
        let rows = lines.dropFirst(2).map(parseRow)
        return .table(headers: headers, rows: Array(rows))
    }

    private static func makeList(_ lines: [String]) -> StoryBlock {
        let items = lines.map { line -> StoryInlineText in
            var text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("- ") {
                text.removeFirst(2)
            }
            return StoryInlineText(markdown: text)
        }
        return .list(items: items)
    }
}
