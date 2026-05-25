import Foundation

enum GoalType: String, CaseIterable, Codable, Identifiable, Equatable, Hashable {
    case loseWeight
    case maintain
    case gainHealthy
    case gainMuscle
    case walkMore
    case eatHealthier
    case healthyLiving
    case stayFit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseWeight: "Kilo vermek"
        case .maintain: "Kilomu korumak"
        case .gainHealthy: "Sağlıklı kilo almak"
        case .gainMuscle: "Kas kazanmak"
        case .walkMore: "Daha düzenli yürümek"
        case .eatHealthier: "Daha sağlıklı beslenmek"
        case .healthyLiving: "Daha sağlıklı yaşamak"
        case .stayFit: "Formda kalmak"
        }
    }

    var isPaceSensitive: Bool {
        switch self {
        case .loseWeight, .gainHealthy, .gainMuscle:
            true
        case .maintain, .walkMore, .eatHealthier, .healthyLiving, .stayFit:
            false
        }
    }
}

enum Gender: String, CaseIterable, Codable, Identifiable, Equatable, Hashable {
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

enum ActivityLevel: String, CaseIterable, Codable, Identifiable, Equatable, Hashable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case athlete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: "Hareketsiz"
        case .lightlyActive: "Hafif aktif"
        case .moderatelyActive: "Orta aktif"
        case .veryActive: "Çok aktif"
        case .athlete: "Atlet seviyesi"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: "Günün çoğu oturarak geçiyor, kısa yürüyüşler başlangıç için yeterli."
        case .lightlyActive: "Haftada birkaç kısa yürüyüş veya hafif hareket var."
        case .moderatelyActive: "Haftada 3-4 gün düzenli yürüyüş ya da antrenman yapıyorsun."
        case .veryActive: "Neredeyse her gün hareket, yürüyüş veya spor rutinin var."
        case .athlete: "Yoğun antrenman veya performans odaklı aktif bir düzenin var."
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: 1.20
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .athlete: 1.90
        }
    }
}

enum GoalPace: String, CaseIterable, Codable, Identifiable, Equatable, Hashable {
    case slow
    case balanced
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slow: "Yavaş ve sürdürülebilir"
        case .balanced: "Dengeli"
        case .fast: "Hızlı ilerleme"
        }
    }

    var subtitle: String {
        switch self {
        case .slow: "Daha küçük değişikliklerle ritmini korumaya odaklanır."
        case .balanced: "Günlük hayatla uyumlu, net ama nazik bir tempo."
        case .fast: "Daha belirgin hedef ayarı; sürdürülebilirlik uyarıları korunur."
        }
    }
}

enum MealType: String, CaseIterable, Codable, Identifiable, Equatable, Hashable, Sendable {
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

enum Mood: String, CaseIterable, Codable, Identifiable, Equatable, Hashable {
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

enum EntitlementSource: String, Codable, Equatable, Hashable {
    case storeKit
    case localFallback
}
