import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    accountCard
                    paywallCard
                    privacyCard
                    notificationCard
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingPrivacy) {
            PrivacyAndKVKKView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("Nuvyra")
                .font(NuvyraTypography.hero())
            Text("Wellness odaklı, veri minimizasyonunu önceleyen günlük ritim koçu.")
                .foregroundStyle(.secondary)
        }
    }

    private var accountCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Durum")
                    .font(NuvyraTypography.sectionTitle())
                Text(appState.entitlementState.tier.title)
                    .font(NuvyraTypography.metric())
                NavigationLink("Profil ve hedefler") {
                    ProfileView()
                }
            }
        }
    }

    private var privacyCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Gizlilik ve KVKK")
                    .font(NuvyraTypography.sectionTitle())
                Text("Sağlık verisi reklam amacıyla kullanılmaz. Uygulama tıbbi tavsiye vermez.")
                    .foregroundStyle(.secondary)
                NuvyraSecondaryButton(title: "Aydınlatma metnini oku", systemImage: "lock.shield") {
                    viewModel.showingPrivacy = true
                }
            }
        }
    }

    private var paywallCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Premium")
                    .font(NuvyraTypography.sectionTitle())
                Text("Sınırsız fotoğraflı kayıt, adaptif yürüyüş planı ve haftalık koç özeti.")
                    .foregroundStyle(.secondary)
                NavigationLink {
                    PaywallView()
                } label: {
                    Label("Abonelik seçeneklerini gör", systemImage: "sparkles")
                        .font(.headline.weight(.semibold))
                }
            }
        }
    }

    private var notificationCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Bildirimler")
                    .font(NuvyraTypography.sectionTitle())
                Text("Hatırlatmaları ritim odaklı ve sınırlı tutarız.")
                    .foregroundStyle(.secondary)
                NuvyraSecondaryButton(title: "Bildirimleri ayarla", systemImage: "bell") {
                    appState.router.presentedSheet = .notificationPermission
                }
            }
        }
    }
}

struct PrivacyAndKVKKView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        Text("Gizlilik ve KVKK Notları")
                            .font(NuvyraTypography.title())
                        legalText("Nuvyra wellness/fitness uygulamasıdır; tıbbi teşhis, tedavi veya profesyonel beslenme danışmanlığı sunmaz.")
                        legalText("Kalori ve besin değerleri tahminidir. Özel diyet, hastalık veya sağlık durumun varsa profesyonel destek almalısın.")
                        legalText("Apple Sağlık verileri yalnızca gerekli izinlerle okunur. İlk fazda adım sayısı kullanılır; sağlık verisi reklam veya üçüncü taraf pazarlama amacıyla paylaşılmaz.")
                        legalText("Veri minimizasyonu esastır. Kullanıcı veri silme talebi için destek kanalı hazırlanmalıdır.")
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle("KVKK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private func legalText(_ text: String) -> some View {
        NuvyraGlassCard {
            Text(text)
                .font(NuvyraTypography.body())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.preview())
}

