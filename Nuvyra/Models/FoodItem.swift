import Foundation

/// Catalog entry returned by the food repository — the rich, source-attributed
/// reference that downstream `MealEntry` instances are derived from. All
/// nutrition values are stored per-100 g; UI layers scale them through
/// `values(for:quantity:)` once the user picks a serving.
struct FoodItem: Identifiable, Hashable, Codable, Sendable {

    // MARK: - Identity & provenance

    let id: UUID
    let source: ProductSource
    /// Stable identifier inside the originating source: OFF barcode/code,
    /// USDA fdcId, FatSecret food id. Nil for fully local or user-created rows.
    let externalID: String?

    // MARK: - Display

    let name: String
    let localizedNameTR: String?
    let brand: String?
    let barcode: String?
    let imageURL: URL?

    // MARK: - Taxonomy

    let category: FoodCategory?
    let subCategory: String?

    // MARK: - Portions

    /// Ordered: 100 g first, then most natural human portion last.
    let servingSizes: [ServingSize]

    // MARK: - Nutrition (per 100 g)

    let nutritionPer100g: NutritionValues
    let micronutrients: Micronutrients?

    // MARK: - Composition

    let ingredients: String?
    let allergens: [Allergen]
    let additives: [String]
    let nutriScore: NutriScore?
    let novaGroup: NovaGroup?

    // MARK: - Quality

    let verifiedLevel: VerifiedLevel
    /// 0...1. Drives the chip color and ranks duplicates from different sources.
    let confidenceScore: Double
    let lastUpdated: Date

    init(
        id: UUID = UUID(),
        source: ProductSource,
        externalID: String? = nil,
        name: String,
        localizedNameTR: String? = nil,
        brand: String? = nil,
        barcode: String? = nil,
        imageURL: URL? = nil,
        category: FoodCategory? = nil,
        subCategory: String? = nil,
        servingSizes: [ServingSize] = [.hundredGrams],
        nutritionPer100g: NutritionValues,
        micronutrients: Micronutrients? = nil,
        ingredients: String? = nil,
        allergens: [Allergen] = [],
        additives: [String] = [],
        nutriScore: NutriScore? = nil,
        novaGroup: NovaGroup? = nil,
        verifiedLevel: VerifiedLevel = .unverified,
        confidenceScore: Double = 0.5,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.externalID = externalID
        self.name = name
        self.localizedNameTR = localizedNameTR
        self.brand = brand
        self.barcode = barcode
        self.imageURL = imageURL
        self.category = category
        self.subCategory = subCategory
        self.servingSizes = servingSizes.isEmpty ? [.hundredGrams] : servingSizes
        self.nutritionPer100g = nutritionPer100g
        self.micronutrients = micronutrients
        self.ingredients = ingredients
        self.allergens = allergens
        self.additives = additives
        self.nutriScore = nutriScore
        self.novaGroup = novaGroup
        self.verifiedLevel = verifiedLevel
        self.confidenceScore = max(0, min(1, confidenceScore))
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Display helpers

extension FoodItem {
    var preferredDisplayName: String { localizedNameTR ?? name }

    var caloriesPer100g: Int { nutritionPer100g.calories }
    var proteinPer100g: Double { nutritionPer100g.protein }
    var carbsPer100g: Double { nutritionPer100g.carbs }
    var fatPer100g: Double { nutritionPer100g.fat }
    var fiberPer100g: Double { nutritionPer100g.fiber }
    var sugarPer100g: Double { nutritionPer100g.sugar }
    var sodiumPer100g: Double { nutritionPer100g.sodium }
    var saturatedFatPer100g: Double { nutritionPer100g.saturatedFat }

    var defaultServing: ServingSize { servingSizes.defaultServing }

    var showsApproximateBadge: Bool { verifiedLevel.shouldShowApproximateBadge }
}

// MARK: - Portion scaling

extension FoodItem {
    /// Scale 100 g base values to the chosen serving × quantity. `quantity` is
    /// the user-picked count for that serving (e.g. 2 of a "1 dilim" serving).
    func values(for serving: ServingSize, quantity: Double) -> NutritionValues {
        let totalGrams = max(0, serving.grams * quantity)
        return nutritionPer100g.scaled(by: totalGrams / 100)
    }

    /// Convenience for direct gram-based scaling.
    func valuesForGrams(_ grams: Double) -> NutritionValues {
        nutritionPer100g.scaled(by: max(0, grams) / 100)
    }
}

// MARK: - SQLite identity

extension FoodItem {
    /// SQLite rowID — `FoodRepository.recordUse` / `setFavorite` / `isFavorite`
    /// için içerikten türetilebilir kimlik. Manuel item'lar (.manual source)
    /// için nil (rowID'leri AUTOINCREMENT olduğu için stable değil).
    var deterministicRowID: Int64? {
        guard let externalID,
              source != .manual,
              !externalID.isEmpty else { return nil }
        return FoodSearchResult.remoteID(source: source, externalID: externalID)
    }
}

// MARK: - Source ranking

extension FoodItem {
    /// Used by `FoodRepository` when the same logical product surfaces from
    /// multiple providers and one must win. Higher = preferred.
    var rankingScore: Double {
        let sourceWeight: Double = {
            switch source {
            case .manual: return 1.0
            case .cache: return 0.85
            case .openFoodFacts: return 0.8
            case .usda: return 0.75
            case .fatSecret: return 0.7
            case .estimated: return 0.3
            }
        }()
        let verifiedWeight: Double = {
            switch verifiedLevel {
            case .verified: return 1.0
            case .userCreated: return 0.9
            case .approximate: return 0.6
            case .unverified: return 0.5
            }
        }()
        return sourceWeight * 0.5 + verifiedWeight * 0.3 + confidenceScore * 0.2
    }
}

// MARK: - Backward compatibility

extension FoodItem {
    /// Legacy entry point used by `QuickFood` seeded into the catalog. The
    /// `grams: 100` on the portion serving is intentional — QuickFood ships
    /// calories that are already per-serving, and the new per-100g convention
    /// only matches the display when (serving.grams / 100) × quantity == 1.
    init(quickFood: QuickFood) {
        self.init(
            source: .manual,
            name: quickFood.name,
            localizedNameTR: quickFood.name,
            category: .localTurkish,
            servingSizes: [
                .hundredGrams,
                ServingSize(label: quickFood.portion, labelTR: quickFood.portion, grams: 100, isDefault: true)
            ],
            nutritionPer100g: NutritionValues(
                calories: quickFood.calories,
                protein: quickFood.protein,
                carbs: quickFood.carbs,
                fat: quickFood.fat
            ),
            verifiedLevel: .approximate,
            confidenceScore: 0.55
        )
    }
}
