import Charts
import SwiftUI

/// Premium 7-day step bar chart. Built on top of a `.prominent`
/// `NuvyraGlassCard` so it shares the hero hierarchy with the Dashboard
/// weekly comparison and weight trend cards. Bars use the accent gradient
/// when the goal is hit and the warm sand tint otherwise so the eye reads
/// "completion" at a single glance.
struct WeeklyStepsChart: View {
    @Environment(\.colorScheme) private var scheme

    var logs: [WalkingLog]
    var goal: Int

    var body: some View {
        NuvyraGlassCard(.prominent) {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                chart
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Haftalık adım grafiği")
                    .font(NuvyraTypography.section)
                Text("Hedef çizgisiyle yürüyüş ritmini karşılaştır.")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NuvyraGlassPill(tint: NuvyraColors.accent) {
                Text("\(averageSteps.formatted()) ort.")
                    .font(.caption.weight(.bold))
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(chartDays) { day in
                BarMark(
                    x: .value("Gün", day.weekday),
                    y: .value("Adım", day.steps)
                )
                .foregroundStyle(barStyle(for: day))
                .cornerRadius(10)
                .accessibilityLabel(day.weekday)
                .accessibilityValue("\(day.steps.formatted()) adım")
            }

            // Soft, dashed target rule that picks up the accent. The
            // top-leading annotation reuses NuvyraGlassPill so the chip
            // matches the rest of the Liquid Glass family.
            RuleMark(y: .value("Hedef", goal))
                .foregroundStyle(NuvyraColors.accent.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [6, 5]))
                .annotation(position: .top, alignment: .leading) {
                    NuvyraGlassPill(systemImage: "target", title: "Hedef \(goal.formatted())")
                        .padding(.bottom, 2)
                }
                .accessibilityLabel("Günlük hedef \(goal.formatted()) adım")
        }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(NuvyraColors.mutedGray.opacity(0.25))
                AxisValueLabel().font(.caption2)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.caption2)
            }
        }
        .chartLegend(.hidden)
        .frame(height: 200)
        .nuvyraChartSummary(
            label: "Haftalık adım grafiği",
            value: ChartAccessibilitySummary.summary(intValues: chartDays.map(\.steps), unit: "adım"),
            hint: "Günlük hedef \(goal.formatted()) adım."
        )
    }

    /// Goal hit → vertical accent gradient (pops). Below goal → warm sand
    /// gradient that fades toward transparency at the top so it never
    /// fights the hero accent visually.
    private func barStyle(for day: StepChartDay) -> AnyShapeStyle {
        if day.steps >= goal {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [NuvyraColors.accent, NuvyraColors.softMint],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    NuvyraColors.softSand.opacity(0.95),
                    NuvyraColors.softSand.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Derived data

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

#if DEBUG
#Preview {
    let now = Date()
    let calendar = Calendar.current
    let sampleLogs: [WalkingLog] = (0..<7).reversed().map { offset in
        WalkingLog(
            date: calendar.date(byAdding: .day, value: -offset, to: now) ?? now,
            steps: [5_400, 7_900, 4_200, 8_700, 6_300, 9_100, 7_200][offset]
        )
    }
    return ZStack {
        NuvyraBackground()
        WeeklyStepsChart(logs: sampleLogs, goal: 7_500)
            .padding()
    }
}
#endif
