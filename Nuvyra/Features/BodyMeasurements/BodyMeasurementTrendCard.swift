import Charts
import SwiftUI

/// Trend chart showing one specific metric (waist, hip, body fat %, etc.) over
/// the user's measurement history. Falls back to a soft empty state if the
/// metric has never been recorded.
struct BodyMeasurementTrendCard: View {
    enum Metric: String, CaseIterable, Identifiable {
        case weight, waist, hip, chest, shoulder, neck, bicep, thigh, bodyFat, waistHipRatio
        var id: String { rawValue }

        var title: String {
            switch self {
            case .weight: "Kilo"
            case .waist: "Bel"
            case .hip: "Kalça"
            case .chest: "Göğüs"
            case .shoulder: "Omuz"
            case .neck: "Boyun"
            case .bicep: "Pazı"
            case .thigh: "Uyluk"
            case .bodyFat: "Vücut yağ %"
            case .waistHipRatio: "Bel/Kalça oranı"
            }
        }

        var unit: String {
            switch self {
            case .weight: "kg"
            case .bodyFat: "%"
            case .waistHipRatio: ""
            default: "cm"
            }
        }

        var systemImage: String {
            switch self {
            case .weight: "scalemass"
            case .bodyFat: "drop.fill"
            case .waistHipRatio: "divide.circle"
            default: "ruler"
            }
        }
    }

    var metric: Metric
    var logs: [WeightLog]

    private var points: [DataPoint] {
        logs.compactMap { log in
            guard let value = value(for: log) else { return nil }
            return DataPoint(date: log.date, value: value)
        }
        .sorted { $0.date < $1.date }
    }

    private var delta: Double? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        return last.value - first.value
    }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                if points.isEmpty {
                    emptyState
                } else {
                    chart
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(metric.title, systemImage: metric.systemImage)
                .font(NuvyraTypography.section)
            Spacer()
            if let delta {
                let increased = delta > 0
                Text("\(increased ? "+" : "")\(delta.cleanFormatted) \(metric.unit)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (increased ? NuvyraColors.mutedCoral : NuvyraColors.accent).opacity(0.16),
                        in: Capsule()
                    )
                    .foregroundStyle(increased ? NuvyraColors.mutedCoral : NuvyraColors.accent)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Tarih", point.date),
                    y: .value(metric.title, point.value)
                )
                .foregroundStyle(NuvyraColors.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                PointMark(
                    x: .value("Tarih", point.date),
                    y: .value(metric.title, point.value)
                )
                .foregroundStyle(NuvyraColors.accent)
                .symbolSize(28)

                AreaMark(
                    x: .value("Tarih", point.date),
                    y: .value(metric.title, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [NuvyraColors.accent.opacity(0.28), NuvyraColors.accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 168)
        .nuvyraChartSummary(
            label: "\(metric.title) trendi",
            value: ChartAccessibilitySummary.summary(values: points.map(\.value), unit: metric.unit),
            hint: delta.map { "Son ölçümde \($0 > 0 ? "+" : "")\($0.cleanFormatted) \(metric.unit) değişim." }
        )
    }

    private var emptyState: some View {
        VStack(spacing: NuvyraSpacing.xs) {
            Image(systemName: metric.systemImage)
                .font(.title2)
                .foregroundStyle(NuvyraColors.accent.opacity(0.6))
            Text("Henüz \(metric.title.lowercased()) verisi yok")
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NuvyraSpacing.lg)
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let min = values.min(), let max = values.max() else { return 0...1 }
        let padding = max == min ? 1 : (max - min) * 0.2
        return (min - padding)...(max + padding)
    }

    private func value(for log: WeightLog) -> Double? {
        switch metric {
        case .weight: return log.weightKg > 0 ? log.weightKg : nil
        case .waist: return log.waistCm
        case .hip: return log.hipCm
        case .chest: return log.chestCm
        case .shoulder: return log.shoulderCm
        case .neck: return log.neckCm
        case .bicep: return log.bicepsCm
        case .thigh: return log.thighCm
        case .bodyFat: return log.bodyFatPercent
        case .waistHipRatio: return log.waistToHipRatio
        }
    }

    private struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
}
