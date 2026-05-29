import Foundation

/// Phase 12 — Apple Health'ten okunan bir öğün kaydı. Birden fazla
/// HKQuantitySample (dietaryEnergy, protein, carbs, fat, fiber) aynı
/// timestamp + source altında gruplanır ve bu yapıya çevrilir. Caller
/// (NutritionViewModel) kullanıcının onayıyla bunu `MealEntry`'ye dönüştürür.
struct ImportedDietarySample: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let date: Date
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let sodium: Double?
    let sugar: Double?
    let saturatedFat: Double?
    let sourceName: String
    let sourceBundleID: String?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date,
        calories: Int,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double? = nil,
        sodium: Double? = nil,
        sugar: Double? = nil,
        saturatedFat: Double? = nil,
        sourceName: String,
        sourceBundleID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sodium = sodium
        self.sugar = sugar
        self.saturatedFat = saturatedFat
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
    }

    /// MealType, saat bandına göre tahmin edilir — kullanıcı içe aktarma
    /// onayında düzeltebilir. Apple Health metadata'sında meal type alanı yok.
    var inferredMealType: MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }
}
