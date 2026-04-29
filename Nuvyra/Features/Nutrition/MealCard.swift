import SwiftUI

struct MealCard: View {
    var meal: MealEntry

    var body: some View {
        NuvyraCard {
            HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                Image(systemName: meal.mealType.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                    .frame(width: 42, height: 42)
                    .background(NuvyraColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm))
                VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(meal.name).font(.headline.weight(.semibold))
                        Spacer()
                        Text("\(meal.calories) kcal").font(.headline.weight(.bold))
                    }
                    Text("\(meal.mealType.title) • \(meal.portionDescription)")
                        .foregroundStyle(.secondary)
                    HStack(spacing: NuvyraSpacing.sm) {
                        if meal.isEstimated { Text("Tahmini") }
                        if meal.isVerifiedTurkishFood { Text("Türk yemeği") }
                        if meal.isFavorite { Text("Favori") }
                    }
                    .font(NuvyraTypography.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
