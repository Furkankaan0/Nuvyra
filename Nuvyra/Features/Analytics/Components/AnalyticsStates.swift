import SwiftUI

/// Loading state — shimmer-filled skeletons that match the eventual
/// chart layout. Avoids the layout jump that a generic spinner card
/// would cause when the real data arrives.
struct AnalyticsLoadingState: View {
    var body: some View {
        VStack(spacing: NuvyraSpacing.md) {
            NuvyraCardSkeleton(style: .hero)
            NuvyraCardSkeleton(style: .hero)
            NuvyraCardSkeleton(style: .strip)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analiz hazırlanıyor")
    }
}

/// Error state — coral-tinted illustrated placeholder + retry CTA. Uses
/// the same scaffold the dashboard / error views ship.
struct AnalyticsErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        NuvyraGlassCard {
            NuvyraIllustratedPlaceholder(
                systemImage: "exclamationmark.triangle.fill",
                title: "Analiz yüklenemedi",
                subtitle: message,
                tint: NuvyraColors.mutedCoral,
                bullets: []
            ) {
                NuvyraSecondaryButton(title: "Tekrar dene", systemImage: "arrow.clockwise", action: retry)
            }
        }
    }
}

/// Empty state — `.prominent` glass + illustrated placeholder with three
/// glass-pill examples that hint at what the user can log to fill the
/// charts up. Period-aware copy.
struct AnalyticsEmptyState: View {
    let period: AnalyticsPeriod

    var body: some View {
        NuvyraGlassCard(.prominent) {
            NuvyraIllustratedPlaceholder(
                systemImage: "chart.xyaxis.line",
                title: "\(period.title) analiz için kayıt bekleniyor",
                subtitle: "Bir öğün, birkaç su kaydı ve yürüyüş verisi eklediğinde grafikler otomatik olarak dolacak.",
                bullets: ["Bir öğün", "Su kaydı", "Adım verisi"]
            ) {
                EmptyView()
            }
        }
    }
}

#if DEBUG
#Preview("Analytics states") {
    ZStack {
        NuvyraBackground()
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                AnalyticsLoadingState()
                AnalyticsErrorState(message: "Sunucuya bağlanılamadı. Tekrar dene.") {}
                AnalyticsEmptyState(period: .weekly)
            }
            .padding()
        }
    }
}
#endif
