import SwiftUI

struct AnalyticsDailySummaryCard: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary

    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.lg) {
                NuvyraProgressRing(
                    progress: summary.targetCompletionRate,
                    lineWidth: 12,
                    center: summary.completionPercentText,
                    caption: "tamamlama"
                )
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Label("Hedef tamamlama", systemImage: "checkmark.seal.fill")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))

                    Text("En başarılı gün: \(summary.bestDayText)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)

                    Text("Kalori, protein, su ve adım hedeflerinin dengeli ortalaması.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hedef tamamlama oranı \(summary.completionPercentText). En başarılı gün \(summary.bestDayText).")
    }
}
