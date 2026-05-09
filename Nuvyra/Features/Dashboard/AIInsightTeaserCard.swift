import SwiftUI

struct AIInsightTeaserCard: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var insight: String
    var onAskCoach: () -> Void
    @State private var orbPulse = false

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                    AssistantOrb(pulse: orbPulse)
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Bugünün içgörüsü", systemImage: "sparkles")
                            .font(NuvyraTypography.section)
                        Text("Bilgilendirme amaçlıdır. Tıbbi tavsiye değildir.")
                            .font(.caption2)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
                Text(insight)
                    .font(NuvyraTypography.body)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onAskCoach) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("AI Coach'a sor")
                    }
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [NuvyraColors.accent, NuvyraColors.softMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: NuvyraColors.accent.opacity(0.32), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("AI Coach'a sor")
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                orbPulse = true
            }
        }
    }
}

private struct AssistantOrb: View {
    var pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [NuvyraColors.softMint.opacity(0.85), NuvyraColors.accent.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 32
                    )
                )
                .frame(width: 56, height: 56)
                .blur(radius: pulse ? 6 : 2)
                .scaleEffect(pulse ? 1.08 : 0.92)
            Image(systemName: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    AIInsightTeaserCard(insight: DashboardMockPreviewData.aiInsight, onAskCoach: {})
        .padding()
        .background(NuvyraBackground())
}
#endif
