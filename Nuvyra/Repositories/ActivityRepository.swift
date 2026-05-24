import Foundation
import SwiftData

@MainActor
protocol ActivityRepository {
    func walkingLogs(days: Int) throws -> [WalkingLog]
    func walkingLogs(days: Int, endingOn date: Date) throws -> [WalkingLog]
    func todayWalkingLog() throws -> WalkingLog?
    func walkingLog(on date: Date) throws -> WalkingLog?
    func upsertWalkingSnapshot(date: Date, steps: Int, activeEnergy: Double, distanceKm: Double?, goal: Int) throws
    func averageSteps(days: Int) throws -> Int
    func averageSteps(days: Int, endingOn date: Date) throws -> Int
    func completionRate(days: Int, goal: Int) throws -> Double
    func completionRate(days: Int, endingOn date: Date, goal: Int) throws -> Double
}

@MainActor
final class SwiftDataActivityRepository: ActivityRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .nuvyra) {
        self.context = context
        self.calendar = calendar
    }

    func walkingLogs(days: Int) throws -> [WalkingLog] {
        try walkingLogs(days: days, endingOn: Date())
    }

    func walkingLogs(days: Int, endingOn date: Date) throws -> [WalkingLog] {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: date)) ?? date
        let descriptor = FetchDescriptor<WalkingLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    func todayWalkingLog() throws -> WalkingLog? {
        try walkingLog(on: Date())
    }

    func walkingLog(on date: Date) throws -> WalkingLog? {
        let (start, end) = calendar.startAndEndOfDay(for: date)
        let descriptor = FetchDescriptor<WalkingLog>(predicate: #Predicate { $0.date >= start && $0.date < end })
        return try context.fetch(descriptor).first
    }

    func upsertWalkingSnapshot(date: Date, steps: Int, activeEnergy: Double, distanceKm: Double?, goal: Int) throws {
        let start = calendar.startOfDay(for: date)
        if let existing = try walkingLog(on: date) {
            existing.steps = steps
            existing.activeEnergy = activeEnergy
            existing.distanceKm = distanceKm
            existing.goalCompleted = steps >= goal
        } else {
            context.insert(WalkingLog(date: start, steps: steps, activeEnergy: activeEnergy, distanceKm: distanceKm, goalCompleted: steps >= goal))
        }
        try context.save()
    }

    func averageSteps(days: Int) throws -> Int {
        try averageSteps(days: days, endingOn: Date())
    }

    func averageSteps(days: Int, endingOn date: Date) throws -> Int {
        let logs = try walkingLogs(days: days, endingOn: date)
        guard !logs.isEmpty else { return 0 }
        return logs.map(\.steps).reduce(0, +) / logs.count
    }

    func completionRate(days: Int, goal: Int) throws -> Double {
        try completionRate(days: days, endingOn: Date(), goal: goal)
    }

    func completionRate(days: Int, endingOn date: Date, goal: Int) throws -> Double {
        let logs = try walkingLogs(days: days, endingOn: date)
        guard !logs.isEmpty else { return 0 }
        let completed = logs.filter { $0.steps >= goal }.count
        return Double(completed) / Double(logs.count)
    }
}
