import Foundation
import SwiftData

@MainActor
final class LocalDataDeletionService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func deletePersonalData() throws {
        try delete(UserProfile.self)
        try delete(DailyLog.self)
        try delete(MealEntry.self)
        try delete(WaterEntry.self)
        try delete(WalkingLog.self)
        try delete(NutritionGoal.self)
        try delete(AppSettings.self)
        try context.save()
    }

    private func delete<T: PersistentModel>(_ model: T.Type) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }
}
