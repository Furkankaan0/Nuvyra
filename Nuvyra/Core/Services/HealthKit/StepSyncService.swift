import Foundation

protocol StepSyncing {
    func syncToday(goal: Int) async -> StepSnapshot
    func syncHistory(days: Int, goal: Int) async -> [StepHistoryDay]
}

struct StepSyncService: StepSyncing {
    let healthKitManager: HealthKitManaging
    let historyRepository: StepHistoryRepository?

    init(healthKitManager: HealthKitManaging, historyRepository: StepHistoryRepository? = nil) {
        self.healthKitManager = healthKitManager
        self.historyRepository = historyRepository
    }

    func syncToday(goal: Int) async -> StepSnapshot {
        do {
            let steps = try await healthKitManager.fetchTodaySteps()
            return StepSnapshot(steps: steps, goal: goal, updatedAt: Date(), source: .healthKit)
        } catch {
            return StepSnapshot(steps: 0, goal: goal, updatedAt: Date(), source: .unavailable)
        }
    }

    func syncHistory(days: Int, goal: Int) async -> [StepHistoryDay] {
        do {
            var history = try await healthKitManager.fetchStepHistory(days: days)
            history = history.map { StepHistoryDay(date: $0.date, steps: $0.steps, goal: goal) }
            try await historyRepository?.saveStepHistory(history)
            return history
        } catch {
            if let historyRepository, let cached = try? await historyRepository.loadStepHistory(), !cached.isEmpty {
                return cached
            }
            return StepHistoryDay.sampleWeek.map { StepHistoryDay(date: $0.date, steps: $0.steps, goal: goal) }
        }
    }
}

struct PreviewStepSyncService: StepSyncing {
    func syncToday(goal: Int) async -> StepSnapshot {
        StepSnapshot(steps: StepSnapshot.preview.steps, goal: goal, updatedAt: Date(), source: .demo)
    }

    func syncHistory(days: Int, goal: Int) async -> [StepHistoryDay] {
        StepHistoryDay.sampleWeek.map { StepHistoryDay(date: $0.date, steps: $0.steps, goal: goal) }
    }
}

