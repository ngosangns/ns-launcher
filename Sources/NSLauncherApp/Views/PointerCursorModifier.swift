// PointerCursorModifier.swift
//
// Adds a pointing-hand cursor to clickable controls on macOS via an NSCursor
// push/pop on hover, exposed as the `.pointerOnHover()` view modifier.

import AppKit
import SwiftUI

/// Adds a pointing-hand cursor to clickable SwiftUI controls on macOS.
struct PointerCursorModifier: ViewModifier {
    let isEnabled: Bool

    /// Pushes and pops NSCursor as hover state changes.
    func body(content: Content) -> some View {
        content.onHover { hovering in
            guard isEnabled else { return }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    /// Convenience modifier used by buttons and segmented controls.
    func pointerOnHover(enabled: Bool = true) -> some View {
        modifier(PointerCursorModifier(isEnabled: enabled))
    }
}
