import CoreMotion
import Foundation

protocol MotionService {
    func todayStepsFallback() async -> Int
}

final class LiveMotionService: MotionService {
    private let pedometer = CMPedometer()
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
}

struct MockMotionService: MotionService {
    var steps: Int = 4_200
    func todayStepsFallback() async -> Int { steps }
}
