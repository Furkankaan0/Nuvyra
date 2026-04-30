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
    /// Activity level captured during onboarding. Optional so existing
    /// installs without this column don't fail SwiftData migration; the
    /// onboarding flow always sets it for new users.
    var activityLevel: ActivityLevel?
    /// Wake / sleep times captured during onboarding so notification
    /// schedules can adapt to the user's actual rhythm (night-shift,
    /// late starters, etc.) instead of firing 14:30 reminders at
    /// everyone. All four are optional so existing installs don't trip
    /// SwiftData's lightweight migration; consumers fall back to a
    /// 07:00 / 23:00 window when nil.
    var wakeHour: Int?
    var wakeMinute: Int?
    var sleepHour: Int?
    var sleepMinute: Int?
    var createdAt: Date
    var updatedAt: Date

    /// Designated initialiser. Every numeric field is required — there are
    /// no fictional "Furkan, 30 yaş, 175 cm" defaults that could leak into
    /// a release build. Always pass values that came from the onboarding
    /// flow (or a calculator that was fed onboarding inputs).
    init(
        id: UUID = UUID(),
        name: String,
        age: Int,
        gender: Gender?,
        heightCm: Double,
        weightKg: Double,
        targetWeightKg: Double? = nil,
        dailyCalorieTarget: Int,
        dailyStepTarget: Int,
        dailyWaterTargetMl: Int,
        goalType: GoalType,
        activityLevel: ActivityLevel? = nil,
        wakeHour: Int? = nil,
        wakeMinute: Int? = nil,
        sleepHour: Int? = nil,
        sleepMinute: Int? = nil,
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
        self.activityLevel = activityLevel
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
        self.sleepHour = sleepHour
        self.sleepMinute = sleepMinute
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
