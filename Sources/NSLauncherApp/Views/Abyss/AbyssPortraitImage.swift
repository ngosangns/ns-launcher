// AbyssPortraitImage.swift
//
// Renders a bundled character or weapon portrait, falling back to the element
// or weapon-type glyph when the file is missing — an unfetched icon, or a
// character/weapon added since `scripts/fetch-abyss-icons.py` last ran, should
// degrade to what the tab already looked like, not to a blank tile.

import AppKit
import SwiftUI

/// Decoded portraits, keyed by file URL.
///
/// `NSImage(contentsOf:)` re-reads and re-decodes from disk on every call;
/// without this, scrolling the roster grid would decode the same 256×256 PNGs
/// over and over as `LazyVGrid` recycles cells. `NSCache` is thread-safe on its
/// own, but every caller is a SwiftUI view body, which only ever runs on the
/// main actor, so isolating the type to it costs nothing and keeps the cache
/// out of Swift 6's "who else can touch this" bookkeeping.
@MainActor
enum AbyssPortraitCache {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(at url: URL) -> NSImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// A square portrait, or a tinted glyph in a matching box when there is none.
struct AbyssPortraitImage: View {
    let url: URL?
    let systemImage: String
    let tint: Color
    var size: CGFloat = 30
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let url, let image = AbyssPortraitCache.image(at: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(LauncherPalette.night.opacity(0.4))
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.system(size: size * 0.44, weight: .semibold))
                            .foregroundStyle(tint))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}
