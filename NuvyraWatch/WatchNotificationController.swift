import SwiftUI
import UserNotifications
import WatchKit

final class WatchNotificationController: WKUserNotificationHostingController<WatchNotificationView> {
    override var body: WatchNotificationView {
        let title = notification?.request.content.title ?? ""
        let message = notification?.request.content.body ?? ""
        return WatchNotificationView(
            title: title.isEmpty ? "Nuvyra" : title,
            message: message.isEmpty ? "Su molası zamanı." : message
        )
    }
}

struct WatchNotificationView: View {
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.cyan)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
