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
    let aiCoachService: AICoachService
    let appleSignInService: AppleSignInService
    let keychainService: KeychainService
    @Published var subscriptionManager: SubscriptionManager
    @Published var authManager: AuthManager

    init(
        healthService: HealthService,
        motionService: MotionService,
        storeKitService: StoreKitService,
        notificationService: NotificationService,
        foodIntelligenceService: FoodIntelligenceService,
        haptics: HapticsService,
        walkingLiveActivityService: WalkingLiveActivityService,
        analytics: AnalyticsService,
        aiCoachService: AICoachService,
        appleSignInService: AppleSignInService,
        keychainService: KeychainService
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
        self.aiCoachService = aiCoachService
        self.appleSignInService = appleSignInService
        self.keychainService = keychainService
        self.subscriptionManager = SubscriptionManager(storeKitService: storeKitService)
        self.authManager = AuthManager(appleService: appleSignInService, keychain: keychainService)
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
            analytics: PrivacyPreservingAnalyticsService(),
            aiCoachService: RemoteAICoachService(),
            appleSignInService: LiveAppleSignInService(),
            keychainService: LiveKeychainService()
        )
    }

    static func preview() -> DependencyContainer {
        let container = DependencyContainer(
            healthService: MockHealthService(),
            motionService: MockMotionService(),
            storeKitService: MockStoreKitService(),
            notificationService: MockNotificationService(),
            foodIntelligenceService: MockFoodIntelligenceService(),
            haptics: MockHapticsService(),
            walkingLiveActivityService: MockWalkingLiveActivityService(),
            analytics: MockAnalyticsService(),
            aiCoachService: MockAICoachService(),
            appleSignInService: MockAppleSignInService(),
            keychainService: InMemoryKeychainService()
        )
        // Preview default: show signed-in state so dashboard previews don't get stuck on LoginView.
        container.authManager = AuthManager.previewSignedIn()
        return container
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

    func subscriptionRepository(context: ModelContext) -> SubscriptionRepository {
        SwiftDataSubscriptionRepository(context: context)
    }
}
