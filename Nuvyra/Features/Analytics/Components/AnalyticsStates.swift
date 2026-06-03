import SwiftUI

/// Loading state — small glass surface with a spinner, so the page doesn't
/// flash empty between view appear and the first repository fetch landing.
struct AnalyticsLoadingState: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.md) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(NuvyraColors.accent.opacity(scheme == .dark ? 0.20 : 0.14))
                    Circle().stroke(NuvyraColors.glassStroke(scheme), lineWidth: 0.6)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .nuvyraLoadingPulse(true)
                }
                .frame(width: 44, height: 44)
                .nuvyraShadow(.ambient, scheme: scheme)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Analiz hazırlanıyor")
                        .font(NuvyraTypography.section)
                    Text("Haftalık ve aylık ritim verilerin toplanıyor.")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
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
