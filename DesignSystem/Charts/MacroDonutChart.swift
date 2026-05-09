//
//  MacroDonutChart.swift
//  Nuvyra Design System / Charts
//
//  SectorMark tabanlı makro besin donut grafiği.
//  - innerRadius: .ratio(0.618) (altın oran boşluk)
//  - angularInset: 2 — dilimler arası soluma
//  - 0.8 sn easeOut açılış animasyonu
//  - Tap ile dilim seçimi (diğerleri opacity 0.4'e düşer)
//  - VoiceOver: her dilimin gram değerini okur
//

import SwiftUI
import Charts

/// Tek makro veri noktası.
public struct MacroSlice: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let label: String
    public let grams: Double
    public let color: Color

    public init(label: String, grams: Double, color: Color) {
        self.label = label
        self.grams = grams
        self.color = color
    }
}

/// Donut grafiği.
public struct MacroDonutChart: View {

    // MARK: - Inputs

    public let slices: [MacroSlice]
    public let centerTitle: String
    public let centerSubtitle: String

    // MARK: - State

    @State private var animationProgress: Double = 0
    @State private var selectedLabel: String? = nil

    // MARK: - Init

    /// - Parameters:
    ///   - slices: Protein/Karb/Yağ dilimleri.
    ///   - centerTitle: Orta üst yazı (örn. toplam gram).
    ///   - centerSubtitle: Orta alt yazı.
    public init(
        slices: [MacroSlice],
        centerTitle: String,
        centerSubtitle: String
    ) {
        self.slices = slices
        self.centerTitle = centerTitle
        self.centerSubtitle = centerSubtitle
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            chart
            centerLabel
        }
        .frame(minHeight: 240)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Makro besin dağılımı")
        .accessibilityValue(voiceOverDescription)
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Gram", slice.grams * animationProgress),
                innerRadius: .ratio(0.618),
                angularInset: 2
            )
            .foregroundStyle(slice.color.gradient)
            .cornerRadius(6)
            .opacity(opacity(for: slice))
        }
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(location: location, proxy: proxy, in: geo)
                    }
            }
        }
        .padding(8)
    }

    // MARK: - Center Label

    private var centerLabel: some View {
        VStack(spacing: 2) {
            Text(selectedLabel ?? centerTitle)
                .font(AppTypography.titleSmall)
                .foregroundStyle(AppColors.textPrimary)
                .contentTransition(.numericText())
            Text(centerSubtitleForSelection)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(8)
        .accessibilityHidden(true)
    }

    private var centerSubtitleForSelection: String {
        if let selectedLabel,
           let slice = slices.first(where: { $0.label == selectedLabel }) {
            return "\(Int(slice.grams.rounded())) g"
        }
        return centerSubtitle
    }

    // MARK: - Helpers

    private func opacity(for slice: MacroSlice) -> Double {
        guard let selectedLabel else { return 1.0 }
        return slice.label == selectedLabel ? 1.0 : 0.4
    }

    private var voiceOverDescription: String {
        let total = slices.map(\.grams).reduce(0, +)
        let parts = slices.map { slice -> String in
            let pct = total > 0 ? Int((slice.grams / total * 100).rounded()) : 0
            return "\(slice.label) \(Int(slice.grams.rounded())) gram, yüzde \(pct)"
        }
        return parts.joined(separator: ". ")
    }

    /// Tap noktasını dilime eşler — açıyı hesaplayıp kümülatif aralığa düşürür.
    private func handleTap(
        location: CGPoint,
        proxy: ChartProxy,
        in geo: GeometryProxy
    ) {
        // Center'a göre normalize konum
        let plotFrame: CGRect = {
            if let anchor = proxy.plotFrame {
                return geo[anchor]
            }
            return geo.frame(in: .local)
        }()
        let center = CGPoint(x: plotFrame.midX, y: plotFrame.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y

        // Açı (-π … π) → (0 … 2π) saat 12 yönüyle
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += .pi * 2 }

        let total = slices.map(\.grams).reduce(0, +)
        guard total > 0 else { return }

        var accumulated: Double = 0
        for slice in slices {
            let sliceAngle = (slice.grams / total) * .pi * 2
            if angle <= accumulated + sliceAngle {
                withAnimation(.easeOut(duration: 0.25)) {
                    selectedLabel = (selectedLabel == slice.label) ? nil : slice.label
                }
                UISelectionFeedbackGenerator().selectionChanged()
                return
            }
            accumulated += sliceAngle
        }
    }
}

// MARK: - Preview

#if DEBUG
private let demoSlices: [MacroSlice] = [
    .init(label: "Protein", grams: 78, color: AppColors.macroProtein),
    .init(label: "Karb",     grams: 145, color: AppColors.macroCarbs),
    .init(label: "Yağ",      grams: 42, color: AppColors.macroFat)
]

#Preview("Light") {
    ZStack {
        NuvyraPageBackground()
        PremiumCard {
            MacroDonutChart(
                slices: demoSlices,
                centerTitle: "265 g",
                centerSubtitle: "toplam makro"
            )
            .frame(height: 280)
        }
        .padding()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ZStack {
        NuvyraPageBackground()
        PremiumCard {
            MacroDonutChart(
                slices: demoSlices,
                centerTitle: "265 g",
                centerSubtitle: "toplam makro"
            )
            .frame(height: 280)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
