import Foundation

/// Macro + calorie container — used as plain value type in view models and previews.
/// Optional micronutrient fields (fiber/sodium/sugar/saturated fat) are tracked on
/// the same struct so daily summaries can roll them up trivially.
struct NutritionValues: Equatable, Hashable {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sodium: Double          // mg
    var sugar: Double
    var saturatedFat: Double

    init(
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0,
        sodium: Double = 0,
        sugar: Double = 0,
        saturatedFat: Double = 0
    ) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
        self.saturatedFat = saturatedFat
    }

    static let zero = NutritionValues(calories: 0, protein: 0, carbs: 0, fat: 0)

    static func + (lhs: NutritionValues, rhs: NutritionValues) -> NutritionValues {
        NutritionValues(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            fiber: lhs.fiber + rhs.fiber,
            sodium: lhs.sodium + rhs.sodium,
            sugar: lhs.sugar + rhs.sugar,
            saturatedFat: lhs.saturatedFat + rhs.saturatedFat
        )
    }

    func scaled(by factor: Double) -> NutritionValues {
        NutritionValues(
            calories: Int((Double(calories) * factor).rounded()),
            protein: (protein * factor).round(toPlaces: 1),
            carbs: (carbs * factor).round(toPlaces: 1),
            fat: (fat * factor).round(toPlaces: 1),
            fiber: (fiber * factor).round(toPlaces: 1),
            sodium: (sodium * factor).round(toPlaces: 0),
            sugar: (sugar * factor).round(toPlaces: 1),
            saturatedFat: (saturatedFat * factor).round(toPlaces: 1)
        )
    }
}

/// Daily macro target (grams) + calories + micronutrient ceilings/floors.
struct MacroTarget: Equatable, Hashable {
    var calories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var fiberGrams: Int
    var sodiumMg: Int
    var sugarGrams: Int
    var saturatedFatGrams: Int

    init(
        calories: Int,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        fiberGrams: Int = 30,
        sodiumMg: Int = 2_300,
        sugarGrams: Int = 50,
        saturatedFatGrams: Int = 22
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sodiumMg = sodiumMg
        self.sugarGrams = sugarGrams
        self.saturatedFatGrams = saturatedFatGrams
    }

    static let defaultTarget = MacroTarget(calories: 1_900, proteinGrams: 120, carbsGrams: 210, fatGrams: 65)
}

extension MacroTarget {
    init(profile: UserProfile) {
        self.init(
            calories: profile.dailyCalorieTarget,
            proteinGrams: profile.dailyProteinTargetGrams,
            carbsGrams: profile.dailyCarbsTargetGrams,
            fatGrams: profile.dailyFatTargetGrams,
            fiberGrams: profile.dailyFiberTargetGrams,
            sodiumMg: profile.dailySodiumTargetMg,
            sugarGrams: profile.dailySugarTargetGrams,
            saturatedFatGrams: profile.dailySaturatedFatTargetGrams
        )
    }
}

/// Portion measurement unit a user can pick while logging food.
enum PortionUnit: String, CaseIterable, Codable, Identifiable, Equatable, Hashable {
    case grams
    case portion
    case piece

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grams: "Gram"
        case .portion: "Porsiyon"
        case .piece: "Adet"
        }
    }

    var shortLabel: String {
        switch self {
        case .grams: "g"
        case .portion: "porsiyon"
        case .piece: "adet"
        }
    }

    var defaultQuantity: Double {
        switch self {
        case .grams: 100
        case .portion: 1
        case .piece: 1
        }
    }

    var step: Double {
        switch self {
        case .grams: 10
        case .portion: 0.5
        case .piece: 1
        }
    }
}

private extension Double {
    func round(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
