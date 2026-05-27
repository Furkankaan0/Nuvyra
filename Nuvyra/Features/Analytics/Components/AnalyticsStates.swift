import SwiftUI

struct AnalyticsLoadingState: View {
    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.md) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analiz hazırlanıyor")
                        .font(NuvyraTypography.section)
                    Text("Haftalık ve aylık ritim verilerin toplanıyor.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct AnalyticsErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label("Analiz yüklenemedi", systemImage: "exclamationmark.triangle.fill")
                    .font(NuvyraTypography.section)
                    .foregroundStyle(NuvyraColors.mutedCoral)
                Text(message)
                    .foregroundStyle(.secondary)
                NuvyraSecondaryButton(title: "Tekrar dene", systemImage: "arrow.clockwise", action: retry)
            }
        }
    }
}

struct AnalyticsEmptyState: View {
    @Environment(\.colorScheme) private var scheme
    let period: AnalyticsPeriod

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)

                Text("\(period.title) analiz için kayıt bekleniyor")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text("Bir öğün, birkaç su kaydı ve yürüyüş verisi eklediğinde grafikler otomatik olarak dolacak.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
    }
}
