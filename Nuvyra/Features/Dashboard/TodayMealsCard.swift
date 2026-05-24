import SwiftUI

struct TodayMealsCard: View {
    var meals: [MealEntry]
    var onAdd: (MealType) -> Void

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Bugünkü öğünler", subtitle: "Kalori değerleri tahminidir")
                VStack(spacing: NuvyraSpacing.sm) {
                    ForEach(MealType.allCases) { type in
                        MealSlotRow(
                            type: type,
                            meal: meals.first { $0.mealType == type },
                            onAdd: { onAdd(type) }
                        )
                    }
                }
            }
        }
    }
}

private struct MealSlotRow: View {
    var type: MealType
    var meal: MealEntry?
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            Image(systemName: type.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
                .frame(width: 38, height: 38)
                .background(NuvyraColors.accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.subheadline.weight(.semibold))
                if let meal {
                    Text(meal.name)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Henüz eklenmedi")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let meal {
                Text("\(meal.calories) kcal")
                    .font(.subheadline.weight(.bold))
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(NuvyraColors.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(type.title) ekle")
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Today meals") {
    ZStack {
        NuvyraBackground()
        TodayMealsCard(meals: [], onAdd: { _ in }).padding()
    }
}
#endif
