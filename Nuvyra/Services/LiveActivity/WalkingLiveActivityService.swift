import ActivityKit
import Foundation

@MainActor
protocol WalkingLiveActivityService {
    var isActive: Bool { get }
    func start(goal: Int, initialSteps: Int) async
    func update(steps: Int, goal: Int, elapsedMinutes: Int) async
    func end(finalSteps: Int, goal: Int) async
}

/// Drives `WalkingActivityAttributes` Live Activity sessions.
///
/// **Background updates note:** ActivityKit only delivers state changes
/// while the host app pushes them. We currently use `pushType: nil`, which
/// means updates only land while the app is foregrounded (driven by the
/// 60-second loop in `WalkingViewModel`). For true background updates the
/// next iteration needs either an `HKObserverQuery` with
/// `enableBackgroundDelivery(...)` or APNs push tokens — both intentionally
/// out of scope until the foreground flow ships.
@MainActor
final class LiveWalkingLiveActivityService: WalkingLiveActivityService {
    private var activity: Activity<WalkingActivityAttributes>?

    var isActive: Bool {
        activity != nil
    }

    func start(goal: Int, initialSteps: Int) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else {
            await update(steps: initialSteps, goal: goal, elapsedMinutes: 0)
            return
        }

        let attributes = WalkingActivityAttributes(goal: goal, startedAt: Date())
        let state = WalkingActivityAttributes.ContentState.state(steps: initialSteps, goal: goal, elapsedMinutes: 0)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))

        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            activity = nil
        }
    }

    func update(steps: Int, goal: Int, elapsedMinutes: Int) async {
        guard let activity else { return }
        let state = WalkingActivityAttributes.ContentState.state(steps: steps, goal: goal, elapsedMinutes: elapsedMinutes)
        await activity.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)))
    }

    func end(finalSteps: Int, goal: Int) async {
        guard let activity else { return }
        let state = WalkingActivityAttributes.ContentState.state(
            steps: finalSteps,
            goal: goal,
            elapsedMinutes: max(Int(Date().timeIntervalSince(activity.attributes.startedAt) / 60), 0)
        )
        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(10 * 60)))
        self.activity = nil
    }
}

@MainActor
final class MockWalkingLiveActivityService: WalkingLiveActivityService {
    private(set) var isActive = false
    private(set) var lastState: WalkingActivityAttributes.ContentState?

    func start(goal: Int, initialSteps: Int) async {
        isActive = true
        lastState = .state(steps: initialSteps, goal: goal, elapsedMinutes: 0)
    }

    func update(steps: Int, goal: Int, elapsedMinutes: Int) async {
        guard isActive else { return }
        lastState = .state(steps: steps, goal: goal, elapsedMinutes: elapsedMinutes)
    }

    func end(finalSteps: Int, goal: Int) async {
        lastState = .state(steps: finalSteps, goal: goal, elapsedMinutes: lastState?.elapsedMinutes ?? 0)
        isActive = false
    }
}
