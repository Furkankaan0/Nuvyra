import Foundation
import SwiftData

@MainActor
protocol UserRepository {
    func settings() throws -> AppSettings
    func profile() throws -> UserProfile?
    func saveOnboardingProfile(name: String, goalType: GoalType) throws -> UserProfile
    func markOnboardingCompleted() throws
}

@MainActor
final class SwiftDataUserRepository: UserRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func settings() throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    func profile() throws -> UserProfile? {
        try context.fetch(FetchDescriptor<UserProfile>()).first
    }

    func saveOnboardingProfile(name: String, goalType: GoalType) throws -> UserProfile {
        let profile: UserProfile
        if let existing = try self.profile() {
            profile = existing
        } else {
            profile = UserProfile()
            context.insert(profile)
        }
        profile.name = name.isEmpty ? "Furkan" : name
        profile.goalType = goalType
        profile.dailyCalorieTarget = Self.defaultCalories(for: goalType)
        profile.dailyStepTarget = Self.defaultSteps(for: goalType)
        profile.dailyWaterTargetMl = 2_000
        profile.updatedAt = Date()
        try markOnboardingCompleted()
        try context.save()
        return profile
    }

    func markOnboardingCompleted() throws {
        let current = try settings()
        current.hasCompletedOnboarding = true
        current.updatedAt = Date()
        try context.save()
    }

    private static func defaultCalories(for goal: GoalType) -> Int {
        switch goal {
        case .loseWeight: 1_750
        case .maintain: 1_950
        case .gainHealthy: 2_150
        case .walkMore: 1_900
        case .eatHealthier: 1_850
        }
    }

    private static func defaultSteps(for goal: GoalType) -> Int {
        switch goal {
        case .walkMore: 8_000
        case .loseWeight: 7_500
        default: 7_000
        }
    }
}
