import SwiftUI

struct AnalyticsChartCard<ChartContent: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let accessibilityLabel: String
    let chartContent: ChartContent

    init(
        title: String,
        subtitle: String,
        accessibilityLabel: String,
        @ViewBuilder chartContent: () -> ChartContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessibilityLabel = accessibilityLabel
        self.chartContent = chartContent()
    }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }

                chartContent
                    .frame(height: 230)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)
            }
        }
    }
}
