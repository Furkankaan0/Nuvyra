import Foundation
import SwiftData

/// Per-day water total — used by the weekly chart on the WaterTracking screen.
struct WaterDayTotal: Identifiable, Equatable {
    let id: Date
    let date: Date
    let totalMl: Int

    init(date: Date, totalMl: Int) {
        self.id = date
        self.date = date
        self.totalMl = totalMl
    }
}

@MainActor
protocol WaterRepository {
    func entries(on date: Date) throws -> [WaterEntry]
    func totalWater(on date: Date) throws -> Int
    func addWater(amountMl: Int, date: Date) throws
    @discardableResult func removeLastEntry(on date: Date) throws -> Int
    func clearDay(_ date: Date) throws
    func weeklyTotals(endingOn date: Date) throws -> [WaterDayTotal]
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
    func removeLastEntry(on date: Date) throws -> Int {
        let items = try entries(on: date)
        guard let last = items.first else { return 0 }
        let amount = last.amountMl
        context.delete(last)
        try context.save()
        return amount
    }

    func clearDay(_ date: Date) throws {
        let items = try entries(on: date)
        items.forEach { context.delete($0) }
        try context.save()
    }

    func weeklyTotals(endingOn date: Date) throws -> [WaterDayTotal] {
        let startOfToday = calendar.startOfDay(for: date)
        return try (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: startOfToday) ?? startOfToday
            let total = try totalWater(on: day)
            return WaterDayTotal(date: day, totalMl: total)
        }
    }
}
