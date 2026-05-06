import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @Query private var settings: [AppSettings]
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showsGoalEditor = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    headerCard
                    profileInfoSection
                    goalsSection
                    premiumSection
                    healthSection
                    preferencesSection
                    legalSection
                    accountSection
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        .sheet(isPresented: $showsGoalEditor) {
            if let profile = viewModel.profile {
                GoalEditorSheet(profile: profile) { calories, water, steps in
                    viewModel.updateGoals(context: modelContext, calories: calories, waterMl: water, steps: steps)
                }
            }
        }
        .alert("Profil", isPresented: alertBinding) {
            Button("Tamam", role: .cancel) { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var headerCard: some View {
        let profile = viewModel.profile
        return NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile?.name ?? "Nuvyra")
                            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        Text(profile?.goalType.title ?? "Ritmini kurmaya hazırsın")
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: dependencies.subscriptionManager.isPremium ? "crown.fill" : "leaf.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(NuvyraColors.accent, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                }

                HStack(spacing: NuvyraSpacing.sm) {
                    ProfilePill(title: "Yaş", value: "\(profile?.age ?? 30)")
                    ProfilePill(title: "Boy", value: "\(Int(profile?.heightCm ?? 175)) cm")
                    ProfilePill(title: "Kilo", value: "\(Int(profile?.weightKg ?? 78)) kg")
                }
            }
        }
    }

    private var profileInfoSection: some View {
        let profile = viewModel.profile
        return SettingsSection(title: "Kullanıcı bilgileri") {
            SettingsRow(title: "Cinsiyet", subtitle: profile?.gender?.title ?? "Belirtmek istemiyorum", systemImage: "person.fill")
            SettingsDivider()
            SettingsRow(title: "Aktivite", subtitle: profile?.activityLevel.title ?? "Hafif aktif", systemImage: "figure.walk")
            SettingsDivider()
            SettingsRow(title: "Hedef temposu", subtitle: profile?.goalPace?.title ?? "Dengeli", systemImage: "speedometer")
        }
    }

    private var goalsSection: some View {
        let profile = viewModel.profile
        return SettingsSection(title: "Günlük hedefler", subtitle: "Onboarding sırasında oluşturulan wellness hedeflerin.") {
            SettingsRow(title: "Kalori hedefi", subtitle: "\(profile?.dailyCalorieTarget ?? 1_900) kcal", systemImage: "flame.fill", tint: NuvyraColors.mutedCoral)
            SettingsDivider()
            SettingsRow(title: "Su hedefi", subtitle: "\(profile?.dailyWaterTargetMl ?? 2_000) ml", systemImage: "drop.fill", tint: NuvyraColors.softMint)
            SettingsDivider()
            SettingsRow(title: "Adım hedefi", subtitle: "\((profile?.dailyStepTarget ?? 7_500).formatted()) adım", systemImage: "figure.walk", tint: NuvyraColors.accent)
            SettingsDivider()
            Button {
                showsGoalEditor = true
            } label: {
                SettingsRow(title: "Hedefleri düzenle", subtitle: "Kalori, su ve adım hedefini güncelle.", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
        }
    }

    private var premiumSection: some View {
        SettingsSection(title: "Premium") {
            NavigationLink {
                SubscriptionSettingsView()
            } label: {
                SettingsRow(title: "Premium durum", subtitle: viewModel.premiumStatusTitle, systemImage: "crown.fill", tint: NuvyraColors.softSand)
            }
            .buttonStyle(.plain)

            SettingsDivider()

            NavigationLink {
                PremiumView()
            } label: {
                SettingsRow(title: "Premium'u keşfet", subtitle: "AI Coach, barkod, kamera tanıma ve gelişmiş analizler.", systemImage: "sparkles", tint: NuvyraColors.accent)
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                SettingsRow(title: "Abonelik yönetimi", subtitle: "Apple ID abonelik ayarlarını aç.", systemImage: "creditcard.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var healthSection: some View {
        SettingsSection(title: "Apple Health") {
            SettingsRow(title: "Bağlantı durumu", subtitle: viewModel.healthStatusTitle, systemImage: "heart.text.square.fill", tint: NuvyraColors.mutedCoral)
            SettingsDivider()
            Button {
                Task { await viewModel.requestHealth(dependencies: dependencies) }
            } label: {
                SettingsRow(title: "Health iznini yenile", subtitle: "Adım ve aktivite verisi için izin iste.", systemImage: "heart")
            }
            .buttonStyle(.plain)
        }
    }

    private var preferencesSection: some View {
        SettingsSection(title: "Tercihler") {
            SettingsRow(title: "Bildirimler", subtitle: "Su, öğün ve yürüyüş hatırlatmaları.", systemImage: "bell.badge.fill") {
                Toggle("Bildirimler", isOn: notificationBinding)
                    .labelsHidden()
                    .tint(NuvyraColors.accent)
            }
            SettingsDivider()
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                SettingsRow(title: "Tema seçimi", subtitle: "Sistem, açık veya koyu görünüm.", systemImage: "paintpalette.fill")
                ThemeSelector()
                    .padding(.top, NuvyraSpacing.xs)
            }
            .padding(.vertical, 12)
        }
    }

    private var legalSection: some View {
        SettingsSection(title: "Yasal ve gizlilik") {
            NavigationLink {
                PrivacyView()
            } label: {
                SettingsRow(title: "Gizlilik politikası", subtitle: "HealthKit ve KVKK notları.", systemImage: "lock.shield.fill")
            }
            .buttonStyle(.plain)

            SettingsDivider()

            Link(destination: URL(string: "https://nuvyra.app/terms")!) {
                SettingsRow(title: "Kullanım şartları", subtitle: "Abonelik ve uygulama kullanım koşulları.", systemImage: "doc.text.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var accountSection: some View {
        SettingsSection(title: "Hesap") {
            NavigationLink {
                AccountManagementView()
            } label: {
                SettingsRow(title: "Hesabı yönet", subtitle: "Veri dışa aktarma, hesap silme ve çıkış.", systemImage: "person.crop.circle.badge.exclamationmark")
            }
            .buttonStyle(.plain)
        }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { settings.first?.notificationsEnabled ?? false },
            set: { newValue in
                let item: AppSettings
                if let existing = settings.first {
                    item = existing
                } else {
                    item = AppSettings()
                    modelContext.insert(item)
                }
                item.notificationsEnabled = newValue
                item.updatedAt = Date()
                try? modelContext.save()
            }
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.alertMessage = nil }
            }
        )
    }
}

private struct ProfilePill: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
            Text(value)
                .font(.footnote.weight(.heavy))
                .foregroundStyle(NuvyraColors.primaryText(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NuvyraColors.card(scheme).opacity(0.62), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
