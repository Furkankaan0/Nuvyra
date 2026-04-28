import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    mainMetrics
                    recommendationCard
                    quickActions
                    recentMeals
                    premiumCard
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable {
                await viewModel.refresh(appState: appState)
            }
        }
        .navigationTitle("Bugünkü ritmin")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh(appState: appState) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text(viewModel.greeting())
                .font(NuvyraTypography.caption().weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Bugünkü ritmin")
                .font(NuvyraTypography.hero())
            Text(DateFormatter.nuvyraShortDate.string(from: Date()))
                .foregroundStyle(.secondary)
        }
    }

    private var mainMetrics: some View {
        VStack(spacing: NuvyraSpacing.md) {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Kalori dengesi")
                                .font(NuvyraTypography.sectionTitle())
                            Text("\(appState.remainingCaloriesToday) kcal kaldı")
                                .font(NuvyraTypography.metric())
                            Text("\(appState.caloriesConsumedToday) / \(appState.calorieTarget.recommended) kcal alındı")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        NuvyraProgressRing(
                            progress: Double(appState.caloriesConsumedToday) / Double(max(appState.calorieTarget.recommended, 1)),
                            lineWidth: 10,
                            centerText: "\(Int(min(Double(appState.caloriesConsumedToday) / Double(max(appState.calorieTarget.recommended, 1)), 1) * 100))%",
                            caption: "kalori"
                        )
                        .frame(width: 116, height: 116)
                    }
                }
            }

            HStack(spacing: NuvyraSpacing.md) {
                NuvyraMetricCard(title: "Adım", value: appState.stepSnapshot.steps.formatted(), detail: "Hedef \(appState.stepSnapshot.goal.formatted())", systemImage: "figure.walk")
                NuvyraMetricCard(title: "Su", value: "\(appState.waterGlassesToday)/8", detail: "Bugünkü bardak", systemImage: "drop.fill", tint: .blue)
            }
        }
    }

    private var recommendationCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Label(appState.dailyPlan?.message.title ?? "Bugün için önerim", systemImage: "sparkles")
                    .font(NuvyraTypography.sectionTitle())
                Text(appState.dailyPlan?.message.body ?? "İlk öğününü ekleyelim ve adımlarını birlikte okuyalım.")
                    .font(NuvyraTypography.body())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Hızlı aksiyonlar")
                .font(NuvyraTypography.sectionTitle())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
                QuickActionButton(title: "Öğün ekle", systemImage: "plus.circle") {
                    appState.router.selectedTab = .meals
                }
                QuickActionButton(title: "Fotoğrafla kaydet", systemImage: "camera") {
                    appState.router.presentedSheet = .photoMeal
                }
                QuickActionButton(title: "Yürüyüş başlat", systemImage: "figure.walk") {
                    appState.router.selectedTab = .walking
                }
                QuickActionButton(title: "Su içtim", systemImage: "drop") {
                    Task { await appState.logWaterGlass() }
                }
            }
        }
    }

    private var recentMeals: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack {
                Text("Son öğünler")
                    .font(NuvyraTypography.sectionTitle())
                Spacer()
                Button("Tümü") { appState.router.selectedTab = .meals }
                    .font(.subheadline.weight(.semibold))
            }
            if appState.meals.isEmpty {
                EmptyStateCard(title: "İlk öğününü ekleyelim.", detail: "Manuel yazabilir, fotoğrafla kaydedebilir veya hızlı Türk yemeği seçebilirsin.", systemImage: "fork.knife")
            } else {
                ForEach(appState.meals.prefix(3)) { meal in
                    NuvyraMealCard(meal: meal)
                }
            }
        }
    }

    private var premiumCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Haftalık koç özetini aç")
                    .font(NuvyraTypography.sectionTitle())
                Text("Ritmini tek tek sayılarla değil, haftalık desenlerle anlamlandır.")
                    .foregroundStyle(.secondary)
                NuvyraSecondaryButton(title: appState.entitlementState.hasPremiumAccess ? "Özete git" : "Premium'u gör", systemImage: "sparkles") {
                    appState.router.selectedTab = appState.entitlementState.hasPremiumAccess ? .weekly : .settings
                }
            }
        }
    }
}

private struct QuickActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button {
            NuvyraHaptics.softTap()
            action()
        } label: {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NuvyraColor.lightPrimary)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateCard: View {
    var title: String
    var detail: String
    var systemImage: String

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(NuvyraColor.lightPrimary)
                Text(title)
                    .font(NuvyraTypography.sectionTitle())
                Text(detail)
                    .font(NuvyraTypography.body())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState.preview())
}
