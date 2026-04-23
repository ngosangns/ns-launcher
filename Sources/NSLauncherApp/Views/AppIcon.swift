import AppKit

enum AppIcon {
    static func make(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let rounded = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.45, blue: 0.86, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.77, blue: 0.67, alpha: 1)
        ])
        gradient?.draw(in: rounded, angle: 45)

        NSColor.white.withAlphaComponent(0.10).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.15, y: size * 0.62, width: size * 0.36, height: size * 0.20)).fill()

        let controllerRect = NSRect(x: size * 0.24, y: size * 0.29, width: size * 0.52, height: size * 0.31)
        let controller = NSBezierPath(
            roundedRect: controllerRect,
            xRadius: size * 0.12,
            yRadius: size * 0.12
        )
        NSColor.white.setFill()
        controller.fill()

        NSColor(calibratedWhite: 0.10, alpha: 0.95).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.33, y: size * 0.405, width: size * 0.075, height: size * 0.026),
            xRadius: size * 0.008,
            yRadius: size * 0.008
        ).fill()
        NSBezierPath(
            roundedRect: NSRect(x: size * 0.355, y: size * 0.38, width: size * 0.026, height: size * 0.075),
            xRadius: size * 0.008,
            yRadius: size * 0.008
        ).fill()

        for point in [
            NSPoint(x: size * 0.59, y: size * 0.42),
            NSPoint(x: size * 0.645, y: size * 0.385),
            NSPoint(x: size * 0.645, y: size * 0.455),
            NSPoint(x: size * 0.70, y: size * 0.42)
        ] {
            let circle = NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: size * 0.04, height: size * 0.04))
            circle.fill()
        }

        NSColor(calibratedWhite: 0.10, alpha: 0.16).setStroke()
        controller.lineWidth = size * 0.010
        controller.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
