import Foundation
import SwiftData
import WatchConnectivity

@MainActor
final class WatchWaterSyncService: NSObject {
    private let processedEventIDsKey = "watch.water.processedEventIDs"
    private var modelContainer: ModelContainer?
    private var isSessionConfigured = false

    func activate(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer

        guard WCSession.isSupported(), !isSessionConfigured else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        isSessionConfigured = true
    }

    /// Outbound state push: mirrors the latest weekly-goal snapshot to
    /// the paired Watch via `updateApplicationContext`. Latest-state
    /// wins (no message queue replay), so we don't have to dedup on the
    /// watch side. Safely no-ops when WC isn't supported, paired, or
    /// the watch hasn't installed the companion app.
    func pushWeeklyGoalSnapshot(_ summary: WeeklyGoalSummary) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }

        let payload: [String: Any] = [
            "type": "goals.snapshot",
            "overallFraction": summary.overallFraction,
            "achievedCount": summary.achievedCount,
            "totalGoals": summary.progress.count,
            "metrics": summary.progress.map { [
                "key": $0.metric.rawValue,
                "daysHit": $0.daysHit,
                "totalDays": $0.totalDays
            ] },
            "badges": summary.badges.map { [
                "id": $0.id,
                "title": $0.title,
                "isEarned": $0.isEarned
            ] }
        ]
        do {
            try session.updateApplicationContext(payload)
        } catch {
            // Non-fatal — the next refresh will retry. Logging only in
            // debug avoids leaking the WC error through release.
            #if DEBUG
            print("[WatchWaterSyncService] updateApplicationContext failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func handleWaterPayload(_ payload: [String: Any]) {
        guard payload["type"] as? String == "water.added" else { return }
        guard let rawAmount = payload["amountMl"] as? Int else { return }

        let eventID = payload["eventID"] as? String
        if let eventID, hasProcessed(eventID) { return }

        let amount = min(max(rawAmount, 1), 2_000)
        let timestamp = payload["timestamp"] as? TimeInterval
        let date = timestamp.map(Date.init(timeIntervalSince1970:)) ?? Date()

        guard let modelContainer else { return }

        do {
            try SwiftDataWaterRepository(context: modelContainer.mainContext).addWater(amountMl: amount, date: date)
            if let eventID { markProcessed(eventID) }
            Task { @MainActor in
                await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(
                    context: modelContainer.mainContext,
                    healthService: LiveHealthService()
                )
            }
            NotificationCenter.default.post(name: .nuvyraAppDidBecomeActive, object: nil)
        } catch {
            assertionFailure("Watch water sync failed: \(error.localizedDescription)")
        }
    }

    private func hasProcessed(_ eventID: String) -> Bool {
        let ids = UserDefaults.standard.stringArray(forKey: processedEventIDsKey) ?? []
        return ids.contains(eventID)
    }

    private func markProcessed(_ eventID: String) {
        var ids = UserDefaults.standard.stringArray(forKey: processedEventIDsKey) ?? []
        ids.append(eventID)
        UserDefaults.standard.set(Array(ids.suffix(50)), forKey: processedEventIDsKey)
    }
}

/// Process-wide outbound hook for one-way iPhone → Watch state pushes.
/// `NuvyraApp` registers the live `WatchWaterSyncService` here once at
/// launch; view models call into it without importing the service or
/// drilling it through `DependencyContainer`. Off by default — a build
/// without a paired watch (simulators, CI) safely no-ops.
@MainActor
enum WatchOutbound {
    private static weak var sink: WatchWaterSyncService?
    /// Last snapshot we actually sent. Used to short-circuit repeat
    /// pushes — every dashboard refresh recomputes WeeklyGoalSummary,
    /// but the value usually hasn't moved within a few minutes. Skipping
    /// the identical payload avoids a needless IPC round-trip + dict
    /// serialise, which matters on a tight foreground refresh loop.
    private static var lastSentSnapshot: WeeklyGoalSummary?

    static func register(_ service: WatchWaterSyncService) { sink = service }

    static func pushWeeklyGoals(_ summary: WeeklyGoalSummary) {
        guard summary != lastSentSnapshot else { return }
        lastSentSnapshot = summary
        sink?.pushWeeklyGoalSnapshot(summary)
    }
}

extension WatchWaterSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.handleWaterPayload(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handleWaterPayload(userInfo)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
