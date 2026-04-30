import Foundation
import SwiftData

@MainActor
protocol WaterRepository {
    func entries(on date: Date) throws -> [WaterEntry]
    func totalWater(on date: Date) throws -> Int
    /// Inserts a water entry and returns the new daily total. Returning
    /// the post-write value lets the view model update its UI state
    /// atomically — no second `load()` round-trip, no race window.
    @discardableResult
    func addWater(amountMl: Int, date: Date) throws -> Int
}

@MainActor
final class SwiftDataWaterRepository: WaterRepository {
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

    @discardableResult
    func addWater(amountMl: Int, date: Date = Date()) throws -> Int {
        // Insert + same-transaction total recompute so the returned
        // value is guaranteed to include this write. Without the post-
        // save fetch, callers would have to re-query and might race
        // with another concurrent reader.
        context.insert(WaterEntry(date: date, amountMl: amountMl))
        try context.save()
        let total = try totalWater(on: date)
        onMutate?()
        return total
    }
}
