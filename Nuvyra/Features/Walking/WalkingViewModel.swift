import Foundation
import SwiftData

@MainActor
final class WalkingViewModel: ObservableObject {
    @Published var snapshot = HealthSnapshot.fallback
    @Published var logs: [WalkingLog] = []
    @Published var averageSteps = 0
    @Published var completionRate = 0.0
    @Published var profile: UserProfile?

    var stepGoal: Int { profile?.dailyStepTarget ?? 7_500 }
    var remainingSteps: Int { max(stepGoal - snapshot.steps, 0) }
    var streak: Int { logs.reversed().prefix { $0.goalCompleted }.count }

    var insight: String {
        if averageSteps > 0, averageSteps < stepGoal {
            return "Son 3 gün ortalaman hedefinin altında. Bugün 12 dakikalık kısa bir yürüyüş ritmini toparlayabilir."
        }
        if remainingSteps == 0 {
            return "Bugün hedefini tamamladın. Devamlılık, fazladan zorlamaktan daha değerli."
        }
        return "Hedefe \(remainingSteps.formatted()) adım kaldı. Kısa ve sakin bir yürüyüş yeterli olabilir."
    }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            profile = try dependencies.userRepository(context: context).profile()
            snapshot = await dependencies.healthService.todaySnapshot()
            if snapshot.steps == 0 {
                let fallbackSteps = await dependencies.motionService.todayStepsFallback()
                snapshot = HealthSnapshot(steps: fallbackSteps, activeEnergy: 0, distanceKm: nil, authorizationStatus: .sharingDenied, source: .coreMotion)
            }
            let repository = dependencies.activityRepository(context: context)
            try repository.upsertWalkingSnapshot(date: Date(), steps: snapshot.steps, activeEnergy: snapshot.activeEnergy, distanceKm: snapshot.distanceKm, goal: stepGoal)
            logs = try repository.walkingLogs(days: 7)
            averageSteps = try repository.averageSteps(days: 3)
            completionRate = try repository.completionRate(days: 7, goal: stepGoal)
        } catch {}
    }
}
