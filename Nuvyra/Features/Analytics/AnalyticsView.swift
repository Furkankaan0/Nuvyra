import Charts
import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = AnalyticsViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    AnalyticsHeader(summary: viewModel.currentSummary)
                    AnalyticsSegmentedControl(selection: $viewModel.selectedPeriod)

                    if viewModel.isLoading {
                        AnalyticsLoadingState()
                    } else if let errorMessage = viewModel.errorMessage {
                        AnalyticsErrorState(message: errorMessage) {
                            Task { await viewModel.reloadSelectedPeriod(context: modelContext, dependencies: dependencies) }
                        }
                    } else if let summary = viewModel.currentSummary {
                        if summary.isEmpty {
                            AnalyticsEmptyState(period: viewModel.selectedPeriod)
                        } else {
                            AnalyticsContent(summary: summary)
                        }
                    } else {
                        AnalyticsLoadingState()
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable {
                await viewModel.reloadSelectedPeriod(context: modelContext, dependencies: dependencies)
            }
        }
        .navigationTitle("Analiz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        .onReceive(NotificationCenter.default.publisher(for: .nuvyraAppDidBecomeActive)) { _ in
            Task { await viewModel.reloadSelectedPeriod(context: modelContext, dependencies: dependencies) }
        }
    }
}

private struct AnalyticsContent: View {
    let summary: AnalyticsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            AnalyticsKPIGrid(summary: summary)
            CompletionAndBestDayCard(summary: summary)
            CalorieChartCard(summary: summary)
            MacroDistributionOverviewCard(summary: summary)
            WaterChartCard(summary: summary)
            StepsChartCard(summary: summary)
            AIInsightCard(summary: summary)
        }
    }
}

private struct AnalyticsHeader: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Ritim analizi")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .foregroundStyle(NuvyraColors.primaryText(scheme))

            Text(summary?.dateRangeText ?? "Kalori, makro, su ve yürüyüş trendlerini tek premium ekranda oku.")
                .font(.body.weight(.medium))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AnalyticsSegmentedControl: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: AnalyticsPeriod

    var body: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        selection = period
                    }
                } label: {
                    Text(period.title)
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selection == period ? .white : NuvyraColors.primaryText(scheme))
                        .background {
                            if selection == period {
                                Capsule()
                                    .fill(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .topLeading, endPoint: .bottomTrailing))
                            } else {
                                Capsule().fill(Color.clear)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(period.title)
                .accessibilityValue(selection == period ? "Seçili" : "Seçili değil")
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.34)))
    }
}

private struct AnalyticsKPIGrid: View {
    let summary: AnalyticsSummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
            AnalyticsMetricTile(title: "Ortalama kalori", value: "\(summary.averageCalories)", unit: "kcal", icon: "flame.fill")
            AnalyticsMetricTile(title: "Ortalama protein", value: "\(summary.averageProtein)", unit: "g", icon: "bolt.heart.fill")
            AnalyticsMetricTile(title: "Ortalama adım", value: summary.averageSteps.formatted(), unit: "", icon: "figure.walk")
            AnalyticsMetricTile(title: "Yürüyüş mesafesi", value: summary.totalDistanceKm.cleanFormatted, unit: "km", icon: "map.fill")
        }
    }
}

private struct AnalyticsMetricTile: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let value: String
    let unit: String
    let icon: String

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value) \(unit)")
    }
}

private struct CompletionAndBestDayCard: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary

    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.lg) {
                NuvyraProgressRing(
                    progress: summary.targetCompletionRate,
                    lineWidth: 12,
                    center: summary.completionPercentText,
                    caption: "tamamlama"
                )
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Label("Hedef tamamlama", systemImage: "checkmark.seal.fill")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))

                    Text("En başarılı gün: \(summary.bestDayText)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)

                    Text("Kalori, protein, su ve adım hedeflerinin dengeli ortalaması.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hedef tamamlama oranı \(summary.completionPercentText). En başarılı gün \(summary.bestDayText).")
    }
}

private struct CalorieChartCard: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary

    private var target: Double {
        summary.caloriePoints.first?.target ?? 0
    }

    var body: some View {
        AnalyticsChartCard(
            title: "\(summary.title) kalori",
            subtitle: "Günlük alınan kalori ve hedef çizgisi.",
            accessibilityLabel: "Kalori grafiği. Ortalama \(summary.averageCalories) kilokalori."
        ) {
            Chart {
                ForEach(summary.caloriePoints) { point in
                    BarMark(
                        x: .value("Gün", point.date, unit: .day),
                        y: .value("Kalori", point.value)
                    )
                    .foregroundStyle(NuvyraColors.mutedCoral.gradient)
                    .cornerRadius(6)
                }

                if target > 0 {
                    RuleMark(y: .value("Kalori hedefi", target))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                        .foregroundStyle(NuvyraColors.accent)
                        .annotation(position: .topTrailing) {
                            Text("Hedef")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }
}

private struct MacroDistributionChartCard: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary

    var body: some View {
        AnalyticsChartCard(
            title: "Makro dağılımı",
            subtitle: "Protein, karbonhidrat ve yağın kalori bazlı oranı.",
            accessibilityLabel: macroAccessibilityText
        ) {
            VStack(spacing: NuvyraSpacing.md) {
                Chart(summary.macroDistribution) { macro in
                    SectorMark(
                        angle: .value("Kalori", macro.calories),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Makro", macro.kind.title))
                }
                .chartForegroundStyleScale([
                    MacroKind.protein.title: NuvyraColors.accent,
                    MacroKind.carbs.title: NuvyraColors.paleLime,
                    MacroKind.fat.title: NuvyraColors.softSand
                ])
                .chartLegend(.hidden)
                .frame(height: 210)

                VStack(spacing: NuvyraSpacing.xs) {
                    ForEach(summary.macroDistribution) { macro in
                        HStack {
                            Circle()
                                .fill(color(for: macro.kind))
                                .frame(width: 10, height: 10)
                            Text(macro.kind.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Spacer()
                            Text("\(Int(macro.grams.rounded()))g • \(Int((macro.percentage * 100).rounded()))%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }
                }
            }
        }
    }

    private var macroAccessibilityText: String {
        let text = summary.macroDistribution.map {
            "\($0.kind.title) \(Int(($0.percentage * 100).rounded())) yüzde"
        }.joined(separator: ", ")
        return "Makro dağılım grafiği. \(text)."
    }

    private func color(for kind: MacroKind) -> Color {
        switch kind {
        case .protein: NuvyraColors.accent
        case .carbs: NuvyraColors.paleLime
        case .fat: NuvyraColors.softSand
        }
    }
}

private struct MacroDistributionOverviewCard: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Makro dağılımı")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text("Protein, karbonhidrat ve yağın kalori bazlı oranı.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer(minLength: 0)
                    ZStack {
                        macroChart
                        VStack(spacing: 2) {
                            Text("\(Int(totalMacroCalories.rounded()))")
                                .font(.system(.title3, design: .rounded).weight(.heavy))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text("kcal")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(summary.macroDistribution) { macro in
                        MacroDistributionRow(macro: macro, tint: color(for: macro.kind))
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(macroAccessibilityText)
    }

    private var macroChart: some View {
        Chart(summary.macroDistribution) { macro in
            SectorMark(
                angle: .value("Kalori", macro.calories),
                innerRadius: .ratio(0.66),
                angularInset: 2.6
            )
            .foregroundStyle(color(for: macro.kind))
        }
        .chartLegend(.hidden)
        .frame(width: 154, height: 154)
    }

    private var totalMacroCalories: Double {
        summary.macroDistribution.map(\.calories).reduce(0, +)
    }

    private var macroAccessibilityText: String {
        let text = summary.macroDistribution.map {
            "\($0.kind.title) \(Int(($0.percentage * 100).rounded())) yüzde"
        }.joined(separator: ", ")
        return "Makro dağılım grafiği. \(text)."
    }

    private func color(for kind: MacroKind) -> Color {
        switch kind {
        case .protein: NuvyraColors.accent
        case .carbs: NuvyraColors.paleLime
        case .fat: NuvyraColors.softSand
        }
    }
}

private struct MacroDistributionRow: View {
    @Environment(\.colorScheme) private var scheme
    let macro: MacroDistribution
    let tint: Color

    private var percent: Int {
        Int((macro.percentage * 100).rounded())
    }

    private var clampedPercentage: Double {
        min(max(macro.percentage, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: NuvyraSpacing.sm) {
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)

                Text(macro.kind.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Spacer(minLength: NuvyraSpacing.sm)

                Text("\(Int(macro.grams.rounded())) g")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                Text("\(percent)%")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .monospacedDigit()
            }

            ProgressView(value: clampedPercentage)
                .tint(tint)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NuvyraColors.card(scheme).opacity(0.46), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }
}

private struct WaterChartCard: View {
    let summary: AnalyticsSummary

    private var target: Double {
        summary.waterPoints.first?.target ?? 0
    }

    var body: some View {
        AnalyticsChartCard(
            title: "Su tüketimi",
            subtitle: "Günlük ml bazında su ritmi.",
            accessibilityLabel: "Su tüketimi grafiği. Ortalama \(summary.averageWaterMl) mililitre."
        ) {
            Chart {
                ForEach(summary.waterPoints) { point in
                    LineMark(
                        x: .value("Gün", point.date, unit: .day),
                        y: .value("Su", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(NuvyraColors.softMint)

                    AreaMark(
                        x: .value("Gün", point.date, unit: .day),
                        y: .value("Su", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(NuvyraColors.softMint.opacity(0.18))
                }

                if target > 0 {
                    RuleMark(y: .value("Su hedefi", target))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                        .foregroundStyle(NuvyraColors.accent)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }
}

private struct StepsChartCard: View {
    let summary: AnalyticsSummary

    private var target: Double {
        summary.stepPoints.first?.target ?? 0
    }

    var body: some View {
        AnalyticsChartCard(
            title: "Günlük adım",
            subtitle: "Adım ve yürüyüş ritminin dönemsel görünümü.",
            accessibilityLabel: "Adım grafiği. Ortalama \(summary.averageSteps) adım."
        ) {
            Chart {
                ForEach(summary.stepPoints) { point in
                    BarMark(
                        x: .value("Gün", point.date, unit: .day),
                        y: .value("Adım", point.value)
                    )
                    .foregroundStyle(NuvyraColors.accent.gradient)
                    .cornerRadius(6)
                }

                if target > 0 {
                    RuleMark(y: .value("Adım hedefi", target))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 6]))
                        .foregroundStyle(NuvyraColors.paleLime)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day)) }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }
}

private struct AIInsightCard: View {
    @Environment(\.colorScheme) private var scheme
    let summary: AnalyticsSummary

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack {
                    Label("AI içgörü", systemImage: "sparkles")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Spacer()
                    Text("Kural bazlı")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }

                Text(summary.aiInsight)
                    .font(.body.weight(.medium))
                    .lineSpacing(4)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))

                Text("Bu yorum tıbbi tavsiye değildir; uygulama içindeki kayıtlarına göre wellness ritmi yorumu üretir.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme).opacity(0.82))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AnalyticsChartCard<ChartContent: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let subtitle: String
    let accessibilityLabel: String
    let chartContent: ChartContent

    init(
        title: String,
        subtitle: String,
        accessibilityLabel: String,
        @ViewBuilder chartContent: () -> ChartContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessibilityLabel = accessibilityLabel
        self.chartContent = chartContent()
    }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(NuvyraTypography.section)
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }

                chartContent
                    .frame(height: 230)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)
            }
        }
    }
}

private struct AnalyticsLoadingState: View {
    var body: some View {
        NuvyraGlassCard {
            HStack(spacing: NuvyraSpacing.md) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analiz hazırlanıyor")
                        .font(NuvyraTypography.section)
                    Text("Haftalık ve aylık ritim verilerin toplanıyor.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct AnalyticsErrorState: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label("Analiz yüklenemedi", systemImage: "exclamationmark.triangle.fill")
                    .font(NuvyraTypography.section)
                    .foregroundStyle(NuvyraColors.mutedCoral)
                Text(message)
                    .foregroundStyle(.secondary)
                NuvyraSecondaryButton(title: "Tekrar dene", systemImage: "arrow.clockwise", action: retry)
            }
        }
    }
}

private struct AnalyticsEmptyState: View {
    @Environment(\.colorScheme) private var scheme
    let period: AnalyticsPeriod

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)

                Text("\(period.title) analiz için kayıt bekleniyor")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                Text("Bir öğün, birkaç su kaydı ve yürüyüş verisi eklediğinde grafikler otomatik olarak dolacak.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
    }
}

#Preview {
    NavigationStack { AnalyticsView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
