import SwiftUI

struct CalorieHeroCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var summary: DailyNutritionSummary
    @State private var animatedProgress: Double = 0

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                HStack(alignment: .center, spacing: NuvyraSpacing.lg) {
                    ZStack {
                        Circle()
                            .stroke(NuvyraColors.accent.opacity(0.12), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.accent],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 14, x: 0, y: 0)
                        VStack(spacing: 2) {
                            Text("\(summary.remaining)")
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText(value: Double(summary.remaining)))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text("kcal kaldı")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }
                    .frame(width: 156, height: 156)

                    VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                        Text("Kalori dengesi")
                            .font(NuvyraTypography.section)
                        MetricRow(title: "Alınan", value: "\(summary.consumed) kcal", tint: NuvyraColors.mutedCoral)
                        MetricRow(title: "Yakılan", value: "\(summary.burned) kcal", tint: NuvyraColors.accent)
                        MetricRow(title: "Hedef", value: "\(summary.target) kcal", tint: NuvyraColors.softSand)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if summary.isOverTarget {
                    Label("Bugün hedefini aştın. Akşamı hafif kapatabilirsin.", systemImage: "exclamationmark.circle")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }
            }
        }
        .onAppear { animateRing() }
        .onChange(of: summary.ringProgress) { _, _ in animateRing() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kalori dengesi. Alınan \(summary.consumed), yakılan \(summary.burned), kalan \(summary.remaining) kalori.")
    }

    private func animateRing() {
        let target = summary.ringProgress
        if reduceMotion {
            animatedProgress = target
        } else {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = target
            }
        }
    }
}

private struct MetricRow: View {
    var title: String
    var value: String
    var tint: Color

    var body: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(NuvyraTypography.body)
    }
}

#if DEBUG
#Preview {
    CalorieHeroCard(summary: DashboardMockPreviewData.nutrition)
        .padding()
        .background(NuvyraBackground())
}
#endif
