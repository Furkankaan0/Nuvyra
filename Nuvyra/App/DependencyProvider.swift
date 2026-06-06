import Foundation
import SwiftData

/// Read-only protocol surface for `DependencyContainer`. ViewModels and other
/// callers can depend on `DependencyProvider` instead of the concrete
/// `DependencyContainer` so they can be unit-tested with a custom mock
/// container, without losing the existing `@EnvironmentObject` ergonomics.
///
/// The container is kept as a class (so SwiftUI's `@EnvironmentObject`
/// continues to work) — this protocol just narrows the contract.
@MainActor
protocol DependencyProvider: AnyObject {
    // MARK: Services (all already protocol-typed today)
    var healthService: HealthService { get }
    var motionService: MotionService { get }
    var stepCountService: StepCountService { get }
    var activeEnergyService: ActiveEnergyService { get }
    var storeKitService: StoreKitService { get }
    var notificationService: NotificationService { get }
    var foodIntelligenceService: FoodIntelligenceService { get }
    var haptics: HapticsService { get }
    var walkingLiveActivityService: WalkingLiveActivityService { get }
    var analytics: AnalyticsService { get }
    var smartReminderEngine: SmartReminderEngine { get }
    var upsellTriggerEngine: UpsellTriggerEngine { get }
    var foodRepository: FoodRepository { get }
    var weeklyInsightEngine: WeeklyInsightEngine { get }
    var mealTimingEngine: MealTimingEngine { get }
    var trendInsightEngine: TrendInsightEngine { get }
    var vitalsService: NuvyraVitalsService { get }
    var cloudSyncService: NuvyraCloudSyncService { get }
    var subscriptionManager: SubscriptionManager { get }

    // MARK: Repository factories (each returns a protocol type)
    func userRepository(context: ModelContext) -> UserRepository
    func nutritionRepository(context: ModelContext) -> NutritionRepository
    func activityRepository(context: ModelContext) -> ActivityRepository
    func analyticsRepository(context: ModelContext) -> AnalyticsRepository
    func waterRepository(context: ModelContext) -> WaterRepository
    func weightRepository(context: ModelContext) -> WeightRepository
    func workoutRepository(context: ModelContext) -> WorkoutRepository
    func subscriptionRepository(context: ModelContext) -> SubscriptionRepository
}
