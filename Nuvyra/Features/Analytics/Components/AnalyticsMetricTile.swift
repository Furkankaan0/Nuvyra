import SwiftUI

struct AnalyticsKPIGrid: View {
    let summary: AnalyticsSummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
            AnalyticsMetricTile(title: "Ortalama kalori", value: "\(summary.averageCalories)", unit: "kcal", icon: "flame.fill")
            AnalyticsMetricTile(title: "Ortalama protein", value: "\(summary.averageProtein)", unit: "g", icon: "bolt.heart.fill")
            AnalyticsMetricTile(title: "Ortalama adım", value: summary.averageSteps.formatted(), unit: "", icon: "figure.walk")
            AnalyticsMetricTile(title: "Yürüyüş mesafesi", value: summary.totalDistanceKm.cleanFormatted, unit: "km", icon: "map.fill")
        }
    }
}

private struct AnalyticsMetricTile: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let value: String
    let unit: String
    let icon: String

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value) \(unit)")
    }
}
