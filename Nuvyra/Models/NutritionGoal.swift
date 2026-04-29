import Foundation
import SwiftData

@Model
final class NutritionGoal: Identifiable {
    @Attribute(.unique) var id: UUID
    var dailyCalories: Int
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dailyCalories: Int = 1_900,
        proteinGrams: Double? = 110,
        carbsGrams: Double? = 210,
        fatGrams: Double? = 65,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dailyCalories = dailyCalories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.updatedAt = updatedAt
    }
}
