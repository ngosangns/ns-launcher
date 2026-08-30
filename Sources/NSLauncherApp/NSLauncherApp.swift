// NSLauncherApp.swift
//
// Application entry point and AppKit lifecycle glue.
//
// NSLauncher is a native macOS launcher shell for a single bundled Genshin Impact
// definition. This file wires the SwiftUI `@main` app to an `NSApplicationDelegate`
// so the app behaves like a regular foreground app (activation policy, dock icon,
// focus), then hosts `ContentView` bound to one shared `LauncherViewModel`.
//
// The production dependency graph (SettingsStore → LauncherCoordinator →
// GenshinSophonInstaller + WineService) is assembled once in
// `LauncherViewModel.bootstrap()` and injected into the root window.

import AppIconKit
import AppKit
import SwiftUI

/// AppKit delegate used for macOS activation and runtime icon setup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Ensures the SwiftUI app behaves like a regular foreground macOS app.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppIcon.make()
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// NSLauncher application entry point.
@main
struct NSLauncherApp: App {
    /// Keeps AppKit lifecycle hooks available inside the SwiftUI app.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// Shared view model for the launcher window.
    @StateObject private var viewModel = LauncherViewModel.bootstrap()

    /// Re-invoking this same binary with `WineShutdownWatchdog.launchArgument` runs the watchdog
    /// instead of the UI — see `WineShutdownWatchdog` for why it needs to be the same executable
    /// rather than a separate bundled tool. Must exit before any SwiftUI/AppKit setup below runs.
    init() {
        if CommandLine.arguments.contains(WineShutdownWatchdog.launchArgument) {
            exit(WineShutdownWatchdog.runBlocking(arguments: CommandLine.arguments))
        }
    }

    var body: some Scene {
        WindowGroup("NS Launcher") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1_040, minHeight: 720)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentMinSize)
    }
}
