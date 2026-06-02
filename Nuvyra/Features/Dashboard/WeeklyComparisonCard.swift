import SwiftUI

/// Dashboard card summarising "this week vs. last week" across calories,
/// protein, steps and water. Renders a soft empty-state when the user has
/// fewer than 2 active days this week so the card never shows misleading %.
struct WeeklyComparisonCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppear = false

    var comparison: WeeklyComparison

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                header
                Text(comparison.storyline)
                    .font(NuvyraTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if comparison.hasEnoughData {
                    metricsGrid
                } else {
                    emptyMetricsHint
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { didAppear = true; return }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) { didAppear = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Haftalık karşılaştırma")
        .accessibilityHint(comparison.storyline)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("weekly.comparison.title")
                    .font(NuvyraTypography.section)
                Text("weekly.comparison.subtitle")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: NuvyraSpacing.sm), GridItem(.flexible(), spacing: NuvyraSpacing.sm)],
            alignment: .leading,
            spacing: NuvyraSpacing.sm
        ) {
            ForEach(comparison.metrics) { metric in
                WeeklyMetricTile(metric: metric)
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : 8)
            }
        }
    }

    private var emptyMetricsHint: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
            Text("weekly.comparison.empty")
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, NuvyraSpacing.xs)
    }
}

/// One tile inside the grid — large current value, "vs last week" baseline,
/// and a coloured direction chip. Each metric type gets a stable tint so the
/// user can pattern-match the same color over many sessions.
private struct WeeklyMetricTile: View {
    let metric: WeeklyMetric

    private var tint: Color {
        switch metric.kind {
        case .calories: NuvyraColors.mutedCoral
        case .protein: NuvyraColors.accent
        case .steps: NuvyraColors.softSand
        case .water: NuvyraColors.softMint
        }
    }

    private var directionColor: Color {
        switch metric.direction {
        case .up: NuvyraColors.accent
        case .down: NuvyraColors.mutedCoral
        case .flat: NuvyraColors.mutedGray
        case .baseline: NuvyraColors.mutedGray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: metric.kind.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(metric.kind.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                changeChip
            }
            Text(metric.currentDisplay)
                .font(NuvyraTypography.metricFont(size: 24, relativeTo: .title2))
                .contentTransition(.numericText())
            Text(metric.kind.unitLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("Geçen hafta")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(metric.previousDisplay)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(NuvyraSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var changeChip: some View {
        Text(metric.changeText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(directionColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(directionColor.opacity(0.14), in: Capsule())
    }

    private var accessibilityLabel: String {
        let unit = metric.kind.unitLabel
        let direction: String = {
            switch metric.direction {
            case .up: "geçen haftadan yüksek"
            case .down: "geçen haftadan düşük"
            case .flat: "geçen haftaya benzer"
            case .baseline: "henüz karşılaştırma yok"
            }
        }()
        return "\(metric.kind.title) bu hafta \(metric.currentDisplay) \(unit), \(direction). Geçen hafta \(metric.previousDisplay)."
    }
}

#if DEBUG
#Preview("Rich data") {
    ZStack {
        NuvyraBackground()
        ScrollView {
            VStack(spacing: NuvyraSpacing.md) {
                WeeklyComparisonCard(comparison: .previewSample)
                WeeklyComparisonCard(comparison: .empty)
            }
            .padding()
        }
    }
}
#endif
