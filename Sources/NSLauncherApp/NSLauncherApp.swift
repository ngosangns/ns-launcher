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

    var body: some Scene {
        WindowGroup("NS Launcher") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 640)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
    }
}
