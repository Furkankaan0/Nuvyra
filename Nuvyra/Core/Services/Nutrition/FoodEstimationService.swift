import Foundation

protocol FoodEstimationServicing {
    func estimateMeal(from imageData: Data?, userHint: String?) async throws -> MealEstimate
}

enum FoodEstimationError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Fotoğraftan tahmin şu an hazır değil. Değerleri manuel düzenleyebilirsin."
    }
}

struct MockFoodEstimationService: FoodEstimationServicing {
    func estimateMeal(from imageData: Data?, userHint: String?) async throws -> MealEstimate {
        try await Task.sleep(nanoseconds: 450_000_000)
        let normalizedHint = userHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = normalizedHint?.isEmpty == false ? normalizedHint! : "Tahmini ev yemeği tabağı"
        return MealEstimate(
            title: title,
            calories: 520,
            macros: MacroNutrients(proteinGrams: 28, carbohydrateGrams: 54, fatGrams: 18),
            confidence: 0.62,
            disclaimer: "Tahmini değer. Fotoğraf, porsiyon ve tarif farklarına göre düzenleyebilirsin."
        )
    }
}

struct UnavailableFoodEstimationService: FoodEstimationServicing {
    func estimateMeal(from imageData: Data?, userHint: String?) async throws -> MealEstimate {
        throw FoodEstimationError.unavailable
    }
}
