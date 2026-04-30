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
    @Published var healthError: HealthServiceError?
    @Published var motionAuthorization: MotionAuthorizationState = .authorized
    private var didPlayGoalHaptic = false
    /// Periodic refresh task that pushes HealthKit step deltas into the
    /// Live Activity while a walking focus is running and the app is in
    /// the foreground. Background updates would require either an
    /// `HKObserverQuery` with `enableBackgroundDelivery` or push-token
    /// updates via APNs — both intentionally out of scope for the MVP.
    private var liveActivityRefreshTask: Task<Void, Never>?

    var stepGoal: Int { profile?.dailyStepTarget ?? 7_500 }
    var remainingSteps: Int { max(stepGoal - snapshot.steps, 0) }
    var streak: Int { logs.reversed().prefix { $0.goalCompleted }.count }
    var focusElapsedMinutes: Int {
        guard let walkingFocusStartedAt else { return 0 }
        return max(Int(Date().timeIntervalSince(walkingFocusStartedAt) / 60), 0)
    }

    /// Surfaced as a banner above the step card when HealthKit or
    /// CoreMotion can't deliver live data.
    var dataIssueBanner: DataIssueBanner? {
        if let healthError {
            let action: DataIssueBanner.Action
            switch healthError {
            case .notAuthorized: action = .openSettings
            case .unavailable: action = .none
            case .queryFailed: action = .retry
            }
            return DataIssueBanner(
                icon: "heart.text.square",
                title: healthError.bannerTitle,
                message: healthError.errorDescription ?? "",
                action: action
            )
        }
        if motionAuthorization == .denied || motionAuthorization == .restricted {
            return DataIssueBanner(
                icon: "figure.walk.motion",
                title: motionAuthorization.bannerTitle ?? "Hareket izni",
                message: motionAuthorization.bannerMessage ?? "",
                action: .openSettings
            )
        }
        return nil
    }

    var insight: String {
        if walkingFocusActive {
            return "Yürüyüş odağı açık. Kilit ekranından ritmini izleyebilirsin."
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
        profile = (try? dependencies.userRepository(context: context).profile())

        // Try HealthKit first, fall back to CoreMotion only when HealthKit
        // can't talk to us (so a real "0 steps" reading is preserved).
        switch await dependencies.healthService.loadTodaySnapshot() {
        case .success(let healthSnapshot):
            snapshot = healthSnapshot
            healthError = nil
        case .failure(let error):
            healthError = error
            let fallbackSteps = await dependencies.motionService.todayStepsFallback()
            motionAuthorization = dependencies.motionService.authorizationState
            snapshot = HealthSnapshot(
                steps: fallbackSteps,
                activeEnergy: 0,
                distanceKm: nil,
                authorizationStatus: error == .notAuthorized ? .sharingDenied : .notDetermined,
                source: fallbackSteps > 0 ? .coreMotion : .manualFallback
            )
        }

        motionState = await dependencies.motionService.currentActivityState()
        motionAuthorization = dependencies.motionService.authorizationState

        let repository = dependencies.activityRepository(context: context)
        do {
            try repository.upsertWalkingSnapshot(
                date: Date(),
                steps: snapshot.steps,
                activeEnergy: snapshot.activeEnergy,
                distanceKm: snapshot.distanceKm,
                goal: stepGoal
            )
            logs = try repository.walkingLogs(days: 7)
            averageSteps = try repository.averageSteps(days: 3)
            completionRate = try repository.completionRate(days: 7, goal: stepGoal)
        } catch {
            // SwiftData read/write failures are non-fatal here — keep the
            // previous in-memory values so the UI doesn't blank out.
        }

        walkingFocusActive = dependencies.walkingLiveActivityService.isActive
        if walkingFocusActive {
            await dependencies.walkingLiveActivityService.update(
                steps: snapshot.steps,
                goal: stepGoal,
                elapsedMinutes: focusElapsedMinutes
            )
        }
        if snapshot.steps >= stepGoal, !didPlayGoalHaptic {
            didPlayGoalHaptic = true
            dependencies.haptics.goalCompleted()
        } else if snapshot.steps < stepGoal {
            didPlayGoalHaptic = false
        }
    }

    /// Banner-bound retry that re-runs `load(...)`.
    func retryHealth(context: ModelContext, dependencies: DependencyContainer) async {
        await load(context: context, dependencies: dependencies)
    }

    func startWalkingFocus(dependencies: DependencyContainer) async {
        walkingFocusStartedAt = Date()
        walkingFocusActive = true
        await dependencies.walkingLiveActivityService.start(goal: stepGoal, initialSteps: snapshot.steps)
        dependencies.haptics.walkStarted()
        startLiveActivityRefreshLoop(dependencies: dependencies)
    }

    func endWalkingFocus(dependencies: DependencyContainer) async {
        liveActivityRefreshTask?.cancel()
        liveActivityRefreshTask = nil
        await dependencies.walkingLiveActivityService.end(finalSteps: snapshot.steps, goal: stepGoal)
        walkingFocusActive = false
        walkingFocusStartedAt = nil
    }

    deinit {
        liveActivityRefreshTask?.cancel()
    }

    // MARK: - Live Activity refresh loop

    /// Pushes a HealthKit-backed update to the running Live Activity every
    /// 60 seconds while the app is in the foreground. Cancelled when the
    /// focus ends or another loop is started.
    private func startLiveActivityRefreshLoop(dependencies: DependencyContainer) {
        liveActivityRefreshTask?.cancel()
        liveActivityRefreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * NSEC_PER_SEC)
                if Task.isCancelled { break }
                guard self.walkingFocusActive else { break }
                let fresh = await dependencies.healthService.todaySnapshot()
                let steps = fresh.steps > 0
                    ? fresh.steps
                    : await dependencies.motionService.todayStepsFallback()
                self.snapshot = HealthSnapshot(
                    steps: steps,
                    activeEnergy: fresh.activeEnergy,
                    distanceKm: fresh.distanceKm,
                    authorizationStatus: fresh.authorizationStatus,
                    source: fresh.source
                )
                await dependencies.walkingLiveActivityService.update(
                    steps: steps,
                    goal: self.stepGoal,
                    elapsedMinutes: self.focusElapsedMinutes
                )
            }
        }
    }
}
