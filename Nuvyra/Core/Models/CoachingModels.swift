import Foundation

struct WeeklySummary: Codable, Equatable {
    var averageCalories: Int
    var averageSteps: Int
    var bestDay: String
    var challengingDay: String
    var mealRhythm: String
    var waterRhythm: String
    var suggestions: [String]
    var insight: String

    static let sample = WeeklySummary(
        averageCalories: 1_840,
        averageSteps: 6_420,
        bestDay: "Cumartesi",
        challengingDay: "Çarşamba",
        mealRhythm: "Öğlenleri düzenin iyi, akşam daha sade bir plan işini kolaylaştırabilir.",
        waterRhythm: "Su takibin haftanın ikinci yarısında güçlenmiş.",
        suggestions: [
            "Akşam yemeğinden sonra 10 dakikalık hafif yürüyüş ekle.",
            "Öğleden sonra küçük bir protein ara öğünü planla.",
            "Su hedefini tek seferde değil, güne yayarak tamamla."
        ],
        insight: "Bu hafta Çarşamba sonrası ritmin düştü. Haftaya akşam yemeğinden sonra 10 dakikalık yürüyüş ekleyerek daha dengeli ilerleyebiliriz."
    )
}

struct CoachingMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String
    var tone: CoachingTone

    init(id: UUID = UUID(), title: String, body: String, tone: CoachingTone) {
        self.id = id
        self.title = title
        self.body = body
        self.tone = tone
    }
}

enum CoachingTone: String, Codable {
    case supportive
    case practical
    case recovery
}

struct DailyPlan: Codable, Equatable {
    var calorieTarget: CalorieTarget
    var stepGoal: Int
    var message: CoachingMessage
}
