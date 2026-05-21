import SwiftUI

struct CalorieHeroCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var summary: DailyNutritionSummary
    @State private var animatedProgress: Double = 0
    @State private var glow: CGFloat = 0

    private var ringColors: [Color] {
        if summary.isOverTarget {
            return [NuvyraColors.mutedCoral, NuvyraColors.softSand, NuvyraColors.mutedCoral]
        }
        return [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.accent]
    }

    private var glowColor: Color {
        summary.isOverTarget ? NuvyraColors.mutedCoral : NuvyraColors.accent
    }

    var body: some View {
        VStack(spacing: NuvyraSpacing.lg) {
            ringBlock
            metaPills
        }
        .padding(.vertical, NuvyraSpacing.lg)
        .padding(.horizontal, NuvyraSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.xl, style: .continuous)
                .stroke(Color.white.opacity(scheme == .dark ? 0.06 : 0.4))
        )
        .shadow(color: NuvyraShadow.card(scheme), radius: 22, x: 0, y: 14)
        .onAppear {
            animateRing()
            startGlow()
        }
        .onChange(of: summary.ringProgress) { _, _ in animateRing() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kalori dengesi. Alınan \(summary.consumed), yakılan \(summary.burned), kalan \(summary.remaining) kalori.")
    }

    // MARK: - Ring

    private var ringBlock: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.18 + 0.10 * glow), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 130
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 18)

            Circle()
                .stroke(NuvyraColors.accent.opacity(0.10), lineWidth: 16)
                .frame(width: 184, height: 184)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(colors: ringColors, center: .center),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 184, height: 184)
                .shadow(color: glowColor.opacity(0.32), radius: 12, x: 0, y: 0)

            VStack(spacing: 2) {
                Text("\(summary.remaining)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(summary.remaining)))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(summary.isOverTarget ? "kcal aştın" : "kcal kaldı")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            .padding(.horizontal, 24)
        }
        .frame(height: 220)
    }

    // MARK: - Meta pills

    private var metaPills: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            metaPill(label: "Alınan", value: "\(summary.consumed)", unit: "kcal", color: NuvyraColors.mutedCoral)
            metaDivider
            metaPill(label: "Yakılan", value: "\(summary.burned)", unit: "kcal", color: NuvyraColors.accent)
            metaDivider
            metaPill(label: "Hedef", value: "\(summary.target)", unit: "kcal", color: NuvyraColors.softSand)
        }
        .frame(maxWidth: .infinity)
    }

    private func metaPill(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
            Capsule()
                .fill(color)
                .frame(width: 18, height: 2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var metaDivider: some View {
        Capsule()
            .fill(NuvyraColors.secondaryText(scheme).opacity(0.12))
            .frame(width: 1, height: 28)
    }

    // MARK: - Animations

    private func animateRing() {
        let target = summary.ringProgress
        if reduceMotion {
            animatedProgress = target
        } else {
            withAnimation(.easeOut(duration: 0.9)) {
                animatedProgress = target
            }
        }
    }

    private func startGlow() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            glow = 1
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        CalorieHeroCard(summary: DashboardMockPreviewData.nutrition)
        CalorieHeroCard(summary: DailyNutritionSummary(consumed: 2_400, burned: 280, target: 1_900))
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
