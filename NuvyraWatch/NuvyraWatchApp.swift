import SwiftUI
import WatchKit

@main
struct NuvyraWatchApp: App {
    @StateObject private var session = WatchConnectivityBridge.shared

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
                .environmentObject(session)
                .task { await session.activate() }
        }
        WKNotificationScene(controller: WatchNotificationController.self, category: "nuvyra.water")
    }
}
