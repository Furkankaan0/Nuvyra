import SwiftData
import SwiftUI

struct WaterTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = WaterTrackingViewModel()

    var body: some View {
        ZStack {
            softBlueBackground
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "Su takibi",
                        subtitle: "Günlük hedefini takip et, küçük molalarla ritmini koru."
                    )
                    NuvyraDateNavigator(
                        date: Binding(
                            get: { viewModel.selectedDate },
                            set: { viewModel.changeDate(to: $0, context: modelContext, dependencies: dependencies) }
                        ),
                        title: "Su tarihi"
                    )
                    WaterProgressCard(
                        summary: viewModel.summary,
                        label: Calendar.nuvyra.isDateInToday(viewModel.selectedDate) ? "Bugün" : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted)
                    )
                    StreakCard(kind: .water, insight: viewModel.streak)
                    drinkPickerSection
                    quickAddSection
                    manualInputSection
                    if !viewModel.entries.isEmpty {
                        todayEntriesSection
                    }
                    DrinkBreakdownCard(
                        breakdown: viewModel.breakdown,
                        totalFluidMl: viewModel.totalFluidMl,
                        hydrationMl: viewModel.totalHydrationMl,
                        waterGoalMl: viewModel.goal.dailyTargetMl
                    )
                    CaffeineCard(totalMg: viewModel.totalCaffeineMg, limitMg: viewModel.caffeineLimitMg)
                    WeeklyWaterChart(totals: viewModel.weeklyTotals, goalMl: viewModel.goal.dailyTargetMl)
                    disclaimer
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }

            if viewModel.showGoalCelebration {
                WaterGoalCelebration {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        viewModel.showGoalCelebration = false
                    }
                }
                .transition(.opacity)
            }

            feedbackOverlay
        }
        .navigationTitle("Su")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
    }

    // MARK: - Background
    @ViewBuilder
    private var softBlueBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.94, blue: 0.99),
                Color(red: 0.97, green: 0.99, blue: 1.00),
                Color(red: 0.78, green: 0.89, blue: 0.97)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color(red: 0.35, green: 0.65, blue: 0.95).opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 120, y: -130)
        }
    }

    // MARK: - Sections

    private var drinkPickerSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(
                    title: "İçecek tipi",
                    subtitle: "Su dışında kahve, çay, smoothie ve diğer içecekleri de kaydedebilirsin."
                )
                DrinkTypePicker(selection: $viewModel.selectedDrinkType)
            }
        }
    }

    private var quickAddSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Hızlı ekle", subtitle: "Seçili: \(viewModel.selectedDrinkType.title)")
                HStack(spacing: NuvyraSpacing.sm) {
                    ForEach(WaterGoal.quickAddPresets, id: \.self) { amount in
                        QuickWaterButton(amountMl: amount, tint: viewModel.selectedDrinkType.tint) {
                            Task { await viewModel.add(amount: amount, context: modelContext, dependencies: dependencies) }
                        }
                    }
                }
            }
        }
    }

    private var manualInputSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Manuel giriş", subtitle: "İstediğin miktarı seç")
                HStack(spacing: NuvyraSpacing.md) {
                    Stepper(value: $viewModel.manualAmountMl, in: WaterGoal.manualEntryRange, step: 25) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.manualAmountMl) ml")
                                .font(.title3.weight(.heavy))
                                .contentTransition(.numericText())
                            Text("50 – 2.000 ml arası")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: NuvyraSpacing.sm) {
                    NuvyraPrimaryButton(title: "Ekle", systemImage: "drop.fill") {
                        Task { await viewModel.add(amount: viewModel.manualAmountMl, context: modelContext, dependencies: dependencies) }
                    }
                    NuvyraSecondaryButton(title: "Geri al", systemImage: "arrow.uturn.backward") {
                        Task { await viewModel.removeLast(context: modelContext, dependencies: dependencies) }
                    }
                }
            }
        }
    }

    private var todayEntriesSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                HStack {
                    NuvyraSectionHeader(title: Calendar.nuvyra.isDateInToday(viewModel.selectedDate) ? "Bugünkü kayıtlar" : "Seçili gün kayıtları", subtitle: nil)
                    Spacer()
                    Button(role: .destructive) {
                        Task { await viewModel.clearToday(context: modelContext, dependencies: dependencies) }
                    } label: {
                        Text("Sıfırla")
                            .font(.caption.weight(.semibold))
                    }
                }
                ForEach(viewModel.entries) { entry in
                    WaterEntryRow(entry: entry) {
                        Task { await viewModel.remove(entry, context: modelContext, dependencies: dependencies) }
                    }
                    if entry.id != viewModel.entries.last?.id {
                        Divider().padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("Hatırlatıcı altyapısı bildirim izniyle aktive olur. Profil > Bildirim ayarlarından açıp kapatabilirsin.")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var feedbackOverlay: some View {
        if let feedback = viewModel.actionFeedback {
            VStack {
                Spacer()
                Text(feedback)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.20, green: 0.56, blue: 0.95).opacity(0.92), in: Capsule())
                    .shadow(color: Color(red: 0.20, green: 0.56, blue: 0.95).opacity(0.35), radius: 12, y: 6)
                    .padding(.bottom, NuvyraSpacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .allowsHitTesting(false)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.actionFeedback)
        }
    }
}

private struct WaterEntryRow: View {
    var entry: WaterEntry
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            Image(systemName: "drop.fill")
                .font(.headline)
                .foregroundStyle(Color(red: 0.20, green: 0.56, blue: 0.95))
                .frame(width: 32, height: 32)
                .background(Color(red: 0.20, green: 0.56, blue: 0.95).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.amountMl) ml")
                    .font(.subheadline.weight(.semibold))
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(NuvyraColors.mutedCoral)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bu kaydı sil")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { WaterTrackingView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
