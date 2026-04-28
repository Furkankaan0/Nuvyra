import Foundation

protocol UserProfileRepository {
    func loadProfile() async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
}

protocol MealRepository {
    func loadMeals() async throws -> [MealLog]
    func saveMeals(_ meals: [MealLog]) async throws
}

protocol WaterRepository {
    func loadWaterLogs() async throws -> [WaterLog]
    func saveWaterLogs(_ logs: [WaterLog]) async throws
}

protocol StepHistoryRepository {
    func loadStepHistory() async throws -> [StepHistoryDay]
    func saveStepHistory(_ history: [StepHistoryDay]) async throws
}

struct LocalUserProfileRepository: UserProfileRepository {
    let store: LocalStore

    func loadProfile() async throws -> UserProfile? {
        try await store.load(UserProfile.self, for: .userProfile)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        try await store.save(profile, for: .userProfile)
    }
}

struct LocalMealRepository: MealRepository {
    let store: LocalStore

    func loadMeals() async throws -> [MealLog] {
        try await store.load([MealLog].self, for: .meals) ?? []
    }

    func saveMeals(_ meals: [MealLog]) async throws {
        try await store.save(meals, for: .meals)
    }
}

struct LocalWaterRepository: WaterRepository {
    let store: LocalStore

    func loadWaterLogs() async throws -> [WaterLog] {
        try await store.load([WaterLog].self, for: .waterLogs) ?? []
    }

    func saveWaterLogs(_ logs: [WaterLog]) async throws {
        try await store.save(logs, for: .waterLogs)
    }
}

struct LocalStepHistoryRepository: StepHistoryRepository {
    let store: LocalStore

    func loadStepHistory() async throws -> [StepHistoryDay] {
        try await store.load([StepHistoryDay].self, for: .stepHistory) ?? []
    }

    func saveStepHistory(_ history: [StepHistoryDay]) async throws {
        try await store.save(history, for: .stepHistory)
    }
}
