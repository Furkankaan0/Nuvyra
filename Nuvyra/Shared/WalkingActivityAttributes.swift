import ActivityKit
import Foundation

struct WalkingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var steps: Int
        var remaining: Int
        var elapsedMinutes: Int
        var message: String

        static func state(steps: Int, goal: Int, elapsedMinutes: Int) -> ContentState {
            let remaining = max(goal - steps, 0)
            let message = remaining == 0
                ? "Bugünkü yürüyüş ritmin tamamlandı."
                : "Hedefe \(remaining.formatted()) adım kaldı."
            return ContentState(steps: steps, remaining: remaining, elapsedMinutes: elapsedMinutes, message: message)
        }
    }

    var goal: Int
    var startedAt: Date
}
