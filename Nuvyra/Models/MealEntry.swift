import Foundation
import SwiftData

@Model
final class MealEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var mealType: MealType
    var name: String
    var calories: Int
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var portionDescription: String
    var isFavorite: Bool
    var isVerifiedTurkishFood: Bool
    var isEstimated: Bool
    var createdAt: Date

    // MARK: - Micronutrients (optional, added in v1.2)
    var fiberGrams: Double?
    var sodiumMg: Double?
    var sugarGrams: Double?
    var saturatedFatGrams: Double?
    @Attribute(.externalStorage) var photoData: Data?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType = .breakfast,
        name: String,
        calories: Int,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        portionDescription: String = "1 porsiyon",
        isFavorite: Bool = false,
        isVerifiedTurkishFood: Bool = false,
        isEstimated: Bool = true,
        createdAt: Date = Date(),
        fiberGrams: Double? = nil,
        sodiumMg: Double? = nil,
        sugarGrams: Double? = nil,
        saturatedFatGrams: Double? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.portionDescription = portionDescription
        self.isFavorite = isFavorite
        self.isVerifiedTurkishFood = isVerifiedTurkishFood
        self.isEstimated = isEstimated
        self.createdAt = createdAt
        self.fiberGrams = fiberGrams
        self.sodiumMg = sodiumMg
        self.sugarGrams = sugarGrams
        self.saturatedFatGrams = saturatedFatGrams
        self.photoData = photoData
    }

    /// True if any micronutrient field is populated — used to drive UI badges.
    var hasMicronutrients: Bool {
        fiberGrams != nil || sodiumMg != nil || sugarGrams != nil || saturatedFatGrams != nil
    }

    /// Macro + calorie rollup as a value type. Optional micros fall back to 0.
    var nutritionValues: NutritionValues {
        NutritionValues(
            calories: calories,
            protein: protein ?? 0,
            carbs: carbs ?? 0,
            fat: fat ?? 0,
            fiber: fiberGrams ?? 0,
            sodium: sodiumMg ?? 0,
            sugar: sugarGrams ?? 0,
            saturatedFat: saturatedFatGrams ?? 0
        )
    }
}
