import SwiftUI

/// Meal-grouped section showing all `MealEntry` rows for a given meal type
/// plus the totals header and an inline "add" button.
struct MealSectionView: View {
    var mealType: MealType
    var entries: [MealEntry]
    var onAdd: () -> Void
    var onEdit: (MealEntry) -> Void
    var onDelete: (MealEntry) -> Void

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                header
                if entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, meal in
                            if index > 0 {
                                Divider().padding(.vertical, 2)
                            }
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
    }

    private var header: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: mealType.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(NuvyraColors.accent)
            Text(mealType.title)
                .font(NuvyraTypography.section)
            Spacer()
            if !entries.isEmpty {
                Text("\(totalCalories) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(NuvyraColors.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(mealType.title) için yemek ekle")
        }
    }

    private var emptyState: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: "tray")
                .foregroundStyle(.secondary)
            Text("Henüz \(mealType.title.lowercased()) eklenmedi")
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#if DEBUG
#Preview {
    ZStack {
        NuvyraBackground()
        VStack(spacing: NuvyraSpacing.md) {
            MealSectionView(mealType: .lunch, entries: [], onAdd: {}, onEdit: { _ in }, onDelete: { _ in })
        }
        .padding()
    }
}
#endif
