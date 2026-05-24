import Foundation
import SwiftData

@MainActor
final class WaterTrackingViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var entries: [WaterEntry] = []
    @Published var weeklyTotals: [WaterDayTotal] = []
    @Published var manualAmountMl: Int = 250
    @Published var isLoading = false
    @Published var showGoalCelebration = false
    @Published var actionFeedback: String?

    private var hasCelebratedToday = false

    var goal: WaterGoal { WaterGoal(profile: profile) }

    var consumedMl: Int { entries.map(\.amountMl).reduce(0, +) }
    var summary: WaterSummary {
        WaterSummary(consumedMl: consumedMl, targetMl: goal.dailyTargetMl)
    }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let userRepository = dependencies.userRepository(context: context)
            let waterRepository = dependencies.waterRepository(context: context)
            profile = try userRepository.profile()
            entries = try waterRepository.entries(on: Date())
            weeklyTotals = try waterRepository.weeklyTotals(endingOn: Date())
            // Reset the celebration flag if the user dropped below the goal.
            if summary.consumedMl < summary.targetMl {
                hasCelebratedToday = false
            }
        } catch {
            entries = []
            weeklyTotals = []
        }
    }

    func add(amount: Int, context: ModelContext, dependencies: DependencyContainer) async {
        let safe = max(min(amount, 2_000), 50)
        do {
            let wasGoalReached = summary.isGoalReached
            try dependencies.waterRepository(context: context).addWater(amountMl: safe, date: Date())
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(safe)"]))
            await load(context: context, dependencies: dependencies)
            flash("+\(safe) ml eklendi")
            if !wasGoalReached, summary.isGoalReached, !hasCelebratedToday {
                hasCelebratedToday = true
                dependencies.haptics.goalCompleted()
                showGoalCelebration = true
            }
        } catch {}
    }

    func remove(_ entry: WaterEntry, context: ModelContext, dependencies: DependencyContainer) async {
        context.delete(entry)
        do {
            try context.save()
            await load(context: context, dependencies: dependencies)
            flash("Kayıt geri alındı")
        } catch {}
    }

    func removeLast(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let removed = try dependencies.waterRepository(context: context).removeLastEntry(on: Date())
            if removed > 0 { flash("-\(removed) ml geri alındı") }
            await load(context: context, dependencies: dependencies)
        } catch {}
    }

    func clearToday(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            try dependencies.waterRepository(context: context).clearDay(Date())
            await load(context: context, dependencies: dependencies)
            flash("Bugün sıfırlandı")
        } catch {}
    }

    private func flash(_ message: String) {
        actionFeedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self?.actionFeedback = nil }
        }
    }
}

