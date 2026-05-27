import Foundation

protocol StepCountService {
    func todaySteps() async -> Int
}

struct LiveStepCountService: StepCountService {
    let healthService: HealthService
    let motionService: MotionService

    func todaySteps() async -> Int {
        let health = await healthService.todaySnapshot()
        if health.steps > 0 { return health.steps }
        return await motionService.todayStepsFallback()
    }
}

/// Deterministic step counter for previews and unit tests. Keeps SwiftUI
/// previews out of HealthKit so they don't trigger authorization prompts.
struct MockStepCountService: StepCountService {
    var stepsToReturn: Int = 5_360
    func todaySteps() async -> Int { stepsToReturn }
}
