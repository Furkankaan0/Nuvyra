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
        case .loseWeight: return "Kilo vermek"
        case .maintain: return "Kilomu korumak"
        case .gainHealthy: return "Sağlıklı kilo almak"
        case .walkMore: return "Daha düzenli yürümek"
        case .eatHealthier: return "Daha sağlıklı beslenmek"
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
        case .female: return "Kadın"
        case .male: return "Erkek"
        case .other: return "Diğer"
        case .preferNotToSay: return "Belirtmek istemiyorum"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable, Identifiable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    /// Mifflin-St Jeor PAL multiplier (TDEE = BMR × multiplier).
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: return "Hareketsiz"
        case .light: return "Hafif aktif"
        case .moderate: return "Orta aktif"
        case .active: return "Aktif"
        case .veryActive: return "Çok aktif"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: return "Masa başı, neredeyse hiç egzersiz yok"
        case .light: return "Haftada 1–3 gün hafif yürüyüş ya da egzersiz"
        case .moderate: return "Haftada 3–5 gün orta tempolu egzersiz"
        case .active: return "Haftada 6–7 gün aktif yaşam"
        case .veryActive: return "Fiziksel iş veya yoğun antrenman"
        }
    }

    var systemImage: String {
        switch self {
        case .sedentary: return "chair.lounge"
        case .light: return "figure.walk"
        case .moderate: return "figure.walk.motion"
        case .active: return "figure.run"
        case .veryActive: return "flame.fill"
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
        case .breakfast: return "Kahvaltı"
        case .lunch: return "Öğle"
        case .dinner: return "Akşam"
        case .snack: return "Atıştırmalık"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars"
        case .snack: return "leaf"
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
        case .calm: return "Sakin"
        case .energetic: return "Enerjik"
        case .tired: return "Yorgun"
        case .stressed: return "Gergin"
        }
    }
}

enum EntitlementSource: String, Codable {
    case storeKit
    case localFallback
}
