import Combine
import Foundation
import SwiftData

@MainActor
final class WaterTrackingViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var entries: [WaterEntry] = []
    @Published var breakdown: [DrinkBreakdown] = []
    @Published var weeklyTotals: [WaterDayTotal] = []
    @Published var selectedDate: Date = Date()
    @Published var manualAmountMl: Int = 250
    @Published var selectedDrinkType: DrinkType = .water
    @Published var totalFluidMl: Int = 0
    @Published var totalHydrationMl: Int = 0
    @Published var totalCaffeineMg: Double = 0
    @Published var streak: StreakInsight = .empty
    @Published var isLoading = false
    @Published var showGoalCelebration = false
    @Published var actionFeedback: String?

    private var hasCelebratedToday = false

    var goal: WaterGoal { WaterGoal(profile: profile) }

    /// Counts only `.water` entries — this is what the headline / wave is for.
    var consumedMl: Int {
        entries.filter { $0.drinkType == .water }.map(\.amountMl).reduce(0, +)
    }
    var summary: WaterSummary {
        WaterSummary(consumedMl: consumedMl, targetMl: goal.dailyTargetMl)
    }

    var caffeineLimitMg: Int { profile?.dailyCaffeineLimitMg ?? 400 }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let userRepository = dependencies.userRepository(context: context)
            let waterRepository = dependencies.waterRepository(context: context)
            profile = try userRepository.profile()
            entries = try waterRepository.entries(on: selectedDate)
            breakdown = try waterRepository.drinksByType(on: selectedDate)
            totalFluidMl = try waterRepository.totalFluid(on: selectedDate)
            totalHydrationMl = try waterRepository.totalHydrationMl(on: selectedDate)
            totalCaffeineMg = try waterRepository.totalCaffeine(on: selectedDate)
            weeklyTotals = try waterRepository.weeklyTotals(endingOn: selectedDate)
            streak = (try? waterRepository.waterStreak(daysBack: 60, targetMl: goal.dailyTargetMl)) ?? .empty
            // Reset the celebration flag if the user dropped below the goal.
            if summary.consumedMl < summary.targetMl {
                hasCelebratedToday = false
            }
        } catch {
            entries = []
            breakdown = []
            totalFluidMl = 0
            totalHydrationMl = 0
            totalCaffeineMg = 0
            weeklyTotals = []
        }
    }

    func add(amount: Int, context: ModelContext, dependencies: DependencyContainer) async {
        await addDrink(amount: amount, drinkType: selectedDrinkType, context: context, dependencies: dependencies)
    }

    func addDrink(amount: Int, drinkType: DrinkType, caffeineMg: Double? = nil, context: ModelContext, dependencies: DependencyContainer) async {
        let safe = max(min(amount, 2_000), 50)
        let caffeine = caffeineMg ?? (drinkType.defaultCaffeinePerServingMg > 0 ? Double(drinkType.defaultCaffeinePerServingMg) * Double(safe) / Double(drinkType.defaultAmountMl) : nil)
        do {
            let wasGoalReached = summary.isGoalReached
            try dependencies.waterRepository(context: context).addDrink(amountMl: safe, drinkType: drinkType, caffeineMg: caffeine, date: selectedDate)
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(safe)", "drink": drinkType.rawValue]))
            await load(context: context, dependencies: dependencies)
            flash("+\(safe) ml \(drinkType.title.lowercased()) eklendi")
            if drinkType == .water, Calendar.nuvyra.isDateInToday(selectedDate), !wasGoalReached, summary.isGoalReached, !hasCelebratedToday {
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
            let removed = try dependencies.waterRepository(context: context).removeLastEntry(on: selectedDate)
            if removed > 0 { flash("-\(removed) ml geri alındı") }
            await load(context: context, dependencies: dependencies)
        } catch {}
    }

    func clearToday(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            try dependencies.waterRepository(context: context).clearDay(selectedDate)
            await load(context: context, dependencies: dependencies)
            flash("Gün sıfırlandı")
        } catch {}
    }

    func changeDate(to date: Date, context: ModelContext, dependencies: DependencyContainer) {
        selectedDate = date
        Task { await load(context: context, dependencies: dependencies) }
    }

    private func flash(_ message: String) {
        actionFeedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self?.actionFeedback = nil }
        }
    }
}
