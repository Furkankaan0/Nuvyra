import Foundation

struct ServingSize: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let label: String
    let labelTR: String?
    let grams: Double
    let isDefault: Bool

    init(
        id: UUID = UUID(),
        label: String,
        labelTR: String? = nil,
        grams: Double,
        isDefault: Bool = false
    ) {
        self.id = id
        self.label = label
        self.labelTR = labelTR
        self.grams = grams
        self.isDefault = isDefault
    }

    var preferredLabel: String { labelTR ?? label }
}

extension ServingSize {
    /// Per-100g referans porsiyonu. `isDefault: false` — bir array'de yer
    /// alıyorsa default seçim olarak kazanmaz; "kültürel porsiyon" varsa
    /// (1 kase, 1 dilim, 1 adet) o tercih edilir. Sadece tek başına ServingSize
    /// olarak duruyorsa fallback olarak gözükür.
    static let hundredGrams = ServingSize(label: "100 g", labelTR: "100 g", grams: 100, isDefault: false)
    static let oneGram = ServingSize(label: "1 g", labelTR: "1 g", grams: 1)

    static let onePiece = ServingSize(label: "1 piece", labelTR: "1 adet", grams: 50)
    static let oneSlice = ServingSize(label: "1 slice", labelTR: "1 dilim", grams: 25)
    static let oneBowl = ServingSize(label: "1 bowl", labelTR: "1 kase", grams: 240)
    static let onePlate = ServingSize(label: "1 plate", labelTR: "1 tabak", grams: 300)
    static let oneGlass = ServingSize(label: "1 glass", labelTR: "1 bardak", grams: 200)
    static let onePortion = ServingSize(label: "1 serving", labelTR: "1 porsiyon", grams: 200, isDefault: true)
    static let oneTablespoon = ServingSize(label: "1 tbsp", labelTR: "1 yemek kaşığı", grams: 15)
    static let oneTeaspoon = ServingSize(label: "1 tsp", labelTR: "1 tatlı kaşığı", grams: 5)
    static let oneCup = ServingSize(label: "1 cup", labelTR: "1 kupa", grams: 240)
}

extension Array where Element == ServingSize {
    var defaultServing: ServingSize {
        first(where: { $0.isDefault }) ?? first ?? .hundredGrams
    }
}
