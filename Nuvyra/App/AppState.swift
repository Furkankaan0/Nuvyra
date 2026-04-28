import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var router = AppRouter()
    @Published var hasCompletedOnboarding = false
    @Published var profile: UserProfile?
    @Published var meals: [MealLog] = []
    @Published var waterLogs: [WaterLog] = []
    @Published var stepSnapshot = StepSnapshot(steps: 0, goal: 6_500, updatedAt: Date(), source: .unavailable)
    @Published var stepHistory: [StepHistoryDay] = []
    @Published var weeklySummary = WeeklySummary.sample
    @Published var dailyPlan: DailyPlan?
    @Published var entitlementState = EntitlementState.free
    @Published var lastErrorMessage: String?

    let environment: AppEnvironment
    private let calorieCalculator = CalorieTargetCalculator()

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    static func live() -> AppState {
        AppState(environment: .live())
    }

    static func launch() -> AppState {
        if CommandLine.arguments.contains("-ui-testing") {
            return preview(completedOnboarding: false)
        }
        return live()
    }

    static func preview(completedOnboarding: Bool = true) -> AppState {
        let state = AppState(environment: .preview())
        state.hasCompletedOnboarding = completedOnboarding
        state.profile = .preview
        state.meals = MealLog.sampleToday
        state.waterLogs = [WaterLog(glasses: 3)]
        state.stepSnapshot = .preview
        state.stepHistory = StepHistoryDay.sampleWeek
        state.recalculateCoaching()
        return state
    }

    var calorieTarget: CalorieTarget {
        profile.map { calorieCalculator.target(for: $0) } ?? CalorieTarget(lowerBound: 1_650, upperBound: 1_950, recommended: 1_800)
    }

    var caloriesConsumedToday: Int {
        meals.reduce(0) { $0 + $1.calories }
    }

    var remainingCaloriesToday: Int {
        max(calorieTarget.recommended - caloriesConsumedToday, 0)
    }

    var waterGlassesToday: Int {
        waterLogs.filter { Calendar.current.isDateInToday($0.loggedAt) }.map(\.glasses).reduce(0, +)
    }

    func loadInitialData() async {
        do {
            profile = try await environment.userProfileRepository.loadProfile()
            hasCompletedOnboarding = profile != nil
            meals = try await environment.mealLogService.meals(on: Date())
            waterLogs = try await environment.waterRepository.loadWaterLogs()
            await refreshSteps()
            await environment.entitlementManager.refresh()
            entitlementState = environment.entitlementManager.state
            recalculateCoaching()
        } catch {
            lastErrorMessage = error.localizedDescription
            seedDemoStateIfNeeded()
        }
    }

    func completeOnboarding(profile: UserProfile) async {
        do {
            self.profile = profile
            stepSnapshot = StepSnapshot(steps: 0, goal: StepGoalAdapter().initialGoal(for: profile.activityLevel), updatedAt: Date(), source: .unavailable)
            try await environment.userProfileRepository.saveProfile(profile)
            hasCompletedOnboarding = true
            await environment.analytics.track(AnalyticsEvent(.onboardingCompleted, payload: ["goal_type": profile.goal.analyticsValue]))
            recalculateCoaching()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshSteps() async {
        let goal = profile.map { StepGoalAdapter().initialGoal(for: $0.activityLevel) } ?? stepSnapshot.goal
        stepSnapshot = await environment.stepSyncService.syncToday(goal: goal)
        stepHistory = await environment.stepSyncService.syncHistory(days: 7, goal: goal)
        recalculateCoaching()
        if stepSnapshot.remainingSteps == 0 {
            await environment.analytics.track(AnalyticsEvent(.walkGoalCompleted))
        }
    }

    func requestHealthKitSteps() async -> HealthAuthorizationStatus {
        await environment.analytics.track(AnalyticsEvent(.healthKitPrepromptViewed))
        let status = await environment.healthKitManager.requestStepAuthorization()
        await environment.analytics.track(AnalyticsEvent(status == .granted ? .healthKitGrantedSteps : .healthKitDeniedSteps))
        if status == .granted {
            await refreshSteps()
        }
        return status
    }

    func requestNotifications() async -> NotificationPermissionStatus {
        let status = await environment.notificationScheduler.requestAuthorization()
        await environment.analytics.track(AnalyticsEvent(status == .granted ? .notificationPermissionGranted : .notificationPermissionDenied))
        return status
    }

    func addMeal(_ meal: MealLog) async {
        do {
            let isFirst = meals.isEmpty
            meals = try await environment.mealLogService.addMeal(meal)
            await environment.analytics.track(AnalyticsEvent(isFirst ? .mealLoggedFirst : .mealLogged, payload: ["source": meal.source.rawValue]))
            recalculateCoaching()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteMeal(id: UUID) async {
        do {
            meals = try await environment.mealLogService.deleteMeal(id: id)
            recalculateCoaching()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func logWaterGlass() async {
        do {
            var logs = try await environment.waterRepository.loadWaterLogs()
            logs.append(WaterLog(glasses: 1))
            try await environment.waterRepository.saveWaterLogs(logs)
            waterLogs = logs
            recalculateCoaching()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func scheduleGentleReminders() async {
        do {
            try await environment.notificationScheduler.scheduleGentleReminders(settings: .gentleDefault, remainingSteps: stepSnapshot.remainingSteps)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func recalculateCoaching() {
        if let profile {
            dailyPlan = environment.coachingEngine.dailyPlan(for: profile, meals: meals, steps: stepSnapshot, waterGlasses: waterGlassesToday)
        }
        weeklySummary = environment.coachingEngine.weeklySummary(meals: meals, steps: stepHistory, waterLogs: waterLogs)
    }

    private func seedDemoStateIfNeeded() {
        guard profile == nil, meals.isEmpty else { return }
        profile = .preview
        meals = MealLog.sampleToday
        waterLogs = [WaterLog(glasses: 2)]
        stepSnapshot = .preview
        stepHistory = StepHistoryDay.sampleWeek
        recalculateCoaching()
    }
}
