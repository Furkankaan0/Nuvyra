import Foundation
import SwiftData

@MainActor
protocol ActivityRepository {
    func walkingLogs(days: Int) throws -> [WalkingLog]
    func todayWalkingLog() throws -> WalkingLog?
    func upsertWalkingSnapshot(date: Date, steps: Int, activeEnergy: Double, distanceKm: Double?, goal: Int) throws
    func averageSteps(days: Int) throws -> Int
    func completionRate(days: Int, goal: Int) throws -> Double
}

@MainActor
final class SwiftDataActivityRepository: ActivityRepository {
    private let context: ModelContext
    private let calendar: Calendar
    private let onMutate: (@MainActor () -> Void)?

    init(
        context: ModelContext,
        calendar: Calendar = .nuvyra,
        onMutate: (@MainActor () -> Void)? = nil
    ) {
        self.context = context
        self.calendar = calendar
        self.onMutate = onMutate
    }

    func walkingLogs(days: Int) throws -> [WalkingLog] {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date())) ?? Date()
        let descriptor = FetchDescriptor<WalkingLog>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    func todayWalkingLog() throws -> WalkingLog? {
        let (start, end) = calendar.startAndEndOfDay(for: Date())
        let descriptor = FetchDescriptor<WalkingLog>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return try context.fetch(descriptor).first
    }

    func upsertWalkingSnapshot(date: Date, steps: Int, activeEnergy: Double, distanceKm: Double?, goal: Int) throws {
        let start = calendar.startOfDay(for: date)
        if let existing = try todayWalkingLog() {
            existing.steps = steps
            existing.activeEnergy = activeEnergy
            existing.distanceKm = distanceKm
            existing.goalCompleted = steps >= goal
        } else {
            context.insert(WalkingLog(date: start, steps: steps, activeEnergy: activeEnergy, distanceKm: distanceKm, goalCompleted: steps >= goal))
        }
        try context.save()
        onMutate?()
    }

    func averageSteps(days: Int) throws -> Int {
        let logs = try walkingLogs(days: days)
        guard !logs.isEmpty else { return 0 }
        return logs.map(\.steps).reduce(0, +) / logs.count
    }

    func completionRate(days: Int, goal: Int) throws -> Double {
        let logs = try walkingLogs(days: days)
        guard !logs.isEmpty else { return 0 }
        let completed = logs.filter { $0.steps >= goal }.count
        return Double(completed) / Double(logs.count)
    }
}
