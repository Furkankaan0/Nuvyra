import Foundation

// MARK: - From local FTS / remote search rows

extension FoodItem {
    /// Lift a thin search row into the rich catalog type. The resulting
    /// `FoodItem` is intentionally conservative on missing fields — anything
    /// we do not have from the search payload is left nil / default rather
    /// than fabricated.
    static func from(searchResult result: FoodSearchResult) -> FoodItem {
        let calories = max(0, result.calories)

        let detailServing: ServingSize? = {
            let trimmed = result.servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.lowercased() != "100 g" else { return nil }
            return ServingSize(label: trimmed, labelTR: trimmed, grams: 100, isDefault: true)
        }()

        var servings: [ServingSize] = [.hundredGrams]
        if let detail = detailServing { servings.append(detail) }

        let verified: VerifiedLevel = {
            switch result.source {
            case .manual: return .userCreated
            case .estimated, .cache: return .approximate
            case .openFoodFacts, .usda, .fatSecret:
                return result.isVerified ? .verified : .unverified
            }
        }()

        let confidence: Double = {
            switch result.source {
            case .manual: return 0.9
            case .openFoodFacts: return result.isVerified ? 0.85 : 0.65
            case .usda: return result.isVerified ? 0.85 : 0.65
            case .fatSecret: return 0.75
            case .cache: return 0.7
            case .estimated: return 0.4
            }
        }()

        return FoodItem(
            source: result.source,
            externalID: result.externalID,
            name: result.name,
            localizedNameTR: result.name,
            brand: result.brand,
            barcode: nil,
            imageURL: result.imageURL,
            servingSizes: servings,
            nutritionPer100g: NutritionValues(
                calories: calories,
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                fiber: result.fiber ?? 0
            ),
            verifiedLevel: verified,
            confidenceScore: confidence
        )
    }
}

// MARK: - From barcode scanner payload

extension FoodItem {
    static func from(scannedProduct product: ScannedProduct, category: FoodCategory? = nil) -> FoodItem {
        // Phase 13.5 — ScannedProduct OFF'tan gelen gerçek porsiyon bilgisini
        // taşıyorsa onu kullan; yoksa generic 1 porsiyon (200 g) fallback.
        let servings: [ServingSize] = {
            if let grams = product.servingGrams, grams > 0 {
                let label = product.servingLabel?.nonEmptyTrimmed ?? "1 porsiyon"
                return [
                    .hundredGrams,
                    ServingSize(label: label, labelTR: label, grams: grams, isDefault: true)
                ]
            }
            return [.hundredGrams, .onePortion]
        }()

        return FoodItem(
            source: product.source,
            externalID: product.barcode,
            name: product.name,
            localizedNameTR: product.name,
            brand: product.brand,
            barcode: product.barcode,
            imageURL: product.imageURL,
            category: category,
            servingSizes: servings,
            nutritionPer100g: NutritionValues(
                calories: Int(product.caloriesPer100g.rounded()),
                protein: product.protein,
                carbs: product.carbs,
                fat: product.fat,
                fiber: product.fiber ?? 0,
                sodium: product.sodium ?? 0,
                sugar: product.sugar ?? 0,
                saturatedFat: product.saturatedFat ?? 0
            ),
            verifiedLevel: product.source == .manual ? .userCreated : .verified,
            confidenceScore: product.source == .manual ? 0.9 : 0.85,
            lastUpdated: product.fetchedAt
        )
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Lightweight FTS row out

extension FoodItem {
    /// Project this catalog entry back into a `FoodSearchRecord` so the SQLite
    /// FTS layer can index it (Phase 3 will route remote hits through here for
    /// write-through caching).
    func toSearchRecord(id rowID: Int64? = nil) -> FoodSearchRecord {
        let portionLabel = servingSizes.first(where: { !$0.isDefault })?.preferredLabel
            ?? defaultServing.preferredLabel

        let categoryKeywords: String = {
            guard let category else { return "" }
            return "\(category.displayLabelTR) \(category.displayLabelEN)"
        }()

        let allergenKeywords = allergens.map(\.rawValue).joined(separator: " ")
        let brandKeywords = brand ?? ""
        let trKeywords = localizedNameTR ?? ""

        let keywords = [name, trKeywords, brandKeywords, categoryKeywords, allergenKeywords]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return FoodSearchRecord(
            id: rowID,
            name: preferredDisplayName,
            brand: brand,
            calories: caloriesPer100g,
            protein: proteinPer100g,
            carbs: carbsPer100g,
            fat: fatPer100g,
            fiber: fiberPer100g,
            sodium: sodiumPer100g,
            sugar: sugarPer100g,
            saturatedFat: saturatedFatPer100g,
            servingDescription: portionLabel,
            keywords: keywords
        )
    }
}

// MARK: - User-created food

extension FoodItem {
    /// Constructor used by the "manual add" flow. `verifiedLevel` is locked to
    /// `.userCreated` so the UI can tag it accordingly.
    static func userCreated(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        category: FoodCategory? = nil,
        servingSizes: [ServingSize] = [.hundredGrams, .onePortion],
        nutritionPer100g: NutritionValues,
        ingredients: String? = nil,
        imageURL: URL? = nil
    ) -> FoodItem {
        FoodItem(
            source: .manual,
            externalID: nil,
            name: name,
            localizedNameTR: name,
            brand: brand,
            barcode: barcode,
            imageURL: imageURL,
            category: category,
            servingSizes: servingSizes,
            nutritionPer100g: nutritionPer100g,
            ingredients: ingredients,
            verifiedLevel: .userCreated,
            confidenceScore: 0.9
        )
    }
}
