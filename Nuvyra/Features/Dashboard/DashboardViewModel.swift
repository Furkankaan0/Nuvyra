import Combine
import Foundation
import SwiftData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var meals: [MealEntry] = []
    @Published var waterMl = 0
    @Published var healthSnapshot = HealthSnapshot.fallback
    @Published var isLoading = false
    @Published var lastUpdated: Date = Date()
    @Published var actionFeedback: String?
    @Published var waterStreak: StreakInsight = .empty
    @Published var mealStreak: StreakInsight = .empty
    @Published var weeklyComparison: WeeklyComparison = .empty
    @Published var weightSummary: WeightTrendSummary = .empty
    @Published var mealTiming: MealTimingInsight = .empty
    @Published var vitals: NuvyraVitalsSnapshot = .empty
    @Published var trendInsights: [TrendInsight] = []
    @Published var weeklyGoals: WeeklyGoalSummary = .empty
    /// Set when the latest load detected a badge the user hadn't earned
    /// before. The view consumes it to fire one celebration, then
    /// clears it. `nil` most of the time.
    @Published var newlyEarnedBadge: NuvyraBadge?
    @Published var didCompleteDayOneTour: Bool = false
    @Published var pendingUpsell: UpsellTrigger?
    @Published var shouldShowVitalsPermissionToast = false

    private var didPlayStepGoalHaptic = false
    private var lastLoadFinishedAt = Date.distantPast
    private let passiveReloadCooldown: TimeInterval = 1.5

    /// Day-one onboarding checklist state — derived live from today's data.
    var dayOneCompletedSteps: Set<DayOneTourCard.Step> {
        var done: Set<DayOneTourCard.Step> = []
        if !meals.isEmpty { done.insert(.firstMeal) }
        if waterMl > 0 { done.insert(.firstWater) }
        if healthSnapshot.steps > 0 { done.insert(.viewSteps) }
        return done
    }

    var shouldShowDayOneTour: Bool {
        !didCompleteDayOneTour && dayOneCompletedSteps.count < DayOneTourCard.Step.allCases.count
    }

    // MARK: - Targets
    var calorieTarget: Int { profile?.dailyCalorieTarget ?? 1_900 }
    var stepTarget: Int { profile?.dailyStepTarget ?? 7_500 }
    var waterTarget: Int { profile?.dailyWaterTargetMl ?? 2_000 }
    var proteinTarget: Double { Double(profile?.dailyProteinTargetGrams ?? 120) }
    var carbsTarget: Double { Double(profile?.dailyCarbsTargetGrams ?? 210) }
    var fatTarget: Double { Double(profile?.dailyFatTargetGrams ?? 65) }

    // MARK: - Totals
    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { meals.reduce(0) { $0 + ($1.protein ?? 0) } }
    var totalCarbs: Double { meals.reduce(0) { $0 + ($1.carbs ?? 0) } }
    var totalFat: Double { meals.reduce(0) { $0 + ($1.fat ?? 0) } }
    var remainingCalories: Int { max(calorieTarget - totalCalories + Int(healthSnapshot.activeEnergy), 0) }

    var hasAnyData: Bool { !meals.isEmpty || waterMl > 0 || healthSnapshot.steps > 0 }
    var greetingName: String { profile?.name.isEmpty == false ? profile!.name : "Hoş geldin" }

    // MARK: - Summaries
    var nutritionSummary: DailyNutritionSummary {
        DailyNutritionSummary(
            consumedCalories: totalCalories,
            burnedCalories: Int(healthSnapshot.activeEnergy.rounded()),
            targetCalories: calorieTarget
        )
    }

    var macroSummaries: [MacroSummary] {
        [
            MacroSummary(kind: .protein, consumedGrams: totalProtein, targetGrams: proteinTarget),
            MacroSummary(kind: .carbs, consumedGrams: totalCarbs, targetGrams: carbsTarget),
            MacroSummary(kind: .fat, consumedGrams: totalFat, targetGrams: fatTarget)
        ]
    }

    var waterSummary: WaterSummary {
        WaterSummary(consumedMl: waterMl, targetMl: waterTarget)
    }

    var stepSummary: StepSummary {
        StepSummary(
            steps: healthSnapshot.steps,
            goal: stepTarget,
            distanceKm: healthSnapshot.distanceKm,
            activeEnergy: healthSnapshot.activeEnergy
        )
    }

    /// Today's TDEE-based deficit/surplus snapshot. Empty when there's no profile yet.
    var energyBalance: EnergyBalanceSummary {
        guard let profile else { return .empty }
        let metrics = BodyMetricsCalculator.summary(for: profile)
        return BodyMetricsCalculator.energyBalance(
            summary: metrics,
            caloriesConsumed: totalCalories,
            caloriesBurned: Int(healthSnapshot.activeEnergy.rounded())
        )
    }

    var recentFoods: [RecentFoodLog] {
        meals
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map(RecentFoodLog.init(meal:))
    }

    var shareableAchievement: ShareableAchievement? {
        if stepSummary.isGoalReached {
            let steps = stepSummary.steps.formatted()
            return ShareableAchievement(
                kind: .steps,
                title: "Bugünkü yürüyüş ritmi tamam",
                subtitle: "Adım hedefini sakin ve sürdürülebilir şekilde tamamladın.",
                metric: steps,
                shareText: "Bugün Nuvyra ile \(steps) adım attım. Günlük ritmimi nazikçe tamamladım."
            )
        }

        if waterStreak.currentStreak >= 3 {
            return ShareableAchievement(
                kind: .waterStreak,
                title: "\(waterStreak.currentStreak) günlük su ritmi",
                subtitle: "Küçük tekrarlar güçlü bir alışkanlığa dönüşüyor.",
                metric: "\(waterStreak.currentStreak) gün",
                shareText: "Nuvyra ile \(waterStreak.currentStreak) gündür su ritmimi koruyorum."
            )
        }

        if mealStreak.currentStreak >= 3 {
            return ShareableAchievement(
                kind: .mealStreak,
                title: "\(mealStreak.currentStreak) günlük öğün kaydı",
                subtitle: "Beslenmeni suçlulukla değil, farkındalıkla takip ediyorsun.",
                metric: "\(mealStreak.currentStreak) gün",
                shareText: "Nuvyra ile \(mealStreak.currentStreak) gündür öğünlerimi düzenli kaydediyorum."
            )
        }

        if waterSummary.isGoalReached {
            return ShareableAchievement(
                kind: .waterGoal,
                title: "Bugünkü su hedefi tamam",
                subtitle: "Vücuduna iyi gelen basit bir ritmi bugün de korudun.",
                metric: "\(waterMl) ml",
                shareText: "Bugün Nuvyra ile su hedefimi tamamladım: \(waterMl) ml."
            )
        }

        return nil
    }

    // MARK: - AI insight (lightweight, on-device, non-medical)
    var insight: String {
        let summary = nutritionSummary
        let water = waterSummary
        let steps = stepSummary
        let proteinShortfall = max(proteinTarget - totalProtein, 0)

        if !hasAnyData {
            return "Güne başlamak için bir öğün veya bir bardak su kaydı eklemen yeterli. Nuvyra ritmini buradan okuyacak."
        }
        if steps.isGoalReached && water.isGoalReached && summary.consumedCalories >= summary.targetCalories - 200 {
            return "Bugünkü ritmin oldukça dengeli. Akşamı sakin geçirmek vücudunun toparlanmasına yardım eder."
        }
        if proteinShortfall > 30 {
            return "Protein hedefine ulaşmak için \(Int(proteinShortfall)) g daha alabilirsin — ızgara tavuk, yoğurt veya yumurta iyi bir seçim olabilir."
        }
        if !water.isGoalReached, water.remainingMl >= 500 {
            return "Su tüketimin biraz geride. \(water.remainingMl) ml daha içmen günü dengelemene yardım eder."
        }
        if !steps.isGoalReached, steps.remaining > 0 {
            return "Hedefe \(steps.remaining.formatted()) adım kaldı — 15-20 dakikalık tempolu bir yürüyüş bunu rahatça tamamlar."
        }
        return "Bugünkü dengeni korumak için küçük bir yürüyüş veya bir bardak daha su iyi gelecek."
    }

    /// Persist the dismiss / completion flag onto AppSettings.
    func dismissDayOneTour(context: ModelContext) {
        didCompleteDayOneTour = true
        mutateSettings(context: context) { $0.didCompleteDayOneTour = true }
    }

    /// Mark the upsell trigger as shown so we don't surface it again.
    func acknowledgeUpsell(_ trigger: UpsellTrigger, context: ModelContext) {
        mutateSettings(context: context) { settings in
            settings.lastUpsellShownAt = Date()
            var shown = UpsellTrigger.parse(rawList: settings.shownUpsellTriggers)
            shown.insert(trigger)
            settings.shownUpsellTriggers = UpsellTrigger.encode(shown)
        }
        pendingUpsell = nil
    }

    func markVitalsPermissionToastShown(context: ModelContext) {
        mutateSettings(context: context) { $0.vitalsPermissionToastShown = true }
        shouldShowVitalsPermissionToast = false
    }

    func requestVitalsAuthorization(context: ModelContext, dependencies: DependencyContainer) async {
        markVitalsPermissionToastShown(context: context)
        let granted = await dependencies.vitalsService.requestAuthorization()
        if granted {
            vitals = await dependencies.vitalsService.snapshot()
        }
    }

    /// Tiny helper for AppSettings upsert with `updatedAt` housekeeping.
    private func mutateSettings(context: ModelContext, mutate: (AppSettings) -> Void) {
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = (try? context.fetch(descriptor))?.first {
            mutate(settings)
            settings.updatedAt = Date()
        } else {
            let settings = AppSettings()
            mutate(settings)
            context.insert(settings)
        }
        try? context.save()
    }

    /// Compares the freshly-computed badge set against the persisted
    /// earned IDs. If a badge was earned that wasn't before, sets
    /// `newlyEarnedBadge` (newest first) and stores the union so the
    /// celebration fires exactly once per unlock — even across relaunch.
    private func detectNewlyEarnedBadge(settings: AppSettings?, context: ModelContext) {
        let earnedNow = Set(weeklyGoals.badges.filter(\.isEarned).map(\.id))
        guard !earnedNow.isEmpty else { return }

        let previouslyEarned = Set(
            (settings?.earnedBadgeIDs ?? "")
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
        let fresh = earnedNow.subtracting(previouslyEarned)
        guard !fresh.isEmpty else { return }

        // Pick the freshest unlock to celebrate. Order follows the
        // badge array (most prestigious last), so we take the last one.
        if let badge = weeklyGoals.badges.last(where: { fresh.contains($0.id) }) {
            newlyEarnedBadge = badge
        }

        // Persist the full union so we never re-celebrate.
        let union = previouslyEarned.union(earnedNow).sorted().joined(separator: ",")
        mutateSettings(context: context) { $0.earnedBadgeIDs = union }
    }

    // MARK: - Load
    func load(context: ModelContext, dependencies: DependencyContainer, force: Bool = false) async {
        let now = Date()
        guard force || (!isLoading && now.timeIntervalSince(lastLoadFinishedAt) > passiveReloadCooldown) else {
            return
        }
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
            lastLoadFinishedAt = lastUpdated
        }
        do {
            let userRepository = dependencies.userRepository(context: context)
            let nutritionRepository = dependencies.nutritionRepository(context: context)
            let waterRepository = dependencies.waterRepository(context: context)
            let activityRepository = dependencies.activityRepository(context: context)
            profile = try userRepository.profile()
            meals = try nutritionRepository.meals(on: Date())
            waterMl = try waterRepository.totalWater(on: Date())
            healthSnapshot = await dependencies.healthService.todaySnapshot()
            try activityRepository.upsertWalkingSnapshot(
                date: Date(),
                steps: healthSnapshot.steps,
                activeEnergy: healthSnapshot.activeEnergy,
                distanceKm: healthSnapshot.distanceKm,
                goal: stepTarget
            )
            // Streak rollups — repository runs a single 60-day fetch + fast in-memory scan.
            waterStreak = (try? waterRepository.waterStreak(daysBack: 60, targetMl: waterTarget)) ?? .empty
            mealStreak = (try? nutritionRepository.mealStreak(daysBack: 60)) ?? .empty

            // 14-day comparison (this week vs. prior). 3 repo fetches, all
            // already async-safe on MainActor.
            weeklyComparison = (try? dependencies.weeklyInsightEngine.computeComparison(
                nutrition: nutritionRepository,
                water: waterRepository,
                activity: activityRepository,
                endingOn: Date()
            )) ?? .empty

            // 30-day weight trend — silently falls back to empty when the
            // user has no measurements; WeightTrendCard hides itself in that case.
            weightSummary = (try? dependencies.weightRepository(context: context).trendSummary(
                days: 30,
                targetWeightKg: profile?.targetWeightKg
            )) ?? .empty

            // Today's meal-rhythm read — pure in-memory evaluation off the
            // meals we already fetched, no extra repo round-trip.
            mealTiming = dependencies.mealTimingEngine.evaluate(meals: meals, at: Date())

            // Sleep + resting heart-rate snapshot. Runs in parallel with
            // the rest of the load() and falls back silently to .empty
            // when HealthKit auth is missing.
            vitals = await dependencies.vitalsService.snapshot()

            // Multi-day behavioural pattern detection (protein shortfall
            // runs, weekend water dips, step streaks). Empty array when
            // nothing notable — the card hides itself.
            trendInsights = (try? dependencies.trendInsightEngine.detect(
                nutrition: nutritionRepository,
                water: waterRepository,
                activity: activityRepository,
                profile: profile,
                endingOn: Date()
            )) ?? []

            // Weekly goal completion + derived milestone badges. Reuses
            // the streak rollups computed just above.
            weeklyGoals = (try? dependencies.weeklyGoalEngine.summary(
                nutrition: nutritionRepository,
                water: waterRepository,
                activity: activityRepository,
                profile: profile,
                mealStreak: mealStreak,
                waterStreak: waterStreak,
                endingOn: Date()
            )) ?? .empty

            // Day-one tour flag — read from AppSettings, auto-complete once every step is done.
            let settings = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first

            // Badge unlock detection — compare the engine's earned set
            // against the IDs we've already celebrated. Fire at most one
            // celebration per load (the freshest unlock) and persist the
            // full earned set so we never re-celebrate.
            detectNewlyEarnedBadge(settings: settings, context: context)

            didCompleteDayOneTour = settings?.didCompleteDayOneTour ?? false
            shouldShowVitalsPermissionToast = dependencies.healthService.isHealthDataAvailable
                && !(settings?.vitalsPermissionToastShown ?? false)
                && vitals == .empty
            if !didCompleteDayOneTour, dayOneCompletedSteps.count == DayOneTourCard.Step.allCases.count {
                dismissDayOneTour(context: context)
            }

            // Stamp firstLaunchAt the very first time we see this user post-onboarding,
            // so behavioural triggers like "one week active" can fire later on.
            if settings?.firstLaunchAt == nil {
                mutateSettings(context: context) { $0.firstLaunchAt = Date() }
            }

            // Behavioural upsell evaluation (skips silently for premium users).
            let alreadyShown = UpsellTrigger.parse(rawList: settings?.shownUpsellTriggers ?? "")
            let upsellContext = UpsellContext(
                isPremium: dependencies.subscriptionManager.isPremium,
                firstLaunchAt: settings?.firstLaunchAt ?? Date(),
                lastShownAt: settings?.lastUpsellShownAt,
                alreadyShown: alreadyShown,
                waterStreak: waterStreak.currentStreak,
                mealStreak: mealStreak.currentStreak,
                stepGoalCompletedToday: healthSnapshot.steps >= stepTarget,
                waterGoalCompletedToday: waterMl >= waterTarget,
                calorieGoalCompletedToday: totalCalories >= Int(Double(calorieTarget) * 0.9)
            )
            pendingUpsell = dependencies.upsellTriggerEngine.nextTrigger(context: upsellContext)

            // Re-plan today's smart reminders against the freshly loaded context.
            let hasLunch = meals.contains { $0.mealType == .lunch }
            let hasDinner = meals.contains { $0.mealType == .dinner }
            let reminderContext = ReminderContext(
                firstName: profile?.name.isEmpty == false ? profile!.name : "Hoş geldin",
                caloriesConsumed: totalCalories,
                calorieTarget: calorieTarget,
                hasLunchLogged: hasLunch,
                hasDinnerLogged: hasDinner,
                waterMl: waterMl,
                waterTargetMl: waterTarget,
                steps: healthSnapshot.steps,
                stepTarget: stepTarget,
                waterStreakDays: waterStreak.currentStreak,
                mealStreakDays: mealStreak.currentStreak
            )
            await dependencies.smartReminderEngine.reschedule(context: reminderContext)

            if healthSnapshot.steps >= stepTarget, !didPlayStepGoalHaptic {
                didPlayStepGoalHaptic = true
                dependencies.haptics.goalCompleted()
                await dependencies.analytics.track(.stepGoalCompleted, payload: AnalyticsPayload())
            } else if healthSnapshot.steps < stepTarget {
                didPlayStepGoalHaptic = false
            }
        } catch {
            healthSnapshot = .fallback
        }
    }

    // MARK: - Actions
    func addWater(context: ModelContext, dependencies: DependencyContainer, amount: Int) async {
        do {
            try dependencies.waterRepository(context: context).addWater(amountMl: amount, date: Date())
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(amount)"]))
            await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(context: context, healthService: dependencies.healthService)
            await load(context: context, dependencies: dependencies, force: true)
            flash("+\(amount) ml eklendi")
        } catch {}
    }

    func removeLastWater(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let removed = try dependencies.waterRepository(context: context).removeLastEntry(on: Date())
            if removed > 0 {
                dependencies.haptics.waterAdded()
                await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(context: context, healthService: dependencies.healthService)
                flash("-\(removed) ml geri alındı")
            }
            await load(context: context, dependencies: dependencies, force: true)
        } catch {}
    }

    func startWalking(dependencies: DependencyContainer) async {
        dependencies.haptics.walkStarted()
        await dependencies.walkingLiveActivityService.start(goal: stepTarget, initialSteps: healthSnapshot.steps)
        flash("Yürüyüş odağı başlatıldı")
    }

    private func flash(_ message: String) {
        actionFeedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            await MainActor.run { self?.actionFeedback = nil }
        }
    }
}
