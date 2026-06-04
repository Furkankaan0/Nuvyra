import Foundation
import HealthKit

/// Sleep + resting heart rate read-only bridge. Lives next to
/// `HealthService` instead of inside it because:
///   1. The auth prompt is separate — we don't want the existing
///      reminders/steps flow to request sleep on day one.
///   2. The values are surfaced on a dedicated card and most callers
///      only want one of the two metrics; a focused service is
///      simpler to depend on than a fat one.
struct NuvyraVitalsSnapshot: Equatable, Sendable {
    /// Hours of "in bed or asleep" for last night, rounded to one
    /// decimal so the card can render "7,5 sa" cleanly.
    var lastNightHours: Double?
    /// Resting heart rate (bpm) for the last available day.
    var restingHeartRate: Int?

    static let empty = NuvyraVitalsSnapshot(lastNightHours: nil, restingHeartRate: nil)
}

@MainActor
protocol NuvyraVitalsService {
    func requestAuthorization() async -> Bool
    func snapshot() async -> NuvyraVitalsSnapshot
}

@MainActor
final class LiveNuvyraVitalsService: NuvyraVitalsService {
    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .nuvyra) {
        self.calendar = calendar
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let reads = readTypes()
        return await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: [], read: reads) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func snapshot() async -> NuvyraVitalsSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else { return .empty }
        async let sleep = sleepHoursLastNight()
        async let rhr = restingHeartRateLatest()
        return NuvyraVitalsSnapshot(lastNightHours: await sleep, restingHeartRate: await rhr)
    }

    // MARK: - Auth types

    private func readTypes() -> Set<HKObjectType> {
        var set: Set<HKObjectType> = []
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            set.insert(sleep)
        }
        if let rhr = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            set.insert(rhr)
        }
        return set
    }

    // MARK: - Sleep

    /// Last night = the window from yesterday 18:00 to today 12:00.
    /// We intentionally start before midnight and end mid-day so naps
    /// don't get mistaken for the user's main sleep block.
    private func sleepHoursLastNight() async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let now = Date()
        let endHour = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let yesterdayEvening = calendar.date(byAdding: .day, value: -1, to: now).flatMap {
            calendar.date(bySettingHour: 18, minute: 0, second: 0, of: $0)
        } ?? now
        let predicate = HKQuery.predicateForSamples(withStart: yesterdayEvening, end: endHour, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        // iOS 16+ ships granular HKCategoryValueSleepAnalysis cases
        // (asleepCore, asleepDeep, asleepREM). Older Watch / iPhone
        // pairs only report .asleep. We count any "asleep*" state and
        // skip "inBed" so naps with no asleep state don't inflate the
        // number.
        let asleepValues: Set<Int> = {
            var values: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue]
            values.insert(HKCategoryValueSleepAnalysis.asleepCore.rawValue)
            values.insert(HKCategoryValueSleepAnalysis.asleepDeep.rawValue)
            values.insert(HKCategoryValueSleepAnalysis.asleepREM.rawValue)
            return values
        }()
        let totalSeconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        guard totalSeconds > 0 else { return nil }
        let hours = totalSeconds / 3600
        return (hours * 10).rounded() / 10  // one decimal
    }

    // MARK: - Resting heart rate

    /// Most recent resting heart rate in the last 7 days. HealthKit
    /// computes RHR daily on Apple Watch — querying for "today" alone
    /// often returns nothing during the morning before the daily
    /// rollup. The 7-day window gives us a fresh value even on quiet
    /// mornings.
    private func restingHeartRateLatest() async -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
        guard let latest = samples.first else { return nil }
        let bpm = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        return Int(bpm.rounded())
    }
}

/// Static stub used by SwiftUI previews + unit tests. Returns a
/// realistic-looking snapshot by default so the dashboard card has
/// data in previews.
@MainActor
final class MockNuvyraVitalsService: NuvyraVitalsService {
    var snapshotValue: NuvyraVitalsSnapshot = NuvyraVitalsSnapshot(lastNightHours: 7.4, restingHeartRate: 62)
    func requestAuthorization() async -> Bool { true }
    func snapshot() async -> NuvyraVitalsSnapshot { snapshotValue }
}
