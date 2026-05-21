import Charts
import SwiftUI

struct WeeklyWaterChart: View {
    @Environment(\.colorScheme) private var scheme
    var totals: [DailyWaterTotal]
    var targetMl: Int

    private var tint: Color { Color(red: 0.30, green: 0.70, blue: 0.95) }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                NuvyraSectionHeader(title: "Haftalık tüketim", subtitle: "Son 7 gün ve hedef çizgisi.")
                Spacer()
            }

            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    Chart(totals) { total in
                        BarMark(
                            x: .value("Gün", DateFormatter.nuvyraWeekday.string(from: total.date)),
                            y: .value("Su", total.totalMl)
                        )
                        .foregroundStyle(barStyle(for: total))
                        .cornerRadius(8)
                        .annotation(position: .top, alignment: .center, spacing: 2) {
                            if total.totalMl > 0 {
                                Text("\(total.totalMl)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            }
                        }

                        if targetMl > 0 {
                            RuleMark(y: .value("Hedef", targetMl))
                                .foregroundStyle(tint.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
                                .annotation(position: .top, alignment: .leading) {
                                    Text("Hedef \(targetMl) ml")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(tint)
                                }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisValueLabel()
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .frame(height: 168)

                    HStack(spacing: NuvyraSpacing.sm) {
                        WeeklyStatPill(title: "Ortalama", value: averageText)
                        WeeklyStatPill(title: "En iyi gün", value: bestDayText)
                        WeeklyStatPill(title: "Hedefe ulaşılan", value: "\(daysAchieved)/7")
                    }
                }
            }
        }
    }

    private func barStyle(for total: DailyWaterTotal) -> LinearGradient {
        let reached = total.totalMl >= targetMl && targetMl > 0
        return LinearGradient(
            colors: reached ? [tint, NuvyraColors.softMint] : [tint.opacity(0.7), tint.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var averageText: String {
        guard !totals.isEmpty else { return "0 ml" }
        let avg = totals.map(\.totalMl).reduce(0, +) / max(totals.count, 1)
        return "\(avg) ml"
    }

    private var bestDayText: String {
        let best = totals.map(\.totalMl).max() ?? 0
        return "\(best) ml"
    }

    private var daysAchieved: Int {
        guard targetMl > 0 else { return 0 }
        return totals.filter { $0.totalMl >= targetMl }.count
    }
}

private struct WeeklyStatPill: View {
    @Environment(\.colorScheme) private var scheme
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(NuvyraColors.primaryText(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(NuvyraColors.card(scheme).opacity(0.65), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }
}

#if DEBUG
private enum WeeklyWaterChartPreviewData {
    static let mocks: [DailyWaterTotal] = {
        let amounts = [1_400, 1_800, 2_200, 1_100, 2_000, 1_600, 1_900]
        return (0..<7).compactMap { offset in
            guard let date = Calendar.nuvyra.date(byAdding: .day, value: offset - 6, to: Date()) else { return nil }
            return DailyWaterTotal(id: date, date: date, totalMl: amounts[offset])
        }
    }()
}

#Preview {
    WeeklyWaterChart(totals: WeeklyWaterChartPreviewData.mocks, targetMl: 2_000)
        .padding()
        .background(NuvyraBackground())
}
#endif
