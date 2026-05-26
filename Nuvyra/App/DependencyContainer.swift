import Combine
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
    let smartReminderEngine: SmartReminderEngine
    let upsellTriggerEngine: UpsellTriggerEngine
    @Published var subscriptionManager: SubscriptionManager

    init(
        healthService: HealthService,
        motionService: MotionService,
        storeKitService: StoreKitService,
        notificationService: NotificationService,
        foodIntelligenceService: FoodIntelligenceService,
        haptics: HapticsService,
        walkingLiveActivityService: WalkingLiveActivityService,
        analytics: AnalyticsService,
        smartReminderEngine: SmartReminderEngine? = nil,
        upsellTriggerEngine: UpsellTriggerEngine? = nil
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
        self.smartReminderEngine = smartReminderEngine ?? LiveSmartReminderEngine(notificationService: notificationService)
        self.upsellTriggerEngine = upsellTriggerEngine ?? DefaultUpsellTriggerEngine()
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
            analytics: MockAnalyticsService(),
            smartReminderEngine: MockSmartReminderEngine()
        )
    }

    func userRepository(context: ModelContext) -> UserRepository {
        SwiftDataUserRepository(context: context)
    }

    func nutritionRepository(context: ModelContext) -> NutritionRepository {
        SwiftDataNutritionRepository(context: context)
    }

    func activityRepository(context: ModelContext) -> ActivityRepository {
        SwiftDataActivityRepository(context: context)
    }

    func analyticsRepository(context: ModelContext) -> AnalyticsRepository {
        SwiftDataAnalyticsRepository(context: context)
    }

    func waterRepository(context: ModelContext) -> WaterRepository {
        SwiftDataWaterRepository(context: context)
    }

    func weightRepository(context: ModelContext) -> WeightRepository {
        SwiftDataWeightRepository(context: context)
    }

    func workoutRepository(context: ModelContext) -> WorkoutRepository {
        SwiftDataWorkoutRepository(context: context)
    }

    func subscriptionRepository(context: ModelContext) -> SubscriptionRepository {
        SwiftDataSubscriptionRepository(context: context)
    }
}
