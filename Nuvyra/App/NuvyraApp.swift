import SwiftData
import SwiftUI
import WidgetKit

@main
@MainActor
struct NuvyraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("nuvyra.theme.preference") private var themePreference = NuvyraThemePreference.system.rawValue
    @StateObject private var dependencies: DependencyContainer
    @StateObject private var router = AppRouter()
    private let modelContainer: ModelContainer

    init() {
        let isUITesting = CommandLine.arguments.contains("-ui-testing")
        modelContainer = isUITesting ? NuvyraModelContainer.uiTesting() : NuvyraModelContainer.live()
        _dependencies = StateObject(wrappedValue: isUITesting ? .preview() : .live())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(modelContainer)
                .environmentObject(dependencies)
                .environmentObject(router)
                .preferredColorScheme(preferredColorScheme)
                .task {
                    await dependencies.analytics.track(.appOpened, payload: AnalyticsPayload())
                    await refreshForegroundState()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await refreshForegroundState() }
                }
        }
    }

    private func refreshForegroundState() async {
        SeedData.ensureMinimumData(in: modelContainer.mainContext)
        await dependencies.subscriptionManager.loadProducts()
        await dependencies.subscriptionManager.refresh(
            repository: dependencies.subscriptionRepository(context: modelContainer.mainContext)
        )
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .nuvyraAppDidBecomeActive, object: nil)
    }

    private var preferredColorScheme: ColorScheme? {
        switch NuvyraThemePreference(rawValue: themePreference) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
