import Foundation

@MainActor
final class MealLoggingViewModel: ObservableObject {
    @Published var mealName = ""
    @Published var calories = 420
    @Published var protein = 24
    @Published var carbs = 42
    @Published var fat = 14
    @Published var selectedSource: MealSource = .manual
    @Published var estimateHint = ""
    @Published var estimate: MealEstimate?
    @Published var isEstimating = false
    @Published var errorMessage: String?

    var canSaveManual: Bool {
        !mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && calories > 0
    }

    func makeManualMeal() -> MealLog {
        MealLog(
            name: mealName.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            macros: MacroNutrients(proteinGrams: Double(protein), carbohydrateGrams: Double(carbs), fatGrams: Double(fat)),
            source: selectedSource,
            isEstimated: selectedSource != .manual
        )
    }

    func resetManualForm() {
        mealName = ""
        calories = 420
        protein = 24
        carbs = 42
        fat = 14
        selectedSource = .manual
    }

    func estimateMeal(imageData: Data?, service: FoodEstimationServicing) async {
        isEstimating = true
        errorMessage = nil
        do {
            estimate = try await service.estimateMeal(from: imageData, userHint: estimateHint)
        } catch {
            errorMessage = error.localizedDescription
        }
        isEstimating = false
    }
}
