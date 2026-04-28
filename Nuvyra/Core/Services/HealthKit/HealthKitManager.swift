import Foundation
import HealthKit

enum HealthAuthorizationStatus: String, Codable, Equatable {
    case unavailable
    case granted
    case denied
}

enum HealthKitManagerError: LocalizedError {
    case healthDataUnavailable
    case stepTypeUnavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable: "Apple Sağlık verisi bu cihazda kullanılamıyor."
        case .stepTypeUnavailable: "Adım verisi bu cihazda okunamıyor."
        case .authorizationDenied: "Adım izni verilmedi. İstersen Ayarlar'dan daha sonra açabilirsin."
        }
    }
}

protocol HealthKitManaging {
    var isHealthDataAvailable: Bool { get }
    func requestStepAuthorization() async -> HealthAuthorizationStatus
    func fetchTodaySteps() async throws -> Int
    func fetchStepHistory(days: Int) async throws -> [StepHistoryDay]
}

final class HealthKitManager: HealthKitManaging {
    private let healthStore = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestStepAuthorization() async -> HealthAuthorizationStatus {
        guard isHealthDataAvailable else { return .unavailable }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return .unavailable }

        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: Set<HKObjectType>([stepType])) { success, _ in
                continuation.resume(returning: success ? .granted : .denied)
            }
        }
    }

    func fetchTodaySteps() async throws -> Int {
        let start = calendar.startOfDay(for: Date())
        return try await fetchSteps(from: start, to: Date())
    }

    func fetchStepHistory(days: Int) async throws -> [StepHistoryDay] {
        guard days > 0 else { return [] }
        var history: [StepHistoryDay] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            let steps = try await fetchSteps(from: start, to: min(end, Date()))
            history.append(StepHistoryDay(date: start, steps: steps, goal: 6_500))
        }
        return history
    }

    private func fetchSteps(from start: Date, to end: Date) async throws -> Int {
        guard isHealthDataAvailable else { throw HealthKitManagerError.healthDataUnavailable }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { throw HealthKitManagerError.stepTypeUnavailable }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps.rounded()))
            }
            healthStore.execute(query)
        }
    }
}

struct PreviewHealthKitManager: HealthKitManaging {
    var isHealthDataAvailable: Bool { true }
    func requestStepAuthorization() async -> HealthAuthorizationStatus { .granted }
    func fetchTodaySteps() async throws -> Int { StepSnapshot.preview.steps }
    func fetchStepHistory(days: Int) async throws -> [StepHistoryDay] { StepHistoryDay.sampleWeek }
}

