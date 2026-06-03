import SwiftUI

/// Hero card: large animated calorie ring with remaining/consumed/burned breakdown.
struct CalorieBalanceCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var animatedProgress: Double = 0
    @State private var ringRotation: Double = 0

    var summary: DailyNutritionSummary

    // Legacy initializer to keep older call sites compiling.
    init(consumed: Int, burned: Int, target: Int, remaining: Int = 0) {
        self.summary = DailyNutritionSummary(consumedCalories: consumed, burnedCalories: burned, targetCalories: target)
    }

    init(summary: DailyNutritionSummary) {
        self.summary = summary
    }

    var body: some View {
        NuvyraGlassCard(.prominent) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                header
                HStack(spacing: NuvyraSpacing.lg) {
                    ringView
                    breakdown
                }
            }
        }
        .onAppear { animate(to: summary.ringProgress) }
        .onChange(of: summary.ringProgress) { _, newValue in animate(to: newValue) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kalori dengesi")
        .accessibilityValue(
            "\(summary.consumedCalories) kilokalori alındı, \(summary.burnedCalories) kilokalori yakıldı, hedef \(summary.targetCalories) kilokalori, kalan \(summary.remainingCalories) kilokalori."
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kalori dengesi")
                    .font(NuvyraTypography.section)
                Text("Hedef \(summary.targetCalories) kcal")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "flame.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(LinearGradient(colors: [NuvyraColors.mutedCoral, NuvyraColors.accent], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
        }
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(NuvyraColors.accent.opacity(0.10), lineWidth: 16)
                .accessibilityHidden(true)
            Circle()
                .trim(from: 0, to: animatedProgress.clamped(to: 0...1))
                .stroke(
                    AngularGradient(
                        colors: [NuvyraColors.accent, NuvyraColors.paleLime, NuvyraColors.mutedCoral, NuvyraColors.accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: NuvyraColors.accent.opacity(0.35), radius: 10, x: 0, y: 4)
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                Text("\(summary.remainingCalories)")
                    .font(NuvyraTypography.metricFont(size: 34, relativeTo: .largeTitle))
                    .contentTransition(.numericText())
                Text("kcal kaldı")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 148, height: 148)
        .rotation3DEffect(
            .degrees(reduceMotion ? 0 : ringRotation),
            axis: (x: 1, y: 0.4, z: 0),
            perspective: 0.6
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.2)) { ringRotation = 0 }
            ringRotation = -8
            withAnimation(.spring(response: 0.9, dampingFraction: 0.65)) { ringRotation = 0 }
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            metricRow(icon: "fork.knife", title: "Alınan", value: "\(summary.consumedCalories) kcal", tint: NuvyraColors.accent)
            metricRow(icon: "flame", title: "Yakılan", value: "\(summary.burnedCalories) kcal", tint: NuvyraColors.mutedCoral)
            metricRow(icon: "target", title: "Hedef", value: "\(summary.targetCalories) kcal", tint: NuvyraColors.softSand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
    }

    private func animate(to target: Double) {
        guard !reduceMotion else { animatedProgress = target; return }
        withAnimation(.easeInOut(duration: 0.85)) { animatedProgress = target }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

#if DEBUG
#Preview("Calorie hero") {
    ZStack {
        NuvyraBackground()
        CalorieBalanceCard(summary: DashboardPreviewData.nutrition)
            .padding()
    }
}
#endif
