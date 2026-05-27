import SwiftUI

struct AnalyticsHeader: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Ritim analizi")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .foregroundStyle(NuvyraColors.primaryText(scheme))

            Text(summary?.dateRangeText ?? "Kalori, makro, su ve yürüyüş trendlerini tek premium ekranda oku.")
                .font(.body.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
        }
        .accessibilityElement(children: .combine)
    }
}
