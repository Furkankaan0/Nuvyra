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
        case .stationary: "Sakin"
        case .walking: "Yürüyüş"
        case .running: "Koşu"
        case .automotive: "Araçta"
        case .unknown: "Belirsiz"
        }
    }
}

protocol MotionService {
    func todayStepsFallback() async -> Int
    func currentActivityState() async -> MotionActivityState
}

final class LiveMotionService: MotionService {
    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private let calendar: Calendar

    init(calendar: Calendar = .nuvyra) {
        self.calendar = calendar
    }

    func todayStepsFallback() async -> Int {
        guard CMPedometer.isStepCountingAvailable() else { return 0 }
        let start = calendar.startOfDay(for: Date())
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: Date()) { data, _ in
                continuation.resume(returning: data?.numberOfSteps.intValue ?? 0)
            }
        }
    }

    func currentActivityState() async -> MotionActivityState {
        guard CMMotionActivityManager.isActivityAvailable() else { return .unknown }
        let start = Date().addingTimeInterval(-15 * 60)
        return await withCheckedContinuation { continuation in
            activityManager.queryActivityStarting(from: start, to: Date(), to: .main) { activities, _ in
                continuation.resume(returning: activities?.last.map(MotionActivityState.init(activity:)) ?? .unknown)
            }
        }
    }
}

struct MockMotionService: MotionService {
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
