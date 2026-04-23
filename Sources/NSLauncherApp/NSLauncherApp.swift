import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppIcon.make()
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct NSLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
