import SwiftUI

/// First-day onboarding nudge — shown when the user has no meals/water/steps yet.
struct DashboardEmptyStateCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var onAddFirstMeal: () -> Void
    var onAddWater: () -> Void

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(spacing: NuvyraSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(NuvyraColors.accent.opacity(0.18))
                            .frame(width: 60, height: 60)
                            .scaleEffect(pulse ? 1.10 : 0.95)
                        Image(systemName: "sparkles")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Güne başla")
                            .font(NuvyraTypography.section)
                        Text("İlk kaydını ekle ki ritmin oluşmaya başlasın.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: NuvyraSpacing.sm) {
                    NuvyraPrimaryButton(title: "Öğün ekle", systemImage: "fork.knife", action: onAddFirstMeal)
                    NuvyraSecondaryButton(title: "+250 ml", systemImage: "drop", action: onAddWater)
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse.toggle() }
        }
    }
}

#if DEBUG
#Preview("Empty") {
    ZStack {
        NuvyraBackground()
        DashboardEmptyStateCard(onAddFirstMeal: {}, onAddWater: {}).padding()
    }
}
#endif
