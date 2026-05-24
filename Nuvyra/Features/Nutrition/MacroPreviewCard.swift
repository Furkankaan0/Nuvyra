import SwiftUI

/// Compact preview row that shows the calorie + macro breakdown that will be saved.
/// Used inside the Add-Food sheet so the user sees exactly what will land in their day.
struct MacroPreviewCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var values: NutritionValues

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Önizleme")
                            .font(NuvyraTypography.section)
                        Text("Kaydedildiğinde günlük toplamlarına eklenecek")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(values.calories) kcal")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(NuvyraColors.accent)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: values.calories)
                }
                HStack(spacing: NuvyraSpacing.sm) {
                    MacroPreviewPill(title: "Protein", grams: values.protein, tint: NuvyraColors.mutedCoral)
                    MacroPreviewPill(title: "Karb.", grams: values.carbs, tint: NuvyraColors.paleLime)
                    MacroPreviewPill(title: "Yağ", grams: values.fat, tint: NuvyraColors.softSand)
                }
            }
        }
    }
}

private struct MacroPreviewPill: View {
    var title: String
    var grams: Double
    var tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(grams.cleanFormatted) g")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        MacroPreviewCard(values: NutritionValues(calories: 430, protein: 24, carbs: 38, fat: 16)).padding()
    }
}
#endif
