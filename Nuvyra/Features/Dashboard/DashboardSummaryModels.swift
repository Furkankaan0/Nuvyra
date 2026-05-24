import Foundation

struct DailyNutritionSummary: Equatable {
    var consumedCalories: Int
    var burnedCalories: Int
    var targetCalories: Int

    var remainingCalories: Int {
        max(targetCalories - consumedCalories + burnedCalories, 0)
    }

    var ringProgress: Double {
        guard targetCalories > 0 else { return 0 }
        return min(Double(consumedCalories) / Double(targetCalories), 1.2)
    }

    static let empty = DailyNutritionSummary(consumedCalories: 0, burnedCalories: 0, targetCalories: 1_900)
}

struct MacroSummary: Equatable, Identifiable {
    enum Kind: String, CaseIterable, Identifiable {
        case protein, carbs, fat
        var id: String { rawValue }

        var title: String {
            switch self {
            case .protein: "Protein"
            case .carbs: "Karbonhidrat"
            case .fat: "Yağ"
            }
        }

        var shortTitle: String {
            switch self {
            case .protein: "P"
            case .carbs: "K"
            case .fat: "Y"
            }
        }

        var systemImage: String {
            switch self {
            case .protein: "bolt.heart"
            case .carbs: "leaf"
            case .fat: "drop.circle"
            }
        }
    }

    var id: Kind.RawValue { kind.rawValue }
    var kind: Kind
    var consumedGrams: Double
    var targetGrams: Double

    var progress: Double {
        guard targetGrams > 0 else { return 0 }
        return min(consumedGrams / targetGrams, 1.0)
    }

    var displayValue: String {
        "\(Int(consumedGrams.rounded()))/\(Int(targetGrams.rounded())) g"
    }
}

struct WaterSummary: Equatable {
    var consumedMl: Int
    var targetMl: Int

    var progress: Double {
        guard targetMl > 0 else { return 0 }
        return min(Double(consumedMl) / Double(targetMl), 1.0)
    }

    var remainingMl: Int { max(targetMl - consumedMl, 0) }
    var isGoalReached: Bool { consumedMl >= targetMl }

    static let empty = WaterSummary(consumedMl: 0, targetMl: 2_000)
}

struct StepSummary: Equatable {
    var steps: Int
    var goal: Int
    var distanceKm: Double?
    var activeEnergy: Double

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1.0)
    }

    var remaining: Int { max(goal - steps, 0) }
    var isGoalReached: Bool { steps >= goal }

    static let empty = StepSummary(steps: 0, goal: 7_500, distanceKm: nil, activeEnergy: 0)
}

struct RecentFoodLog: Identifiable, Equatable {
    let id: UUID
    let name: String
    let calories: Int
    let portion: String
    let mealType: MealType
    let createdAt: Date

    var relativeTimeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

extension RecentFoodLog {
    init(meal: MealEntry) {
        self.init(
            id: meal.id,
            name: meal.name,
            calories: meal.calories,
            portion: meal.portionDescription,
            mealType: meal.mealType,
            createdAt: meal.createdAt
        )
    }
}
