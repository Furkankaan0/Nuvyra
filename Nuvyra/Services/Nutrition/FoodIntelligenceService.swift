import Foundation

/// AI/heuristic tabanlı canlı tahmin sonucu. Tüm besin değerleri **100 g
/// başına** normalize edilmiştir; `portionGrams` ile kullanıcının gördüğü
/// kültürel porsiyonun (1 kase, 1 dilim, 1 lahmacun…) gerçek gram karşılığı
/// taşınır. Caller (AddFoodView) `FoodItem.servingSizes` üzerinde bu iki
/// referansla doğru ölçeklemeyi yapar.
struct EstimatedMealResult: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let portion: String
    let portionGrams: Double

    // Per-100g makro + temel "ikincil" makrolar
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let sodium: Double?
    let sugar: Double?
    let saturatedFat: Double?

    let confidence: Double
    let source: FoodEstimationSource
    let isEstimated: Bool

    init(
        name: String,
        portion: String,
        portionGrams: Double,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        sodium: Double? = nil,
        sugar: Double? = nil,
        saturatedFat: Double? = nil,
        confidence: Double,
        source: FoodEstimationSource,
        isEstimated: Bool = true
    ) {
        self.name = name
        self.portion = portion
        self.portionGrams = max(1, portionGrams)
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
        self.saturatedFat = saturatedFat
        self.confidence = confidence
        self.source = source
        self.isEstimated = isEstimated
    }
}

enum FoodEstimationSource: String, Codable {
    case localTurkishNLP
    case photoAdapter
    case barcodeAdapter
    case cloudProvider
}

protocol FoodIntelligenceService {
    func estimateFromText(_ input: String, mealType: MealType) async throws -> [EstimatedMealResult]
}

struct MockFoodIntelligenceService: FoodIntelligenceService {
    func estimateFromText(_ input: String, mealType: MealType) async throws -> [EstimatedMealResult] {
        try await LocalFoodIntelligenceService().estimateFromText(input, mealType: mealType)
    }
}

struct LocalFoodIntelligenceService: FoodIntelligenceService {
    func estimateFromText(_ input: String, mealType: MealType) async throws -> [EstimatedMealResult] {
        let normalizedInput = Self.normalized(input)
        let matches = QuickFood.turkishDefaults.filter { food in
            normalizedInput.contains(Self.normalized(food.name))
        }

        if !matches.isEmpty {
            return matches.map { food in
                // QuickFood "porsiyon başına" değerleri taşır → per-100g'e çevir.
                // Kültürel porsiyonların yaklaşık gram karşılığı tahmini olarak
                // 200 g alınır (çorba kasesi ~240, ana yemek tabağı ~250, ortalama).
                let portionGrams: Double = Self.commonPortionGrams(forName: food.name, fallback: 200)
                let factor = portionGrams > 0 ? 100 / portionGrams : 1
                return EstimatedMealResult(
                    name: food.name,
                    portion: food.portion,
                    portionGrams: portionGrams,
                    calories: Int((Double(food.calories) * factor).rounded()),
                    protein: food.protein * factor,
                    carbs: food.carbs * factor,
                    fat: food.fat * factor,
                    confidence: 0.82,
                    source: .localTurkishNLP
                )
            }
        }

        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return [] }
        // Çok genel fallback — kullanıcıya "boş bırakmaktansa düşük güvenle
        // bir başlangıç değeri" göster, formdan düzenlemesini bekle.
        return [
            EstimatedMealResult(
                name: cleanInput.capitalized(with: Locale(identifier: "tr_TR")),
                portion: "1 porsiyon",
                portionGrams: 200,
                calories: 180,
                protein: 9,
                carbs: 19,
                fat: 7,
                confidence: 0.42,
                source: .localTurkishNLP
            )
        ]
    }

    /// Yaygın Türk porsiyon → gram dönüşümleri. QuickFood'da explicit gram
    /// yok; isim ipuçlarından heuristik tahmin yaparız.
    private static func commonPortionGrams(forName name: String, fallback: Double) -> Double {
        let normalized = name.lowercased(with: Locale(identifier: "tr_TR"))
        if normalized.contains("çorba") { return 240 }
        if normalized.contains("ekmek") || normalized.contains("simit") { return 60 }
        if normalized.contains("ayran") || normalized.contains("kefir") || normalized.contains("süt") { return 240 }
        if normalized.contains("yumurta") { return 50 }
        if normalized.contains("pilav") || normalized.contains("bulgur") { return 180 }
        if normalized.contains("salata") { return 150 }
        if normalized.contains("döner") || normalized.contains("kebap") { return 220 }
        if normalized.contains("baklava") || normalized.contains("sütlaç") || normalized.contains("tatlı") { return 100 }
        if normalized.contains("çay") || normalized.contains("kahve") { return 120 }
        return fallback
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .lowercased(with: Locale(identifier: "tr_TR"))
    }
}
