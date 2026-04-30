import CoreMotion
import Foundation

enum MotionActivityState: String, Codable, Equatable {
    case stationary
    case walking
    case running
    case automotive
    case unknown

    var title: String {
        switch self {
        case .stationary: return "Sakin"
        case .walking: return "Yürüyüş"
        case .running: return "Koşu"
        case .automotive: return "Araçta"
        case .unknown: return "Belirsiz"
        }
    }
}

/// Mirrors `CMAuthorizationStatus` but uses our own labels so the UI never
/// has to import CoreMotion. We additionally distinguish "device doesn't
/// have a motion coprocessor" from a normal not-yet-asked state, which
/// CoreMotion lumps together as `notDetermined`.
enum MotionAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied
    case restricted

    var isUsable: Bool {
        switch self {
        case .authorized: return true
        case .unavailable, .notDetermined, .denied, .restricted: return false
        }
    }

    var bannerTitle: String? {
        switch self {
        case .authorized, .notDetermined: return nil
        case .unavailable: return "Hareket sensörü yok"
        case .denied: return "Hareket izni gerekli"
        case .restricted: return "Hareket izni kısıtlı"
        }
    }

    var bannerMessage: String? {
        switch self {
        case .authorized, .notDetermined:
            return nil
        case .unavailable:
            return "Bu cihazda hareket koprosesörü bulunmuyor; adımlar manuel modda ilerler."
        case .denied:
            return "Adım yedeği için Ayarlar > Gizlilik ve Güvenlik > Hareket ve Fitness'tan Nuvyra'ya izin verebilirsin."
        case .restricted:
            return "Bu cihazda hareket verisi yönetici tarafından kısıtlanmış."
        }
    }
}

protocol MotionService {
    /// Latest known authorization state. Cheap to read; updated by
    /// `todayStepsFallback` and `currentActivityState` based on the
    /// underlying CoreMotion errors.
    var authorizationState: MotionAuthorizationState { get }
    func todayStepsFallback() async -> Int
    func currentActivityState() async -> MotionActivityState
}

final class LiveMotionService: MotionService {
    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private let calendar: Calendar
    private let queue = DispatchQueue(label: "com.nuvyra.motion.auth")
    private var _authorizationState: MotionAuthorizationState

    init(calendar: Calendar = .nuvyra) {
        self.calendar = calendar
        // Seed from CMPedometer's static authorizationStatus before the
        // first query — keeps the UI accurate on cold launch.
        self._authorizationState = LiveMotionService.currentSystemAuthorization()
    }

    var authorizationState: MotionAuthorizationState {
        queue.sync { _authorizationState }
    }

    func todayStepsFallback() async -> Int {
        guard CMPedometer.isStepCountingAvailable() else {
            updateAuthorization(.unavailable)
            return 0
        }
        let start = calendar.startOfDay(for: Date())
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: Date()) { [weak self] data, error in
                if let error {
                    self?.updateAuthorization(LiveMotionService.classify(error: error))
                    continuation.resume(returning: 0)
                    return
                }
                self?.updateAuthorization(.authorized)
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }

    func currentActivityState() async -> MotionActivityState {
        guard CMMotionActivityManager.isActivityAvailable() else {
            updateAuthorization(.unavailable)
            return .unknown
        }
        let start = Date().addingTimeInterval(-15 * 60)
        return await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: start, to: Date(), to: .main) { [weak self] activities, error in
                if let error {
                    self?.updateAuthorization(LiveMotionService.classify(error: error))
                    continuation.resume(returning: .unknown)
                    return
                }
                self?.updateAuthorization(.authorized)
                continuation.resume(returning: activities?.last.map(MotionActivityState.init(activity:)) ?? .unknown)
            }
        }
    }

    // MARK: - Helpers

    private func updateAuthorization(_ newState: MotionAuthorizationState) {
        queue.sync { _authorizationState = newState }
    }

    private static func currentSystemAuthorization() -> MotionAuthorizationState {
        guard CMPedometer.isStepCountingAvailable() else { return .unavailable }
        switch CMPedometer.authorizationStatus() {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    /// Maps CoreMotion errors to our authorization state. The numeric
    /// codes below come from `CMError` in `<CoreMotion/CMError.h>` and
    /// have been stable since iOS 11. We compare integers directly to
    /// avoid depending on Swift's private bridging into the CMError enum.
    private enum CoreMotionErrorCode {
        static let motionActivityNotAvailable = 104
        static let motionActivityNotAuthorized = 105
        static let motionActivityNotEntitled = 106
        static let notAvailable = 109
        static let notEntitled = 110
    }

    private static func classify(error: Error) -> MotionAuthorizationState {
        let nsError = error as NSError
        guard nsError.domain == CMErrorDomain else { return .denied }
        switch nsError.code {
        case CoreMotionErrorCode.motionActivityNotAuthorized:
            return .denied
        case CoreMotionErrorCode.motionActivityNotEntitled,
             CoreMotionErrorCode.notEntitled:
            return .restricted
        case CoreMotionErrorCode.motionActivityNotAvailable,
             CoreMotionErrorCode.notAvailable:
            return .unavailable
        default:
            return .denied
        }
    }
}

struct MockMotionService: MotionService {
    var authorizationState: MotionAuthorizationState = .authorized
    var steps: Int = 4_200
    var activityState: MotionActivityState = .walking

    func todayStepsFallback() async -> Int { steps }
    func currentActivityState() async -> MotionActivityState { activityState }
}

private extension MotionActivityState {
    init(activity: CMMotionActivity) {
        if activity.automotive {
            self = .automotive
        } else if activity.running {
            self = .running
        } else if activity.walking {
            self = .walking
        } else if activity.stationary {
            self = .stationary
        } else {
            self = .unknown
        }
    }
}
