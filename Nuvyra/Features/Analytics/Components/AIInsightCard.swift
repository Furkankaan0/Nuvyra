import SwiftUI

struct AIInsightCard: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    Label("AI içgörü", systemImage: "sparkles")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Spacer()
                    Text("Kural bazlı")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }

                Text(summary.aiInsight)
                    .font(.body.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                Text("Bu yorum tıbbi tavsiye değildir; uygulama içindeki kayıtlarına göre wellness ritmi yorumu üretir.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme).opacity(0.82))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
