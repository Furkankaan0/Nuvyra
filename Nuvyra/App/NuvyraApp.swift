import SwiftData
import SwiftUI
import UserNotifications

@main
@MainActor
struct NuvyraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("nuvyra.theme.preference") private var themePreference = NuvyraThemePreference.system.rawValue
    @StateObject private var dependencies: DependencyContainer
    @StateObject private var router = AppRouter()
    private let modelContainer: ModelContainer
    private let notificationDelegate = NuvyraNotificationDelegate()
    private let watchWaterSyncService = WatchWaterSyncService()

    init() {
        let isUITesting = CommandLine.arguments.contains("-ui-testing")
        let container = isUITesting ? NuvyraModelContainer.uiTesting() : NuvyraModelContainer.live()
        let dependencyContainer = isUITesting ? DependencyContainer.preview() : DependencyContainer.live()
        modelContainer = container
        _dependencies = StateObject(wrappedValue: dependencyContainer)
        Self.configureImageCache()
        Self.configureNotifications(
            delegate: notificationDelegate,
            modelContainer: container,
            dependencies: dependencyContainer
        )
    }

    /// Phase 9 — OFF/USDA ürün görselleri için URLSession.shared.URLCache'i
    /// büyütür. Varsayılan ~4MB mem / ~20MB disk, food images (50-300KB) için
    /// yetersiz. 30MB mem + 150MB disk ile yaklaşık 500 ürün görselini
    /// disk'te tutar; AsyncImage HTTP cache header'larına uyar.
    private static func configureImageCache() {
        let memoryCapacity = 30 * 1024 * 1024
        let diskCapacity = 150 * 1024 * 1024
        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            directory: nil
        )
        URLCache.shared = cache
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
        watchWaterSyncService.activate(modelContainer: modelContainer)
        SeedData.ensureMinimumData(in: modelContainer.mainContext)
        NuvyraNotificationCategoryService.shared.registerCategories()
        await dependencies.subscriptionManager.loadProducts()
        await dependencies.subscriptionManager.refresh(
            repository: dependencies.subscriptionRepository(context: modelContainer.mainContext)
        )
        await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(
            context: modelContainer.mainContext,
            healthService: dependencies.healthService
        )
        NotificationCenter.default.post(name: .nuvyraAppDidBecomeActive, object: nil)
    }

    private var preferredColorScheme: ColorScheme? {
        switch NuvyraThemePreference(rawValue: themePreference) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private static func configureNotifications(
        delegate: NuvyraNotificationDelegate,
        modelContainer: ModelContainer,
        dependencies: DependencyContainer
    ) {
        NuvyraNotificationCategoryService.shared.registerCategories()
        UNUserNotificationCenter.current().delegate = delegate
        delegate.actionHandler = { action in
            Task { @MainActor in
                await handleNotificationAction(
                    action,
                    modelContainer: modelContainer,
                    dependencies: dependencies
                )
            }
        }
    }

    private static func handleNotificationAction(
        _ action: NuvyraNotificationCategoryService.Action,
        modelContainer: ModelContainer,
        dependencies: DependencyContainer
    ) async {
        switch action {
        case .addWater250:
            await addWaterFromNotification(amount: 250, modelContainer: modelContainer, dependencies: dependencies)
        case .addWater500:
            await addWaterFromNotification(amount: 500, modelContainer: modelContainer, dependencies: dependencies)
        case .snooze:
            await scheduleSnoozedReminder()
        case .logBreakfast, .logLunch, .logDinner:
            NotificationCenter.default.post(name: .nuvyraOpenNutritionRequested, object: action.rawValue)
        }
    }

    private static func addWaterFromNotification(
        amount: Int,
        modelContainer: ModelContainer,
        dependencies: DependencyContainer
    ) async {
        do {
            try dependencies.waterRepository(context: modelContainer.mainContext).addWater(amountMl: amount, date: Date())
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["source": "notification", "amount_ml": "\(amount)"]))
            await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(
                context: modelContainer.mainContext,
                healthService: dependencies.healthService
            )
            NotificationCenter.default.post(name: .nuvyraAppDidBecomeActive, object: nil)
        } catch {
            await scheduleSnoozedReminder()
        }
    }

    private static func scheduleSnoozedReminder() async {
        let content = UNMutableNotificationContent()
        content.title = "Nuvyra"
        content.body = "Bir saat sonra ritmine nazikçe tekrar bakacağız."
        content.sound = .default
        content.categoryIdentifier = NuvyraNotificationCategoryService.Category.waterReminder.rawValue
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3_600, repeats: false)
        let request = UNNotificationRequest(
            identifier: "nuvyra.snooze.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
