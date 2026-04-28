import SwiftUI

struct WalkingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = WalkingViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    NuvyraStepGoalCard(snapshot: appState.stepSnapshot)
                    suggestionCard
                    weeklyChart
                    permissionCard
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.refresh(appState: appState) }
        }
        .navigationTitle("Yürüyüş")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh(appState: appState) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("Bugün düşük tempoda kalmak da sorun değil.")
                .font(NuvyraTypography.caption().weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Devamlılık daha önemli.")
                .font(NuvyraTypography.title())
        }
    }

    private var suggestionCard: some View {
        let suggestion = WalkingSuggestion.today(from: appState.stepSnapshot)
        return NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Label(suggestion.title, systemImage: "figure.walk.motion")
                    .font(NuvyraTypography.sectionTitle())
                Text(suggestion.detail)
                    .foregroundStyle(.secondary)
                if let recommendation = viewModel.recommendation {
                    Divider()
                    Text(recommendation.reason)
                        .font(NuvyraTypography.caption())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var weeklyChart: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Haftalık adım trendi")
                    .font(NuvyraTypography.sectionTitle())
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(appState.stepHistory) { day in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(day.didHitGoal ? NuvyraColor.lightPrimary : NuvyraColor.lightSecondaryAccent.opacity(0.45))
                                .frame(height: max(CGFloat(day.steps) / CGFloat(max(day.goal, 1)) * 120, 12))
                            Text(shortWeekday(day.date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private var permissionCard: some View {
        Group {
            if appState.stepSnapshot.source == .unavailable {
                NuvyraPermissionCard(
                    title: "Adımlarını otomatik almak ister misin?",
                    bodyText: "Apple Sağlık izni yoksa uygulama kırılmaz; sadece adım verisini manuel veya demo düzeyinde gösterir.",
                    systemImage: "heart.text.square",
                    primaryTitle: "Apple Sağlık'a bağlan",
                    secondaryTitle: nil,
                    primaryAction: { appState.router.presentedSheet = .healthPermission },
                    secondaryAction: nil
                )
            }
        }
    }

    private func shortWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

#Preview {
    WalkingView()
        .environmentObject(AppState.preview())
}
