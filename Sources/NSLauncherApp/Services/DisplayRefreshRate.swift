// DisplayRefreshRate.swift
//
// Reads the refresh rate of the display the game will run on.
//
// DXMT's `d3d11.preferredMaxFrameRate` is only valid when it divides the refresh rate,
// so the launch profile needs the real number rather than an assumed 60 (see
// `AppSettings.supportedFrameCap`).

import AppKit

/// Refresh rate of the display the launcher is running on.
enum DisplayRefreshRate {
    /// Refresh rate in Hz of the main display, or 0 when macOS does not report one.
    ///
    /// `NSScreen.maximumFramesPerSecond` is used rather than `CGDisplayCopyDisplayMode`, which
    /// reports 0 for some built-in Apple panels.
    static var mainDisplay: Int {
        max(NSScreen.main?.maximumFramesPerSecond ?? 0, 0)
    }
}
