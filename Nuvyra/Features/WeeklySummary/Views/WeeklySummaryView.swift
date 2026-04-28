import SwiftUI

struct WeeklySummaryView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = WeeklySummaryViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    summaryMetrics
                    NuvyraWeeklyInsightCard(summary: appState.weeklySummary)
                    rhythmCards
                    premiumGate
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Haftalık özet")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.markOpened(appState: appState) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("Haftayı suçlamadan okuyalım")
                .font(NuvyraTypography.caption().weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Küçük desenler, daha iyi planlar.")
                .font(NuvyraTypography.title())
        }
    }

    private var summaryMetrics: some View {
        HStack(spacing: NuvyraSpacing.md) {
            NuvyraMetricCard(title: "Ortalama kalori", value: appState.weeklySummary.averageCalories.formatted(), detail: "kcal / gün", systemImage: "flame")
            NuvyraMetricCard(title: "Ortalama adım", value: appState.weeklySummary.averageSteps.formatted(), detail: "adım / gün", systemImage: "figure.walk")
        }
    }

    private var rhythmCards: some View {
        VStack(spacing: NuvyraSpacing.md) {
            InsightLineCard(title: "En iyi gün", value: appState.weeklySummary.bestDay, detail: "Bu günü çoğaltmaya değil, neden iyi geçtiğini anlamaya odaklanalım.")
            InsightLineCard(title: "Zorlanılan gün", value: appState.weeklySummary.challengingDay, detail: "Telafi baskısı yok. Haftaya o güne küçük bir destek ekleyelim.")
            InsightLineCard(title: "Öğün düzeni", value: "", detail: appState.weeklySummary.mealRhythm)
            InsightLineCard(title: "Su düzeni", value: "", detail: appState.weeklySummary.waterRhythm)
        }
    }

    private var premiumGate: some View {
        Group {
            if !appState.entitlementState.hasPremiumAccess {
                NuvyraGlassCard {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                        Text("Premium ile haftalık özet derinleşir")
                            .font(NuvyraTypography.sectionTitle())
                        Text("Daha kişisel trendler ve adaptif öneriler için abonelik ekranını inceleyebilirsin.")
                            .foregroundStyle(.secondary)
                        NuvyraSecondaryButton(title: "Paywall'u aç", systemImage: "sparkles") {
                            appState.router.selectedTab = .settings
                        }
                    }
                }
            }
        }
    }
}

private struct InsightLineCard: View {
    var title: String
    var value: String
    var detail: String

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                Text(title)
                    .font(NuvyraTypography.caption().weight(.semibold))
                    .foregroundStyle(.secondary)
                if !value.isEmpty {
                    Text(value)
                        .font(NuvyraTypography.title())
                }
                Text(detail)
                    .font(NuvyraTypography.body())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WeeklySummaryView()
        .environmentObject(AppState.preview())
}
