import SwiftData
import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var authManager: AuthManager
    @Query private var settings: [AppSettings]

    private var hasCompletedOnboarding: Bool {
        return settings.first?.hasCompletedOnboarding == true
    }

    var body: some View {
        Group {
            switch authManager.state {
            case .unknown:
                AuthBootstrapView()
            case .signedOut:
                LoginView()
            case .signedIn:
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
        }
        .tint(NuvyraColors.accent)
        .animation(.easeInOut(duration: 0.25), value: authManager.state)
    }
}

private struct AuthBootstrapView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            NuvyraColors.calmGradient(scheme).ignoresSafeArea()
            VStack(spacing: NuvyraSpacing.md) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.4)
                    .tint(NuvyraColors.accent)
                Text("Nuvyra hazırlanıyor")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
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
        .environmentObject(AuthManager.previewSignedIn())
        .environmentObject(AppRouter())
}

#Preview("Login") {
    AppRootView()
        .modelContainer(NuvyraModelContainer.uiTesting())
        .environmentObject(DependencyContainer.preview())
        .environmentObject(AuthManager.previewSignedOut())
        .environmentObject(AppRouter())
}
