import Charts
import SwiftUI

struct WeeklyTrendChart: View {
    enum Metric {
        case calories
        case water
        case steps
    }

    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary
    let metric: Metric

    var body: some View {
        AnalyticsChartCard(
            title: metric.title(for: summary),
            subtitle: metric.subtitle,
            accessibilityLabel: metric.accessibilityLabel(for: summary)
        ) {
            Chart {
                switch metric {
                case .calories:
                    ForEach(summary.caloriePoints) { point in
                        BarMark(
                            x: .value("Gün", point.date, unit: .day),
                            y: .value("Kalori", point.value)
                        )
                        .foregroundStyle(NuvyraColors.mutedCoral.gradient)
                        .cornerRadius(6)
                    }

                    if metric.target(in: summary) > 0 {
                        RuleMark(y: .value("Kalori hedefi", metric.target(in: summary)))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            .foregroundStyle(NuvyraColors.accent)
                            .annotation(position: .topTrailing) {
                                Text("Hedef")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            }
                    }
                case .water:
                    ForEach(summary.waterPoints) { point in
                        LineMark(
                            x: .value("Gün", point.date, unit: .day),
                            y: .value("Su", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(NuvyraColors.softMint)

                        AreaMark(
                            x: .value("Gün", point.date, unit: .day),
                            y: .value("Su", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(NuvyraColors.softMint.opacity(0.18))
                    }

                    if metric.target(in: summary) > 0 {
                        RuleMark(y: .value("Su hedefi", metric.target(in: summary)))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                case .steps:
                    ForEach(summary.stepPoints) { point in
                        BarMark(
                            x: .value("Gün", point.date, unit: .day),
                            y: .value("Adım", point.value)
                        )
                        .foregroundStyle(NuvyraColors.accent.gradient)
                        .cornerRadius(6)
                    }

                    if metric.target(in: summary) > 0 {
                        RuleMark(y: .value("Adım hedefi", metric.target(in: summary)))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                            .foregroundStyle(NuvyraColors.paleLime)
                    }
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }
}

private extension WeeklyTrendChart.Metric {
    var subtitle: String {
        switch self {
        case .calories:
            "Günlük alınan kalori ve hedef çizgisi."
        case .water:
            "Günlük ml bazında su ritmi."
        case .steps:
            "Adım ve yürüyüş ritminin dönemsel görünümü."
        }
    }

    func title(for summary: AnalyticsSummary) -> String {
        switch self {
        case .calories:
            "\(summary.title) kalori"
        case .water:
            "Su tüketimi"
        case .steps:
            "Günlük adım"
        }
    }

    func accessibilityLabel(for summary: AnalyticsSummary) -> String {
        switch self {
        case .calories:
            "Kalori grafiği. Ortalama \(summary.averageCalories) kilokalori."
        case .water:
            "Su tüketimi grafiği. Ortalama \(summary.averageWaterMl) mililitre."
        case .steps:
            "Adım grafiği. Ortalama \(summary.averageSteps) adım."
        }
    }

    func target(in summary: AnalyticsSummary) -> Double {
        switch self {
        case .calories:
            summary.caloriePoints.first?.target ?? 0
        case .water:
            summary.waterPoints.first?.target ?? 0
        case .steps:
            summary.stepPoints.first?.target ?? 0
        }
    }
}
