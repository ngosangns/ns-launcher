// PointerCursorModifier.swift
//
// Adds a pointing-hand cursor to clickable controls on macOS via an NSCursor
// push/pop on hover, exposed as the `.pointerOnHover()` view modifier.

import AppKit
import SwiftUI

/// Adds a pointing-hand cursor to clickable SwiftUI controls on macOS.
struct PointerCursorModifier: ViewModifier {
    let isEnabled: Bool
    /// Hover state for the caller, so a control that tracks its own highlight
    /// shares this modifier's tracking area instead of installing a second one.
    /// Repeated cells are the reason: a grid of a hundred cards was two
    /// `NSTrackingArea`s per card.
    let onHoverChange: ((Bool) -> Void)?

    /// Whether this view is the one currently holding a pushed cursor.
    ///
    /// `NSCursor` is a stack, so an unmatched `push` leaves the pointing hand
    /// stuck for good. A view can be torn down while the pointer is still over
    /// it — switching tabs away from a hovered card does exactly that — and the
    /// exit callback never arrives, so the pop has to be guaranteed on
    /// disappear rather than left to `onHover`.
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                onHoverChange?(hovering)
                guard isEnabled else { return }
                if hovering {
                    guard !isPushed else { return }
                    isPushed = true
                    NSCursor.pointingHand.push()
                } else {
                    pop()
                }
            }
            .onDisappear(perform: pop)
    }

    private func pop() {
        guard isPushed else { return }
        isPushed = false
        NSCursor.pop()
    }
}

extension View {
    /// Convenience modifier used by buttons and segmented controls.
    ///
    /// Pass `onHoverChange` instead of chaining a second `.onHover` when the
    /// control also drives its own hover styling.
    func pointerOnHover(enabled: Bool = true,
                        onHoverChange: ((Bool) -> Void)? = nil) -> some View {
        modifier(PointerCursorModifier(isEnabled: enabled, onHoverChange: onHoverChange))
    }
}
