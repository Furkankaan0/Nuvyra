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
