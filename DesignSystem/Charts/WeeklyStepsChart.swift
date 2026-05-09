//
//  WeeklyStepsChart.swift
//  Nuvyra Design System / Charts
//
//  Haftalık adım bar grafiği:
//  - BarMark, cornerRadius: 6
//  - Hedefe ulaşılan günler yeşil (success), ulaşılmayanlar turuncu (warning)
//  - Hedefe ulaşılan günlere checkmark annotation
//  - chartYScale: 0...15000
//  - chartScrollableAxes(.horizontal) ile haftalar arası kaydırma
//

import SwiftUI
import Charts

/// Tek günlük adım veri noktası.
public struct DailyStepsPoint: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let date: Date
    public let steps: Int

    public init(date: Date, steps: Int) {
        self.date = date
        self.steps = steps
    }
}

public struct WeeklyStepsChart: View {

    // MARK: - Inputs

    public let data: [DailyStepsPoint]
    public let dailyGoal: Int

    // MARK: - State

    @State private var animationProgress: CGFloat = 0

    // MARK: - Init

    /// - Parameters:
    ///   - data: Günlük adım serisi (en fazla 200 puana otomatik downsample edilir).
    ///   - dailyGoal: Günlük hedef (default 10000).
    public init(data: [DailyStepsPoint], dailyGoal: Int = 10_000) {
        self.data = ChartDownsampler.downsample(data, targetCount: 200)
        self.dailyGoal = dailyGoal
    }

    // MARK: - Body

    public var body: some View {
        Chart {
            ForEach(data) { p in
                let reached = p.steps >= dailyGoal
                BarMark(
                    x: .value("Gün", p.date, unit: .day),
                    y: .value("Adım", Double(p.steps) * Double(animationProgress))
                )
                .cornerRadius(6)
                .foregroundStyle(reached
                                 ? AppColors.success.gradient
                                 : AppColors.warning.gradient)
                .annotation(position: .top, alignment: .center, spacing: 4) {
                    if reached {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.success)
                            .opacity(Double(animationProgress))
                    }
                }
            }

            // Hedef RuleMark
            RuleMark(y: .value("Hedef", dailyGoal))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(AppColors.textTertiary.opacity(0.7))
        }
        .chartYScale(domain: 0...15_000)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 7 * 86_400)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(d.formatted(.dateTime.weekday(.narrow)))
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(AppColors.borderHairline)
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text(formatThousands(v))
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .frame(minHeight: 200)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                animationProgress = 1
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Haftalık adım sayısı grafiği")
        .accessibilityValue(voiceOverSummary)
    }

    // MARK: - Helpers

    private func formatThousands(_ value: Int) -> String {
        if value >= 1000 {
            return "\(value / 1000)K"
        }
        return "\(value)"
    }

    private var voiceOverSummary: String {
        let parts = data.map { p -> String in
            let weekday = p.date.formatted(.dateTime.weekday(.wide))
            let reached = p.steps >= dailyGoal
            return "\(weekday) \(p.steps) adım, " + (reached ? "hedefe ulaşıldı" : "hedefe ulaşılmadı")
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Preview Data

#if DEBUG
private func sampleStepsData() -> [DailyStepsPoint] {
    let cal = Calendar.current
    let counts = [8200, 11200, 5800, 9700, 12300, 4500, 10800,
                  9100, 11600, 7400, 13200, 8900, 6200, 12700]
    return counts.enumerated().reversed().map { idx, steps in
        let date = cal.date(byAdding: .day, value: -idx, to: .now)!
        return DailyStepsPoint(date: date, steps: steps)
    }
}

#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Adımlar")
                    .font(AppTypography.titleSmall)
                WeeklyStepsChart(data: sampleStepsData())
                    .frame(height: 220)
            }
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Adımlar")
                    .font(AppTypography.titleSmall)
                WeeklyStepsChart(data: sampleStepsData())
                    .frame(height: 220)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
