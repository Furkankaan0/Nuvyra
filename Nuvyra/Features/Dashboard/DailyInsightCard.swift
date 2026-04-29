import SwiftUI

struct DailyInsightCard: View {
    var text: String

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Label("Günün içgörüsü", systemImage: "sparkles")
                    .font(NuvyraTypography.section)
                Text(text)
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
