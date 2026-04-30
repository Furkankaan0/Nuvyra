import Foundation
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var meals: [MealEntry] = []
    @Published var waterMl = 0
    @Published var healthSnapshot = HealthSnapshot.fallback
    @Published var isLoading = false
    /// Last health-fetch error, surfaced in the dashboard banner so the
    /// user knows whether 0 steps means "you really did 0 steps" or
    /// "permission denied / data unavailable".
    @Published var healthError: HealthServiceError?
    @Published var motionAuthorization: MotionAuthorizationState = .authorized
    private var didPlayStepGoalHaptic = false
    /// In-flight `load()` task. We coalesce concurrent loads so two
    /// near-simultaneous foreground triggers (scenePhase + .task on
    /// view appear, for example) don't fight each other writing
    /// snapshots into `@Published` state.
    private var loadTask: Task<Void, Never>?

    var calorieTarget: Int { profile?.dailyCalorieTarget ?? 1_900 }
    var stepTarget: Int { profile?.dailyStepTarget ?? 7_500 }
    var waterTarget: Int { profile?.dailyWaterTargetMl ?? 2_000 }
    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var remainingCalories: Int { max(calorieTarget - totalCalories + Int(healthSnapshot.activeEnergy), 0) }

    /// Computed banner shown above the step ring. Health takes priority
    /// over motion (HealthKit is the primary source); if HealthKit is
    /// missing AND motion is denied, both effectively block live steps.
    var dataIssueBanner: DataIssueBanner? {
        if let healthError {
            return DataIssueBanner(
                icon: "heart.text.square",
                title: healthError.bannerTitle,
                message: healthError.errorDescription ?? "",
                action: bannerAction(for: healthError)
            )
        }
        if motionAuthorization == .denied || motionAuthorization == .restricted {
            return DataIssueBanner(
                icon: "figure.walk.motion",
                title: motionAuthorization.bannerTitle ?? "Hareket izni",
                message: motionAuthorization.bannerMessage ?? "",
                action: .openSettings
            )
        }
        return nil
    }

    var insight: String {
        if healthError == .notAuthorized {
            return "Apple Sağlık izni olmadan canlı adım takibi yapamıyoruz. Manuel olarak günü değerlendirebilirsin."
        }
        if healthSnapshot.steps >= stepTarget {
            return "Bugünkü yürüyüş ritmin tamamlandı. Akşamı sakin kapatmak yeterli."
        }
        if healthSnapshot.steps > stepTarget / 2 {
            return "Bugün adım ritmin iyi gidiyor. Akşam kısa bir yürüyüşle hedefi rahat tamamlayabilirsin."
        }
        if meals.isEmpty {
            return "İlk öğününü ekleyerek günün dengesini daha net görebilirsin."
        }
        return "Bugün küçük bir yürüyüş molası ritmini toparlamana yardımcı olabilir."
    }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        // Coalesce: if a load is already running, just await its
        // completion instead of starting a second pass that races with
        // it. Every async-boundary in `performLoad` writes to
        // @Published state, so two parallel loads can produce out-of-
        // order writes and observable flicker.
        if let existing = loadTask {
            await existing.value
            return
        }
        let task = Task { await self.performLoad(context: context, dependencies: dependencies) }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad(context: ModelContext, dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        let userRepository = dependencies.userRepository(context: context)
        let nutritionRepository = dependencies.nutritionRepository(context: context)
        let waterRepository = dependencies.waterRepository(context: context)
        let activityRepository = dependencies.activityRepository(context: context)

        // SwiftData reads are independent of HealthKit — we still want
        // calories/water on screen even if Apple Health is denied.
        profile = (try? userRepository.profile())
        meals = (try? nutritionRepository.meals(on: Date())) ?? []
        waterMl = (try? waterRepository.totalWater(on: Date())) ?? 0

        // Try HealthKit. On error we keep the previous snapshot so the
        // ring doesn't visibly reset to 0 when the network blips.
        switch await dependencies.healthService.loadTodaySnapshot() {
        case .success(let snapshot):
            healthSnapshot = snapshot
            healthError = nil
            try? activityRepository.upsertWalkingSnapshot(
                date: Date(),
                steps: snapshot.steps,
                activeEnergy: snapshot.activeEnergy,
                distanceKm: snapshot.distanceKm,
                goal: stepTarget
            )
        case .failure(let error):
            healthError = error
            // Try the CoreMotion fallback. It only kicks in if HealthKit
            // is unavailable / unauthorized — useful on devices without
            // an Apple Watch.
            let fallbackSteps = await dependencies.motionService.todayStepsFallback()
            motionAuthorization = dependencies.motionService.authorizationState
            healthSnapshot = HealthSnapshot(
                steps: fallbackSteps,
                activeEnergy: 0,
                distanceKm: nil,
                authorizationStatus: error == .notAuthorized ? .sharingDenied : .notDetermined,
                source: fallbackSteps > 0 ? .coreMotion : .manualFallback
            )
        }

        if healthSnapshot.source == .healthKit {
            // HealthKit returned successfully → keep the latest motion
            // status synced too so the banner is accurate.
            _ = await dependencies.motionService.todayStepsFallback()
            motionAuthorization = dependencies.motionService.authorizationState
        }

        if healthSnapshot.steps >= stepTarget, !didPlayStepGoalHaptic {
            didPlayStepGoalHaptic = true
            dependencies.haptics.goalCompleted()
            await dependencies.analytics.track(.stepGoalCompleted, payload: AnalyticsPayload())
        } else if healthSnapshot.steps < stepTarget {
            didPlayStepGoalHaptic = false
        }
    }

    func addWater(context: ModelContext, dependencies: DependencyContainer, amount: Int) async {
        do {
            // Atomic: repository writes the row + returns the post-
            // write daily total in one transaction. We use the returned
            // value directly instead of triggering a full `load()` —
            // that round-trip used to overlap with foreground refreshes
            // and produce ghost decrements when two refreshes raced.
            let newTotal = try dependencies
                .waterRepository(context: context)
                .addWater(amountMl: amount, date: Date())
            waterMl = newTotal
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(amount)"]))
        } catch {}
    }

    /// Try a HealthKit request again. The view binds this to the banner's
    /// retry button when the underlying error is transient.
    func retryHealth(context: ModelContext, dependencies: DependencyContainer) async {
        await load(context: context, dependencies: dependencies)
    }

    /// Re-prompt for HealthKit authorization. Used when the banner says
    /// "İzin gerekli" and the user taps the banner action.
    func requestHealthAuthorization(dependencies: DependencyContainer) async {
        _ = await dependencies.healthService.requestAuthorization()
    }

    private func bannerAction(for error: HealthServiceError) -> DataIssueBanner.Action {
        switch error {
        case .notAuthorized: return .openSettings
        case .unavailable: return .none
        case .queryFailed: return .retry
        }
    }
}

/// Lightweight VM-side description of the inline error banner shown above
/// the step ring. Built up in the dashboard view model; rendered by
/// `DataIssueBannerView` in DashboardView.
struct DataIssueBanner: Equatable {
    enum Action: Equatable {
        case none
        case retry
        case openSettings
    }

    let icon: String
    let title: String
    let message: String
    let action: Action
}
