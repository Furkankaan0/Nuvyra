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
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage) }
                .tag(AppTab.dashboard)

            NavigationStack { NutritionView() }
                .tabItem { Label(AppTab.nutrition.title, systemImage: AppTab.nutrition.systemImage) }
                .tag(AppTab.nutrition)

            NavigationStack { WalkingView() }
                .tabItem { Label(AppTab.walking.title, systemImage: AppTab.walking.systemImage) }
                .tag(AppTab.walking)

            NavigationStack { InsightsView() }
                .tabItem { Label(AppTab.insights.title, systemImage: AppTab.insights.systemImage) }
                .tag(AppTab.insights)

            NavigationStack { ProfileView() }
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
    }
}

#Preview("Onboarding") {
    AppRootView()
        .modelContainer(NuvyraModelContainer.uiTesting())
        .environmentObject(DependencyContainer.preview())
        .environmentObject(AppRouter())
}
