import Combine
import Foundation
import SwiftData

/// Protocol-oriented dependency container. Every property is exposed via a
/// protocol type (see `DependencyProvider`); the concrete `Live*` / `Mock*`
/// implementations are wired through the `live()`, `preview()` and `mock()`
/// factories. Repositories are returned through factory methods because they
/// need the per-context `ModelContext` SwiftData hands out at runtime.
///
/// Kept as `final class` + `ObservableObject` so existing call sites that use
/// `@EnvironmentObject private var dependencies: DependencyContainer` keep
/// compiling. New call sites are free to type against `DependencyProvider`.
@MainActor
final class DependencyContainer: ObservableObject, DependencyProvider {
    // MARK: - Services
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
    let foodRepository: FoodRepository
    let weeklyInsightEngine: WeeklyInsightEngine
    let mealTimingEngine: MealTimingEngine
    @Published var subscriptionManager: SubscriptionManager

    // MARK: - Init
    /// Designated initialiser. Every dependency must arrive through a protocol
    /// type; `stepCountService` / `activeEnergyService` are derived from the
    /// passed-in `healthService` + `motionService` by default but can be
    /// overridden for tests/previews so HealthKit isn't touched.
    init(
        healthService: HealthService,
        motionService: MotionService,
        storeKitService: StoreKitService,
        notificationService: NotificationService,
        foodIntelligenceService: FoodIntelligenceService,
        haptics: HapticsService,
        walkingLiveActivityService: WalkingLiveActivityService,
        analytics: AnalyticsService,
        stepCountService: StepCountService? = nil,
        activeEnergyService: ActiveEnergyService? = nil,
        smartReminderEngine: SmartReminderEngine? = nil,
        upsellTriggerEngine: UpsellTriggerEngine? = nil,
        foodRepository: FoodRepository? = nil,
        weeklyInsightEngine: WeeklyInsightEngine? = nil,
        mealTimingEngine: MealTimingEngine? = nil,
        subscriptionManager: SubscriptionManager? = nil
    ) {
        self.healthService = healthService
        self.motionService = motionService
        self.stepCountService = stepCountService
            ?? LiveStepCountService(healthService: healthService, motionService: motionService)
        self.activeEnergyService = activeEnergyService
            ?? LiveActiveEnergyService(healthService: healthService)
        self.storeKitService = storeKitService
        self.notificationService = notificationService
        self.foodIntelligenceService = foodIntelligenceService
        self.haptics = haptics
        self.walkingLiveActivityService = walkingLiveActivityService
        self.analytics = analytics
        self.smartReminderEngine = smartReminderEngine
            ?? LiveSmartReminderEngine(notificationService: notificationService)
        self.upsellTriggerEngine = upsellTriggerEngine ?? DefaultUpsellTriggerEngine()
        self.foodRepository = foodRepository ?? DefaultFoodRepository()
        self.weeklyInsightEngine = weeklyInsightEngine ?? DefaultWeeklyInsightEngine()
        self.mealTimingEngine = mealTimingEngine ?? DefaultMealTimingEngine()
        self.subscriptionManager = subscriptionManager
            ?? SubscriptionManager(storeKitService: storeKitService)
    }

    // MARK: - Factories

    /// Production bootstrap — Live* implementations everywhere.
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

    /// SwiftUI preview bootstrap — every dependency is a Mock so previews
    /// never touch HealthKit, StoreKit, the keychain or the network.
    static func preview() -> DependencyContainer {
        mock()
    }

    /// Unit-test bootstrap — same wiring as `preview()`, exposed under an
    /// explicit name so tests can be read without ambiguity. Phase 10 —
    /// `foodRepository` artık `MockFoodRepository` (in-memory actor) ile
    /// gelir: testler ve previews paylaşılan SQLite singleton'a sızdırmaz,
    /// her bootstrap fresh state'le başlar.
    static func mock() -> DependencyContainer {
        DependencyContainer(
            healthService: MockHealthService(),
            motionService: MockMotionService(),
            storeKitService: MockStoreKitService(),
            notificationService: MockNotificationService(),
            foodIntelligenceService: MockFoodIntelligenceService(),
            haptics: MockHapticsService(),
            walkingLiveActivityService: MockWalkingLiveActivityService(),
            analytics: MockAnalyticsService(),
            stepCountService: MockStepCountService(),
            activeEnergyService: MockActiveEnergyService(),
            smartReminderEngine: MockSmartReminderEngine(),
            foodRepository: MockFoodRepository(seed: MockFoodRepository.previewSeed),
            weeklyInsightEngine: MockWeeklyInsightEngine(comparison: .previewSample)
        )
    }

    // MARK: - Repository factories
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
