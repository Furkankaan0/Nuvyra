import Foundation
import SwiftData

/// Owns a long-running HealthKit observer for today's step / active-energy
/// data. Whenever Apple Health delivers a new sample (foreground OR
/// background, including watch-originated steps) it pulls a fresh
/// snapshot, persists it to SwiftData, and lets the repository hooks
/// refresh the widget.
///
/// This is the piece that makes the app feel "live" — without it, the user
/// would have to open the app to see new steps on the dashboard or
/// home-screen widget.
///
/// Notes:
/// - The HealthKit entitlement (`com.apple.developer.healthkit`) is
///   already configured. iOS will wake the app for HealthKit background
///   deliveries without any additional `UIBackgroundModes` key.
/// - Observer fire handlers run on an arbitrary HealthKit queue. We hop
///   to the main actor before touching SwiftData (which is `@MainActor`).
@MainActor
final class HealthSyncCoordinator {
    private let healthService: HealthService
    private let modelContext: ModelContext
    private let dependencies: DependencyContainer
    private var observerToken: HealthObservationToken?
    /// Coalesces bursts of observer fires (e.g. a Watch sync delivering
    /// 30 minutes of stale samples in one shot) so we don't query
    /// HealthKit dozens of times in a row.
    private var coalesceTask: Task<Void, Never>?

    init(
        healthService: HealthService,
        modelContext: ModelContext,
        dependencies: DependencyContainer
    ) {
        self.healthService = healthService
        self.modelContext = modelContext
        self.dependencies = dependencies
    }

    /// Begin observing. Safe to call repeatedly — subsequent calls are
    /// no-ops while an observer is already active.
    func start() {
        guard observerToken == nil else { return }
        observerToken = healthService.startObservingTodayChanges { [weak self] in
            // Hop back to MainActor; HealthKit invokes observer handlers
            // on its own internal queue.
            Task { @MainActor [weak self] in
                self?.scheduleSync()
            }
        }
    }

    func stop() {
        observerToken?.cancel()
        observerToken = nil
        coalesceTask?.cancel()
        coalesceTask = nil
    }

    /// Force one sync cycle (e.g. on app foreground). Useful for the case
    /// where the observer hasn't fired yet but the user just opened the
    /// app and we want fresh numbers immediately.
    func syncNow() async {
        await performSync()
    }

    // MARK: - Internal

    private func scheduleSync() {
        // Drop any pending coalesce task and start a new one. 1.5s window
        // is short enough that the user feels updates as immediate.
        coalesceTask?.cancel()
        coalesceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            await self?.performSync()
        }
    }

    private func performSync() async {
        let outcome = await healthService.loadTodaySnapshot()
        guard case .success(let snapshot) = outcome else {
            // Errors are handled by the foreground UI (Walking/Dashboard
            // view models call `loadTodaySnapshot()` themselves and
            // surface a banner). The background observer just stays
            // quiet; there is no UI to talk to.
            return
        }
        let profile = try? dependencies.userRepository(context: modelContext).profile()
        let goal = profile?.dailyStepTarget ?? 7_500
        do {
            // The repository's `onMutate` hook is wired to
            // `WidgetRefresh.reload(...)`, so the home-screen widget
            // will see the fresh numbers without us touching it here.
            try dependencies
                .activityRepository(context: modelContext)
                .upsertWalkingSnapshot(
                    date: Date(),
                    steps: snapshot.steps,
                    activeEnergy: snapshot.activeEnergy,
                    distanceKm: snapshot.distanceKm,
                    goal: goal
                )
        } catch {
            // SwiftData write failures are logged in higher layers; here
            // we don't have a UI surface to report to.
        }
    }
}
