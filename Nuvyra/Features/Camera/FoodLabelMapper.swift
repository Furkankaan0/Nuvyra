import Foundation

/// Maps raw vision labels (English/ImageNet style) to Turkish `EstimatedMealResult`s with
/// average calorie + macro estimates. Falls back to a generic "Tahmini öğün" entry for
/// unrecognised labels so the user can still log + edit the values.
struct FoodLabelMapper {
    private static let normalizedTable: [String: FoodTemplate] = {
        var dict: [String: FoodTemplate] = [:]
        for entry in catalog {
            for key in entry.matchKeys {
                dict[normalize(key)] = entry
            }
        }
        return dict
    }()

    /// Maps a single detection to a candidate meal result.
    func map(_ detection: CameraDetection) -> EstimatedMealResult {
        let normalizedLabel = Self.normalize(detection.label)
        let template = Self.lookup(normalizedLabel: normalizedLabel)
        let confidence = adjustedConfidence(detection.confidence, hasMatch: template != nil)
        return template?.toResult(confidence: confidence)
            ?? EstimatedMealResult(
                name: prettify(detection.label),
                calories: 320,
                protein: 16,
                carbs: 36,
                fat: 12,
                portion: "1 porsiyon",
                confidence: confidence,
                source: .photoAdapter,
                isEstimated: true
            )
    }

    /// Maps an array of detections, deduplicates by name (best confidence wins) and
    /// sorts by confidence descending.
    func map(_ detections: [CameraDetection], maxResults: Int = 4) -> [EstimatedMealResult] {
        var seen: [String: EstimatedMealResult] = [:]
        for detection in detections {
            let result = map(detection)
            if let existing = seen[result.name], existing.confidence >= result.confidence { continue }
            seen[result.name] = result
        }
        return Array(seen.values.sorted { $0.confidence > $1.confidence }.prefix(maxResults))
    }

    // MARK: - Helpers

    private func adjustedConfidence(_ rawConfidence: Float, hasMatch: Bool) -> Double {
        let value = Double(rawConfidence)
        // For unrecognised labels we cap confidence at 0.45 so the UI signals it's a guess.
        return hasMatch ? min(max(value, 0.30), 0.95) : min(value, 0.45)
    }

    private func prettify(_ label: String) -> String {
        let lower = label.replacingOccurrences(of: "_", with: " ")
        return lower.capitalized(with: Locale(identifier: "tr_TR"))
    }

    static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .lowercased(with: Locale(identifier: "en_US"))
            .trimmingCharacters(in: .whitespaces)
    }

    private static func lookup(normalizedLabel: String) -> FoodTemplate? {
        if let direct = normalizedTable[normalizedLabel] { return direct }
        // Try substring match — many vision labels are multi-word ("breakfast burrito" → match "burrito").
        for (key, template) in normalizedTable where normalizedLabel.contains(key) {
            return template
        }
        return nil
    }
}

// MARK: - Catalog

private struct FoodTemplate {
    let displayName: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let portion: String
    let matchKeys: [String]

    func toResult(confidence: Double) -> EstimatedMealResult {
        EstimatedMealResult(
            name: displayName,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            portion: portion,
            confidence: confidence,
            source: .photoAdapter,
            isEstimated: true
        )
    }
}

// Curated catalog of common Vision/ImageNet labels that may surface from food photos.
// Values are average per typical serving; the user can adjust before saving.
private let catalog: [FoodTemplate] = [
    // Bread / starch
    FoodTemplate(displayName: "Pizza", calories: 285, protein: 12, carbs: 36, fat: 10, portion: "1 dilim", matchKeys: ["pizza"]),
    FoodTemplate(displayName: "Hamburger", calories: 540, protein: 25, carbs: 40, fat: 27, portion: "1 adet", matchKeys: ["hamburger", "cheeseburger"]),
    FoodTemplate(displayName: "Sandviç", calories: 320, protein: 14, carbs: 36, fat: 12, portion: "1 adet", matchKeys: ["sandwich", "panini", "submarine"]),
    FoodTemplate(displayName: "Hot dog", calories: 290, protein: 11, carbs: 25, fat: 17, portion: "1 adet", matchKeys: ["hot dog", "hotdog"]),
    FoodTemplate(displayName: "Burrito", calories: 520, protein: 22, carbs: 60, fat: 18, portion: "1 adet", matchKeys: ["burrito"]),
    FoodTemplate(displayName: "Taco", calories: 220, protein: 9, carbs: 18, fat: 11, portion: "1 adet", matchKeys: ["taco"]),
    FoodTemplate(displayName: "Bagel", calories: 280, protein: 11, carbs: 56, fat: 2, portion: "1 adet", matchKeys: ["bagel"]),
    FoodTemplate(displayName: "Simit", calories: 360, protein: 10, carbs: 68, fat: 7, portion: "1 adet", matchKeys: ["simit", "pretzel"]),
    FoodTemplate(displayName: "Ekmek", calories: 240, protein: 8, carbs: 48, fat: 2, portion: "2 dilim", matchKeys: ["bread", "loaf", "french loaf", "baguette"]),
    FoodTemplate(displayName: "Pilav", calories: 280, protein: 5, carbs: 58, fat: 4, portion: "1 tabak", matchKeys: ["rice", "fried rice", "pilaf"]),
    FoodTemplate(displayName: "Makarna", calories: 350, protein: 12, carbs: 65, fat: 5, portion: "1 tabak", matchKeys: ["pasta", "spaghetti", "carbonara", "lasagna", "lasagne"]),
    FoodTemplate(displayName: "Patates kızartması", calories: 365, protein: 4, carbs: 48, fat: 17, portion: "1 porsiyon", matchKeys: ["french fries", "fries", "potato", "mashed potato"]),

    // Proteins
    FoodTemplate(displayName: "Izgara tavuk", calories: 360, protein: 48, carbs: 4, fat: 14, portion: "1 porsiyon", matchKeys: ["chicken", "rotisserie", "grilled chicken", "drumstick"]),
    FoodTemplate(displayName: "Köfte", calories: 320, protein: 24, carbs: 8, fat: 22, portion: "1 porsiyon", matchKeys: ["meatball", "meatballs", "kofta", "kofte"]),
    FoodTemplate(displayName: "Tavuk döner", calories: 520, protein: 36, carbs: 52, fat: 18, portion: "1 porsiyon", matchKeys: ["doner", "kebab", "shawarma", "gyro"]),
    FoodTemplate(displayName: "Balık", calories: 220, protein: 28, carbs: 0, fat: 11, portion: "1 porsiyon", matchKeys: ["fish", "salmon", "tuna", "cod", "trout"]),
    FoodTemplate(displayName: "Yumurta", calories: 156, protein: 12, carbs: 1, fat: 11, portion: "2 adet", matchKeys: ["egg", "eggs", "scrambled eggs", "fried egg"]),
    FoodTemplate(displayName: "Menemen", calories: 330, protein: 18, carbs: 12, fat: 22, portion: "1 tabak", matchKeys: ["menemen", "shakshuka"]),
    FoodTemplate(displayName: "Steak", calories: 480, protein: 42, carbs: 0, fat: 32, portion: "1 porsiyon", matchKeys: ["steak", "beef", "ribeye"]),

    // Salads & soups
    FoodTemplate(displayName: "Salata", calories: 180, protein: 5, carbs: 14, fat: 12, portion: "1 tabak", matchKeys: ["salad", "caesar"]),
    FoodTemplate(displayName: "Mercimek çorbası", calories: 210, protein: 11, carbs: 31, fat: 6, portion: "1 kase", matchKeys: ["soup", "lentil"]),

    // Dairy & breakfast
    FoodTemplate(displayName: "Yoğurt", calories: 120, protein: 8, carbs: 9, fat: 5, portion: "1 kase", matchKeys: ["yogurt", "yoghurt"]),
    FoodTemplate(displayName: "Peynir", calories: 110, protein: 7, carbs: 1, fat: 9, portion: "1 dilim", matchKeys: ["cheese", "feta", "cheddar"]),
    FoodTemplate(displayName: "Süt", calories: 105, protein: 8, carbs: 12, fat: 3, portion: "1 bardak", matchKeys: ["milk"]),

    // Fruits
    FoodTemplate(displayName: "Elma", calories: 95, protein: 0, carbs: 25, fat: 0, portion: "1 adet", matchKeys: ["apple", "granny smith"]),
    FoodTemplate(displayName: "Muz", calories: 105, protein: 1, carbs: 27, fat: 0, portion: "1 adet", matchKeys: ["banana"]),
    FoodTemplate(displayName: "Portakal", calories: 70, protein: 1, carbs: 18, fat: 0, portion: "1 adet", matchKeys: ["orange"]),
    FoodTemplate(displayName: "Üzüm", calories: 100, protein: 1, carbs: 27, fat: 0, portion: "1 salkım", matchKeys: ["grape", "grapes"]),
    FoodTemplate(displayName: "Çilek", calories: 50, protein: 1, carbs: 12, fat: 0, portion: "1 kase", matchKeys: ["strawberry"]),
    FoodTemplate(displayName: "Karpuz", calories: 90, protein: 2, carbs: 22, fat: 0, portion: "1 dilim", matchKeys: ["watermelon"]),
    FoodTemplate(displayName: "Avokado", calories: 240, protein: 3, carbs: 12, fat: 22, portion: "1 adet", matchKeys: ["avocado", "guacamole"]),
    FoodTemplate(displayName: "Limon", calories: 17, protein: 1, carbs: 5, fat: 0, portion: "1 adet", matchKeys: ["lemon"]),

    // Vegetables
    FoodTemplate(displayName: "Brokoli", calories: 55, protein: 4, carbs: 11, fat: 0, portion: "1 porsiyon", matchKeys: ["broccoli"]),
    FoodTemplate(displayName: "Domates", calories: 25, protein: 1, carbs: 5, fat: 0, portion: "1 adet", matchKeys: ["tomato"]),
    FoodTemplate(displayName: "Salatalık", calories: 16, protein: 1, carbs: 4, fat: 0, portion: "1 adet", matchKeys: ["cucumber"]),
    FoodTemplate(displayName: "Mantar", calories: 25, protein: 3, carbs: 4, fat: 0, portion: "1 porsiyon", matchKeys: ["mushroom"]),

    // Sweets & drinks
    FoodTemplate(displayName: "Dondurma", calories: 270, protein: 4, carbs: 31, fat: 14, portion: "1 top", matchKeys: ["ice cream", "icecream", "gelato"]),
    FoodTemplate(displayName: "Çikolata", calories: 230, protein: 3, carbs: 25, fat: 14, portion: "1 dilim", matchKeys: ["chocolate", "brownie"]),
    FoodTemplate(displayName: "Kek", calories: 320, protein: 4, carbs: 48, fat: 12, portion: "1 dilim", matchKeys: ["cake", "cupcake"]),
    FoodTemplate(displayName: "Donut", calories: 250, protein: 3, carbs: 31, fat: 13, portion: "1 adet", matchKeys: ["donut", "doughnut"]),
    FoodTemplate(displayName: "Tatlı", calories: 380, protein: 4, carbs: 52, fat: 18, portion: "1 porsiyon", matchKeys: ["dessert", "trifle", "strudel", "tiramisu", "cheesecake"]),
    FoodTemplate(displayName: "Kahve", calories: 5, protein: 0, carbs: 1, fat: 0, portion: "1 fincan", matchKeys: ["coffee", "espresso", "cappuccino", "latte"]),
    FoodTemplate(displayName: "Çay şekersiz", calories: 0, protein: 0, carbs: 0, fat: 0, portion: "1 bardak", matchKeys: ["tea"]),
    FoodTemplate(displayName: "Ayran", calories: 80, protein: 5, carbs: 6, fat: 3, portion: "1 bardak", matchKeys: ["ayran", "buttermilk"]),
    FoodTemplate(displayName: "Meyve suyu", calories: 110, protein: 0, carbs: 27, fat: 0, portion: "1 bardak", matchKeys: ["juice", "smoothie"]),

    // Mixed plate fallbacks (Apple Vision common labels)
    FoodTemplate(displayName: "Karışık tabak", calories: 480, protein: 22, carbs: 56, fat: 18, portion: "1 tabak", matchKeys: ["plate", "dish", "meal", "buffet"])
]
