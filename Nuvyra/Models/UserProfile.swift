import Foundation
import SwiftData

@Model
final class UserProfile: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var age: Int
    var gender: Gender?
    var heightCm: Double
    var weightKg: Double
    var targetWeightKg: Double?
    var dailyCalorieTarget: Int
    var dailyProteinTargetGrams: Int = 120
    var dailyCarbsTargetGrams: Int = 210
    var dailyFatTargetGrams: Int = 65
    var dailyStepTarget: Int
    var dailyWaterTargetMl: Int
    var goalType: GoalType
    var activityLevel: ActivityLevel = .lightlyActive
    var goalPace: GoalPace? = .balanced
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Furkan",
        age: Int = 30,
        gender: Gender? = .preferNotToSay,
        heightCm: Double = 175,
        weightKg: Double = 78,
        targetWeightKg: Double? = 74,
        dailyCalorieTarget: Int = 1_900,
        dailyProteinTargetGrams: Int = 120,
        dailyCarbsTargetGrams: Int = 210,
        dailyFatTargetGrams: Int = 65,
        dailyStepTarget: Int = 7_500,
        dailyWaterTargetMl: Int = 2_000,
        goalType: GoalType = .walkMore,
        activityLevel: ActivityLevel = .lightlyActive,
        goalPace: GoalPace? = .balanced,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.targetWeightKg = targetWeightKg
        self.dailyCalorieTarget = dailyCalorieTarget
        self.dailyProteinTargetGrams = dailyProteinTargetGrams
        self.dailyCarbsTargetGrams = dailyCarbsTargetGrams
        self.dailyFatTargetGrams = dailyFatTargetGrams
        self.dailyStepTarget = dailyStepTarget
        self.dailyWaterTargetMl = dailyWaterTargetMl
        self.goalType = goalType
        self.activityLevel = activityLevel
        self.goalPace = goalPace
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
