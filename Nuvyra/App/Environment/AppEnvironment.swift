import Foundation

struct AppEnvironment {
    let userProfileRepository: any UserProfileRepository
    let mealLogService: any MealLogServicing
    let waterRepository: any WaterRepository
    let stepSyncService: any StepSyncing
    let healthKitManager: any HealthKitManaging
    let foodEstimationService: any FoodEstimationServicing
    let coachingEngine: any CoachingGenerating
    let storeKitService: any StoreKitServicing
    let entitlementManager: any EntitlementManaging
    let notificationScheduler: any NotificationScheduling
    let analytics: any AnalyticsServicing

    @MainActor
    static func live() -> AppEnvironment {
        let store = (try? LocalStore.live()) ?? LocalStore.inMemory()
        let profileRepository = LocalUserProfileRepository(store: store)
        let mealRepository = LocalMealRepository(store: store)
        let waterRepository = LocalWaterRepository(store: store)
        let stepHistoryRepository = LocalStepHistoryRepository(store: store)
        let healthKitManager = HealthKitManager()
        let storeKitService = StoreKitService()
        let keychainService = KeychainService()
        let entitlementManager = EntitlementManager(storeKitService: storeKitService, keychainService: keychainService)

        return AppEnvironment(
            userProfileRepository: profileRepository,
            mealLogService: MealLogService(repository: mealRepository),
            waterRepository: waterRepository,
            stepSyncService: StepSyncService(healthKitManager: healthKitManager, historyRepository: stepHistoryRepository),
            healthKitManager: healthKitManager,
            foodEstimationService: MockFoodEstimationService(),
            coachingEngine: CoachingEngine(),
            storeKitService: storeKitService,
            entitlementManager: entitlementManager,
            notificationScheduler: NotificationScheduler(),
            analytics: AnalyticsService()
        )
    }

    @MainActor
    static func preview() -> AppEnvironment {
        let store = LocalStore.inMemory()
        let profileRepository = LocalUserProfileRepository(store: store)
        let storeKitService = PreviewStoreKitService()
        let entitlementManager = PreviewEntitlementManager()
        return AppEnvironment(
            userProfileRepository: profileRepository,
            mealLogService: PreviewMealLogService(),
            waterRepository: LocalWaterRepository(store: store),
            stepSyncService: PreviewStepSyncService(),
            healthKitManager: PreviewHealthKitManager(),
            foodEstimationService: MockFoodEstimationService(),
            coachingEngine: CoachingEngine(),
            storeKitService: storeKitService,
            entitlementManager: entitlementManager,
            notificationScheduler: PreviewNotificationScheduler(),
            analytics: NoopAnalyticsService()
        )
    }
}
