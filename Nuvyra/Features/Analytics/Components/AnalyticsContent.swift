import SwiftUI

struct AnalyticsContent: View {
    let summary: AnalyticsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            AnalyticsKPIGrid(summary: summary)
            AnalyticsDailySummaryCard(summary: summary)
            WeeklyTrendChart(summary: summary, metric: .calories)
            MacroDistributionChart(summary: summary)
            WeeklyTrendChart(summary: summary, metric: .water)
            WeeklyTrendChart(summary: summary, metric: .steps)
            AIInsightCard(summary: summary)
        }
    }
}
