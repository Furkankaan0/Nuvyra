import SwiftUI

struct AICoachInsightCard: View {
    @Environment(\.colorScheme) private var scheme
    var insight: AICoachInsight

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(insight.category.tint(scheme).opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: insight.category.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(insight.category.tint(scheme))
                }
                Text(insight.category.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    .textCase(.uppercase)
                Spacer()
            }

            Text(insight.headline)
                .font(NuvyraTypography.section)
                .foregroundStyle(NuvyraColors.primaryText(scheme))

            Text(insight.detail)
                .font(NuvyraTypography.body)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(insight.category.tint(scheme).opacity(0.16))
        )
        .shadow(color: NuvyraShadow.card(scheme), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        AICoachInsightCard(insight: AICoachInsight(category: .daily, headline: "Bugün için kısa not", detail: "Bugün adım ritmin iyi gidiyor. Akşam kısa bir yürüyüşle hedefi rahat tamamlarsın."))
        AICoachInsightCard(insight: AICoachInsight(category: .water, headline: "Su tüketimi", detail: "Hedefe 600 ml kaldı."))
    }
    .padding()
    .background(NuvyraBackground())
}
#endif
