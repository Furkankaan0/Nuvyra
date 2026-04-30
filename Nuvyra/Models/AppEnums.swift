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
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: "Hareketsiz"
        case .light: "Hafif aktif"
        case .moderate: "Orta aktif"
        case .active: "Aktif"
        case .veryActive: "Çok aktif"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: "Masa başı, neredeyse hiç egzersiz yok"
        case .light: "Haftada 1–3 gün hafif yürüyüş ya da egzersiz"
        case .moderate: "Haftada 3–5 gün orta tempolu egzersiz"
        case .active: "Haftada 6–7 gün aktif yaşam"
        case .veryActive: "Fiziksel iş veya yoğun antrenman"
        }
    }

    var systemImage: String {
        switch self {
        case .sedentary: "chair.lounge"
        case .light: "figure.walk"
        case .moderate: "figure.walk.motion"
        case .active: "figure.run"
        case .veryActive: "flame.fill"
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
