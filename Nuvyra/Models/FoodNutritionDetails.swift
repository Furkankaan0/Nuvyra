import Foundation

enum Allergen: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case gluten
    case dairy
    case egg
    case soy
    case peanut
    case treeNut
    case fish
    case shellfish
    case sesame
    case mustard
    case celery
    case sulfite
    case lupin
    case mollusc

    var id: String { rawValue }

    var displayLabelTR: String {
        switch self {
        case .gluten: "Gluten"
        case .dairy: "Süt / Laktoz"
        case .egg: "Yumurta"
        case .soy: "Soya"
        case .peanut: "Yer fıstığı"
        case .treeNut: "Sert kabuklu kuruyemiş"
        case .fish: "Balık"
        case .shellfish: "Kabuklu deniz ürünü"
        case .sesame: "Susam"
        case .mustard: "Hardal"
        case .celery: "Kereviz"
        case .sulfite: "Sülfit"
        case .lupin: "Acı bakla"
        case .mollusc: "Yumuşakça"
        }
    }

    /// Parse the comma-separated allergen tags Open Food Facts returns (e.g.
    /// "en:gluten, en:milk, en:soybeans"). Unknown tags are dropped silently.
    static func parse(offTags raw: String?) -> [Allergen] {
        guard let raw, !raw.isEmpty else { return [] }
        let tokens = raw
            .split(whereSeparator: { ",;|".contains($0) })
            .map { token -> String in
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let colon = trimmed.firstIndex(of: ":") {
                    return String(trimmed[trimmed.index(after: colon)...])
                }
                return trimmed
            }

        var result: [Allergen] = []
        var seen = Set<Allergen>()
        for token in tokens {
            guard let match = mapping[token] else { continue }
            if seen.insert(match).inserted { result.append(match) }
        }
        return result
    }

    private static let mapping: [String: Allergen] = [
        "gluten": .gluten,
        "wheat": .gluten,
        "milk": .dairy,
        "lactose": .dairy,
        "dairy": .dairy,
        "eggs": .egg,
        "egg": .egg,
        "soybeans": .soy,
        "soya": .soy,
        "soy": .soy,
        "peanuts": .peanut,
        "peanut": .peanut,
        "nuts": .treeNut,
        "tree-nuts": .treeNut,
        "almond": .treeNut,
        "hazelnut": .treeNut,
        "walnut": .treeNut,
        "fish": .fish,
        "crustaceans": .shellfish,
        "shellfish": .shellfish,
        "molluscs": .mollusc,
        "sesame-seeds": .sesame,
        "sesame": .sesame,
        "mustard": .mustard,
        "celery": .celery,
        "sulphur-dioxide-and-sulphites": .sulfite,
        "sulfites": .sulfite,
        "lupin": .lupin
    ]
}

enum NutriScore: String, Codable, CaseIterable, Hashable, Sendable {
    case a, b, c, d, e

    init?(rawTag: String?) {
        guard let lower = rawTag?.lowercased() else { return nil }
        let stripped = lower.hasPrefix("en:") ? String(lower.dropFirst(3)) : lower
        self.init(rawValue: stripped)
    }

    var displayLabel: String { rawValue.uppercased() }
}

enum NovaGroup: Int, Codable, CaseIterable, Hashable, Sendable {
    case unprocessed = 1
    case processedIngredient = 2
    case processed = 3
    case ultraProcessed = 4

    init?(value: Int?) {
        guard let value, let mapped = NovaGroup(rawValue: value) else { return nil }
        self = mapped
    }

    var displayLabelTR: String {
        switch self {
        case .unprocessed: "İşlenmemiş"
        case .processedIngredient: "İşlenmiş içerik"
        case .processed: "İşlenmiş gıda"
        case .ultraProcessed: "Ultra işlenmiş"
        }
    }
}

/// Caller-facing confidence tier. The numeric `confidenceScore` on `FoodItem`
/// drives the chip color, this enum drives the wording shown to the user.
enum VerifiedLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case verified
    case approximate
    case userCreated
    case unverified

    var displayLabelTR: String {
        switch self {
        case .verified: "Doğrulanmış"
        case .approximate: "Yaklaşık değer"
        case .userCreated: "Kullanıcı tarafından eklendi"
        case .unverified: "Doğrulanmamış"
        }
    }

    var shouldShowApproximateBadge: Bool {
        self == .approximate || self == .unverified
    }
}

/// Optional per-100g micronutrient panel. Every field is `Double?` so callers
/// can distinguish "not measured" from "measured zero".
struct Micronutrients: Codable, Hashable, Sendable {
    var calciumMg: Double?
    var ironMg: Double?
    var magnesiumMg: Double?
    var phosphorusMg: Double?
    var potassiumMg: Double?
    var zincMg: Double?

    var vitaminAUg: Double?
    var vitaminCMg: Double?
    var vitaminDUg: Double?
    var vitaminEMg: Double?
    var vitaminKUg: Double?
    var vitaminB1Mg: Double?
    var vitaminB2Mg: Double?
    var vitaminB3Mg: Double?
    var vitaminB6Mg: Double?
    var folateUg: Double?
    var vitaminB12Ug: Double?

    var cholesterolMg: Double?

    static let empty = Micronutrients()

    var hasAnyValue: Bool {
        let scalars: [Double?] = [
            calciumMg, ironMg, magnesiumMg, phosphorusMg, potassiumMg, zincMg,
            vitaminAUg, vitaminCMg, vitaminDUg, vitaminEMg, vitaminKUg,
            vitaminB1Mg, vitaminB2Mg, vitaminB3Mg, vitaminB6Mg, folateUg, vitaminB12Ug,
            cholesterolMg
        ]
        return scalars.contains(where: { $0 != nil })
    }
}
