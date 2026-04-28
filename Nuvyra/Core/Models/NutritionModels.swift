import Foundation

struct MacroNutrients: Codable, Equatable {
    var proteinGrams: Double
    var carbohydrateGrams: Double
    var fatGrams: Double

    static let empty = MacroNutrients(proteinGrams: 0, carbohydrateGrams: 0, fatGrams: 0)

    var summary: String {
        "P \(proteinGrams.roundedInt)g / K \(carbohydrateGrams.roundedInt)g / Y \(fatGrams.roundedInt)g"
    }
}

struct MealLog: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var calories: Int
    var macros: MacroNutrients
    var loggedAt: Date
    var source: MealSource
    var imageLocalIdentifier: String?
    var isEstimated: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        macros: MacroNutrients,
        loggedAt: Date = Date(),
        source: MealSource,
        imageLocalIdentifier: String? = nil,
        isEstimated: Bool,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.macros = macros
        self.loggedAt = loggedAt
        self.source = source
        self.imageLocalIdentifier = imageLocalIdentifier
        self.isEstimated = isEstimated
        self.notes = notes
    }

    static let sampleToday: [MealLog] = [
        MealLog(
            name: "Menemen ve tam buğday ekmeği",
            calories: 430,
            macros: MacroNutrients(proteinGrams: 21, carbohydrateGrams: 42, fatGrams: 18),
            loggedAt: Calendar.current.date(byAdding: .hour, value: -5, to: Date()) ?? Date(),
            source: .quickTurkishFood,
            isEstimated: true
        ),
        MealLog(
            name: "Mercimek çorbası",
            calories: 210,
            macros: MacroNutrients(proteinGrams: 11, carbohydrateGrams: 31, fatGrams: 6),
            loggedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            source: .manual,
            isEstimated: true
        )
    ]
}

enum MealSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case photo
    case barcode
    case quickTurkishFood

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "Manuel yaz"
        case .photo: "Fotoğrafla kaydet"
        case .barcode: "Barkod tara"
        case .quickTurkishFood: "Hızlı Türk yemeği seç"
        }
    }
}

struct MealEstimate: Codable, Equatable {
    var title: String
    var calories: Int
    var macros: MacroNutrients
    var confidence: Double
    var disclaimer: String

    var asMealLog: MealLog {
        MealLog(
            name: title,
            calories: calories,
            macros: macros,
            source: .photo,
            isEstimated: true,
            notes: disclaimer
        )
    }
}

struct QuickFood: Identifiable, Codable, Equatable {
    var id: String { name }
    var name: String
    var calories: Int
    var macros: MacroNutrients

    var mealLog: MealLog {
        MealLog(name: name, calories: calories, macros: macros, source: .quickTurkishFood, isEstimated: true)
    }

    static let turkishDefaults: [QuickFood] = [
        QuickFood(name: "Menemen", calories: 330, macros: MacroNutrients(proteinGrams: 18, carbohydrateGrams: 12, fatGrams: 22)),
        QuickFood(name: "Mercimek çorbası", calories: 210, macros: MacroNutrients(proteinGrams: 11, carbohydrateGrams: 31, fatGrams: 6)),
        QuickFood(name: "Pilav üstü tavuk", calories: 620, macros: MacroNutrients(proteinGrams: 42, carbohydrateGrams: 72, fatGrams: 16)),
        QuickFood(name: "Ayran", calories: 80, macros: MacroNutrients(proteinGrams: 5, carbohydrateGrams: 6, fatGrams: 3)),
        QuickFood(name: "Simit", calories: 360, macros: MacroNutrients(proteinGrams: 10, carbohydrateGrams: 68, fatGrams: 7)),
        QuickFood(name: "Yumurta", calories: 78, macros: MacroNutrients(proteinGrams: 6, carbohydrateGrams: 1, fatGrams: 5)),
        QuickFood(name: "Tavuk döner", calories: 520, macros: MacroNutrients(proteinGrams: 36, carbohydrateGrams: 52, fatGrams: 18)),
        QuickFood(name: "Izgara köfte", calories: 430, macros: MacroNutrients(proteinGrams: 34, carbohydrateGrams: 8, fatGrams: 29)),
        QuickFood(name: "Yoğurt", calories: 120, macros: MacroNutrients(proteinGrams: 8, carbohydrateGrams: 9, fatGrams: 5)),
        QuickFood(name: "Salata", calories: 160, macros: MacroNutrients(proteinGrams: 5, carbohydrateGrams: 18, fatGrams: 8)),
        QuickFood(name: "Çorba", calories: 190, macros: MacroNutrients(proteinGrams: 8, carbohydrateGrams: 26, fatGrams: 6)),
        QuickFood(name: "Lahmacun", calories: 310, macros: MacroNutrients(proteinGrams: 15, carbohydrateGrams: 38, fatGrams: 11)),
        QuickFood(name: "Ev yemeği", calories: 480, macros: MacroNutrients(proteinGrams: 24, carbohydrateGrams: 48, fatGrams: 20))
    ]
}

struct WaterLog: Identifiable, Codable, Equatable {
    var id: UUID
    var glasses: Int
    var loggedAt: Date

    init(id: UUID = UUID(), glasses: Int, loggedAt: Date = Date()) {
        self.id = id
        self.glasses = glasses
        self.loggedAt = loggedAt
    }
}
