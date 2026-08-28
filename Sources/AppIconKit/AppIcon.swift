import AppKit

public enum AppIcon {
    public static func make(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let iconScale: CGFloat = 0.88
        let iconInset = size * (1 - iconScale) / 2
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState()
        context.translateBy(x: iconInset, y: iconInset)
        context.scaleBy(x: iconScale, y: iconScale)

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let rounded = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.18, green: 0.38, blue: 0.66, alpha: 1)
        ])?.draw(in: rounded, angle: 52)

        NSColor(calibratedRed: 0.96, green: 0.84, blue: 0.53, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.08, y: size * 0.62, width: size * 0.64, height: size * 0.24)).fill()

        let center = NSPoint(x: size * 0.5, y: size * 0.5)
        let outerRadius = size * 0.23
        let innerRadius = size * 0.155

        NSColor(calibratedRed: 0.98, green: 0.88, blue: 0.59, alpha: 0.92).setStroke()
        let outerRing = NSBezierPath(ovalIn: NSRect(x: center.x - outerRadius, y: center.y - outerRadius, width: outerRadius * 2, height: outerRadius * 2))
        outerRing.lineWidth = size * 0.018
        outerRing.stroke()

        NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.40, alpha: 0.95).setFill()
        compassPoint(center: center, radius: innerRadius, angle: 90).fill()
        compassPoint(center: center, radius: innerRadius, angle: 270).fill()

        NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.98, alpha: 0.96).setFill()
        compassPoint(center: center, radius: innerRadius * 0.72, angle: 0).fill()
        compassPoint(center: center, radius: innerRadius * 0.72, angle: 180).fill()

        NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.24, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - size * 0.045, y: center.y - size * 0.045, width: size * 0.09, height: size * 0.09)).fill()

        context.restoreGState()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func compassPoint(center: NSPoint, radius: CGFloat, angle: CGFloat) -> NSBezierPath {
        let radians = angle * .pi / 180
        let direction = NSPoint(x: cos(radians), y: sin(radians))
        let perpendicular = NSPoint(x: -direction.y, y: direction.x)
        let tip = NSPoint(x: center.x + direction.x * radius, y: center.y + direction.y * radius)
        let left = NSPoint(x: center.x + perpendicular.x * radius * 0.22, y: center.y + perpendicular.y * radius * 0.22)
        let right = NSPoint(x: center.x - perpendicular.x * radius * 0.22, y: center.y - perpendicular.y * radius * 0.22)
        let path = NSBezierPath()
        path.move(to: tip)
        path.line(to: left)
        path.line(to: right)
        path.close()
        return path
    }
}
