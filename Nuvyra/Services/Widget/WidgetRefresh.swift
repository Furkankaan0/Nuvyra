import Foundation
import SwiftData
import WidgetKit

/// Builds a `NuvyraWidgetSnapshot` from SwiftData and pushes it to the
/// shared App Group, then asks WidgetKit to reload all timelines.
///
/// Lives only in the main-app target — the widget extension never queries
/// SwiftData directly; it only reads the snapshot via `WidgetSnapshotStore`.
enum WidgetRefresh {
    /// Recompute today's snapshot and reload every widget timeline.
    /// Safe to call from any place that mutates calorie/water/step state.
    /// Failures are swallowed: a missing snapshot just means the widget
    /// keeps showing its last good entry.
    @MainActor
    static func reload(context: ModelContext, now: Date = Date()) {
        guard let snapshot = build(context: context, now: now) else { return }
        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Pure(ish) snapshot builder — exposed so tests can assert on the
    /// values without touching WidgetKit.
    @MainActor
    static func build(context: ModelContext, now: Date = Date()) -> NuvyraWidgetSnapshot? {
        let calendar = Calendar.nuvyra
        let (start, end) = calendar.startAndEndOfDay(for: now)

        // Profile (targets) — fall back to neutral defaults if onboarding
        // hasn't run yet so the widget never shows zeroed-out values.
        let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first
        let stepGoal = profile?.dailyStepTarget ?? 7_500
        let calorieTarget = profile?.dailyCalorieTarget ?? 1_900
        let waterTarget = profile?.dailyWaterTargetMl ?? 2_000

        // Calories — sum today's MealEntry rows.
        let mealDescriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        let meals = (try? context.fetch(mealDescriptor)) ?? []
        let calorieIntake = meals.reduce(0) { $0 + $1.calories }
        let calorieBalance = max(calorieTarget - calorieIntake, 0)

        // Water — sum today's WaterEntry rows.
        let waterDescriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        let waterEntries = (try? context.fetch(waterDescriptor)) ?? []
        let waterMl = waterEntries.map(\.amountMl).reduce(0, +)

        // Steps — read the most recent WalkingLog for today.
        let walkingDescriptor = FetchDescriptor<WalkingLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        let walkingLog = try? context.fetch(walkingDescriptor).first
        let steps = walkingLog?.steps ?? 0

        let ringProgress = stepGoal > 0 ? min(Double(steps) / Double(stepGoal), 1) : 0
        let insight = self.insight(
            steps: steps,
            stepGoal: stepGoal,
            calorieBalance: calorieBalance,
            waterMl: waterMl,
            waterTarget: waterTarget
        )

        return NuvyraWidgetSnapshot(
            generatedAt: now,
            dayKey: NuvyraWidgetSnapshot.dayKey(for: now, calendar: calendar),
            steps: steps,
            stepGoal: stepGoal,
            calorieIntake: calorieIntake,
            calorieTarget: calorieTarget,
            calorieBalance: calorieBalance,
            waterMl: waterMl,
            waterTargetMl: waterTarget,
            ringProgress: ringProgress,
            insight: insight
        )
    }

    private static func insight(
        steps: Int,
        stepGoal: Int,
        calorieBalance: Int,
        waterMl: Int,
        waterTarget: Int
    ) -> String {
        if steps >= stepGoal && waterMl >= waterTarget {
            return "Bugünkü adım ve su ritmin tamam. Akşamı sakin geçirebilirsin."
        }
        if steps >= stepGoal {
            return "Adım hedefin tamam. Suya \(max(waterTarget - waterMl, 0)) ml kaldı."
        }
        let remaining = max(stepGoal - steps, 0)
        if calorieBalance < 200 && remaining > 0 {
            return "Kaloride sınıra yaklaştın. Kısa bir yürüyüş dengeyi kurar."
        }
        if remaining > 0 {
            return "Hedefe \(remaining.formatted()) adım kaldı. Kısa ve sakin yeter."
        }
        return "Bugünün dengesi sakin görünüyor."
    }
}
