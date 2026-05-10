import SwiftUI

struct MacroPreviewCard: View {
    @Environment(\.colorScheme) private var scheme
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    private var totalGrams: Double { protein + carbs + fat }

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Önizleme")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(calories)")
                                .font(.system(size: 38, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText(value: Double(calories)))
                                .foregroundStyle(NuvyraColors.primaryText(scheme))
                            Text("kcal")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        }
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(NuvyraColors.mutedCoral)
                        .padding(10)
                        .background(NuvyraColors.mutedCoral.opacity(0.14), in: Circle())
                }

                stackBar

                HStack(spacing: NuvyraSpacing.sm) {
                    MacroBadge(label: "Protein", value: protein, suffix: "g", color: NuvyraColors.mutedCoral)
                    MacroBadge(label: "Karb", value: carbs, suffix: "g", color: NuvyraColors.paleLime)
                    MacroBadge(label: "Yağ", value: fat, suffix: "g", color: NuvyraColors.softSand)
                }
            }
        }
    }

    @ViewBuilder
    private var stackBar: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                segment(width: proxy.size.width, ratio: ratio(for: protein), color: NuvyraColors.mutedCoral)
                segment(width: proxy.size.width, ratio: ratio(for: carbs), color: NuvyraColors.paleLime)
                segment(width: proxy.size.width, ratio: ratio(for: fat), color: NuvyraColors.softSand)
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .background(NuvyraColors.card(scheme).opacity(0.5), in: Capsule())
    }

    private func segment(width: CGFloat, ratio: Double, color: Color) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
            .frame(width: max(width * CGFloat(ratio), ratio > 0 ? 4 : 0))
    }

    private func ratio(for value: Double) -> Double {
        guard totalGrams > 0 else { return 1.0 / 3.0 }
        return value / totalGrams
    }
}

private struct MacroBadge: View {
    @Environment(\.colorScheme) private var scheme
    var label: String
    var value: Double
    var suffix: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .contentTransition(.numericText(value: value))
                Text(suffix)
                    .font(.caption2)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous)
                .stroke(color.opacity(0.22))
        )
    }
}

#if DEBUG
#Preview {
    MacroPreviewCard(calories: 520, protein: 36, carbs: 52, fat: 18)
        .padding()
        .background(NuvyraBackground())
}
#endif
