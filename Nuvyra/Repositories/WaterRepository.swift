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

/// Aggregated drink breakdown returned by `WaterRepository.drinksByType(on:)`.
struct DrinkBreakdown: Equatable {
    let type: DrinkType
    let totalMl: Int
    let totalCaffeineMg: Double
}

@MainActor
protocol WaterRepository {
    func entries(on date: Date) throws -> [WaterEntry]
    func totalWater(on date: Date) throws -> Int
    func totalFluid(on date: Date) throws -> Int
    func totalHydrationMl(on date: Date) throws -> Int
    func totalCaffeine(on date: Date) throws -> Double
    func drinksByType(on date: Date) throws -> [DrinkBreakdown]
    func addWater(amountMl: Int, date: Date) throws
    func addDrink(amountMl: Int, drinkType: DrinkType, caffeineMg: Double?, date: Date) throws
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

    /// Sum of entries explicitly classified as `.water` (incl. legacy rows where
    /// `drinkType` is nil — those default to water for backward compat).
    func totalWater(on date: Date) throws -> Int {
        try entries(on: date)
            .filter { $0.drinkType == .water }
            .map(\.amountMl)
            .reduce(0, +)
    }

    /// Raw fluid intake across every drink type (no hydration weighting).
    func totalFluid(on date: Date) throws -> Int {
        try entries(on: date).map(\.amountMl).reduce(0, +)
    }

    /// Hydration-weighted total — applies each drink's `hydrationFactor` so
    /// coffee/soda count less toward the water goal than plain water.
    func totalHydrationMl(on date: Date) throws -> Int {
        try entries(on: date).map(\.hydrationMl).reduce(0, +)
    }

    func totalCaffeine(on date: Date) throws -> Double {
        try entries(on: date).compactMap(\.caffeineMg).reduce(0, +)
    }

    func drinksByType(on date: Date) throws -> [DrinkBreakdown] {
        let entries = try entries(on: date)
        let grouped = Dictionary(grouping: entries, by: \.drinkType)
        return DrinkType.allCases.compactMap { type in
            guard let rows = grouped[type], !rows.isEmpty else { return nil }
            let ml = rows.map(\.amountMl).reduce(0, +)
            let caffeine = rows.compactMap(\.caffeineMg).reduce(0, +)
            return DrinkBreakdown(type: type, totalMl: ml, totalCaffeineMg: caffeine)
        }
    }

    func addWater(amountMl: Int, date: Date = Date()) throws {
        // Default add path = plain water. AppIntents and Dashboard still call this.
        try addDrink(amountMl: amountMl, drinkType: .water, caffeineMg: nil, date: date)
    }

    func addDrink(amountMl: Int, drinkType: DrinkType, caffeineMg: Double?, date: Date = Date()) throws {
        context.insert(WaterEntry(date: date, amountMl: amountMl, drinkType: drinkType, caffeineMg: caffeineMg))
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
