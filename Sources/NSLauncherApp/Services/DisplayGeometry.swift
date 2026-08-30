// DisplayGeometry.swift
//
// The size of the display a Wine game is about to run on, expressed the way Wine's Mac driver
// reports it — which is what a launch has to match to avoid a display mode switch.
//
// Wine's macdrv builds the display-mode list it shows to Windows from Core Graphics' own list. With
// `RetinaMode` off it reports each mode's point size; with it on it reports the mode's backing pixel
// count. A launch that asks for a size absent from that list does not fail: macOS synthesises a
// stretched mode for it, which is what distorts the image and drops the display's colour profile
// once `CaptureDisplaysForFullscreen` lets macdrv capture the display. So the unit matters as much
// as the number, and both come from the same place here.

import CoreGraphics

enum DisplayGeometry {
    /// Size of the main display's current mode, or nil when Core Graphics reports no usable mode
    /// (headless CI, no display attached).
    ///
    /// `retina` must be the value the launch writes to macdrv's `RetinaMode` registry key: the two
    /// describe the same unit, and disagreeing on it puts the requested size a factor of two away
    /// from any real mode.
    static func mainDisplaySize(retina: Bool) -> RenderSize? {
        guard let mode = CGDisplayCopyDisplayMode(CGMainDisplayID()) else { return nil }
        let width = retina ? mode.pixelWidth : mode.width
        let height = retina ? mode.pixelHeight : mode.height
        guard width > 0, height > 0 else { return nil }
        return RenderSize(width: width, height: height)
    }
}
