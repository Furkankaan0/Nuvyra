import Foundation

struct SubscriptionProduct: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var priceDisplay: String
    var period: SubscriptionPeriod
    var tier: EntitlementTier
    var features: [String]

    static let fallback: [SubscriptionProduct] = [
        SubscriptionProduct(
            id: "com.nuvyra.premium.monthly",
            title: "Premium Aylık",
            priceDisplay: "App Store fiyatı",
            period: .monthly,
            tier: .premium,
            features: ["Sınırsız fotoğraflı öğün kaydı", "Adaptif yürüyüş planı", "Haftalık koç özeti"]
        ),
        SubscriptionProduct(
            id: "com.nuvyra.premium.yearly",
            title: "Premium Yıllık",
            priceDisplay: "App Store fiyatı",
            period: .yearly,
            tier: .premium,
            features: ["Yıllık avantajlı erişim", "Gelişmiş kalori/makro görünümü", "Gelişmiş hatırlatmalar"]
        ),
        SubscriptionProduct(
            id: "com.nuvyra.plus.monthly",
            title: "Premium Plus Aylık",
            priceDisplay: "App Store fiyatı",
            period: .monthly,
            tier: .premiumPlus,
            features: ["AI koç sohbeti hazırlığı", "İleri trend analizi", "PDF/CSV dışa aktarım hazırlığı"]
        )
    ]
}

enum SubscriptionPeriod: String, Codable {
    case monthly
    case yearly

    var title: String {
        switch self {
        case .monthly: "Aylık"
        case .yearly: "Yıllık"
        }
    }
}

enum EntitlementTier: String, Codable, Comparable {
    case free
    case premium
    case premiumPlus

    static func < (lhs: EntitlementTier, rhs: EntitlementTier) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .free: 0
        case .premium: 1
        case .premiumPlus: 2
        }
    }

    var title: String {
        switch self {
        case .free: "Free"
        case .premium: "Premium"
        case .premiumPlus: "Premium Plus"
        }
    }
}

struct EntitlementState: Codable, Equatable {
    var tier: EntitlementTier
    var activeProductID: String?
    var expiresAt: Date?
    var verifiedAt: Date
    var isOfflineCache: Bool

    var hasPremiumAccess: Bool { tier >= .premium }
    var hasPremiumPlusAccess: Bool { tier >= .premiumPlus }

    static let free = EntitlementState(tier: .free, activeProductID: nil, expiresAt: nil, verifiedAt: Date(), isOfflineCache: false)
}
