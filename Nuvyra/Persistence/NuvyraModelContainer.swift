import Foundation
import SwiftData

enum NuvyraModelContainer {
    static let schema = Schema([
        UserProfile.self,
        DailyLog.self,
        MealEntry.self,
        WaterEntry.self,
        WalkingLog.self,
        NutritionGoal.self,
        SubscriptionState.self,
        AppSettings.self
    ])

    @MainActor
    static func live() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            assertionFailure("SwiftData container failed, falling back to in-memory store: \(error)")
            return preview()
        }
    }

    @MainActor
    static func preview() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            SeedData.seedPreview(in: container.mainContext)
            return container
        } catch {
            fatalError("Preview ModelContainer could not be created: \(error)")
        }
    }

    @MainActor
    static func uiTesting() -> ModelContainer {
        do {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            SeedData.ensureMinimumData(in: container.mainContext)
            return container
        } catch {
            fatalError("UI testing ModelContainer could not be created: \(error)")
        }
    }
}
