import Foundation

/// Bir `FoodItem` + seçilen porsiyon + miktarı taşıyan değer nesnesi.
/// Search/detail akışı tamamlandığında `FoodSearchView`'ın `onSelect`'i
/// bunu döner; çağrılan tarafı (NutritionViewModel) `MealEntry`'ye çevirir.
struct FoodSelection: Hashable, Sendable {
    let item: FoodItem
    let values: NutritionValues
    let serving: ServingSize
    let quantity: Double

    /// "1 kase" / "2 × 1 dilim" gibi `MealEntry.portionDescription` için
    /// kullanıma hazır kısa açıklama.
    var portionDescription: String {
        let qty = quantity == quantity.rounded()
            ? String(Int(quantity))
            : String(format: "%.1f", quantity)
        if quantity == 1 {
            return serving.preferredLabel
        }
        return "\(qty) × \(serving.preferredLabel)"
    }

    /// `FoodItem.deterministicRowID`'ye delege — `recordUse` / `setFavorite`
    /// için içerikten türetilen kimlik.
    var deterministicRowID: Int64? { item.deterministicRowID }
}
