import SwiftData
import SwiftUI

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query private var subscriptionStates: [SubscriptionState]

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    profileCard
                    NavigationLink { SettingsView() } label: { settingsLink("Ayarlar", icon: "gearshape") }
                    NavigationLink { SubscriptionSettingsView() } label: { settingsLink("Abonelik", icon: "crown") }
                    NavigationLink { PrivacyView() } label: { settingsLink("Gizlilik ve KVKK", icon: "lock.shield") }
                    NavigationLink { PremiumView() } label: { settingsLink("Premium'u keşfet", icon: "sparkles") }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileCard: some View {
        let profile = profiles.first
        let subscription = subscriptionStates.first
        return NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text(profile?.name ?? "Nuvyra")
                    .font(NuvyraTypography.hero)
                Text(profile?.goalType.title ?? "Ritmini kurmaya hazırsın")
                    .foregroundStyle(.secondary)
                HStack(spacing: NuvyraSpacing.md) {
                    NuvyraMetricCard(title: "Kalori", value: "\(profile?.dailyCalorieTarget ?? 1_900)", caption: "günlük", systemImage: "flame")
                    NuvyraMetricCard(title: "Adım", value: (profile?.dailyStepTarget ?? 7_500).formatted(), caption: "günlük", systemImage: "figure.walk")
                }
                Text(subscription?.isPremium == true ? "Premium aktif" : "Free plan")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
            }
        }
    }

    private func settingsLink(_ title: String, icon: String) -> some View {
        NuvyraCard {
            HStack {
                Label(title, systemImage: icon)
                    .font(NuvyraTypography.section)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
        }
    }
}
