//
//  CalorieTrendChart.swift
//  Nuvyra Design System / Charts
//
//  30 günlük kalori trend grafiği:
//  - LineMark (catmullRom interpolation)
//  - AreaMark (yeşil → şeffaf gradient)
//  - Hedef çizgisi (dashed)
//  - Sürükleyerek tarih seçimi (PointMark + annotation callout)
//  - chartXAxis: 7 gün arayla "gün.kısaAy"
//  - chartYAxis: sağ tarafta "kcal"
//

import SwiftUI
import Charts

/// Tek günlük kalori veri noktası.
public struct CalorieDataPoint: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let date: Date
    public let kcal: Double

    public init(date: Date, kcal: Double) {
        self.date = date
        self.kcal = kcal
    }
}

public struct CalorieTrendChart: View {

    // MARK: - Inputs

    public let data: [CalorieDataPoint]
    public let dailyTarget: Double

    // MARK: - State

    @State private var selectedDate: Date?
    @State private var animationProgress: CGFloat = 0

    // MARK: - Init

    /// - Parameters:
    ///   - data: 30 günlük kalori serisi (büyükse otomatik downsample edilir).
    ///   - dailyTarget: Günlük hedef kalori (dashed çizgi).
    public init(data: [CalorieDataPoint], dailyTarget: Double) {
        self.data = ChartDownsampler.downsample(data, targetCount: 200)
        self.dailyTarget = dailyTarget
    }

    // MARK: - Computed

    private var selectedPoint: CalorieDataPoint? {
        guard let selectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate))
                < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    // MARK: - Body

    public var body: some View {
        Chart {
            // Area
            ForEach(data) { p in
                AreaMark(
                    x: .value("Tarih", p.date),
                    yStart: .value("Min", 0),
                    yEnd: .value("Kcal", p.kcal * Double(animationProgress))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.brandPrimary.opacity(0.45),
                            AppColors.brandPrimary.opacity(0.05),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Line
            ForEach(data) { p in
                LineMark(
                    x: .value("Tarih", p.date),
                    y: .value("Kcal", p.kcal * Double(animationProgress))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppColors.brandPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            // Target line
            RuleMark(y: .value("Hedef", dailyTarget))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .foregroundStyle(AppColors.textTertiary.opacity(0.8))
                .annotation(position: .topTrailing, alignment: .trailing) {
                    Text("Hedef \(Int(dailyTarget))")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                }

            // Selected point
            if let sp = selectedPoint {
                PointMark(
                    x: .value("Tarih", sp.date),
                    y: .value("Kcal", sp.kcal)
                )
                .foregroundStyle(AppColors.brandPrimary)
                .symbolSize(120)
                .annotation(position: .top, alignment: .center) {
                    selectedCallout(point: sp)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine().foregroundStyle(AppColors.borderHairline)
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(d.formatted(.dateTime.day().month(.abbreviated)))
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine().foregroundStyle(AppColors.borderHairline)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v)) kcal")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelection(at: value.location, proxy: proxy, in: geo)
                            }
                            .onEnded { _ in
                                // Sürükleme bittiğinde seçimi koruyoruz; iki kez tap'la kapanır.
                            }
                    )
                    .onTapGesture(count: 2) {
                        selectedDate = nil
                    }
            }
        }
        .frame(minHeight: 220)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animationProgress = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Son 30 gün kalori trendi")
        .accessibilityValue(voiceOverSummary)
    }

    // MARK: - Selection

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, in geo: GeometryProxy) {
        let plot: CGRect = {
            if let anchor = proxy.plotFrame { return geo[anchor] }
            return geo.frame(in: .local)
        }()
        let xInPlot = location.x - plot.minX
        guard xInPlot >= 0, xInPlot <= plot.width else { return }
        if let date: Date = proxy.value(atX: xInPlot) {
            selectedDate = date
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func selectedCallout(point: CalorieDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(AppTypography.micro)
                .foregroundStyle(AppColors.textSecondary)
            Text("\(Int(point.kcal.rounded())) kcal")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: AppRadius.shape(AppRadius.sm))
        .overlay(
            AppRadius.shape(AppRadius.sm)
                .stroke(AppColors.borderHairline, lineWidth: 1)
        )
        .shadow(AppShadow.card1)
    }

    // MARK: - VoiceOver

    private var voiceOverSummary: String {
        guard let first = data.first, let last = data.last else { return "Veri yok." }
        let avg = data.map(\.kcal).reduce(0, +) / Double(max(1, data.count))
        return """
        \(first.date.formatted(.dateTime.day().month())) ile \
        \(last.date.formatted(.dateTime.day().month())) arasında ortalama \
        \(Int(avg.rounded())) kcal. Hedef \(Int(dailyTarget)) kcal.
        """
    }
}

// MARK: - Preview Data

#if DEBUG
private func sampleCalorieData() -> [CalorieDataPoint] {
    let cal = Calendar.current
    return (0..<30).reversed().map { offset in
        let date = cal.date(byAdding: .day, value: -offset, to: .now)!
        let base = 2200.0
        let noise = Double.random(in: -350...250)
        return CalorieDataPoint(date: date, kcal: max(1200, base + noise))
    }
}

#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Son 30 Gün")
                    .font(AppTypography.titleSmall)
                CalorieTrendChart(data: sampleCalorieData(), dailyTarget: 2300)
                    .frame(height: 240)
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
                Text("Son 30 Gün")
                    .font(AppTypography.titleSmall)
                CalorieTrendChart(data: sampleCalorieData(), dailyTarget: 2300)
                    .frame(height: 240)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
