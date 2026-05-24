import Foundation

/// A bite-sized wellness observation shown on the coach hero screen.
/// Topic determines the icon + tint; intent is purely informational.
struct AICoachInsight: Identifiable, Equatable, Hashable {
    enum Topic: String, CaseIterable, Codable {
        case daily, weekly, calories, water, steps

        var title: String {
            switch self {
            case .daily: "Günlük içgörü"
            case .weekly: "Haftalık gelişim"
            case .calories: "Kalori & makro dengesi"
            case .water: "Su tüketimi"
            case .steps: "Yürüyüş ritmi"
            }
        }

        var systemImage: String {
            switch self {
            case .daily: "sparkles"
            case .weekly: "chart.line.uptrend.xyaxis"
            case .calories: "flame.fill"
            case .water: "drop.fill"
            case .steps: "figure.walk"
            }
        }
    }

    let id: UUID
    let topic: Topic
    let title: String
    let body: String
    let generatedAt: Date

    init(id: UUID = UUID(), topic: Topic, title: String, body: String, generatedAt: Date = Date()) {
        self.id = id
        self.topic = topic
        self.title = title
        self.body = body
        self.generatedAt = generatedAt
    }
}

/// Single message in the coach chat. `coach` is the AI side.
struct AICoachMessage: Identifiable, Equatable, Hashable {
    enum Role: String, Codable { case user, coach }

    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

/// Snapshot of user metrics passed into the coach so it can produce context-aware copy.
struct AICoachContext: Equatable {
    var greetingName: String
    var caloriesConsumed: Int
    var caloriesTarget: Int
    var proteinGrams: Double
    var proteinTargetGrams: Double
    var waterMl: Int
    var waterTargetMl: Int
    var steps: Int
    var stepTarget: Int
    var weeklyAverageSteps: Int
    var weeklyAverageWaterMl: Int

    static let empty = AICoachContext(
        greetingName: "Hoş geldin",
        caloriesConsumed: 0,
        caloriesTarget: 1_900,
        proteinGrams: 0,
        proteinTargetGrams: 120,
        waterMl: 0,
        waterTargetMl: 2_000,
        steps: 0,
        stepTarget: 7_500,
        weeklyAverageSteps: 0,
        weeklyAverageWaterMl: 0
    )
}

/// Pre-baked example questions surfaced in the chat empty state.
enum AICoachExampleQuestion: String, CaseIterable, Identifiable {
    case proteinIdeas = "Daha çok protein için ne ekleyebilirim?"
    case waterTips = "Su içmeyi nasıl unutmam?"
    case eveningRoutine = "Akşam atıştırmasını nasıl azaltabilirim?"
    case morningWalk = "Sabah yürüyüşü için kısa bir plan ver"

    var id: String { rawValue }
}
