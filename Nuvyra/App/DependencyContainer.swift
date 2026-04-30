import Foundation
import SwiftData

@MainActor
final class DependencyContainer: ObservableObject {
    let healthService: HealthService
    let motionService: MotionService
    let stepCountService: StepCountService
    let activeEnergyService: ActiveEnergyService
    let storeKitService: StoreKitService
    let notificationService: NotificationService
    let foodIntelligenceService: FoodIntelligenceService
    let haptics: HapticsService
    let walkingLiveActivityService: WalkingLiveActivityService
    let analytics: AnalyticsService
    @Published var subscriptionManager: SubscriptionManager

    init(
        healthService: HealthService,
        motionService: MotionService,
        storeKitService: StoreKitService,
        notificationService: NotificationService,
        foodIntelligenceService: FoodIntelligenceService,
        haptics: HapticsService,
        walkingLiveActivityService: WalkingLiveActivityService,
        analytics: AnalyticsService
    ) {
        self.healthService = healthService
        self.motionService = motionService
        self.stepCountService = LiveStepCountService(healthService: healthService, motionService: motionService)
        self.activeEnergyService = LiveActiveEnergyService(healthService: healthService)
        self.storeKitService = storeKitService
        self.notificationService = notificationService
        self.foodIntelligenceService = foodIntelligenceService
        self.haptics = haptics
        self.walkingLiveActivityService = walkingLiveActivityService
        self.analytics = analytics
        self.subscriptionManager = SubscriptionManager(storeKitService: storeKitService)
    }

    static func live() -> DependencyContainer {
        DependencyContainer(
            healthService: LiveHealthService(),
            motionService: LiveMotionService(),
            storeKitService: LiveStoreKitService(),
            notificationService: LiveNotificationService(),
            foodIntelligenceService: LocalFoodIntelligenceService(),
            haptics: LiveHapticsService(),
            walkingLiveActivityService: LiveWalkingLiveActivityService(),
            analytics: PrivacyPreservingAnalyticsService()
        )
    }

    static func preview() -> DependencyContainer {
        DependencyContainer(
            healthService: MockHealthService(),
            motionService: MockMotionService(),
            storeKitService: MockStoreKitService(),
            notificationService: MockNotificationService(),
            foodIntelligenceService: MockFoodIntelligenceService(),
            haptics: MockHapticsService(),
            walkingLiveActivityService: MockWalkingLiveActivityService(),
            analytics: MockAnalyticsService()
        )
    }

    func userRepository(context: ModelContext) -> UserRepository {
        SwiftDataUserRepository(context: context, onMutate: widgetReloader(for: context))
    }

    func nutritionRepository(context: ModelContext) -> NutritionRepository {
        SwiftDataNutritionRepository(context: context, onMutate: widgetReloader(for: context))
    }

    func activityRepository(context: ModelContext) -> ActivityRepository {
        SwiftDataActivityRepository(context: context, onMutate: widgetReloader(for: context))
    }

    func waterRepository(context: ModelContext) -> WaterRepository {
        SwiftDataWaterRepository(context: context, onMutate: widgetReloader(for: context))
    }

    /// Builds the closure repositories use to push a fresh snapshot to the
    /// widget extension. Captures the same `ModelContext` they read from.
    private func widgetReloader(for context: ModelContext) -> @MainActor () -> Void {
        { WidgetRefresh.reload(context: context) }
    }

    func subscriptionRepository(context: ModelContext) -> SubscriptionRepository {
        SwiftDataSubscriptionRepository(context: context)
    }
}
