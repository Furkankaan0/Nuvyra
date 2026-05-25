import Foundation
import SwiftData

/// Per-day workout rollup surfaced by `WorkoutRepository.dailySummary(on:)`.
struct WorkoutDailySummary: Equatable {
    var date: Date
    var totalCalories: Int
    var totalMinutes: Int
    var sessionCount: Int

    static let empty = WorkoutDailySummary(date: Date(), totalCalories: 0, totalMinutes: 0, sessionCount: 0)
}

@MainActor
protocol WorkoutRepository {
    /// Locally stored (manual) workouts only.
    func manualWorkouts(on date: Date) throws -> [WorkoutLog]
    /// Merged feed of manual + HealthKit entries for the given day, newest first.
    func combinedWorkouts(on date: Date, healthKitWorkouts: [WorkoutEntry]) throws -> [WorkoutEntry]
    func add(_ workout: WorkoutLog) throws
    func update(_ workout: WorkoutLog) throws
    func delete(id: UUID) throws
    func dailySummary(on date: Date, healthKitWorkouts: [WorkoutEntry]) throws -> WorkoutDailySummary
    func weeklyCalories(endingOn date: Date, healthKitProvider: (Date) async -> [WorkoutEntry]) async throws -> [WorkoutDayCalories]
}

struct WorkoutDayCalories: Identifiable, Equatable {
    let id: Date
    let date: Date
    let calories: Int

    init(date: Date, calories: Int) {
        self.id = date
        self.date = date
        self.calories = calories
    }
}

@MainActor
final class SwiftDataWorkoutRepository: WorkoutRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .nuvyra) {
        self.context = context
        self.calendar = calendar
    }

    func manualWorkouts(on date: Date) throws -> [WorkoutLog] {
        let (start, end) = calendar.startAndEndOfDay(for: date)
        let descriptor = FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func combinedWorkouts(on date: Date, healthKitWorkouts: [WorkoutEntry]) throws -> [WorkoutEntry] {
        let manual = try manualWorkouts(on: date).map(WorkoutEntry.init(log:))
        // De-dup: HealthKit workouts whose UUID matches a manual log are ignored.
        let manualIds = Set(manual.map(\.id))
        let merged = manual + healthKitWorkouts.filter { !manualIds.contains($0.id) }
        return merged.sorted { $0.date > $1.date }
    }

    func add(_ workout: WorkoutLog) throws {
        context.insert(workout)
        try context.save()
    }

    func update(_ workout: WorkoutLog) throws {
        try context.save()
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<WorkoutLog>(predicate: #Predicate { $0.id == id })
        if let log = try context.fetch(descriptor).first {
            context.delete(log)
            try context.save()
        }
    }

    func dailySummary(on date: Date, healthKitWorkouts: [WorkoutEntry]) throws -> WorkoutDailySummary {
        let entries = try combinedWorkouts(on: date, healthKitWorkouts: healthKitWorkouts)
        let kcal = entries.map(\.caloriesBurned).reduce(0, +)
        let minutes = entries.map(\.durationMinutes).reduce(0, +)
        return WorkoutDailySummary(date: date, totalCalories: kcal, totalMinutes: minutes, sessionCount: entries.count)
    }

    /// Async because HealthKit is fetched per-day via the supplied provider closure.
    func weeklyCalories(endingOn date: Date, healthKitProvider: (Date) async -> [WorkoutEntry]) async throws -> [WorkoutDayCalories] {
        let startOfToday = calendar.startOfDay(for: date)
        var result: [WorkoutDayCalories] = []
        for offset in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) ?? startOfToday
            // HealthKit per-day fetch is optional; manual logs cover the rest.
            let hkEntries = await healthKitProvider(day)
            let merged = try combinedWorkouts(on: day, healthKitWorkouts: hkEntries)
            let kcal = merged.map(\.caloriesBurned).reduce(0, +)
            result.append(WorkoutDayCalories(date: day, calories: kcal))
        }
        return result
    }
}
