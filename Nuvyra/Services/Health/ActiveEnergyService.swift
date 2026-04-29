import Foundation

protocol ActiveEnergyService {
    func todayActiveEnergy() async -> Double
}

struct LiveActiveEnergyService: ActiveEnergyService {
    let healthService: HealthService

    func todayActiveEnergy() async -> Double {
        await healthService.todaySnapshot().activeEnergy
    }
}
