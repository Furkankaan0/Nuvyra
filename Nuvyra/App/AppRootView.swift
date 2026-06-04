import SwiftData
import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var router: AppRouter
    @Query private var settings: [AppSettings]

    private var hasCompletedOnboarding: Bool {
        return settings.first?.hasCompletedOnboarding == true
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(NuvyraColors.accent)
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraOpenNutritionRequested)) { _ in
            router.selectedTab = .nutrition
        }
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraOpenWalkingRequested)) { _ in
            router.selectedTab = .walking
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            tab(.dashboard) { DashboardView() }
            tab(.nutrition) { NutritionView() }
            tab(.walking) { WalkingView() }
            tab(.insights) { InsightsView() }
            tab(.profile) { ProfileView() }
        }
    }

    /// Tab item builder shared by every entry. Wraps the navigation stack
    /// in a `.tabItem` whose symbol gets the iOS 17 `.symbolEffect(.bounce)`
    /// tied to the router's selection — every tap nods the icon, but the
    /// effect only fires on the active tab so background tabs stay still.
    @ViewBuilder
    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack { content() }
            .tabItem {
                Label {
                    Text(tab.title)
                } icon: {
                    Image(systemName: tab.systemImage)
                        // Bounce on every router selection change.
                        // iOS 17 `value:` parameter — fires only when
                        // the new value equals this tab, so other tabs
                        // stay quiet.
                        .symbolEffect(.bounce.up, value: router.selectedTab == tab)
                }
            }
            .tag(tab)
    }
}

#Preview("Onboarding") {
    AppRootView()
        .modelContainer(NuvyraModelContainer.uiTesting())
        .environmentObject(DependencyContainer.preview())
        .environmentObject(AppRouter())
}
