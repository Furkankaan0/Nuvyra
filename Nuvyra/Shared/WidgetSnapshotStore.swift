import Foundation

/// Codable summary of "today" that the widget extension can render without
/// reading SwiftData. It is written by the main app (every time a relevant
/// repository mutates) and read by the widget timeline provider.
///
/// Lives in `Nuvyra/Shared` so both the app and widget targets can use it.
public struct NuvyraWidgetSnapshot: Codable, Equatable {
    /// Wall-clock time the snapshot was produced. The widget uses this to
    /// surface a stale indicator if the day has rolled over and nothing
    /// has refreshed yet.
    public var generatedAt: Date
    /// `yyyy-MM-dd` of the day this snapshot represents.
    public var dayKey: String

    public var steps: Int
    public var stepGoal: Int

    /// kcal already consumed today (sum of MealEntry.calories).
    public var calorieIntake: Int
    /// daily calorie target from UserProfile / NutritionGoal.
    public var calorieTarget: Int
    /// `target - intake` (capped at 0). "kcal kaldı" in the UI.
    public var calorieBalance: Int

    public var waterMl: Int
    public var waterTargetMl: Int

    /// 0…1 progress that the small widget's ring shows. Steps progress.
    public var ringProgress: Double

    public var insight: String

    public init(
        generatedAt: Date,
        dayKey: String,
        steps: Int,
        stepGoal: Int,
        calorieIntake: Int,
        calorieTarget: Int,
        calorieBalance: Int,
        waterMl: Int,
        waterTargetMl: Int,
        ringProgress: Double,
        insight: String
    ) {
        self.generatedAt = generatedAt
        self.dayKey = dayKey
        self.steps = steps
        self.stepGoal = stepGoal
        self.calorieIntake = calorieIntake
        self.calorieTarget = calorieTarget
        self.calorieBalance = calorieBalance
        self.waterMl = waterMl
        self.waterTargetMl = waterTargetMl
        self.ringProgress = ringProgress
        self.insight = insight
    }
}

extension NuvyraWidgetSnapshot {
    /// Static demo snapshot, used as a placeholder before any data has been
    /// written to the App Group store. Only shown for the brief moment
    /// before the first real refresh.
    public static let preview = NuvyraWidgetSnapshot(
        generatedAt: Date(),
        dayKey: NuvyraWidgetSnapshot.dayKey(for: Date()),
        steps: 5_360,
        stepGoal: 7_500,
        calorieIntake: 1_280,
        calorieTarget: 1_900,
        calorieBalance: 620,
        waterMl: 1_250,
        waterTargetMl: 2_000,
        ringProgress: 5_360.0 / 7_500.0,
        insight: "Kısa bir yürüyüş ritmini tamamlamana yardımcı olabilir."
    )

    /// Stable, locale-independent day identifier ("yyyy-MM-dd") so the
    /// widget can compare today against the snapshot's recorded day.
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// App-Group-backed storage for the widget snapshot. Single key so we can't
/// race across multiple writers; main thread access only (the @MainActor
/// annotation is intentional — it is always called from the app's main
/// actor and from the widget timeline provider on the extension's main
/// thread).
public enum WidgetSnapshotStore {
    /// Must match the App Group declared in both `Nuvyra.entitlements`
    /// and `NuvyraWidget.entitlements`.
    public static let appGroupID = "group.com.nuvyra.app"
    private static let key = "nuvyra.widget.snapshot.v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func read() -> NuvyraWidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NuvyraWidgetSnapshot.self, from: data)
    }

    public static func write(_ snapshot: NuvyraWidgetSnapshot) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// Wipe the persisted snapshot. Useful on sign-out / data-reset paths.
    public static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
