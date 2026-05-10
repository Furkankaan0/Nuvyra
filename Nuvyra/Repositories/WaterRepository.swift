import Foundation
import SwiftData

struct DailyWaterTotal: Identifiable, Equatable {
    let id: Date
    let date: Date
    let totalMl: Int
}

@MainActor
protocol WaterRepository {
    func entries(on date: Date) throws -> [WaterEntry]
    func totalWater(on date: Date) throws -> Int
    func addWater(amountMl: Int, date: Date) throws
    @discardableResult
    func removeLatestEntry(on date: Date) throws -> Int?
    func remove(_ entry: WaterEntry) throws
    func weeklyTotals(endingOn date: Date) throws -> [DailyWaterTotal]
}

@MainActor
final class SwiftDataWaterRepository: WaterRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .nuvyra) {
        self.context = context
        self.calendar = calendar
    }

    func entries(on date: Date) throws -> [WaterEntry] {
        let (start, end) = calendar.startAndEndOfDay(for: date)
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func totalWater(on date: Date) throws -> Int {
        try entries(on: date).map(\.amountMl).reduce(0, +)
    }

    func addWater(amountMl: Int, date: Date = Date()) throws {
        context.insert(WaterEntry(date: date, amountMl: amountMl))
        try context.save()
    }

    @discardableResult
    func removeLatestEntry(on date: Date) throws -> Int? {
        let (start, end) = calendar.startAndEndOfDay(for: date)
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let latest = try context.fetch(descriptor).first else { return nil }
        let amount = latest.amountMl
        context.delete(latest)
        try context.save()
        return amount
    }

    func remove(_ entry: WaterEntry) throws {
        context.delete(entry)
        try context.save()
    }

    func weeklyTotals(endingOn date: Date) throws -> [DailyWaterTotal] {
        let endDay = calendar.startOfDay(for: date)
        guard let weekStartDay = calendar.date(byAdding: .day, value: -6, to: endDay) else {
            return []
        }
        let weekEndExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.date >= weekStartDay && $0.date < weekEndExclusive },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let entries = try context.fetch(descriptor)

        var bucket: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            bucket[day, default: 0] += entry.amountMl
        }

        return (0..<7).compactMap { offset -> DailyWaterTotal? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStartDay) else { return nil }
            return DailyWaterTotal(id: day, date: day, totalMl: bucket[day] ?? 0)
        }
    }
}
