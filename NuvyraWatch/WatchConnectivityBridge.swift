import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = WatchConnectivityBridge()

    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var isReachable = false

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
}
