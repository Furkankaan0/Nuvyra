import Foundation

struct EstimatedMealResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let portion: String
    let confidence: Double
    let source: FoodEstimationSource
    let isEstimated: Bool
}

enum FoodEstimationSource: String, Codable {
    case mockTurkishNLP
    case photoAdapter
    case barcodeAdapter
    case cloudProvider
}

protocol FoodIntelligenceService {
    func estimateFromText(_ input: String, mealType: MealType) async throws -> [EstimatedMealResult]
}

struct MockFoodIntelligenceService: FoodIntelligenceService {
    func estimateFromText(_ input: String, mealType: MealType) async throws -> [EstimatedMealResult] {
        let normalizedInput = Self.normalized(input)
        let matches = QuickFood.turkishDefaults.filter { food in
            normalizedInput.contains(Self.normalized(food.name))
        }

        if !matches.isEmpty {
            return matches.map { food in
                EstimatedMealResult(
                    name: food.name,
                    calories: food.calories,
                    protein: food.protein,
                    carbs: food.carbs,
                    fat: food.fat,
                    portion: food.portion,
                    confidence: 0.82,
                    source: .mockTurkishNLP,
                    isEstimated: true
                )
            }
        }

        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return [] }
        return [
            EstimatedMealResult(
                name: cleanInput.capitalized(with: Locale(identifier: "tr_TR")),
                calories: 360,
                protein: 18,
                carbs: 38,
                fat: 14,
                portion: "1 porsiyon",
                confidence: 0.42,
                source: .mockTurkishNLP,
                isEstimated: true
            )
        ]
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .lowercased(with: Locale(identifier: "tr_TR"))
    }
}
