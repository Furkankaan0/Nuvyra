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
    let analytics: AnalyticsService
    @Published var subscriptionManager: SubscriptionManager

    init(
        healthService: HealthService,
        motionService: MotionService,
        storeKitService: StoreKitService,
        notificationService: NotificationService,
        analytics: AnalyticsService
    ) {
        self.healthService = healthService
        self.motionService = motionService
        self.stepCountService = LiveStepCountService(healthService: healthService, motionService: motionService)
        self.activeEnergyService = LiveActiveEnergyService(healthService: healthService)
        self.storeKitService = storeKitService
        self.notificationService = notificationService
        self.analytics = analytics
        self.subscriptionManager = SubscriptionManager(storeKitService: storeKitService)
    }

    static func live() -> DependencyContainer {
        DependencyContainer(
            healthService: LiveHealthService(),
            motionService: LiveMotionService(),
            storeKitService: LiveStoreKitService(),
            notificationService: LiveNotificationService(),
            analytics: MockAnalyticsService()
        )
    }

    static func preview() -> DependencyContainer {
        DependencyContainer(
            healthService: MockHealthService(),
            motionService: MockMotionService(),
            storeKitService: MockStoreKitService(),
            notificationService: MockNotificationService(),
            analytics: MockAnalyticsService()
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

    func waterRepository(context: ModelContext) -> WaterRepository {
        SwiftDataWaterRepository(context: context)
    }

    func subscriptionRepository(context: ModelContext) -> SubscriptionRepository {
        SwiftDataSubscriptionRepository(context: context)
    }
}
