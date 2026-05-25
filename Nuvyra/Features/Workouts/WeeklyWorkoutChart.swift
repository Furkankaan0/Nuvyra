import Charts
import SwiftUI

struct WeeklyWorkoutChart: View {
    var totals: [WorkoutDayCalories]

    private var averageKcal: Int {
        guard !totals.isEmpty else { return 0 }
        return totals.map(\.calories).reduce(0, +) / totals.count
    }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haftalık aktif kalori")
                            .font(NuvyraTypography.section)
                        Text("Son 7 gün")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Ort. \(averageKcal) kcal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }
                if totals.allSatisfy({ $0.calories == 0 }) {
                    emptyState
                } else {
                    chart
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(totals) { day in
                BarMark(
                    x: .value("Gün", DateFormatter.nuvyraWeekday.string(from: day.date)),
                    y: .value("Kalori", day.calories)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [NuvyraColors.mutedCoral, NuvyraColors.accent.opacity(0.7)],
                        startPoint: .bottom, endPoint: .top
                    )
                )
                .cornerRadius(8)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 168)
    }

    private var emptyState: some View {
        VStack(spacing: NuvyraSpacing.xs) {
            Image(systemName: "figure.run")
                .font(.title2)
                .foregroundStyle(NuvyraColors.accent.opacity(0.6))
            Text("Bu hafta egzersiz kaydı yok")
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NuvyraSpacing.lg)
    }
}
