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
    var dailyStepTarget: Int
    var dailyWaterTargetMl: Int
    var goalType: GoalType
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
        dailyStepTarget: Int = 7_500,
        dailyWaterTargetMl: Int = 2_000,
        goalType: GoalType = .walkMore,
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
        self.dailyStepTarget = dailyStepTarget
        self.dailyWaterTargetMl = dailyWaterTargetMl
        self.goalType = goalType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
