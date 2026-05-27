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

/// Deterministic active-energy provider for previews and unit tests.
struct MockActiveEnergyService: ActiveEnergyService {
    var caloriesToReturn: Double = 280
    func todayActiveEnergy() async -> Double { caloriesToReturn }
}
