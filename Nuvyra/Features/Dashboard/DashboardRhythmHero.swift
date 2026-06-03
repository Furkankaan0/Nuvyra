import SwiftUI

/// Top-most Dashboard card: a single-glance "ritim skoru" that blends
/// today's calorie, water and step progress into one normalised 0–100
/// number, surrounded by three small companion metrics.
///
/// The score is computed exactly the way the lock-screen widget does
/// (`NuvyraWidgetSnapshot.rhythmScore`) so a user looking at the app and
/// the lock-screen widget at the same time sees the same number.
struct DashboardRhythmHero: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedScore: Double = 0

    var summary: DailyNutritionSummary
    var water: WaterSummary
    var steps: StepSummary
    var proteinGrams: Double
    var proteinTargetGrams: Double

    var body: some View {
        NuvyraGlassCard(.prominent) {
            HStack(alignment: .center, spacing: NuvyraSpacing.lg) {
                rhythmRing
                companionRail
            }
        }
        .onAppear { animate() }
        .onChange(of: rhythmScore) { _, _ in animate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Score computation

    private var calorieProgress: Double {
        guard summary.targetCalories > 0 else { return 0 }
        return min(max(Double(summary.consumedCalories) / Double(summary.targetCalories), 0), 1)
    }

    private var waterProgress: Double { water.progress }
    private var stepProgress: Double { steps.progress }

    private var proteinProgress: Double {
        guard proteinTargetGrams > 0 else { return 0 }
        return min(max(proteinGrams / proteinTargetGrams, 0), 1)
    }

    /// Same weighting the widget uses — keep these constants in sync.
    private var rhythmScore: Double {
        let combined =
            (calorieProgress * 0.24) +
            (waterProgress * 0.28) +
            (stepProgress * 0.32) +
            (proteinProgress * 0.16)
        return min(combined, 1.0)
    }

    private var rhythmPercent: Int { Int((rhythmScore * 100).rounded()) }

    // MARK: - Ring

    /// Goal-reached threshold. 80% is the score we treat as "today's
    /// rhythm is on", same line the lock-screen widget uses.
    private var hasReachedGoal: Bool { rhythmPercent >= 80 }

    private var rhythmRing: some View {
        ZStack {
            // Background ring — faint accent so the ring still reads on the
            // glass surface in light scheme.
            Circle()
                .stroke(NuvyraColors.accent.opacity(scheme == .dark ? 0.22 : 0.14), lineWidth: 12)

            // Gradient progress arc.
            Circle()
                .trim(from: 0, to: animatedScore)
                .stroke(NuvyraColors.accentGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: NuvyraColors.accent.opacity(0.36), radius: 10, x: 0, y: 4)

            // Center label stack.
            VStack(spacing: 0) {
                Text("\(rhythmPercent)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(NuvyraColors.accentGradient)
                Text("ritim")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 124, height: 124)
        // Slow ambient breath behind the ring so the hero feels alive
        // even before the user logs anything.
        .nuvyraBreath(amount: 1.018, duration: 3.6)
        // Soft accent halo + one-shot scale pop the moment the rhythm
        // crosses 80%. Pulses gently while the goal stays reached.
        .nuvyraGoalGlow(isActive: hasReachedGoal)
    }

    // MARK: - Companion metrics

    private var companionRail: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            companionRow(
                symbol: "flame.fill",
                tint: NuvyraColors.mutedCoral,
                label: "Kalori",
                value: "\(summary.consumedCalories)/\(summary.targetCalories)"
            )
            companionRow(
                symbol: "drop.fill",
                tint: NuvyraColors.softMint,
                label: "Su",
                value: "\(water.consumedMl)/\(water.targetMl) ml"
            )
            companionRow(
                symbol: "figure.walk",
                tint: NuvyraColors.accent,
                label: "Adım",
                value: "\(steps.steps.formatted())/\(steps.goal.formatted())"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func companionRow(symbol: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: NuvyraSpacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(scheme == .dark ? 0.22 : 0.14))
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Animation + a11y

    private func animate() {
        let target = rhythmScore
        guard !reduceMotion else { animatedScore = target; return }
        withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
            animatedScore = target
        }
    }

    private var accessibilityLabel: String {
        "Bugünkü ritim skorun yüzde \(rhythmPercent). Kalori \(summary.consumedCalories) / \(summary.targetCalories). Su \(water.consumedMl) / \(water.targetMl) mililitre. Adım \(steps.steps) / \(steps.goal)."
    }
}

#if DEBUG
#Preview("Rhythm hero") {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            DashboardRhythmHero(
                summary: DashboardPreviewData.nutrition,
                water: DashboardPreviewData.water,
                steps: DashboardPreviewData.steps,
                proteinGrams: 78,
                proteinTargetGrams: 120
            )
            DashboardRhythmHero(
                summary: DailyNutritionSummary(consumedCalories: 0, burnedCalories: 0, targetCalories: 1_900),
                water: .empty,
                steps: .empty,
                proteinGrams: 0,
                proteinTargetGrams: 120
            )
        }
        .padding()
    }
}
#endif
