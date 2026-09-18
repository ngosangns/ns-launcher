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
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        // Roughly 40 MB of decoded pixels. Uncapped, the roster's 371 sources at
        // 256x256 would sit resident forever once the grid had been scrolled
        // through; the tiles that are actually on screen are a small fraction of
        // that, and anything evicted costs one re-decode to get back.
        cache.totalCostLimit = 40 * 1_024 * 1_024
        return cache
    }()

    /// The portrait, scaled down to what the tile will actually draw.
    ///
    /// The sources are 256x256 but the grid draws them at 54pt and the result
    /// rows at 20-34pt, so handing SwiftUI the full-size image made every redraw
    /// resample it. Downscaling once, into the cache, means later frames blit an
    /// image that is already the right size — and it is what keeps the cache
    /// inside its budget, since a 54pt tile costs a fraction of the original.
    static func image(at url: URL, fittingPointSize points: CGFloat) -> NSImage? {
        let scale = max(2, NSScreen.main?.backingScaleFactor ?? 2)
        let target = (points * scale).rounded(.up)
        let key = "\(url.path)@\(Int(target))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = NSImage(contentsOf: url) else { return nil }

        let image = downscaled(source, to: target) ?? source
        cache.setObject(image, forKey: key, cost: cost(of: image))
        return image
    }

    /// Returns nil when the source is already at or below the target, so a
    /// small icon is never blown up into a larger, blurrier copy.
    private static func downscaled(_ source: NSImage, to target: CGFloat) -> NSImage? {
        let longestSide = max(source.size.width, source.size.height)
        guard longestSide > target, longestSide > 0 else { return nil }

        let ratio = target / longestSide
        let size = NSSize(width: (source.size.width * ratio).rounded(),
                          height: (source.size.height * ratio).rounded())
        guard size.width >= 1, size.height >= 1 else { return nil }

        let scaled = NSImage(size: size)
        scaled.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: size),
                    from: NSRect(origin: .zero, size: source.size),
                    operation: .copy,
                    fraction: 1)
        scaled.unlockFocus()
        return scaled
    }

    private static func cost(of image: NSImage) -> Int {
        Int(image.size.width * image.size.height * 4)
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
            if let url, let image = AbyssPortraitCache.image(at: url, fittingPointSize: size) {
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
