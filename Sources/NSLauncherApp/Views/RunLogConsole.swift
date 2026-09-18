// RunLogConsole.swift
//
// The scrolling text view behind the Home tab's log panes.
//
// A SwiftUI `Text` lays out its whole string every time that string changes.
// The run log is capped at `RunLogBuffer.retainedCharacters` and is rewritten on
// every flush while a game or an update is streaming output, so that came to a
// full layout pass over ~80 KB of monospaced text several times a second, on the
// main thread, for content that is almost entirely scrolled out of sight.
// `NSTextView` lays out only what is on screen, which is the whole reason this
// drops to AppKit rather than styling a `Text`.

import AppKit
import SwiftUI

/// A read-only, selectable, auto-tailing console for one log channel.
struct RunLogConsole: NSViewRepresentable {
    let text: String
    /// Colour and font are passed in rather than read from the palette here so
    /// this file stays a rendering detail and the styling lives with the rest of
    /// the Home tab's chrome.
    var font: NSFont
    var textColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.font = font
        textView.textColor = textColor
        // Only the visible run of glyphs gets laid out; the rest is measured
        // lazily as the user scrolls. This is the reason for the AppKit detour.
        textView.layoutManager?.allowsNonContiguousLayout = true
        apply(text, to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.font != font { textView.font = font }
        if textView.textColor != textColor { textView.textColor = textColor }
        guard textView.string != text else { return }
        apply(text, to: textView)
        scrollToBottom(scrollView)
    }

    /// Appends when the new text merely extends the old, and replaces otherwise.
    ///
    /// Appending is the case that matters: a flush adds a few hundred bytes to a
    /// buffer of tens of thousands, and replacing the whole storage would throw
    /// away the layout that was just computed for everything above it. The log
    /// is also trimmed from the front once it passes its cap, which is the case
    /// that falls through to a replace.
    private func apply(_ newText: String, to textView: NSTextView) {
        guard let storage = textView.textStorage else {
            textView.string = newText
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let current = textView.string
        if !current.isEmpty, newText.hasPrefix(current) {
            let addition = String(newText.dropFirst(current.count))
            storage.append(NSAttributedString(string: addition, attributes: attributes))
        } else {
            storage.setAttributedString(NSAttributedString(string: newText, attributes: attributes))
        }
    }

    private func scrollToBottom(_ scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}
