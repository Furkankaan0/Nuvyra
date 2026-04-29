import SwiftData
import SwiftUI

struct SubscriptionSettingsView: View {
    @Query private var states: [SubscriptionState]

    var body: some View {
        ZStack {
            NuvyraBackground()
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                let state = states.first
                NuvyraSectionHeader(title: "Abonelik", subtitle: "StoreKit 2 ile yönetilir.")
                NuvyraMetricCard(title: "Durum", value: state?.isPremium == true ? "Premium" : "Free", caption: state?.productId ?? "Yerel fallback", systemImage: "crown")
                Link("Apple aboneliklerini yönet", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                Spacer()
            }
            .padding(NuvyraSpacing.lg)
        }
        .navigationTitle("Abonelik")
        .navigationBarTitleDisplayMode(.inline)
    }
}
