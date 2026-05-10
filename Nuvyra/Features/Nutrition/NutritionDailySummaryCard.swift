import SwiftUI

struct NutritionDailySummaryCard: View {
    @Environment(\.colorScheme) private var scheme
    var nutrition: DailyNutritionSummary
    var macros: [MacroSummary]

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bugünün özeti")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(nutrition.consumed)")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText(value: Double(nutrition.consumed)))
                            Text("/ \(nutrition.target) kcal")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }
                    Spacer()
                    Text("\(Int(nutrition.ringProgress * 100))%")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(NuvyraColors.accent)
                }

                progressBar

                HStack(spacing: NuvyraSpacing.sm) {
                    ForEach(macros) { macro in
                        MacroProgressMini(summary: macro)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NuvyraColors.accent.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: [NuvyraColors.accent, NuvyraColors.softMint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.width * CGFloat(nutrition.ringProgress), nutrition.consumed > 0 ? 6 : 0))
                    .shadow(color: NuvyraColors.accent.opacity(0.4), radius: 6)
            }
        }
        .frame(height: 8)
    }
}

private struct MacroProgressMini: View {
    @Environment(\.colorScheme) private var scheme
    var summary: MacroSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: summary.kind.systemImage)
                    .foregroundStyle(summary.tint(scheme: scheme))
                    .font(.caption2.weight(.bold))
                Text(summary.kind.shortTitle)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
            Text("\(Int(summary.consumedGrams))/\(Int(summary.targetGrams))g")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.primaryText(scheme))
            Capsule()
                .fill(summary.tint(scheme: scheme).opacity(0.16))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(summary.tint(scheme: scheme))
                            .frame(width: proxy.size.width * CGFloat(summary.progress))
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(summary.tint(scheme: scheme).opacity(0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }
}

#if DEBUG
#Preview {
    NutritionDailySummaryCard(
        nutrition: DailyNutritionSummary(consumed: 1_240, burned: 280, target: 1_900),
        macros: [
            MacroSummary(kind: .protein, consumedGrams: 78, targetGrams: 120),
            MacroSummary(kind: .carbs, consumedGrams: 132, targetGrams: 210),
            MacroSummary(kind: .fat, consumedGrams: 41, targetGrams: 65)
        ]
    )
    .padding()
    .background(NuvyraBackground())
}
#endif
