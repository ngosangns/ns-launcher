// StoryPresentation.swift
//
// Non-localized presentation mappings (SF Symbols, accent colors) for story
// domain types. Localized labels stay in `AppText`; this file only maps enum
// cases to visuals so `StoryModels.swift` doesn't need to import SwiftUI.

import SwiftUI

extension StoryEntity.Kind {
    /// Sidebar/detail grouping order — narrative-central kinds first.
    static let sidebarOrder: [StoryEntity.Kind] = [.archon, .character, .nation, .faction, .event, .concept]

    var systemImage: String {
        switch self {
        case .character: return "person.fill"
        case .archon: return "sun.max.fill"
        case .faction: return "flag.fill"
        case .nation: return "globe.asia.australia.fill"
        case .event: return "bolt.fill"
        case .concept: return "sparkles"
        }
    }
}

extension StoryCalloutKind {
    var accentColor: Color {
        switch self {
        case .turningPoint: return LauncherPalette.gold
        case .openMystery: return LauncherPalette.sky
        case .note: return LauncherPalette.mist
        }
    }

    var systemImage: String {
        switch self {
        case .turningPoint: return "arrow.triangle.branch"
        case .openMystery: return "questionmark.circle.fill"
        case .note: return "quote.opening"
        }
    }
}

extension StoryDocumentKind {
    var systemImage: String {
        switch self {
        case .narrativeChapter: return "book.closed.fill"
        case .questReference: return "list.bullet.rectangle.portrait.fill"
        }
    }
}
