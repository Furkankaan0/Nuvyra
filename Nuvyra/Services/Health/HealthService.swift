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

/// Errors that the UI needs to be able to react to. We deliberately keep
/// the surface narrow — a "permission" / "unavailable" / "transient
/// failure" trichotomy is enough to drive copy + a settings deep-link.
enum HealthServiceError: LocalizedError, Equatable {
    /// HealthKit is not available on this device (e.g. iPad without
    /// HealthKit capability).
    case unavailable
    /// The user has not yet been asked, or has denied, sharing.
    case notAuthorized
    /// Query ran but failed for a transient reason. Retryable.
    case queryFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Bu cihazda Apple Sağlık verisi okunamıyor. Manuel mod kullanılacak."
        case .notAuthorized:
            return "Sağlık verisi izni gerekli. Ayarlar'dan Apple Sağlık iznini etkinleştirebilirsin."
        case .queryFailed:
            return "Sağlık verisi okunamadı. Tekrar denemeyi sağla."
        }
    }

    /// Short, action-oriented copy for inline UI banners.
    var bannerTitle: String {
        switch self {
        case .unavailable: return "Manuel mod"
        case .notAuthorized: return "İzin gerekli"
        case .queryFailed: return "Bağlantı sorunu"
        }
    }
}

protocol HealthService {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async -> HealthAuthorizationState
    /// Legacy convenience: returns a snapshot or `.fallback` on any error,
    /// matching the original API. New callers should prefer
    /// `loadTodaySnapshot()` so they can show a proper error state.
    func todaySnapshot() async -> HealthSnapshot
    /// Result-style today snapshot — tells the caller exactly *why* a
    /// snapshot couldn't be produced, so the UI can show targeted copy.
    func loadTodaySnapshot() async -> Result<HealthSnapshot, HealthServiceError>
    /// Subscribe to background step / active-energy updates from Apple
    /// Health. The handler runs on an arbitrary thread; callers must hop
    /// to MainActor before touching SwiftData. Returns a token that, when
    /// dropped, cancels the underlying queries.
    func startObservingTodayChanges(_ handler: @escaping @Sendable () -> Void) -> HealthObservationToken
}

/// Opaque cancellation handle. The underlying observer queries stay alive
/// for the lifetime of the token; dropping it tears them down.
final class HealthObservationToken {
    private let onCancel: () -> Void
    private var isCancelled = false

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        onCancel()
    }

    deinit { cancel() }
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
        switch await loadTodaySnapshot() {
        case .success(let snapshot):
            return snapshot
        case .failure:
            return .fallback
        }
    }

    func loadTodaySnapshot() async -> Result<HealthSnapshot, HealthServiceError> {
        guard isHealthDataAvailable else { return .failure(.unavailable) }
        guard !quantityTypes().isEmpty else { return .failure(.unavailable) }
        // Authorization status for `read` permissions is not directly
        // queryable in iOS — `authorizationStatus(for:)` only reflects
        // share permissions. We instead let the query execute; if every
        // sum comes back nil with a permission error, we surface
        // `.notAuthorized`.
        do {
            async let steps = cumulativeValueOrThrow(for: .stepCount, unit: .count())
            async let energy = cumulativeValueOrThrow(for: .activeEnergyBurned, unit: .kilocalorie())
            async let distance = cumulativeValueOrThrow(for: .distanceWalkingRunning, unit: .meterUnit(with: .kilo))
            let stepValue = try await steps
            let energyValue = try await energy
            let distanceValue = try await distance
            return .success(
                HealthSnapshot(
                    steps: Int((stepValue ?? 0).rounded()),
                    activeEnergy: energyValue ?? 0,
                    distanceKm: distanceValue,
                    authorizationStatus: .sharingAuthorized,
                    source: .healthKit
                )
            )
        } catch let error as HealthServiceError {
            return .failure(error)
        } catch {
            return .failure(.queryFailed(message: error.localizedDescription))
        }
    }

    // MARK: - Background observers

    func startObservingTodayChanges(_ handler: @escaping @Sendable () -> Void) -> HealthObservationToken {
        guard isHealthDataAvailable else {
            return HealthObservationToken(onCancel: {})
        }
        let identifiers: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned, .distanceWalkingRunning]
        var queries: [HKObserverQuery] = []
        for identifier in identifiers {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completionHandler, _ in
                handler()
                // Tell HealthKit we processed this update so it can stop
                // launching us in the background until the next change.
                completionHandler()
            }
            store.execute(query)
            queries.append(query)
            // `enableBackgroundDelivery` tells iOS to wake the app when
            // new samples land — including from a paired Apple Watch.
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in
                // Failures here usually mean the user denied background
                // delivery for this type. The observer will still fire
                // while the app is foregrounded, so we don't surface
                // this error.
            }
        }
        let store = self.store
        return HealthObservationToken {
            for query in queries { store.stop(query) }
        }
    }

    // MARK: - Helpers

    private func quantityTypes() -> Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned, .distanceWalkingRunning]
        return Set(identifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    /// Variant that throws so the parent can distinguish "no data" (nil
    /// statistics) from "permission denied" (an actual error).
    private func cumulativeValueOrThrow(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let (start, end) = calendar.startAndEndOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain,
                       nsError.code == HKError.errorAuthorizationDenied.rawValue
                        || nsError.code == HKError.errorAuthorizationNotDetermined.rawValue {
                        continuation.resume(throwing: HealthServiceError.notAuthorized)
                    } else {
                        continuation.resume(throwing: HealthServiceError.queryFailed(message: error.localizedDescription))
                    }
                    return
                }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}

struct MockHealthService: HealthService {
    var snapshot: HealthSnapshot = HealthSnapshot(steps: 5_360, activeEnergy: 280, distanceKm: 3.8, authorizationStatus: .sharingAuthorized, source: .healthKit)
    var error: HealthServiceError? = nil
    var isHealthDataAvailable: Bool { true }
    func requestAuthorization() async -> HealthAuthorizationState { snapshot.authorizationStatus }
    func todaySnapshot() async -> HealthSnapshot {
        if error != nil { return .fallback }
        return snapshot
    }
    func loadTodaySnapshot() async -> Result<HealthSnapshot, HealthServiceError> {
        if let error { return .failure(error) }
        return .success(snapshot)
    }
    func startObservingTodayChanges(_ handler: @escaping @Sendable () -> Void) -> HealthObservationToken {
        HealthObservationToken(onCancel: {})
    }
}
