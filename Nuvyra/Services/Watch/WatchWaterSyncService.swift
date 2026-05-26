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
