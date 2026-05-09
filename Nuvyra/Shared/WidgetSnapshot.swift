import Foundation
import WidgetKit

/// Snapshot of the user's daily ritmi — written by the main app, read by the
/// widget extension via App Group `UserDefaults`.
///
/// Keep this struct **stable**: adding new optional fields is fine, removing or
/// renaming requires a migration of `Version` below.
public struct WidgetSnapshot: Codable, Equatable {
    public static let storageKey = "nuvyra.widget.snapshot.v1"
    public static let appGroupSuiteName = "group.com.nuvyra.app"

    public var version: Int
    public var generatedAt: Date

    public var caloriesConsumed: Int
    public var calorieTarget: Int
    public var caloriesBurned: Int

    public var proteinGrams: Double
    public var proteinTargetGrams: Double
    public var carbsGrams: Double
    public var carbsTargetGrams: Double
    public var fatGrams: Double
    public var fatTargetGrams: Double

    public var waterMl: Int
    public var waterTargetMl: Int

    public var steps: Int
    public var stepGoal: Int
    public var distanceKm: Double?

    public var lastMealName: String?
    public var lastMealLoggedAt: Date?
    public var todayMealCount: Int

    public var insight: String
    public var displayName: String?

    public init(
        version: Int = 1,
        generatedAt: Date = Date(),
        caloriesConsumed: Int = 0,
        calorieTarget: Int = 1_900,
        caloriesBurned: Int = 0,
        proteinGrams: Double = 0,
        proteinTargetGrams: Double = 120,
        carbsGrams: Double = 0,
        carbsTargetGrams: Double = 210,
        fatGrams: Double = 0,
        fatTargetGrams: Double = 65,
        waterMl: Int = 0,
        waterTargetMl: Int = 2_000,
        steps: Int = 0,
        stepGoal: Int = 7_500,
        distanceKm: Double? = nil,
        lastMealName: String? = nil,
        lastMealLoggedAt: Date? = nil,
        todayMealCount: Int = 0,
        insight: String = "Bugünkü ritmin için Nuvyra'yı aç.",
        displayName: String? = nil
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.caloriesConsumed = caloriesConsumed
        self.calorieTarget = calorieTarget
        self.caloriesBurned = caloriesBurned
        self.proteinGrams = proteinGrams
        self.proteinTargetGrams = proteinTargetGrams
        self.carbsGrams = carbsGrams
        self.carbsTargetGrams = carbsTargetGrams
        self.fatGrams = fatGrams
        self.fatTargetGrams = fatTargetGrams
        self.waterMl = waterMl
        self.waterTargetMl = waterTargetMl
        self.steps = steps
        self.stepGoal = stepGoal
        self.distanceKm = distanceKm
        self.lastMealName = lastMealName
        self.lastMealLoggedAt = lastMealLoggedAt
        self.todayMealCount = todayMealCount
        self.insight = insight
        self.displayName = displayName
    }

    public static let placeholder = WidgetSnapshot(
        caloriesConsumed: 1_240,
        calorieTarget: 1_900,
        caloriesBurned: 280,
        proteinGrams: 78,
        carbsGrams: 132,
        fatGrams: 41,
        waterMl: 1_400,
        steps: 5_360,
        distanceKm: 3.8,
        lastMealName: "Mercimek çorbası",
        lastMealLoggedAt: Date().addingTimeInterval(-1_800),
        todayMealCount: 3,
        insight: "Akşam küçük bir yürüyüş ritmini tamamlayabilir."
    )

    // MARK: Derived metrics

    public var calorieRingProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(max(Double(caloriesConsumed) / Double(calorieTarget), 0), 1)
    }

    public var calorieRemaining: Int {
        max(calorieTarget - caloriesConsumed + caloriesBurned, 0)
    }

    public var stepsProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(max(Double(steps) / Double(stepGoal), 0), 1)
    }

    public var waterProgress: Double {
        guard waterTargetMl > 0 else { return 0 }
        return min(max(Double(waterMl) / Double(waterTargetMl), 0), 1)
    }

    public var proteinProgress: Double {
        guard proteinTargetGrams > 0 else { return 0 }
        return min(max(proteinGrams / proteinTargetGrams, 0), 1)
    }

    public var allGoalsCompleted: Bool {
        calorieRingProgress >= 1 && stepsProgress >= 1 && waterProgress >= 1
    }
}

// MARK: - Store

public enum WidgetSnapshotStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetSnapshot.appGroupSuiteName)
    }

    public static func read() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: WidgetSnapshot.storageKey),
              let snapshot = try? JSONDecoder.snapshot.decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    public static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder.snapshot.encode(snapshot) else { return }
        defaults?.set(data, forKey: WidgetSnapshot.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func clear() {
        defaults?.removeObject(forKey: WidgetSnapshot.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private extension JSONEncoder {
    static let snapshot: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let snapshot: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
