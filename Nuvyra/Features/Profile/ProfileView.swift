import Charts
import Foundation
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @Query private var settings: [AppSettings]
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var auth = AuthManager.shared
    @State private var showsGoalEditor = false
    @State private var showsProfileEditor = false

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    headerCard
                    ProfileAuthSection()
                    profileInfoSection
                    weightTrendSection
                    bodyMetricsSection
                    bodyMeasurementsSection
                    workoutsSection
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
        .task {
            await auth.restoreSession()
            await viewModel.load(context: modelContext, dependencies: dependencies)
        }
        .sheet(isPresented: $showsGoalEditor) {
            if let profile = viewModel.profile {
                GoalEditorSheet(profile: profile) { calories, water, steps in
                    viewModel.updateGoals(context: modelContext, dependencies: dependencies, calories: calories, waterMl: water, steps: steps)
                }
            }
        }
        .sheet(isPresented: $showsProfileEditor) {
            if let profile = viewModel.profile {
                ProfileEditorSheet(profile: profile) { name, input in
                    viewModel.updateProfile(context: modelContext, dependencies: dependencies, name: name, input: input)
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
                        Text(headerDisplayName)
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

                NuvyraSecondaryButton(title: "Profili düzenle", systemImage: "pencil") {
                    showsProfileEditor = true
                }
            }
        }
    }

    private var headerDisplayName: String {
        cleanProfileName(viewModel.profile?.name)
            ?? cleanProfileName(auth.state.session?.displayName)
            ?? "Profilini tamamla"
    }

    private func cleanProfileName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed == "Nuvyra" ? nil : trimmed
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

    private var weightTrendSection: some View {
        ProfileWeightTrendCard(summary: viewModel.weightTrend, targetWeightKg: viewModel.profile?.targetWeightKg)
    }

    @ViewBuilder
    private var bodyMetricsSection: some View {
        if let profile = viewModel.profile {
            BodyMetricsCard(summary: BodyMetricsCalculator.summary(for: profile))
        }
    }

    private var bodyMeasurementsSection: some View {
        SettingsSection(title: "Vücut ölçüleri", subtitle: "Bel, kalça, vücut yağı gibi kompozisyon değişimleri.") {
            NavigationLink {
                BodyMeasurementsView()
            } label: {
                SettingsRow(
                    title: "Tüm ölçümler",
                    subtitle: "Trend, geçmiş ve yeni kayıt.",
                    systemImage: "ruler",
                    tint: NuvyraColors.accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var workoutsSection: some View {
        SettingsSection(title: "Egzersizler", subtitle: "Koşu, bisiklet, gym ve diğer aktivite kayıtların.") {
            NavigationLink {
                WorkoutsView()
            } label: {
                SettingsRow(
                    title: "Tüm egzersizler",
                    subtitle: "Apple Health + manuel kayıtlar tek listede.",
                    systemImage: "figure.run.circle.fill",
                    tint: NuvyraColors.mutedCoral
                )
            }
            .buttonStyle(.plain)
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
                SettingsRow(title: "Hesabı yönet", subtitle: "Veri dışa aktarma, yerel veri silme ve oturum bilgileri.", systemImage: "person.crop.circle.badge.exclamationmark")
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

private struct ProfileWeightTrendCard: View {
    @Environment(\.colorScheme) private var scheme
    var summary: WeightTrendSummary
    var targetWeightKg: Double?

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kilo trendi")
                            .font(NuvyraTypography.section)
                        Text(subtitle)
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    Spacer()
                    if let latest = summary.latestWeightKg {
                        Text("\(latest, specifier: "%.1f") kg")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                }

                if summary.logs.count >= 2 {
                    Chart(summary.logs) { log in
                        LineMark(
                            x: .value("Tarih", log.date),
                            y: .value("Kilo", log.weightKg)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(NuvyraColors.accent)

                        PointMark(
                            x: .value("Tarih", log.date),
                            y: .value("Kilo", log.weightKg)
                        )
                        .foregroundStyle(NuvyraColors.accent)
                    }
                    .frame(height: 150)
                    .chartXAxis(.hidden)
                    .accessibilityLabel("Kilo trend grafiği")
                    .accessibilityValue(accessibilitySummary)
                } else {
                    HStack(spacing: NuvyraSpacing.sm) {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundStyle(NuvyraColors.accent)
                        Text("Trend için en az iki kilo kaydı gerekir. Profilini güncellediğinde kayıt otomatik oluşur.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var subtitle: String {
        if let projected = summary.projectedGoalDate {
            return "Bu tempoyla hedefe yaklaşık \(projected.formatted(date: .abbreviated, time: .omitted)) civarında ulaşabilirsin."
        }
        if summary.deltaKg == 0 {
            return targetWeightKg == nil ? "Hedef kilo ekleyerek projeksiyon alabilirsin." : "Trend oluşması için birkaç kayıt daha yeterli."
        }
        let sign = summary.deltaKg > 0 ? "+" : ""
        return "Son 90 günde \(sign)\(String(format: "%.1f", summary.deltaKg)) kg değişim."
    }

    private var accessibilitySummary: String {
        guard let latest = summary.latestWeightKg else { return "Henüz kilo kaydı yok." }
        return "Son kilo \(String(format: "%.1f", latest)) kilogram. Değişim \(String(format: "%.1f", summary.deltaKg)) kilogram."
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
