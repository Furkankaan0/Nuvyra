import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var goal: WellnessGoal
    var age: Int
    var heightCentimeters: Int
    var weightKilograms: Double
    var targetWeightKilograms: Double?
    var gender: GenderOption
    var activityLevel: ActivityLevel
    var routine: DailyRoutine
    var createdAt: Date

    init(
        id: UUID = UUID(),
        goal: WellnessGoal,
        age: Int,
        heightCentimeters: Int,
        weightKilograms: Double,
        targetWeightKilograms: Double?,
        gender: GenderOption,
        activityLevel: ActivityLevel,
        routine: DailyRoutine,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.goal = goal
        self.age = age
        self.heightCentimeters = heightCentimeters
        self.weightKilograms = weightKilograms
        self.targetWeightKilograms = targetWeightKilograms
        self.gender = gender
        self.activityLevel = activityLevel
        self.routine = routine
        self.createdAt = createdAt
    }

    static let preview = UserProfile(
        goal: .buildHealthRhythm,
        age: 31,
        heightCentimeters: 174,
        weightKilograms: 78,
        targetWeightKilograms: 74,
        gender: .preferNotToSay,
        activityLevel: .light,
        routine: .preview
    )
}

enum WellnessGoal: String, CaseIterable, Identifiable, Codable {
    case loseWeight
    case eatMoreRegularly
    case walkMore
    case maintainWeight
    case buildHealthRhythm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseWeight: "Kilo vermek"
        case .eatMoreRegularly: "Daha düzenli beslenmek"
        case .walkMore: "Daha çok yürümek"
        case .maintainWeight: "Kilomu korumak"
        case .buildHealthRhythm: "Genel sağlık ritmi kurmak"
        }
    }

    var analyticsValue: String {
        switch self {
        case .loseWeight: "lose_weight"
        case .eatMoreRegularly: "regular_nutrition"
        case .walkMore: "walk_more"
        case .maintainWeight: "maintain_weight"
        case .buildHealthRhythm: "health_rhythm"
        }
    }
}

enum GenderOption: String, CaseIterable, Identifiable, Codable {
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

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case low
    case light
    case moderate
    case active

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Çoğunlukla hareketsiz"
        case .light: "Hafif aktif"
        case .moderate: "Orta aktif"
        case .active: "Aktif"
        }
    }

    var stepBaseline: Int {
        switch self {
        case .low: 4_500
        case .light: 6_500
        case .moderate: 8_000
        case .active: 9_500
        }
    }
}

struct DailyRoutine: Codable, Equatable {
    var mealsPerDay: Int
    var difficultMoment: DifficultMoment
    var preferredWalkTime: WalkTimePreference
    var wantsReminders: Bool

    static let preview = DailyRoutine(
        mealsPerDay: 3,
        difficultMoment: .evening,
        preferredWalkTime: .afterDinner,
        wantsReminders: true
    )
}

enum DifficultMoment: String, CaseIterable, Identifiable, Codable {
    case morning
    case afternoon
    case evening
    case lateNight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Sabah"
        case .afternoon: "Öğleden sonra"
        case .evening: "Akşam"
        case .lateNight: "Gece atıştırmaları"
        }
    }
}

enum WalkTimePreference: String, CaseIterable, Identifiable, Codable {
    case morning
    case lunchBreak
    case afterDinner
    case flexible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Sabah"
        case .lunchBreak: "Öğle arası"
        case .afterDinner: "Akşam yemeğinden sonra"
        case .flexible: "Güne göre değişir"
        }
    }
}

struct CalorieTarget: Codable, Equatable {
    var lowerBound: Int
    var upperBound: Int
    var recommended: Int

    var displayRange: String { "\(lowerBound)-\(upperBound) kcal" }
}
