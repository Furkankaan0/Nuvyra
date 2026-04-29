import Charts
import SwiftUI

struct RhythmTrendCard: View {
    var calories: Int
    var calorieTarget: Int
    var steps: Int
    var stepGoal: Int
    var waterMl: Int
    var waterTarget: Int

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ritim trendi")
                            .font(NuvyraTypography.section)
                        Text("Kalori, adım ve su hedefini tek bakışta oku.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }

                Chart(points) { point in
                    BarMark(
                        x: .value("Ritim", point.title),
                        y: .value("Tamamlanma", point.progressPercent)
                    )
                    .foregroundStyle(point.color)
                    .cornerRadius(8)
                    .accessibilityLabel(point.title)
                    .accessibilityValue("\(Int(point.progressPercent)) yüzde tamamlandı")
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100])
                }
                .frame(height: 148)
            }
        }
    }

    private var points: [RhythmTrendPoint] {
        [
            RhythmTrendPoint(title: "Kalori", progress: Double(calories) / Double(max(calorieTarget, 1)), color: NuvyraColors.mutedCoral),
            RhythmTrendPoint(title: "Adım", progress: Double(steps) / Double(max(stepGoal, 1)), color: NuvyraColors.accent),
            RhythmTrendPoint(title: "Su", progress: Double(waterMl) / Double(max(waterTarget, 1)), color: NuvyraColors.softMint)
        ]
    }
}

private struct RhythmTrendPoint: Identifiable {
    let id = UUID()
    let title: String
    let progress: Double
    let color: Color

    var progressPercent: Double {
        min(max(progress, 0), 1) * 100
    }
}
