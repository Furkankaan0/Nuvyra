import Combine
import Foundation
import SwiftData

@MainActor
final class WorkoutsViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var entries: [WorkoutEntry] = []
    @Published var summary: WorkoutDailySummary = .empty
    @Published var weeklyCalories: [WorkoutDayCalories] = []
    @Published var showingAdd = false
    @Published var editingLog: WorkoutLog?
    @Published var errorMessage: String?

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let repo = dependencies.workoutRepository(context: context)
            // HealthKit fetch only for today's screen — historical days use manual data only.
            let hk = Calendar.nuvyra.isDateInToday(selectedDate) ? await dependencies.healthService.todayWorkouts() : []
            entries = try repo.combinedWorkouts(on: selectedDate, healthKitWorkouts: hk)
            summary = try repo.dailySummary(on: selectedDate, healthKitWorkouts: hk)
            weeklyCalories = try await repo.weeklyCalories(endingOn: Date()) { day in
                Calendar.nuvyra.isDateInToday(day) ? hk : []
            }
        } catch {
            entries = []
            summary = .empty
            weeklyCalories = []
            errorMessage = "Egzersiz verisi yüklenemedi."
        }
    }

    func changeDate(to date: Date, context: ModelContext, dependencies: DependencyContainer) {
        selectedDate = date
        Task { await load(context: context, dependencies: dependencies) }
    }

    func delete(_ entry: WorkoutEntry, context: ModelContext, dependencies: DependencyContainer) {
        guard entry.source == .manual else { return }
        do {
            try dependencies.workoutRepository(context: context).delete(id: entry.id)
            Task { await load(context: context, dependencies: dependencies) }
        } catch {
            errorMessage = "Silinemedi."
        }
    }

    func startEditing(_ entry: WorkoutEntry, context: ModelContext) {
        guard entry.source == .manual else { return }
        let descriptor = FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == entry.id })
        if let log = try? context.fetch(descriptor).first {
            editingLog = log
        }
    }
}
