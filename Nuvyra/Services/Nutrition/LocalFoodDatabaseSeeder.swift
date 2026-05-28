import Foundation

/// Reads the versioned `LocalFoodDatabase.json` resource from the app bundle
/// and converts each entry into a rich `FoodItem`. The JSON schema is kept
/// simple and human-editable; this seeder fills in the catalog-side
/// boilerplate (UUID, `lastUpdated`, source attribution, verifiedLevel).
///
/// Every entry is marked `verifiedLevel: .approximate` and
/// `confidenceScore: 0.6` because these are crowd-curated estimates for
/// Turkish cuisine, not laboratory-measured values. UI badges driven by
/// `VerifiedLevel.shouldShowApproximateBadge` will surface this to the user.
enum LocalFoodDatabaseSeeder {

    /// Bumped whenever the JSON contents materially change. The SQLite layer
    /// stores the last-applied version in `PRAGMA user_version` and re-runs
    /// the seed only when this constant moves ahead.
    static let version: Int32 = 1

    static let resourceName = "LocalFoodDatabase"
    static let resourceExtension = "json"

    // MARK: - DTOs

    struct Database: Codable, Sendable {
        let version: Int
        let generatedAt: String?
        let foods: [Entry]
    }

    struct Entry: Codable, Sendable {
        let slug: String
        let name: String
        let nameTR: String
        let category: String?
        let subCategory: String?
        let servingSizes: [SizeDTO]?
        let nutritionPer100g: Nutrition
        let allergens: [String]?

        struct SizeDTO: Codable, Sendable {
            let label: String
            let labelTR: String?
            let grams: Double
            let isDefault: Bool?
        }

        struct Nutrition: Codable, Sendable {
            let calories: Int
            let protein: Double
            let carbs: Double
            let fat: Double
            let fiber: Double?
            let sodium: Double?
            let sugar: Double?
            let saturatedFat: Double?
        }
    }

    // MARK: - Public

    /// Loads the JSON, maps every row into a `FoodItem`. Throws if the
    /// resource is missing or malformed — callers (the SQLite seeder) treat
    /// this as a non-fatal warning and fall through to an empty seed.
    static func loadSeedFoods(bundle: Bundle = .main) throws -> [FoodItem] {
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw SeederError.missingResource
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let db = try decoder.decode(Database.self, from: data)
        return db.foods.map(makeFoodItem)
    }

    // MARK: - Mapping

    private static func makeFoodItem(from entry: Entry) -> FoodItem {
        let servings: [ServingSize] = (entry.servingSizes ?? [])
            .map { dto in
                ServingSize(
                    label: dto.label,
                    labelTR: dto.labelTR,
                    grams: max(1, dto.grams),
                    isDefault: dto.isDefault ?? false
                )
            }

        let resolvedServings: [ServingSize] = servings.isEmpty
            ? [.hundredGrams, .onePortion]
            : servings

        let nutrition = NutritionValues(
            calories: entry.nutritionPer100g.calories,
            protein: entry.nutritionPer100g.protein,
            carbs: entry.nutritionPer100g.carbs,
            fat: entry.nutritionPer100g.fat,
            fiber: entry.nutritionPer100g.fiber ?? 0,
            sodium: entry.nutritionPer100g.sodium ?? 0,
            sugar: entry.nutritionPer100g.sugar ?? 0,
            saturatedFat: entry.nutritionPer100g.saturatedFat ?? 0
        )

        let category = entry.category.flatMap { FoodCategory(rawValue: $0) } ?? .localTurkish
        let allergens = (entry.allergens ?? []).compactMap { Allergen(rawValue: $0) }

        return FoodItem(
            source: .estimated,
            externalID: "local:\(entry.slug)",
            name: entry.name,
            localizedNameTR: entry.nameTR,
            brand: nil,
            barcode: nil,
            imageURL: nil,
            category: category,
            subCategory: entry.subCategory,
            servingSizes: resolvedServings,
            nutritionPer100g: nutrition,
            micronutrients: nil,
            ingredients: nil,
            allergens: allergens,
            additives: [],
            nutriScore: nil,
            novaGroup: nil,
            verifiedLevel: .approximate,
            confidenceScore: 0.6
        )
    }

    enum SeederError: LocalizedError {
        case missingResource

        var errorDescription: String? {
            switch self {
            case .missingResource:
                return "LocalFoodDatabase.json kaynağı app bundle'da bulunamadı."
            }
        }
    }
}
