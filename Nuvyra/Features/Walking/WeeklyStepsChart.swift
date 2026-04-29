import SwiftUI

struct WeeklyStepsChart: View {
    var logs: [WalkingLog]
    var goal: Int

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Haftalık adım grafiği")
                    .font(NuvyraTypography.section)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(chartDays) { day in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(day.steps >= goal ? NuvyraColors.accent : NuvyraColors.softSand.opacity(0.65))
                                .frame(height: max(CGFloat(day.steps) / CGFloat(max(goal, 1)) * 120, 12))
                            Text(DateFormatter.nuvyraWeekday.string(from: day.date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 148)
            }
        }
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
}
