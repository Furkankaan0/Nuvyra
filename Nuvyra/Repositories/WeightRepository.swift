import Foundation
import SwiftData

struct WeightTrendSummary {
    var logs: [WeightLog]
    var latestWeightKg: Double?
    var deltaKg: Double
    var projectedGoalDate: Date?

    static let empty = WeightTrendSummary(logs: [], latestWeightKg: nil, deltaKg: 0, projectedGoalDate: nil)
}

/// Per-day body composition snapshot exposed to the UI.
struct BodyMeasurementSnapshot: Equatable {
    var date: Date
    var weightKg: Double?
    var waistCm: Double?
    var hipCm: Double?
    var chestCm: Double?
    var shoulderCm: Double?
    var neckCm: Double?
    var bicepsCm: Double?
    var thighCm: Double?
    var bodyFatPercent: Double?
    var note: String?

    var waistToHipRatio: Double? {
        guard let w = waistCm, let h = hipCm, h > 0 else { return nil }
        return w / h
    }

    static let empty = BodyMeasurementSnapshot(date: Date())
}

extension BodyMeasurementSnapshot {
    init(log: WeightLog) {
        self.init(
            date: log.date,
            weightKg: log.weightKg,
            waistCm: log.waistCm,
            hipCm: log.hipCm,
            chestCm: log.chestCm,
            shoulderCm: log.shoulderCm,
            neckCm: log.neckCm,
            bicepsCm: log.bicepsCm,
            thighCm: log.thighCm,
            bodyFatPercent: log.bodyFatPercent,
            note: log.note
        )
    }
}

@MainActor
protocol WeightRepository {
    func logs(days: Int) throws -> [WeightLog]
    func latestLog() throws -> WeightLog?
    func upsertToday(weightKg: Double, note: String?) throws
    func trendSummary(days: Int, targetWeightKg: Double?) throws -> WeightTrendSummary

    // MARK: - Body composition (added with the body-measurements module)
    func saveBodyMeasurement(_ snapshot: BodyMeasurementSnapshot) throws
    func deleteMeasurement(_ log: WeightLog) throws
    func latestBodyMeasurement() throws -> WeightLog?
    func bodyMeasurementHistory(days: Int) throws -> [WeightLog]
}

@MainActor
final class SwiftDataWeightRepository: WeightRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .nuvyra) {
        self.context = context
        self.calendar = calendar
    }

    func logs(days: Int) throws -> [WeightLog] {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date())) ?? Date()
        let descriptor = FetchDescriptor<WeightLog>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    func latestLog() throws -> WeightLog? {
        var descriptor = FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func upsertToday(weightKg: Double, note: String? = nil) throws {
        let today = calendar.startOfDay(for: Date())
        let (start, end) = calendar.startAndEndOfDay(for: today)
        let descriptor = FetchDescriptor<WeightLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let existing = try context.fetch(descriptor).first {
            existing.weightKg = weightKg
            existing.note = note
            existing.source = "manual"
        } else {
            context.insert(WeightLog(date: today, weightKg: weightKg, source: "manual", note: note))
        }
        try context.save()
    }

    func trendSummary(days: Int, targetWeightKg: Double?) throws -> WeightTrendSummary {
        let items = try logs(days: days)
        guard let latest = items.last else { return .empty }
        let first = items.first?.weightKg ?? latest.weightKg
        let delta = latest.weightKg - first
        return WeightTrendSummary(
            logs: items,
            latestWeightKg: latest.weightKg,
            deltaKg: delta,
            projectedGoalDate: projectedGoalDate(logs: items, targetWeightKg: targetWeightKg)
        )
    }

    private func projectedGoalDate(logs: [WeightLog], targetWeightKg: Double?) -> Date? {
        guard
            logs.count >= 2,
            let targetWeightKg,
            let first = logs.first,
            let latest = logs.last,
            latest.weightKg != targetWeightKg
        else { return nil }

        let elapsedDays = max(calendar.dateComponents([.day], from: first.date, to: latest.date).day ?? 0, 1)
        let dailyChange = (latest.weightKg - first.weightKg) / Double(elapsedDays)
        guard abs(dailyChange) >= 0.01 else { return nil }

        let remaining = targetWeightKg - latest.weightKg
        let projectedDays = remaining / dailyChange
        guard projectedDays > 0, projectedDays.isFinite, projectedDays < 730 else { return nil }

        return calendar.date(byAdding: .day, value: Int(projectedDays.rounded()), to: latest.date)
    }

    // MARK: - Body composition

    /// Upsert a full snapshot — weight stays as the primary axis; circumferences and
    /// body-fat % land on the same day's `WeightLog`. If a log already exists for
    /// the date we mutate it in place so the day has a single canonical row.
    func saveBodyMeasurement(_ snapshot: BodyMeasurementSnapshot) throws {
        let day = calendar.startOfDay(for: snapshot.date)
        let (start, end) = calendar.startAndEndOfDay(for: day)
        let descriptor = FetchDescriptor<WeightLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        if let existing = try context.fetch(descriptor).first {
            if let weight = snapshot.weightKg { existing.weightKg = weight }
            existing.waistCm = snapshot.waistCm ?? existing.waistCm
            existing.hipCm = snapshot.hipCm ?? existing.hipCm
            existing.chestCm = snapshot.chestCm ?? existing.chestCm
            existing.shoulderCm = snapshot.shoulderCm ?? existing.shoulderCm
            existing.neckCm = snapshot.neckCm ?? existing.neckCm
            existing.bicepsCm = snapshot.bicepsCm ?? existing.bicepsCm
            existing.thighCm = snapshot.thighCm ?? existing.thighCm
            existing.bodyFatPercent = snapshot.bodyFatPercent ?? existing.bodyFatPercent
            if let note = snapshot.note { existing.note = note }
            existing.source = "manual"
        } else {
            let latestWeight = try latestLog()?.weightKg
            let weight = snapshot.weightKg ?? latestWeight ?? 0
            let log = WeightLog(
                date: day,
                weightKg: weight,
                source: "manual",
                note: snapshot.note,
                waistCm: snapshot.waistCm,
                hipCm: snapshot.hipCm,
                chestCm: snapshot.chestCm,
                shoulderCm: snapshot.shoulderCm,
                neckCm: snapshot.neckCm,
                bicepsCm: snapshot.bicepsCm,
                thighCm: snapshot.thighCm,
                bodyFatPercent: snapshot.bodyFatPercent
            )
            context.insert(log)
        }
        try context.save()
    }

    func deleteMeasurement(_ log: WeightLog) throws {
        context.delete(log)
        try context.save()
    }

    func latestBodyMeasurement() throws -> WeightLog? {
        var descriptor = FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Last `days` worth of logs that carry **any** body-composition field, oldest first.
    func bodyMeasurementHistory(days: Int) throws -> [WeightLog] {
        try logs(days: days).filter { $0.hasBodyComposition }
    }
}
