import SwiftUI

private enum AppTab: Hashable {
    case home
    case settings
}

/// App shell: pinned chrome (wordmark, tab switch, language) plus the active tab's content.
/// Settings used to be a pushed `NavigationStack` destination; a tab switch keeps both screens'
/// state alive and drops that extra navigation layer.
struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var activeTab: AppTab = .home

    private var text: AppText { viewModel.text }

    var body: some View {
        ZStack {
            CelestialBackdrop()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 34)
                    .padding(.top, 22)
                    .padding(.bottom, 16)

                Group {
                    switch activeTab {
                    case .home:
                        HomeView(viewModel: viewModel)
                    case .settings:
                        SettingsView(viewModel: viewModel)
                    }
                }
                .id(activeTab)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.2), value: activeTab)
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
