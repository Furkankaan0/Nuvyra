import Combine
import Foundation
import SwiftData

@MainActor
final class WalkingViewModel: ObservableObject {
    @Published var snapshot = HealthSnapshot.fallback
    @Published var logs: [WalkingLog] = []
    @Published var averageSteps = 0
    @Published var completionRate = 0.0
    @Published var profile: UserProfile?
    @Published var motionState: MotionActivityState = .unknown
    @Published var walkingFocusActive = false
    @Published var walkingFocusStartedAt: Date?
    @Published var selectedDate: Date = Date()
    private var didPlayGoalHaptic = false
    private var didPlayHalfwayHaptic = false

    var stepGoal: Int { profile?.dailyStepTarget ?? 7_500 }
    var remainingSteps: Int { max(stepGoal - snapshot.steps, 0) }
    var isViewingToday: Bool { Calendar.nuvyra.isDateInToday(selectedDate) }
    var streak: Int { logs.reversed().prefix { $0.goalCompleted }.count }
    var focusElapsedMinutes: Int {
        guard let walkingFocusStartedAt else { return 0 }
        return max(Int(Date().timeIntervalSince(walkingFocusStartedAt) / 60), 0)
    }

    var insight: String {
        if walkingFocusActive {
            return "Yürüyüş odağı açık. Kilit ekranından ritmini izleyebilirsin."
        }
        if !isViewingToday {
            return "Bu günün yürüyüş ritmini inceliyorsun. Geçmiş günleri görmek, hedeflerini gerçek hayata göre ayarlamana yardımcı olur."
        }
        if motionState == .automotive {
            return "Şu an araç hareketi algılanıyor. Yürüyüş önerisini daha sakin bir zamana bırakalım."
        }
        if motionState == .walking, remainingSteps > 0 {
            return "Yürüyüş ritmi algılandı. Bu tempoyla hedefe yaklaşman daha kolay."
        }
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
            let repository = dependencies.activityRepository(context: context)
            if isViewingToday {
                snapshot = await dependencies.healthService.todaySnapshot()
            } else if let log = try repository.walkingLog(on: selectedDate) {
                snapshot = HealthSnapshot(steps: log.steps, activeEnergy: log.activeEnergy, distanceKm: log.distanceKm, authorizationStatus: .sharingDenied, source: .manualFallback)
            } else {
                snapshot = HealthSnapshot(steps: 0, activeEnergy: 0, distanceKm: nil, authorizationStatus: .sharingDenied, source: .manualFallback)
            }
            if isViewingToday, snapshot.steps == 0 {
                let fallbackSteps = await dependencies.motionService.todayStepsFallback()
                snapshot = HealthSnapshot(steps: fallbackSteps, activeEnergy: 0, distanceKm: nil, authorizationStatus: .sharingDenied, source: .coreMotion)
            }
            motionState = await dependencies.motionService.currentActivityState()
            if isViewingToday {
                try repository.upsertWalkingSnapshot(date: selectedDate, steps: snapshot.steps, activeEnergy: snapshot.activeEnergy, distanceKm: snapshot.distanceKm, goal: stepGoal)
            }
            logs = try repository.walkingLogs(days: 7, endingOn: selectedDate)
            averageSteps = try repository.averageSteps(days: 3, endingOn: selectedDate)
            completionRate = try repository.completionRate(days: 7, endingOn: selectedDate, goal: stepGoal)
            walkingFocusActive = dependencies.walkingLiveActivityService.isActive
            if walkingFocusActive {
                await dependencies.walkingLiveActivityService.update(steps: snapshot.steps, goal: stepGoal, elapsedMinutes: focusElapsedMinutes)
            }
            if isViewingToday, snapshot.steps >= stepGoal / 2, snapshot.steps < stepGoal, !didPlayHalfwayHaptic {
                didPlayHalfwayHaptic = true
                dependencies.haptics.walkingHalfwayReached()
            } else if snapshot.steps < stepGoal / 2 {
                didPlayHalfwayHaptic = false
            }
            if isViewingToday, snapshot.steps >= stepGoal, !didPlayGoalHaptic {
                didPlayGoalHaptic = true
                dependencies.haptics.goalCompleted()
            } else if snapshot.steps < stepGoal {
                didPlayGoalHaptic = false
            }
        } catch {}
    }

    func changeDate(to date: Date, context: ModelContext, dependencies: DependencyContainer) {
        selectedDate = date
        Task { await load(context: context, dependencies: dependencies) }
    }

    func startWalkingFocus(dependencies: DependencyContainer) async {
        walkingFocusStartedAt = Date()
        walkingFocusActive = true
        await dependencies.walkingLiveActivityService.start(goal: stepGoal, initialSteps: snapshot.steps)
        dependencies.haptics.walkStarted()
    }

    func endWalkingFocus(dependencies: DependencyContainer) async {
        await dependencies.walkingLiveActivityService.end(finalSteps: snapshot.steps, goal: stepGoal)
        walkingFocusActive = false
        walkingFocusStartedAt = nil
    }
}
