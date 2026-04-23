import AppKit
import SwiftUI

struct PointerCursorModifier: ViewModifier {
    let isEnabled: Bool

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
    func pointerOnHover(enabled: Bool = true) -> some View {
        modifier(PointerCursorModifier(isEnabled: enabled))
    }
}
