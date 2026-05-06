import CoreMotion
import Foundation

struct WalkingTrackerSnapshot: Equatable {
    var isStationary: Bool
    var isWalking: Bool
    var isRunning: Bool
    var isStepCountingActive: Bool
    var trackedSteps: Int
    var confidence: CMMotionActivityConfidence
    var updatedAt: Date

    var activityState: MotionActivityState {
        if isRunning { return .running }
        if isWalking { return .walking }
        if isStationary { return .stationary }
        return .unknown
    }

    static let idle = WalkingTrackerSnapshot(
        isStationary: false,
        isWalking: false,
        isRunning: false,
        isStepCountingActive: false,
        trackedSteps: 0,
        confidence: .low,
        updatedAt: Date()
    )
}

struct WalkingActivityFlags: Equatable {
    var isStationary: Bool
    var isWalking: Bool
    var isRunning: Bool

    var shouldCountSteps: Bool {
        isWalking || isRunning
    }
}

enum WalkingTrackerStepCountingAction: Equatable {
    case start
    case pause
    case keepCurrentState
}

enum WalkingTrackerBatteryPolicy {
    static func action(
        for flags: WalkingActivityFlags,
        isCountingSteps: Bool
    ) -> WalkingTrackerStepCountingAction {
        if flags.shouldCountSteps, !isCountingSteps {
            return .start
        }

        if !flags.shouldCountSteps, isCountingSteps {
            return .pause
        }

        return .keepCurrentState
    }
}

protocol WalkingTrackerService {
    var snapshots: AsyncStream<WalkingTrackerSnapshot> { get }
    func start()
    func stop()
    func reset()
}

final class CoreMotionWalkingTrackerService: WalkingTrackerService, @unchecked Sendable {
    private let activityManager: CMMotionActivityManager
    private let pedometer: CMPedometer
    private let activityQueue: OperationQueue
    private let stateQueue = DispatchQueue(label: "com.nuvyra.walking-tracker.state", qos: .utility)

    private var continuation: AsyncStream<WalkingTrackerSnapshot>.Continuation?
    private var latestSnapshot = WalkingTrackerSnapshot.idle
    private var isTrackingActivity = false
    private var isCountingSteps = false

    init(
        activityManager: CMMotionActivityManager = CMMotionActivityManager(),
        pedometer: CMPedometer = CMPedometer()
    ) {
        self.activityManager = activityManager
        self.pedometer = pedometer
        self.activityQueue = OperationQueue()
        self.activityQueue.name = "com.nuvyra.walking-tracker.activity"
        self.activityQueue.qualityOfService = .utility
        self.activityQueue.maxConcurrentOperationCount = 1
    }

    var snapshots: AsyncStream<WalkingTrackerSnapshot> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { [weak self] continuation in
            self?.stateQueue.async {
                self?.continuation = continuation
                if let latestSnapshot = self?.latestSnapshot {
                    continuation.yield(latestSnapshot)
                }
            }
        }
    }

    func start() {
        stateQueue.async { [weak self] in
            guard let self, !self.isTrackingActivity else { return }
            guard CMMotionActivityManager.isActivityAvailable() else {
                self.publish(self.latestSnapshot)
                return
            }

            self.isTrackingActivity = true
            self.activityManager.startActivityUpdates(to: self.activityQueue) { [weak self] activity in
                guard let self, let activity else { return }
                self.handle(activity)
            }
        }
    }

    func stop() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.activityManager.stopActivityUpdates()
            self.stopStepCountingLocked()
            self.isTrackingActivity = false
            self.publish(self.latestSnapshot)
            self.continuation?.finish()
            self.continuation = nil
        }
    }

    func reset() {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.stopStepCountingLocked()
            self.latestSnapshot = .idle
            self.publish(self.latestSnapshot)
        }
    }

    private func handle(_ activity: CMMotionActivity) {
        stateQueue.async { [weak self] in
            guard let self else { return }

            let motionFlags = Self.motionFlags(from: activity)
            let stepCountingAction = WalkingTrackerBatteryPolicy.action(
                for: motionFlags,
                isCountingSteps: self.isCountingSteps
            )

            if stepCountingAction == .start {
                self.startStepCountingLocked()
            } else if stepCountingAction == .pause {
                self.stopStepCountingLocked()
            }

            self.latestSnapshot = WalkingTrackerSnapshot(
                isStationary: motionFlags.isStationary,
                isWalking: motionFlags.isWalking,
                isRunning: motionFlags.isRunning,
                isStepCountingActive: self.isCountingSteps,
                trackedSteps: self.latestSnapshot.trackedSteps,
                confidence: activity.confidence,
                updatedAt: Date()
            )
            self.publish(self.latestSnapshot)
        }
    }

    private func startStepCountingLocked() {
        guard !isCountingSteps, CMPedometer.isStepCountingAvailable() else { return }

        isCountingSteps = true
        let segmentStart = Date()
        let baseSteps = latestSnapshot.trackedSteps

        pedometer.startUpdates(from: segmentStart) { [weak self] data, _ in
            guard let self, let data else { return }
            self.stateQueue.async {
                let segmentSteps = data.numberOfSteps.intValue
                self.latestSnapshot.trackedSteps = baseSteps + segmentSteps
                self.latestSnapshot.isStepCountingActive = self.isCountingSteps
                self.latestSnapshot.updatedAt = Date()
                self.publish(self.latestSnapshot)
            }
        }
    }

    private func stopStepCountingLocked() {
        guard isCountingSteps else { return }
        pedometer.stopUpdates()
        isCountingSteps = false
        latestSnapshot.isStepCountingActive = false
    }

    private func publish(_ snapshot: WalkingTrackerSnapshot) {
        continuation?.yield(snapshot)
    }

    static func motionFlags(from activity: CMMotionActivity) -> WalkingActivityFlags {
        WalkingActivityFlags(
            isStationary: activity.stationary,
            isWalking: activity.walking,
            isRunning: activity.running
        )
    }
}

final class MockWalkingTrackerService: WalkingTrackerService {
    private let stream: AsyncStream<WalkingTrackerSnapshot>
    private let continuation: AsyncStream<WalkingTrackerSnapshot>.Continuation
    private(set) var didStart = false
    private(set) var didStop = false

    init(initialSnapshot: WalkingTrackerSnapshot = .idle) {
        var continuation: AsyncStream<WalkingTrackerSnapshot>.Continuation!
        stream = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation = $0 }
        self.continuation = continuation
        continuation.yield(initialSnapshot)
    }

    var snapshots: AsyncStream<WalkingTrackerSnapshot> { stream }

    func start() {
        didStart = true
    }

    func stop() {
        didStop = true
    }

    func reset() {
        continuation.yield(.idle)
    }

    func send(_ snapshot: WalkingTrackerSnapshot) {
        continuation.yield(snapshot)
    }
}
