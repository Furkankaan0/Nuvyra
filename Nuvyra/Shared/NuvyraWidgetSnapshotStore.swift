import Foundation

struct NuvyraWidgetSnapshot: Codable, Equatable {
    var snapshotDate: Date
    var updatedAt: Date
    var userName: String
    var caloriesConsumed: Int
    var calorieTarget: Int
    var caloriesBurned: Int
    var waterMl: Int
    var waterTargetMl: Int
    var steps: Int
    var stepTarget: Int
    var proteinGrams: Double
    var proteinTargetGrams: Int
    var mealCount: Int
    var waterStreakDays: Int
    var mealStreakDays: Int

    static var empty: NuvyraWidgetSnapshot {
        let now = Date()
        return NuvyraWidgetSnapshot(
            snapshotDate: now,
            updatedAt: now,
            userName: "Nuvyra",
            caloriesConsumed: 0,
            calorieTarget: 1_900,
            caloriesBurned: 0,
            waterMl: 0,
            waterTargetMl: 2_000,
            steps: 0,
            stepTarget: 7_500,
            proteinGrams: 0,
            proteinTargetGrams: 120,
            mealCount: 0,
            waterStreakDays: 0,
            mealStreakDays: 0
        )
    }

    static var preview: NuvyraWidgetSnapshot {
        let now = Date()
        return NuvyraWidgetSnapshot(
            snapshotDate: now,
            updatedAt: now,
            userName: "Furkan",
            caloriesConsumed: 1_280,
            calorieTarget: 1_900,
            caloriesBurned: 310,
            waterMl: 1_450,
            waterTargetMl: 2_000,
            steps: 6_420,
            stepTarget: 7_500,
            proteinGrams: 84,
            proteinTargetGrams: 120,
            mealCount: 3,
            waterStreakDays: 4,
            mealStreakDays: 6
        )
    }

    var firstName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").first.map(String.init) ?? "Nuvyra"
    }

    var calorieBalance: Int {
        max(calorieTarget - caloriesConsumed + caloriesBurned, 0)
    }

    var calorieProgress: Double {
        progress(Double(caloriesConsumed), target: Double(max(calorieTarget, 1)))
    }

    var waterProgress: Double {
        progress(Double(waterMl), target: Double(max(waterTargetMl, 1)))
    }

    var stepProgress: Double {
        progress(Double(steps), target: Double(max(stepTarget, 1)))
    }

    var proteinProgress: Double {
        progress(proteinGrams, target: Double(max(proteinTargetGrams, 1)))
    }

    var rhythmScore: Int {
        let combined = (calorieProgress * 0.24) + (waterProgress * 0.28) + (stepProgress * 0.32) + (proteinProgress * 0.16)
        return Int((min(combined, 1) * 100).rounded())
    }

    var hasLoggedToday: Bool {
        caloriesConsumed > 0 || waterMl > 0 || steps > 0 || mealCount > 0
    }

    func resetForToday(_ date: Date = Date()) -> NuvyraWidgetSnapshot {
        NuvyraWidgetSnapshot(
            snapshotDate: date,
            updatedAt: date,
            userName: userName,
            caloriesConsumed: 0,
            calorieTarget: calorieTarget,
            caloriesBurned: 0,
            waterMl: 0,
            waterTargetMl: waterTargetMl,
            steps: 0,
            stepTarget: stepTarget,
            proteinGrams: 0,
            proteinTargetGrams: proteinTargetGrams,
            mealCount: 0,
            waterStreakDays: 0,
            mealStreakDays: 0
        )
    }

    private func progress(_ value: Double, target: Double) -> Double {
        min(max(value / target, 0), 1)
    }
}

enum NuvyraWidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.nuvyra.app"
    static let widgetKind = "NuvyraWidget"

    private static let snapshotKey = "nuvyra.widget.snapshot.v1"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func current() -> NuvyraWidgetSnapshot {
        guard let stored = readRaw() else { return .empty }
        if Calendar.current.isDate(stored.snapshotDate, inSameDayAs: Date()) {
            return stored
        }
        return stored.resetForToday()
    }

    static func write(_ snapshot: NuvyraWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        sharedDefaults.set(data, forKey: snapshotKey)
        sharedDefaults.synchronize()
    }

    private static func readRaw() -> NuvyraWidgetSnapshot? {
        guard let data = sharedDefaults.data(forKey: snapshotKey) else { return nil }
        return try? decoder.decode(NuvyraWidgetSnapshot.self, from: data)
    }

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
