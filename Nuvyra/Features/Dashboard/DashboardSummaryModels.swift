import Foundation
import SwiftUI

struct DailyNutritionSummary: Equatable {
    var consumed: Int
    var burned: Int
    var target: Int

    var remaining: Int { max(target - consumed + burned, 0) }
    var ringProgress: Double {
        guard target > 0 else { return 0 }
        return min(max(Double(consumed) / Double(target), 0), 1)
    }
    var isOverTarget: Bool { consumed > target + burned }

    static let empty = DailyNutritionSummary(consumed: 0, burned: 0, target: 1_900)
}

struct MacroSummary: Equatable, Identifiable {
    enum Kind: String, CaseIterable {
        case protein, carbs, fat

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
            case .fat: "drop.triangle"
            }
        }
    }

    var id: Kind { kind }
    var kind: Kind
    var consumedGrams: Double
    var targetGrams: Double

    var progress: Double {
        guard targetGrams > 0 else { return 0 }
        return min(max(consumedGrams / targetGrams, 0), 1)
    }

    var remainingGrams: Double { max(targetGrams - consumedGrams, 0) }

    func tint(scheme: ColorScheme) -> Color {
        switch kind {
        case .protein: return NuvyraColors.mutedCoral
        case .carbs: return NuvyraColors.paleLime
        case .fat: return NuvyraColors.softSand
        }
    }
}

struct WaterSummary: Equatable {
    var consumedMl: Int
    var targetMl: Int

    var progress: Double {
        guard targetMl > 0 else { return 0 }
        return min(max(Double(consumedMl) / Double(targetMl), 0), 1)
    }

    var isCompleted: Bool { consumedMl >= targetMl && targetMl > 0 }
    var remainingMl: Int { max(targetMl - consumedMl, 0) }
}

struct StepSummary: Equatable {
    var steps: Int
    var goal: Int
    var distanceKm: Double?
    var activeEnergyKcal: Double

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(steps) / Double(goal), 0), 1)
    }

    var isCompleted: Bool { steps >= goal && goal > 0 }
    var remainingSteps: Int { max(goal - steps, 0) }
}

struct RecentFoodLog: Identifiable, Equatable {
    let id: UUID
    let name: String
    let mealType: MealType
    let calories: Int
    let portion: String
    let loggedAt: Date

    init(from meal: MealEntry) {
        self.id = meal.id
        self.name = meal.name
        self.mealType = meal.mealType
        self.calories = meal.calories
        self.portion = meal.portionDescription
        self.loggedAt = meal.createdAt
    }

    init(id: UUID = UUID(), name: String, mealType: MealType, calories: Int, portion: String, loggedAt: Date) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.calories = calories
        self.portion = portion
        self.loggedAt = loggedAt
    }
}
