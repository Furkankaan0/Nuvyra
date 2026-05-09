import Foundation
import SwiftUI

enum AICoachInsightCategory: String, CaseIterable, Codable {
    case daily
    case weekly
    case calories
    case macros
    case water
    case steps

    var title: String {
        switch self {
        case .daily: "Günlük içgörü"
        case .weekly: "Haftalık gelişim"
        case .calories: "Kalori dengesi"
        case .macros: "Makro dağılımı"
        case .water: "Su tüketimi"
        case .steps: "Yürüyüş ritmin"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "sun.max"
        case .weekly: "calendar"
        case .calories: "flame"
        case .macros: "chart.pie"
        case .water: "drop.fill"
        case .steps: "figure.walk"
        }
    }

    func tint(_ scheme: ColorScheme) -> Color {
        switch self {
        case .daily: return NuvyraColors.accent
        case .weekly: return NuvyraColors.softMint
        case .calories: return NuvyraColors.mutedCoral
        case .macros: return NuvyraColors.softSand
        case .water: return Color(red: 0.30, green: 0.70, blue: 0.95)
        case .steps: return NuvyraColors.paleLime
        }
    }
}

struct AICoachInsight: Identifiable, Equatable {
    let id: UUID
    var category: AICoachInsightCategory
    var headline: String
    var detail: String

    init(id: UUID = UUID(), category: AICoachInsightCategory, headline: String, detail: String) {
        self.id = id
        self.category = category
        self.headline = headline
        self.detail = detail
    }
}

enum AICoachRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

struct AICoachMessage: Identifiable, Equatable {
    let id: UUID
    var role: AICoachRole
    var content: String
    var timestamp: Date
    var isTyping: Bool

    init(id: UUID = UUID(), role: AICoachRole, content: String, timestamp: Date = Date(), isTyping: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isTyping = isTyping
    }

    static func typingPlaceholder() -> AICoachMessage {
        AICoachMessage(role: .assistant, content: "", isTyping: true)
    }
}

struct AICoachContext: Equatable {
    var caloriesConsumed: Int
    var calorieTarget: Int
    var burnedKcal: Int
    var proteinGrams: Double
    var proteinTargetGrams: Double
    var carbsGrams: Double
    var carbsTargetGrams: Double
    var fatGrams: Double
    var fatTargetGrams: Double
    var waterMl: Int
    var waterTargetMl: Int
    var steps: Int
    var stepGoal: Int
    var goalType: GoalType?
    var userName: String?

    static let empty = AICoachContext(
        caloriesConsumed: 0, calorieTarget: 1_900, burnedKcal: 0,
        proteinGrams: 0, proteinTargetGrams: 120,
        carbsGrams: 0, carbsTargetGrams: 210,
        fatGrams: 0, fatTargetGrams: 65,
        waterMl: 0, waterTargetMl: 2_000,
        steps: 0, stepGoal: 7_500,
        goalType: nil, userName: nil
    )
}

struct AICoachExampleQuestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let systemImage: String
}
