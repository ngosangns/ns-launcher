import SwiftUI

private enum AppTab: Hashable {
    case home
    case settings
}

/// App shell: pinned chrome (wordmark, tab switch, language) plus the active tab's content.
/// Settings used to be a pushed `NavigationStack` destination; a tab switch keeps both screens'
/// state alive and drops that extra navigation layer. Both tabs are mounted for the life of
/// the window (see `tabContent`), so each keeps its own scroll position and in-progress UI
/// state across switches.
struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @State private var activeTab: AppTab = .home

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

                // Both tabs stay mounted at all times — only opacity/hit-testing toggle —
                // so each tab's local @State (scroll position, in-progress edits, expanded
                // sections) survives switching away and back.
                ZStack {
                    tabContent(.home) { HomeView(viewModel: viewModel) }
                    tabContent(.settings) { SettingsView(viewModel: viewModel) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            WindowFrameOrnament()
        }
        .onChange(of: activeTab) { _, newValue in
            // SettingsView's cache report used to refresh in its own onAppear; now that the view
            // stays mounted permanently, that would only fire once at launch instead of on every
            // visit, so the refresh moves here.
            if newValue == .settings {
                viewModel.refreshCacheReport()
            }
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
        TabGroup {
            SidebarTabButton(title: text.homeTitle, systemImage: "house.fill", isSelected: activeTab == .home) {
                switchTab(to: .home)
            }
            SidebarTabButton(title: text.settingsTitle, systemImage: "gearshape.fill", isSelected: activeTab == .settings) {
                switchTab(to: .settings)
            }
        }
        .fixedSize()
    }

    private func switchTab(to tab: AppTab) {
        guard tab != activeTab else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            activeTab = tab
        }
    }

    /// Renders `content` permanently in the `ZStack`, cross-fading and settling in from a slight
    /// scale/offset when it becomes the active tab rather than popping in — the mount/unmount a
    /// `switch` would otherwise do is what loses each tab's local state on every visit.
    @ViewBuilder
    private func tabContent(_ tab: AppTab, @ViewBuilder content: () -> some View) -> some View {
        let isActive = activeTab == tab
        content()
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.98)
            .offset(y: isActive ? 0 : 6)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
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
