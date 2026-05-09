import Foundation
import SwiftData

@MainActor
final class WaterTrackingViewModel: ObservableObject {
    @Published var entries: [WaterEntry] = []
    @Published var weeklyTotals: [DailyWaterTotal] = []
    @Published var totalToday: Int = 0
    @Published var profile: UserProfile?
    @Published var manualEntryText: String = ""
    @Published var manualEntryError: String?
    @Published var showCelebration: Bool = false
    @Published var remindersEnabled: Bool = false
    private var didCelebrateForCurrentTarget: Bool = false
    private var hasInitiallyLoaded: Bool = false

    var targetMl: Int { profile?.dailyWaterTargetMl ?? 2_000 }
    var summary: WaterSummary { WaterSummary(consumedMl: totalToday, targetMl: targetMl) }

    var weeklyAverageMl: Int {
        guard !weeklyTotals.isEmpty else { return 0 }
        let sum = weeklyTotals.map(\.totalMl).reduce(0, +)
        return sum / weeklyTotals.count
    }

    var bestDayTotal: Int {
        weeklyTotals.map(\.totalMl).max() ?? 0
    }

    var daysAchievedThisWeek: Int {
        let goal = max(targetMl, 1)
        return weeklyTotals.filter { $0.totalMl >= goal }.count
    }

    func load(context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let userRepo = dependencies.userRepository(context: context)
            let waterRepo = dependencies.waterRepository(context: context)
            profile = try userRepo.profile()
            entries = try waterRepo.entries(on: Date())
            totalToday = try waterRepo.totalWater(on: Date())
            weeklyTotals = try waterRepo.weeklyTotals(endingOn: Date())
            remindersEnabled = (try? context.fetch(FetchDescriptor<AppSettings>()).first?.notificationsEnabled) ?? false
            updateCelebrationState()
            await WidgetSnapshotPublisher.publish(context: context, dependencies: dependencies)
        } catch {}
    }

    func add(amount: Int, context: ModelContext, dependencies: DependencyContainer) async {
        guard amount > 0 else { return }
        do {
            let waterRepo = dependencies.waterRepository(context: context)
            try waterRepo.addWater(amountMl: amount, date: Date())
            dependencies.haptics.waterAdded()
            await dependencies.analytics.track(.waterAdded, payload: AnalyticsPayload(values: ["amount_ml": "\(amount)"]))
            await load(context: context, dependencies: dependencies)
        } catch {}
    }

    @discardableResult
    func submitManualEntry(context: ModelContext, dependencies: DependencyContainer) async -> Bool {
        let trimmed = manualEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            manualEntryError = "Bir miktar gir."
            return false
        }
        guard let value = Int(trimmed), value > 0 else {
            manualEntryError = "Lütfen pozitif bir sayı gir (örn. 350)."
            return false
        }
        guard value <= 5_000 else {
            manualEntryError = "Tek seferde en fazla 5000 ml ekleyebilirsin."
            return false
        }
        manualEntryError = nil
        manualEntryText = ""
        await add(amount: value, context: context, dependencies: dependencies)
        return true
    }

    func remove(_ entry: WaterEntry, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let waterRepo = dependencies.waterRepository(context: context)
            try waterRepo.remove(entry)
            dependencies.haptics.waterAdded()
            await load(context: context, dependencies: dependencies)
        } catch {}
    }

    func setReminders(enabled: Bool, context: ModelContext, dependencies: DependencyContainer) async {
        remindersEnabled = enabled
        if enabled {
            let granted = await dependencies.notificationService.requestAuthorization()
            if granted {
                var preferences = currentPreferences(context: context)
                preferences.masterEnabled = true
                persistPreferences(preferences, context: context)
                let personal = personalContext()
                await dependencies.notificationService.schedule(preferences: preferences, context: personal)
            } else {
                remindersEnabled = false
                var preferences = currentPreferences(context: context)
                preferences.masterEnabled = false
                persistPreferences(preferences, context: context)
            }
        } else {
            var preferences = currentPreferences(context: context)
            preferences.masterEnabled = false
            persistPreferences(preferences, context: context)
            await dependencies.notificationService.cancelAll()
        }
    }

    private func currentPreferences(context: ModelContext) -> NotificationPreferences {
        let descriptor = FetchDescriptor<AppSettings>()
        return (try? context.fetch(descriptor).first?.notificationPreferences) ?? .default
    }

    private func persistPreferences(_ preferences: NotificationPreferences, context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        guard let settings = try? context.fetch(descriptor).first else { return }
        settings.notificationPreferences = preferences
        try? context.save()
    }

    private func personalContext() -> NotificationPersonalContext {
        NotificationPersonalContext(
            firstName: profile?.name,
            goalType: profile?.goalType,
            activityLevel: profile?.activityLevel
        )
    }

    func dismissCelebration() { showCelebration = false }

    private func updateCelebrationState() {
        let isComplete = totalToday >= targetMl && targetMl > 0
        if !hasInitiallyLoaded {
            // Suppress celebration on first load; user gets it only when crossing the target this session.
            didCelebrateForCurrentTarget = isComplete
            hasInitiallyLoaded = true
            return
        }
        if isComplete && !didCelebrateForCurrentTarget {
            didCelebrateForCurrentTarget = true
            showCelebration = true
        } else if !isComplete {
            didCelebrateForCurrentTarget = false
        }
    }
}
