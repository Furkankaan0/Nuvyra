import Foundation

/// Reference catalog entry — base nutrition values per 100 g (or per piece) that the
/// user can scale into a logged `MealEntry` via a portion picker.
struct FoodItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let baseUnit: PortionUnit
    let baseQuantity: Double
    let baseValues: NutritionValues
    let defaultPortionDescription: String

    init(
        id: UUID = UUID(),
        name: String,
        baseUnit: PortionUnit = .grams,
        baseQuantity: Double = 100,
        baseValues: NutritionValues,
        defaultPortionDescription: String = "1 porsiyon"
    ) {
        self.id = id
        self.name = name
        self.baseUnit = baseUnit
        self.baseQuantity = baseQuantity
        self.baseValues = baseValues
        self.defaultPortionDescription = defaultPortionDescription
    }

    /// Scale base values to a user-chosen quantity in the same `baseUnit`.
    func values(forQuantity quantity: Double) -> NutritionValues {
        guard baseQuantity > 0 else { return baseValues }
        return baseValues.scaled(by: quantity / baseQuantity)
    }
}

extension FoodItem {
    init(quickFood: QuickFood) {
        self.init(
            name: quickFood.name,
            baseUnit: .portion,
            baseQuantity: 1,
            baseValues: NutritionValues(
                calories: quickFood.calories,
                protein: quickFood.protein,
                carbs: quickFood.carbs,
                fat: quickFood.fat
            ),
            defaultPortionDescription: quickFood.portion
        )
    }
}
