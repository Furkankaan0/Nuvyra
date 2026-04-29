import Charts
import SwiftUI

struct WeeklyStepsChart: View {
    var logs: [WalkingLog]
    var goal: Int

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Haftalık adım grafiği")
                            .font(NuvyraTypography.section)
                        Text("Hedef çizgisiyle yürüyüş ritmini karşılaştır.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(averageSteps.formatted()) ort.")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }

                Chart {
                    ForEach(chartDays) { day in
                        BarMark(
                            x: .value("Gün", day.weekday),
                            y: .value("Adım", day.steps)
                        )
                        .foregroundStyle(day.steps >= goal ? NuvyraColors.accent : NuvyraColors.softSand.opacity(0.72))
                        .cornerRadius(8)
                        .accessibilityLabel(day.weekday)
                        .accessibilityValue("\(day.steps.formatted()) adım")
                    }

                    RuleMark(y: .value("Hedef", goal))
                        .foregroundStyle(NuvyraColors.accent.opacity(0.42))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .accessibilityLabel("Günlük hedef \(goal.formatted()) adım")
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(.clear)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks()
                }
                .chartLegend(.hidden)
                .overlay(alignment: .topLeading) {
                    Text("Hedef: \(goal.formatted())")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                }
                .frame(height: 176)
                .accessibilityLabel("Haftalık adım grafiği")
            }
        }
    }

    private var averageSteps: Int {
        let days = chartDays
        guard !days.isEmpty else { return 0 }
        return days.map(\.steps).reduce(0, +) / days.count
    }

    private var chartDays: [StepChartDay] {
        if logs.isEmpty {
            return Array((0..<7).map { offset in
                StepChartDay(date: Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date(), steps: 0)
            }.reversed())
        }
        return logs.map { StepChartDay(date: $0.date, steps: $0.steps) }
    }
}

private struct StepChartDay: Identifiable {
    let id = UUID()
    let date: Date
    let steps: Int

    var weekday: String {
        DateFormatter.nuvyraWeekday.string(from: date)
    }
}
