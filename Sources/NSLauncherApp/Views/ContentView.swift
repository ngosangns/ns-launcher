import SwiftUI

private enum AppTab: Hashable {
    case home
    case settings
    case story
}

/// App shell: pinned chrome (wordmark, tab switch, language) plus the active tab's content.
/// Settings used to be a pushed `NavigationStack` destination; a tab switch keeps both screens'
/// state alive and drops that extra navigation layer.
struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var activeTab: AppTab = .home
    // Held here, above the `.id(activeTab)` switch below, so switching away from
    // and back to Story doesn't re-parse Resources/Story/ every time.
    @StateObject private var storyViewModel = StoryViewModel()

    private var text: AppText { viewModel.text }

    var body: some View {
        ZStack {
            CelestialBackdrop()

            VStack(spacing: 0) {
                topBar
                    // Horizontal and top padding must clear WindowFrameOrnament's corner brackets,
                    // which occupy a 16-40pt band from each window edge — see HomeView's matching
                    // comment. Bottom is untouched: the top bar never gets near the window's bottom
                    // corners.
                    .padding(.horizontal, 44)
                    .padding(.top, 44)
                    .padding(.bottom, 12)

                Group {
                    switch activeTab {
                    case .home:
                        HomeView(viewModel: viewModel)
                    case .settings:
                        SettingsView(viewModel: viewModel)
                    case .story:
                        StoryView(viewModel: storyViewModel, text: text)
                    }
                }
                .id(activeTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            WindowFrameOrnament()
        }
        .alert(text.error, isPresented: Binding(get: {
            viewModel.errorMessage != nil
        }, set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        })) {
            Button(text.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LauncherPalette.gold.opacity(0.16))
                    .frame(width: 42, height: 42)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LauncherPalette.goldHighlight)
            }

            Text("NS LAUNCHER")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .tracking(1.8)
                .foregroundStyle(LauncherPalette.parchment)

            tabSwitcher
                .padding(.leading, 8)

            Spacer()

            languageSwitcher
        }
    }

    private var tabSwitcher: some View {
        HStack(spacing: 8) {
            SidebarTabButton(title: text.homeTitle, systemImage: "house.fill", isSelected: activeTab == .home) {
                activeTab = .home
            }
            SidebarTabButton(title: text.settingsTitle, systemImage: "gearshape.fill", isSelected: activeTab == .settings) {
                activeTab = .settings
            }
            SidebarTabButton(title: text.storyTitle, systemImage: "book.closed.fill", isSelected: activeTab == .story) {
                activeTab = .story
            }
        }
        .fixedSize()
    }

    private var languageSwitcher: some View {
        let current = viewModel.settings.language
        let target: AppLanguage = current == .english ? .vietnamese : .english
        let targetName = target.nativeName
        return Button {
            viewModel.setLanguage(target)
        } label: {
            Label(targetName, systemImage: "globe")
        }
        .quest(.quiet)
    }
}
