import Foundation

enum GoalType: String, CaseIterable, Codable, Identifiable {
    case loseWeight
    case maintain
    case gainHealthy
    case walkMore
    case eatHealthier

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseWeight: "Kilo vermek"
        case .maintain: "Kilomu korumak"
        case .gainHealthy: "Sağlıklı kilo almak"
        case .walkMore: "Daha düzenli yürümek"
        case .eatHealthier: "Daha sağlıklı beslenmek"
        }
    }
}

enum Gender: String, CaseIterable, Codable, Identifiable {
    case female
    case male
    case other
    case preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: "Kadın"
        case .male: "Erkek"
        case .other: "Diğer"
        case .preferNotToSay: "Belirtmek istemiyorum"
        }
    }
}

enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Kahvaltı"
        case .lunch: "Öğle"
        case .dinner: "Akşam"
        case .snack: "Atıştırmalık"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "fork.knife"
        case .dinner: "moon.stars"
        case .snack: "leaf"
        }
    }
}

enum Mood: String, CaseIterable, Codable, Identifiable {
    case calm
    case energetic
    case tired
    case stressed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: "Sakin"
        case .energetic: "Enerjik"
        case .tired: "Yorgun"
        case .stressed: "Gergin"
        }
    }
}

enum EntitlementSource: String, Codable {
    case storeKit
    case localFallback
}
