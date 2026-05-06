import ActivityKit
import Foundation

@available(iOS 16.1, *)
@MainActor
final class NuvyraWalkingLiveActivityManager {
    private var activity: Activity<NuvyraWalkingAttributes>?

    var isLiveActivityRunning: Bool {
        activity != nil
    }

    func startLiveActivity(
        steps: Int = 0,
        caloriesBurned: Double = 0,
        elapsedTime: TimeInterval = 0
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if activity != nil {
            await updateLiveActivity(
                steps: steps,
                caloriesBurned: caloriesBurned,
                elapsedTime: elapsedTime
            )
            return
        }

        let attributes = NuvyraWalkingAttributes(startedAt: Date().addingTimeInterval(-elapsedTime))
        let state = NuvyraWalkingAttributes.ContentState.walking(
            steps: steps,
            caloriesBurned: caloriesBurned,
            elapsedTime: elapsedTime
        )

        do {
            if #available(iOS 16.2, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)),
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
        } catch {
            activity = nil
        }
    }

    func updateLiveActivity(
        steps: Int,
        caloriesBurned: Double,
        elapsedTime: TimeInterval
    ) async {
        guard let activity else { return }

        let state = NuvyraWalkingAttributes.ContentState.walking(
            steps: steps,
            caloriesBurned: caloriesBurned,
            elapsedTime: elapsedTime
        )

        if #available(iOS 16.2, *) {
            await activity.update(
                ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
            )
        } else {
            await activity.update(using: state)
        }
    }

    func endLiveActivity(
        steps: Int,
        caloriesBurned: Double,
        elapsedTime: TimeInterval
    ) async {
        guard let activity else { return }

        let finalState = NuvyraWalkingAttributes.ContentState.walking(
            steps: steps,
            caloriesBurned: caloriesBurned,
            elapsedTime: elapsedTime
        )

        if #available(iOS 16.2, *) {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(10 * 60))
            )
        } else {
            await activity.end(
                using: finalState,
                dismissalPolicy: .after(Date().addingTimeInterval(10 * 60))
            )
        }

        self.activity = nil
    }
}

@available(iOS 16.1, *)
@MainActor
final class MockNuvyraWalkingLiveActivityManager {
    private(set) var didStart = false
    private(set) var didEnd = false
    private(set) var lastState: NuvyraWalkingAttributes.ContentState?

    func startLiveActivity(
        steps: Int = 0,
        caloriesBurned: Double = 0,
        elapsedTime: TimeInterval = 0
    ) async {
        didStart = true
        lastState = .walking(steps: steps, caloriesBurned: caloriesBurned, elapsedTime: elapsedTime)
    }

    func updateLiveActivity(
        steps: Int,
        caloriesBurned: Double,
        elapsedTime: TimeInterval
    ) async {
        lastState = .walking(steps: steps, caloriesBurned: caloriesBurned, elapsedTime: elapsedTime)
    }

    func endLiveActivity(
        steps: Int,
        caloriesBurned: Double,
        elapsedTime: TimeInterval
    ) async {
        didEnd = true
        lastState = .walking(steps: steps, caloriesBurned: caloriesBurned, elapsedTime: elapsedTime)
    }
}
