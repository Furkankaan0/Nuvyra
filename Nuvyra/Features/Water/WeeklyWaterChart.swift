import Charts
import SwiftUI

struct WeeklyWaterChart: View {
    var totals: [WaterDayTotal]
    var goalMl: Int

    private var averageMl: Int {
        guard !totals.isEmpty else { return 0 }
        return totals.map(\.totalMl).reduce(0, +) / totals.count
    }

    private var daysHit: Int {
        totals.filter { $0.totalMl >= goalMl }.count
    }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haftalık su tüketimi")
                            .font(NuvyraTypography.section)
                        Text("\(daysHit)/7 günde hedefe ulaştın")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Ort. \(averageMl) ml")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }

                if totals.allSatisfy({ $0.totalMl == 0 }) {
                    emptyState
                } else {
                    chart
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Haftalık su grafiği")
    }

    private var chart: some View {
        Chart {
            ForEach(totals) { day in
                BarMark(
                    x: .value("Gün", DateFormatter.nuvyraWeekday.string(from: day.date)),
                    y: .value("Su", day.totalMl)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: day.totalMl >= goalMl
                            ? [Color(red: 0.20, green: 0.56, blue: 0.95), Color(red: 0.45, green: 0.86, blue: 0.96)]
                            : [Color(red: 0.30, green: 0.66, blue: 0.95).opacity(0.55), Color(red: 0.45, green: 0.86, blue: 0.96).opacity(0.45)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .cornerRadius(8)
                .accessibilityValue("\(day.totalMl) mililitre")
            }
            RuleMark(y: .value("Hedef", goalMl))
                .foregroundStyle(NuvyraColors.accent.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .accessibilityLabel("Günlük hedef \(goalMl) mililitre")
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks()
        }
        .chartLegend(.hidden)
        .frame(height: 168)
        .nuvyraChartSummary(
            label: "Haftalık su grafiği",
            value: ChartAccessibilitySummary.summary(intValues: totals.map(\.totalMl), unit: "mililitre"),
            hint: "\(daysHit) günde hedefe ulaştın. Detay için aşağı kaydır."
        )
    }

    private var emptyState: some View {
        VStack(spacing: NuvyraSpacing.xs) {
            Image(systemName: "drop")
                .font(.title2)
                .foregroundStyle(NuvyraColors.accent.opacity(0.6))
            Text("Henüz haftalık veri yok")
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NuvyraSpacing.lg)
    }
}

#if DEBUG
#Preview {
    let now = Calendar.nuvyra.startOfDay(for: Date())
    let totals: [WaterDayTotal] = (0..<7).reversed().map { offset in
        let date = Calendar.nuvyra.date(byAdding: .day, value: -offset, to: now) ?? now
        return WaterDayTotal(date: date, totalMl: Int.random(in: 800...2_400))
    }
    return ZStack {
        NuvyraBackground()
        WeeklyWaterChart(totals: totals, goalMl: 2_000).padding()
    }
}
#endif
