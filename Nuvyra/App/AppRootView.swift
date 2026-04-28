import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(NuvyraColor.lightPrimary)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.router.selectedTab) {
            NavigationStack(path: $appState.router.dashboardPath) {
                DashboardView()
            }
            .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.systemImage) }
            .tag(AppTab.dashboard)

            NavigationStack(path: $appState.router.mealPath) {
                MealLoggingView()
            }
            .tabItem { Label(AppTab.meals.title, systemImage: AppTab.meals.systemImage) }
            .tag(AppTab.meals)

            NavigationStack(path: $appState.router.walkingPath) {
                WalkingView()
            }
            .tabItem { Label(AppTab.walking.title, systemImage: AppTab.walking.systemImage) }
            .tag(AppTab.walking)

            NavigationStack {
                WeeklySummaryView()
            }
            .tabItem { Label(AppTab.weekly.title, systemImage: AppTab.weekly.systemImage) }
            .tag(AppTab.weekly)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
            .tag(AppTab.settings)
        }
        .sheet(item: $appState.router.presentedSheet) { sheet in
            switch sheet {
            case .addMeal:
                NavigationStack {
                    MealLoggingView(mode: .sheet)
                }
            case .photoMeal:
                PhotoMealEstimateView()
            case .healthPermission:
                HealthPermissionExplainerView()
            case .notificationPermission:
                NotificationPermissionExplainerView()
            }
        }
    }
}

#Preview("Onboarding") {
    AppRootView()
        .environmentObject(AppState.preview(completedOnboarding: false))
}

#Preview("Main") {
    AppRootView()
        .environmentObject(AppState.preview())
}
