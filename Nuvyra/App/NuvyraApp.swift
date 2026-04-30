import SwiftData
import SwiftUI
import WidgetKit

@main
@MainActor
struct NuvyraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dependencies: DependencyContainer
    @StateObject private var router = AppRouter()
    private let modelContainer: ModelContainer
    /// Holds the HealthKit observer for the lifetime of the app so that
    /// step/calorie data flows in even when the user hasn't opened the
    /// dashboard. Created lazily on first foreground.
    @State private var healthSync: HealthSyncCoordinator?

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
        // Start the StoreKit Transaction.updates listener once. This is
        // the only place Ask-to-Buy approvals, cross-device purchases,
        // refunds and renewals can land while the app is open. Without
        // it, those events would never reach our entitlement state.
        let subscriptionRepository = dependencies.subscriptionRepository(context: modelContainer.mainContext)
        dependencies.subscriptionManager.startListening(repository: subscriptionRepository)
        await dependencies.subscriptionManager.loadProducts()
        await dependencies.subscriptionManager.refresh(repository: subscriptionRepository)
        startHealthSyncIfNeeded()
        await healthSync?.syncNow()
        // Publish today's state to the App Group every time the app
        // foregrounds, so the widget never shows stale or fictional
        // numbers — even if no mutation happened during the previous
        // session. `WidgetRefresh.reload` writes the snapshot AND calls
        // `WidgetCenter.shared.reloadAllTimelines()`, so we don't need a
        // separate reload call here.
        WidgetRefresh.reload(context: modelContainer.mainContext)
        NotificationCenter.default.post(name: .nuvyraAppDidBecomeActive, object: nil)
    }

    /// Spin up the long-lived HealthKit observer once. We don't gate this
    /// on authorization status — if the user denies, the observer simply
    /// never fires. Re-running is a no-op.
    private func startHealthSyncIfNeeded() {
        if healthSync == nil {
            healthSync = HealthSyncCoordinator(
                healthService: dependencies.healthService,
                modelContext: modelContainer.mainContext,
                dependencies: dependencies
            )
        }
        healthSync?.start()
    }
}
