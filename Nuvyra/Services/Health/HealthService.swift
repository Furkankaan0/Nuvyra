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
    func saveNutrition(for meal: MealEntry) async
    func todayWorkouts() async -> [WorkoutEntry]
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
        let shareTypes = nutritionShareTypes()
        guard !readTypes.isEmpty || !shareTypes.isEmpty else { return .unavailable }
        return await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: shareTypes, read: readTypes) { success, _ in
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

    private func nutritionShareTypes() -> Set<HKSampleType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal
        ]
        return Set(identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    func saveNutrition(for meal: MealEntry) async {
        guard isHealthDataAvailable else { return }
        let shareTypes = nutritionShareTypes()
        guard !shareTypes.isEmpty else { return }

        let state = await requestAuthorization()
        guard state == .sharingAuthorized else { return }

        var samples: [HKQuantitySample] = []
        let metadata = [HKMetadataKeyFoodType: meal.name]
        appendSample(
            to: &samples,
            identifier: .dietaryEnergyConsumed,
            value: Double(meal.calories),
            unit: .kilocalorie(),
            date: meal.date,
            metadata: metadata
        )
        appendSample(
            to: &samples,
            identifier: .dietaryProtein,
            value: meal.protein ?? 0,
            unit: .gram(),
            date: meal.date,
            metadata: metadata
        )
        appendSample(
            to: &samples,
            identifier: .dietaryCarbohydrates,
            value: meal.carbs ?? 0,
            unit: .gram(),
            date: meal.date,
            metadata: metadata
        )
        appendSample(
            to: &samples,
            identifier: .dietaryFatTotal,
            value: meal.fat ?? 0,
            unit: .gram(),
            date: meal.date,
            metadata: metadata
        )
        guard !samples.isEmpty else { return }
        let objects = samples.map { $0 as HKObject }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.save(objects) { _, _ in
                continuation.resume()
            }
        }
    }

    private func appendSample(
        to samples: inout [HKQuantitySample],
        identifier: HKQuantityTypeIdentifier,
        value: Double,
        unit: HKUnit,
        date: Date,
        metadata: [String: Any]
    ) {
        guard value > 0, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: unit, doubleValue: value),
            start: date,
            end: date,
            metadata: metadata
        )
        samples.append(sample)
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

    // MARK: - Workouts
    func todayWorkouts() async -> [WorkoutEntry] {
        guard isHealthDataAvailable else { return [] }
        let workoutType = HKObjectType.workoutType()
        let (start, end) = calendar.startAndEndOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let samples: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 32, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        return samples.map { workout in
            let kcal: Int
            if let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                kcal = Int(energy.rounded())
            } else {
                kcal = 0
            }
            let distanceKm: Double? = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
                ?? workout.statistics(for: HKQuantityType(.distanceCycling))?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
                ?? workout.statistics(for: HKQuantityType(.distanceSwimming))?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
            return WorkoutEntry(
                id: workout.uuid,
                date: workout.startDate,
                type: WorkoutType.from(activity: workout.workoutActivityType),
                durationMinutes: Int((workout.duration / 60).rounded()),
                caloriesBurned: kcal,
                distanceKm: distanceKm,
                note: nil,
                source: .healthKit
            )
        }
    }
}

struct MockHealthService: HealthService {
    var snapshot: HealthSnapshot = HealthSnapshot(steps: 5_360, activeEnergy: 280, distanceKm: 3.8, authorizationStatus: .sharingAuthorized, source: .healthKit)
    var workouts: [WorkoutEntry] = []
    var isHealthDataAvailable: Bool { true }
    func requestAuthorization() async -> HealthAuthorizationState { snapshot.authorizationStatus }
    func todaySnapshot() async -> HealthSnapshot { snapshot }
    func saveNutrition(for meal: MealEntry) async {}
    func todayWorkouts() async -> [WorkoutEntry] { workouts }
}

private extension WorkoutType {
    /// Map HealthKit's exhaustive `HKWorkoutActivityType` to the smaller user-facing buckets.
    static func from(activity: HKWorkoutActivityType) -> WorkoutType {
        switch activity {
        case .running, .crossTraining: .running
        case .cycling, .handCycling: .cycling
        case .swimming, .waterSports: .swimming
        case .walking, .hiking: .walking
        case .highIntensityIntervalTraining, .mixedCardio, .stairClimbing, .stairs, .stepTraining: .hiit
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: .gym
        case .yoga, .mindAndBody, .flexibility: .yoga
        case .pilates, .barre: .pilates
        case .soccer, .basketball, .volleyball, .americanFootball, .baseball, .hockey, .rugby, .tennis, .badminton, .tableTennis, .racquetball, .squash, .cricket: .sports
        default: .other
        }
    }
}
