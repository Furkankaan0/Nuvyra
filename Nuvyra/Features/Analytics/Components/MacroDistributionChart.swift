import Charts
import SwiftUI

struct MacroDistributionChart: View {
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
