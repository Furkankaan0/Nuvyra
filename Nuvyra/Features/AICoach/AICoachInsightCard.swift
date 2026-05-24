import SwiftUI

struct AICoachInsightCard: View {
    var insight: AICoachInsight

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                HStack(spacing: NuvyraSpacing.sm) {
                    Image(systemName: insight.topic.systemImage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .frame(width: 34, height: 34)
                        .background(NuvyraColors.accent.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text(insight.topic.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(insight.title)
                            .font(.subheadline.weight(.bold))
                    }
                    Spacer(minLength: 0)
                }
                Text(insight.body)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        AICoachInsightCard(insight: AICoachInsight(
            topic: .calories,
            title: "Kalori & makro",
            body: "Kalori hedefine 420 kcal kaldı. Protein hedefin için 22 g daha alabilirsin."
        ))
        .padding()
    }
}
#endif
