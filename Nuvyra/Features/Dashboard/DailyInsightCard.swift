import SwiftUI

/// AI wellness insight card with an animated assistant orb.
struct DailyInsightCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbPulse = false
    @State private var glowAngle: Double = 0

    var text: String
    var onAskCoach: (() -> Void)? = nil

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(spacing: NuvyraSpacing.md) {
                    orb
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wellness koçu")
                            .font(NuvyraTypography.section)
                        Text("Bugünkü içgörün")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(NuvyraColors.accent)
                }
                Text(text)
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let onAskCoach {
                    NuvyraSecondaryButton(title: "Koça sor", systemImage: "bubble.left.and.bubble.right", action: onAskCoach)
                }
                Text("Genel bilgilendirme amaçlıdır, tıbbi tavsiye yerine geçmez.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { startAnimations() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wellness koçu: \(text)")
    }

    private var orb: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [NuvyraColors.accent, NuvyraColors.softMint, NuvyraColors.paleLime, NuvyraColors.accent],
                        center: .center
                    )
                )
                .rotationEffect(.degrees(glowAngle))
                .frame(width: 48, height: 48)
                .blur(radius: 4)
                .opacity(0.85)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 38, height: 38)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.headline)
                        .foregroundStyle(NuvyraColors.accent)
                )
                .scaleEffect(orbPulse ? 1.06 : 0.96)
        }
        .accessibilityHidden(true)
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            orbPulse.toggle()
        }
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            glowAngle = 360
        }
    }
}

#if DEBUG
#Preview("Insight") {
    ZStack {
        NuvyraBackground()
        DailyInsightCard(text: DashboardPreviewData.aiInsight, onAskCoach: {}).padding()
    }
}
#endif
