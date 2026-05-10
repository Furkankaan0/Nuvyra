import SwiftUI

struct MealSectionView: View {
    @Environment(\.colorScheme) private var scheme
    var mealType: MealType
    var meals: [MealEntry]
    var onAdd: () -> Void
    var onEdit: (MealEntry) -> Void
    var onDelete: (MealEntry) -> Void

    private var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(NuvyraColors.accent.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: mealType.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mealType.title)
                        .font(NuvyraTypography.section)
                    if !meals.isEmpty {
                        Text("\(meals.count) öğe • \(totalCalories) kcal")
                            .font(.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mealType.title) öğünü ekle")
            }

            if meals.isEmpty {
                emptyState
            } else {
                VStack(spacing: 6) {
                    ForEach(meals) { meal in
                        FoodLogRow(
                            meal: meal,
                            onEdit: { onEdit(meal) },
                            onDelete: { onDelete(meal) }
                        )
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Button(action: onAdd) {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(NuvyraColors.accent)
                Text("\(mealType.title) ekle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NuvyraColors.accent)
                Spacer()
            }
            .padding(NuvyraSpacing.sm)
            .background(NuvyraColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous)
                    .strokeBorder(NuvyraColors.accent.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
    }
}
