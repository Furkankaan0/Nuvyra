import Foundation
import SwiftData

@MainActor
protocol WaterRepository {
    func entries(on date: Date) throws -> [WaterEntry]
    func totalWater(on date: Date) throws -> Int
    func addWater(amountMl: Int, date: Date) throws
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
}
