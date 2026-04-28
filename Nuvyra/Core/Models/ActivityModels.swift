import Foundation

struct StepSnapshot: Codable, Equatable {
    var steps: Int
    var goal: Int
    var updatedAt: Date
    var source: StepDataSource

    var remainingSteps: Int { max(goal - steps, 0) }
    var progress: Double { goal == 0 ? 0 : min(Double(steps) / Double(goal), 1) }
    var estimatedMinutesToFinish: Int { max(Int(Double(remainingSteps) / 110.0), 0) }

    static let preview = StepSnapshot(steps: 5_320, goal: 6_500, updatedAt: Date(), source: .demo)
}

enum StepDataSource: String, Codable {
    case healthKit
    case manual
    case demo
    case unavailable
}

struct StepHistoryDay: Identifiable, Codable, Equatable {
    var id: String { dayKey }
    var date: Date
    var steps: Int
    var goal: Int

    var dayKey: String { DateFormatter.nuvyraDayKey.string(from: date) }
    var didHitGoal: Bool { steps >= goal }

    static let sampleWeek: [StepHistoryDay] = Array((0..<7).compactMap { offset in
        guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
        let steps = [4_900, 6_800, 7_100, 3_900, 8_250, 6_200, 5_700][offset]
        return StepHistoryDay(date: date, steps: steps, goal: 6_500)
    }.reversed())
}

struct StepGoalRecommendation: Equatable {
    var goal: Int
    var reason: String
}

struct StepGoalAdapter {
    func initialGoal(for activityLevel: ActivityLevel) -> Int {
        activityLevel.stepBaseline
    }

    func adaptedGoal(currentGoal: Int, recentDays: [StepHistoryDay]) -> StepGoalRecommendation {
        let lastThree = Array(recentDays.suffix(3))
        if lastThree.count == 3, lastThree.allSatisfy(\.didHitGoal) {
            return StepGoalRecommendation(
                goal: min(currentGoal + 500, 12_000),
                reason: "Son üç gün hedefini geçtin. Hedefi küçük bir adımla yükselttik."
            )
        }

        let lastTwo = Array(recentDays.suffix(2))
        if lastTwo.count == 2, lastTwo.allSatisfy({ $0.steps < Int(Double($0.goal) * 0.45) }) {
            return StepGoalRecommendation(
                goal: max(currentGoal - 500, 3_500),
                reason: "Son iki gün yoğun geçmiş olabilir. Hedefi cezalandırmadan biraz yumuşattık."
            )
        }

        return StepGoalRecommendation(
            goal: currentGoal,
            reason: "Hedefin dengede. Bugün küçük bir yürüyüş yeterli olabilir."
        )
    }
}

struct WalkingSuggestion: Codable, Equatable {
    var title: String
    var detail: String
    var estimatedMinutes: Int

    static func today(from snapshot: StepSnapshot) -> WalkingSuggestion {
        if snapshot.remainingSteps == 0 {
            return WalkingSuggestion(
                title: "Bugünkü ritim tamamlandı",
                detail: "Hedefini tamamladın. İstersen kısa ve rahat bir yürüyüşle günü kapatabilirsin.",
                estimatedMinutes: 0
            )
        }

        return WalkingSuggestion(
            title: "Bugün için mini yürüyüş",
            detail: "Bugünkü hedefe \(snapshot.remainingSteps.formatted()) adım kaldı. Yaklaşık \(snapshot.estimatedMinutesToFinish) dakikalık hafif yürüyüş yeterli olabilir.",
            estimatedMinutes: snapshot.estimatedMinutesToFinish
        )
    }
}
