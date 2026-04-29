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
        createdAt: Date = Date()
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
    }
}
