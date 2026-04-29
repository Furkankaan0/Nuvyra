import Foundation
import HealthKit

struct HealthSnapshot: Equatable {
    var steps: Int
    var activeEnergy: Double
    var distanceKm: Double?
    var authorizationStatus: HealthAuthorizationState
    var source: HealthDataSource

    static let fallback = HealthSnapshot(steps: 0, activeEnergy: 0, distanceKm: nil, authorizationStatus: .notDetermined, source: .manualFallback)
}

enum HealthAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case sharingAuthorized
    case sharingDenied
}

enum HealthDataSource: String, Equatable {
    case healthKit
    case coreMotion
    case manualFallback
}

protocol HealthService {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async -> HealthAuthorizationState
    func todaySnapshot() async -> HealthSnapshot
}

final class LiveHealthService: HealthService {
    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .nuvyra) {
        self.calendar = calendar
    }

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> HealthAuthorizationState {
        guard isHealthDataAvailable else { return .unavailable }
        let readTypes = quantityTypes()
        guard !readTypes.isEmpty else { return .unavailable }
        return await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes) { success, _ in
                continuation.resume(returning: success ? .sharingAuthorized : .sharingDenied)
            }
        }
    }

    func todaySnapshot() async -> HealthSnapshot {
        guard isHealthDataAvailable else { return .fallback }
        async let steps = cumulativeValue(for: .stepCount, unit: .count())
        async let energy = cumulativeValue(for: .activeEnergyBurned, unit: .kilocalorie())
        async let distance = cumulativeValue(for: .distanceWalkingRunning, unit: .meterUnit(with: .kilo))
        let stepValue = await steps ?? 0
        let energyValue = await energy ?? 0
        let distanceValue = await distance
        return HealthSnapshot(
            steps: Int(stepValue.rounded()),
            activeEnergy: energyValue,
            distanceKm: distanceValue,
            authorizationStatus: .sharingAuthorized,
            source: .healthKit
        )
    }

    private func quantityTypes() -> Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned, .distanceWalkingRunning]
        return Set(identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    private func cumulativeValue(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let (start, end) = calendar.startAndEndOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}

struct MockHealthService: HealthService {
    var snapshot: HealthSnapshot = HealthSnapshot(steps: 5_360, activeEnergy: 280, distanceKm: 3.8, authorizationStatus: .sharingAuthorized, source: .healthKit)
    var isHealthDataAvailable: Bool { true }
    func requestAuthorization() async -> HealthAuthorizationState { snapshot.authorizationStatus }
    func todaySnapshot() async -> HealthSnapshot { snapshot }
}
