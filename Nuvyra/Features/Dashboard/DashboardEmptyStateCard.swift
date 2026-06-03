import SwiftUI

/// First-day onboarding nudge — shown when the user has no meals/water/steps
/// yet. Built on top of `NuvyraIllustratedPlaceholder` so empty/error
/// states across the app stay visually consistent.
struct DashboardEmptyStateCard: View {
    var onAddFirstMeal: () -> Void
    var onAddWater: () -> Void

    var body: some View {
        NuvyraGlassCard(.prominent) {
            NuvyraIllustratedPlaceholder(
                systemImage: "sparkles",
                title: "Güne başla",
                subtitle: "İlk kaydını ekle ki ritmin sakin bir şekilde oluşmaya başlasın.",
                bullets: ["Bir öğün", "1 bardak su", "10 dk yürüyüş"]
            ) {
                HStack(spacing: NuvyraSpacing.sm) {
                    NuvyraPrimaryButton(title: "Öğün ekle", systemImage: "fork.knife", action: onAddFirstMeal)
                    NuvyraSecondaryButton(title: "+250 ml", systemImage: "drop", action: onAddWater)
                }
            }
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
