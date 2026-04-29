import AppIntents
import Foundation
import SwiftData

extension MealType: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Öğün tipi"

    static var caseDisplayRepresentations: [MealType: DisplayRepresentation] = [
        .breakfast: "Kahvaltı",
        .lunch: "Öğle",
        .dinner: "Akşam",
        .snack: "Atıştırmalık"
    ]
}

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Nuvyra’da su ekle"
    static var description = IntentDescription("Nuvyra’ya hızlıca su kaydı ekler.")
    static var openAppWhenRun = false

    @Parameter(title: "Miktar", default: 250)
    var amountMl: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await IntentActionStore.addWater(amountMl: amountMl)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct AddQuickMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Nuvyra’ya öğün ekle"
    static var description = IntentDescription("Serbest metinden tahmini öğün kaydı oluşturur.")
    static var openAppWhenRun = false

    @Parameter(title: "Yemek", default: "Mercimek çorbası")
    var mealText: String

    @Parameter(title: "Öğün tipi", default: .lunch)
    var mealType: MealType

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await IntentActionStore.addQuickMeal(text: mealText, mealType: mealType)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct StartWalkingFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Nuvyra’da yürüyüş başlat"
    static var description = IntentDescription("Nuvyra yürüyüş odağını ve Live Activity akışını başlatır.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = await IntentActionStore.startWalkingFocus()
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct NuvyraShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "\(.applicationName)'da su ekle",
                "\(.applicationName)'ya 250 ml su ekle"
            ],
            shortTitle: "Su Ekle",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: AddQuickMealIntent(),
            phrases: [
                "\(.applicationName)'ya öğün ekle",
                "\(.applicationName)'ya yemek kaydet"
            ],
            shortTitle: "Öğün Ekle",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: StartWalkingFocusIntent(),
            phrases: [
                "\(.applicationName)'da yürüyüş başlat",
                "\(.applicationName)'da yürüyüş odağı başlat"
            ],
            shortTitle: "Yürüyüş Başlat",
            systemImageName: "figure.walk"
        )
    }
}

private enum IntentActionStore {
    @MainActor
    static func addWater(amountMl: Int) throws -> String {
        let safeAmount = min(max(amountMl, 50), 2_000)
        let container = NuvyraModelContainer.live()
        SeedData.ensureMinimumData(in: container.mainContext)
        try SwiftDataWaterRepository(context: container.mainContext).addWater(amountMl: safeAmount, date: Date())
        return "\(safeAmount) ml su Nuvyra’ya eklendi."
    }

    @MainActor
    static func addQuickMeal(text: String, mealType: MealType) async throws -> String {
        let container = NuvyraModelContainer.live()
        SeedData.ensureMinimumData(in: container.mainContext)
        let estimates = try await MockFoodIntelligenceService().estimateFromText(text, mealType: mealType)
        guard let estimate = estimates.first else {
            return "Bu metinden öğün çıkaramadık. Uygulamada manuel ekleyebilirsin."
        }
        let meal = MealEntry(
            mealType: mealType,
            name: estimate.name,
            calories: estimate.calories,
            protein: estimate.protein,
            carbs: estimate.carbs,
            fat: estimate.fat,
            portionDescription: estimate.portion,
            isFavorite: false,
            isVerifiedTurkishFood: estimate.source == .mockTurkishNLP,
            isEstimated: true
        )
        try SwiftDataNutritionRepository(context: container.mainContext).addMeal(meal)
        return "\(estimate.name), tahmini \(estimate.calories) kcal olarak kaydedildi."
    }

    @MainActor
    static func startWalkingFocus() async -> String {
        let container = NuvyraModelContainer.live()
        SeedData.ensureMinimumData(in: container.mainContext)
        let profile = try? SwiftDataUserRepository(context: container.mainContext).profile()
        let goal = profile?.dailyStepTarget ?? 7_500
        let snapshot = await LiveHealthService().todaySnapshot()
        await LiveWalkingLiveActivityService().start(goal: goal, initialSteps: snapshot.steps)
        return "Nuvyra yürüyüş odağı başlatıldı."
    }
}
