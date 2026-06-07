import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = WatchConnectivityBridge()

    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var isReachable = false
    /// Latest weekly-goal snapshot the iPhone has pushed via
    /// `updateApplicationContext`. `nil` until the first push lands.
    @Published private(set) var weeklyGoalsSnapshot: WatchWeeklyGoalSnapshot?

    private override init() {
        super.init()
    }

    func activate() async {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        activationState = session.activationState
        isReachable = session.isReachable
        // If the phone already pushed an application context before
        // activation, grab the latest one now so the watch UI shows
        // real data on first launch instead of an empty grid.
        if let snapshot = WatchWeeklyGoalSnapshot(applicationContext: session.receivedApplicationContext) {
            weeklyGoalsSnapshot = snapshot
        }
    }

    func sendWater(amountMl: Int, totalMl: Int) {
        guard WCSession.isSupported() else { return }
        let payload: [String: Any] = [
            "type": "water.added",
            "eventID": UUID().uuidString,
            "amountMl": amountMl,
            "totalMl": totalMl,
            "timestamp": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else if session.activationState == .activated {
            session.transferUserInfo(payload)
        }
    }
}

extension WatchConnectivityBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            if let snapshot = WatchWeeklyGoalSnapshot(applicationContext: applicationContext) {
                self.weeklyGoalsSnapshot = snapshot
            }
        }
    }
}

/// Decoded form of the iPhone's `goals.snapshot` payload. Lives next to
/// the bridge so the watch view can read a typed model instead of poking
/// at raw `[String: Any]` dictionaries.
struct WatchWeeklyGoalSnapshot: Equatable {
    struct Metric: Equatable, Identifiable {
        let key: String
        let daysHit: Int
        let totalDays: Int
        var id: String { key }
        var fraction: Double { totalDays > 0 ? Double(daysHit) / Double(totalDays) : 0 }
        var isAchieved: Bool { daysHit >= 5 }

        /// Locale-resolved short title for the row label. Kept here so
        /// the watch view doesn't depend on the iOS engine's copy bank.
        var title: String {
            switch key {
            case "steps": "Adım"
            case "water": "Su"
            case "calories": "Kalori"
            case "protein": "Protein"
            default: key.capitalized
            }
        }

        var systemImage: String {
            switch key {
            case "steps": "figure.walk"
            case "water": "drop.fill"
            case "calories": "flame.fill"
            case "protein": "bolt.heart"
            default: "circle"
            }
        }
    }

    struct Badge: Equatable, Identifiable {
        let id: String
        let title: String
        let isEarned: Bool
    }

    let overallFraction: Double
    let achievedCount: Int
    let totalGoals: Int
    let metrics: [Metric]
    let badges: [Badge]

    init?(applicationContext: [String: Any]) {
        guard applicationContext["type"] as? String == "goals.snapshot" else { return nil }
        self.overallFraction = (applicationContext["overallFraction"] as? Double) ?? 0
        self.achievedCount = (applicationContext["achievedCount"] as? Int) ?? 0
        self.totalGoals = (applicationContext["totalGoals"] as? Int) ?? 0
        self.metrics = (applicationContext["metrics"] as? [[String: Any]])?.compactMap { dict in
            guard
                let key = dict["key"] as? String,
                let daysHit = dict["daysHit"] as? Int,
                let totalDays = dict["totalDays"] as? Int
            else { return nil }
            return Metric(key: key, daysHit: daysHit, totalDays: totalDays)
        } ?? []
        self.badges = (applicationContext["badges"] as? [[String: Any]])?.compactMap { dict in
            guard
                let id = dict["id"] as? String,
                let title = dict["title"] as? String,
                let isEarned = dict["isEarned"] as? Bool
            else { return nil }
            return Badge(id: id, title: title, isEarned: isEarned)
        } ?? []
    }
}
