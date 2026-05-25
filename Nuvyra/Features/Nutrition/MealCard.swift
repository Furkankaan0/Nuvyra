import SwiftUI

struct MealCard: View {
    var meal: MealEntry

    var body: some View {
        NuvyraCard {
            HStack(alignment: .top, spacing: NuvyraSpacing.md) {
                MealPhotoThumbnail(
                    data: meal.photoData,
                    fallbackSystemImage: meal.mealType.systemImage,
                    size: 46,
                    cornerRadius: NuvyraRadius.md
                )
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
                        if meal.photoData != nil { Text("Fotoğraflı") }
                    }
                    .font(NuvyraTypography.caption.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
