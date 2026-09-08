// AbyssPresentation.swift
//
// SF Symbol and colour for the Abyss domain enums.
//
// Lives here, not in `Domain/Abyss/`, so the domain types stay free of SwiftUI —
// the same split `Views/Story/StoryPresentation.swift` uses. Wording lives in
// `AppText`, not here.

import SwiftUI

extension GenshinElement {
    var symbolName: String {
        switch self {
        case .anemo: return "wind"
        case .geo: return "mountain.2.fill"
        case .electro: return "bolt.fill"
        case .dendro: return "leaf.fill"
        case .hydro: return "drop.fill"
        case .pyro: return "flame.fill"
        case .cryo: return "snowflake"
        }
    }

    /// Roughly the in-game element colours, pulled toward the launcher's palette
    /// so seven of them can sit next to each other without clashing.
    var accentColor: Color {
        switch self {
        case .anemo: return Color(red: 0.45, green: 0.82, blue: 0.72)
        case .geo: return Color(red: 0.93, green: 0.76, blue: 0.35)
        case .electro: return Color(red: 0.72, green: 0.56, blue: 0.90)
        case .dendro: return Color(red: 0.60, green: 0.83, blue: 0.38)
        case .hydro: return Color(red: 0.40, green: 0.72, blue: 0.94)
        case .pyro: return Color(red: 0.95, green: 0.52, blue: 0.36)
        case .cryo: return Color(red: 0.62, green: 0.88, blue: 0.94)
        }
    }
}

extension WeaponType {
    var symbolName: String {
        switch self {
        case .sword: return "line.diagonal"
        case .claymore: return "hammer.fill"
        case .polearm: return "arrow.up.right"
        case .bow: return "arrow.up.forward"
        case .catalyst: return "sparkles"
        }
    }
}

extension AbyssRole {
    var symbolName: String {
        switch self {
        case .mainDPS: return "burst.fill"
        case .subDPS: return "sparkle"
        case .support: return "hands.and.sparkles.fill"
        case .shield: return "shield.fill"
        case .healer: return "cross.case.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .mainDPS: return LauncherPalette.goldHighlight
        case .subDPS: return LauncherPalette.gold
        case .support: return LauncherPalette.mist
        case .shield: return LauncherPalette.sky
        case .healer: return LauncherPalette.success
        }
    }
}

extension AbyssTeamNote {
    var symbolName: String {
        switch self {
        case .noSustainPenalty: return "exclamationmark.triangle.fill"
        case .breaksShield: return "shield.lefthalf.filled.slash"
        case .exploitsWeakness: return "target"
        case .moonsignAscendantGleam: return "moon.stars.fill"
        case .hexereiSecretRite: return "wand.and.stars"
        case .resonance: return "circle.hexagongrid.fill"
        case .weaponContested: return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    /// Warnings read differently from bonuses, so they are tinted differently.
    var accentColor: Color {
        switch self {
        case .noSustainPenalty, .weaponContested: return LauncherPalette.warning
        case .breaksShield, .exploitsWeakness: return LauncherPalette.success
        case .moonsignAscendantGleam, .hexereiSecretRite, .resonance: return LauncherPalette.goldHighlight
        }
    }
}
