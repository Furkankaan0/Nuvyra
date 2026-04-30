import SwiftData
import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @Query private var states: [SubscriptionState]

    var body: some View {
        SubscriptionSettingsContent(
            state: states.first,
            manager: dependencies.subscriptionManager
        )
    }
}

private struct SubscriptionSettingsContent: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    let state: SubscriptionState?
    @ObservedObject var manager: SubscriptionManager
    @State private var isRestoring = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                NuvyraSectionHeader(title: "Abonelik", subtitle: "StoreKit 2 ile yönetilir.")

                NuvyraMetricCard(
                    title: "Durum",
                    value: statusValue,
                    caption: state?.productId ?? "Yerel fallback",
                    systemImage: "crown"
                )

                if let expiration = state?.expirationDate {
                    NuvyraCard {
                        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                            Text(state?.isActive == true ? "Yenileme tarihi" : "Bitiş tarihi")
                                .font(NuvyraTypography.section)
                            Text(expiration.formatted(date: .long, time: .shortened))
                                .font(NuvyraTypography.body)
                                .foregroundStyle(.secondary)
                            // Stale local row warning: the SwiftData row
                            // says premium, but `isActive` says no — the
                            // user's subscription has lapsed.
                            if state?.isPremium == true && state?.isActive == false {
                                Text("Aboneliğin sona ermiş. Erişimi sürdürmek için Premium'u yeniden başlat.")
                                    .font(NuvyraTypography.caption)
                                    .foregroundStyle(NuvyraColors.mutedCoral)
                            }
                        }
                    }
                }

                Link("Apple aboneliklerini yönet", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)

                RestorePurchaseButton(isProcessing: isRestoring) {
                    Task {
                        isRestoring = true
                        await manager.restore(repository: dependencies.subscriptionRepository(context: modelContext))
                        isRestoring = false
                    }
                }

                Spacer()
            }
            .padding(NuvyraSpacing.lg)
        }
        .navigationTitle("Abonelik")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $manager.lastMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }

    private var statusValue: String {
        guard let state else { return "Free" }
        if state.isActive { return "Premium" }
        if state.isPremium { return "Süresi geçti" }
        return "Free"
    }
}
