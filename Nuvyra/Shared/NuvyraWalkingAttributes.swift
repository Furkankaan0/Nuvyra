import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct NuvyraWalkingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var steps: Int
        var caloriesBurned: Double
        var elapsedTime: TimeInterval

        var elapsedMinutes: Int {
            max(Int(elapsedTime / 60), 0)
        }

        var formattedCalories: String {
            "\(Int(caloriesBurned.rounded())) kcal"
        }

        var summary: String {
            "\(steps.formatted()) adım • \(formattedCalories) • \(elapsedMinutes) dk"
        }

        static func walking(
            steps: Int,
            caloriesBurned: Double,
            elapsedTime: TimeInterval
        ) -> ContentState {
            ContentState(
                steps: max(steps, 0),
                caloriesBurned: max(caloriesBurned, 0),
                elapsedTime: max(elapsedTime, 0)
            )
        }
    }

    var sessionName: String
    var startedAt: Date

    init(sessionName: String = "Nuvyra yürüyüş", startedAt: Date = Date()) {
        self.sessionName = sessionName
        self.startedAt = startedAt
    }
}
