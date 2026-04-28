import SwiftUI

struct HealthPermissionExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var status: HealthAuthorizationStatus?

    var body: some View {
        NuvyraBackground()
            .overlay {
                NuvyraPermissionCard(
                    title: "Apple Sağlık bağlantısı",
                    bodyText: "Nuvyra yalnızca adım sayını okuyarak yürüyüş hedefini kişiselleştirir. Sağlık verisi reklam amacıyla kullanılmaz.",
                    systemImage: "heart.text.square",
                    primaryTitle: status == .granted ? "Bağlandı" : "İzin ver",
                    secondaryTitle: "Kapat",
                    primaryAction: {
                        Task { status = await appState.requestHealthKitSteps() }
                    },
                    secondaryAction: { dismiss() }
                )
                .padding()
            }
    }
}

struct NotificationPermissionExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var status: NotificationPermissionStatus?

    var body: some View {
        NuvyraBackground()
            .overlay {
                NuvyraPermissionCard(
                    title: "Nazik bildirimler",
                    bodyText: "İlk gün çok bildirim göndermeyiz. Hatırlatmalar ritim odaklıdır ve Ayarlar'dan kapatılabilir.",
                    systemImage: "bell.badge",
                    primaryTitle: status == .granted ? "Bildirimler açık" : "İzin ver",
                    secondaryTitle: "Kapat",
                    primaryAction: {
                        Task {
                            status = await appState.requestNotifications()
                            await appState.scheduleGentleReminders()
                        }
                    },
                    secondaryAction: { dismiss() }
                )
                .padding()
            }
    }
}
