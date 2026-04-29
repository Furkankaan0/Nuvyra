import SwiftUI

struct HealthPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var dependencies: DependencyContainer

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label("Apple Health bağlantısı", systemImage: "heart.text.square")
                    .font(NuvyraTypography.section)
                Text("Adım, aktif enerji ve yürüyüş mesafesini yalnızca uygulama içindeki hedef ve içgörüler için okuruz. Sağlık verilerin reklam hedefleme için kullanılmaz.")
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.secondary)
                NuvyraSecondaryButton(title: healthButtonTitle, systemImage: "heart") {
                    Task { await viewModel.requestHealth(dependencies: dependencies) }
                }
                Toggle("Nazik bildirimler iste", isOn: $viewModel.wantsNotifications)
            }
        }
        .padding(.horizontal, NuvyraSpacing.lg)
    }

    private var healthButtonTitle: String {
        viewModel.healthState == .sharingAuthorized ? "Apple Health bağlı" : "Health iznini aç"
    }
}
