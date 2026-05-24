import SwiftUI

/// Single logged food entry — appears inside a `MealSectionView`. Tap to edit,
/// swipe to delete.
struct FoodLogRow: View {
    var meal: MealEntry
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: NuvyraSpacing.md) {
                Image(systemName: meal.mealType.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
                    .frame(width: 38, height: 38)
                    .background(NuvyraColors.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: NuvyraSpacing.xs) {
                        Text(meal.portionDescription)
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                        if meal.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(NuvyraColors.softSand)
                        }
                        if meal.isEstimated {
                            Text("tahmini")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(NuvyraColors.accent)
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(meal.calories) kcal")
                        .font(.subheadline.weight(.bold))
                    HStack(spacing: 4) {
                        macroChip("P", value: meal.protein)
                        macroChip("K", value: meal.carbs)
                        macroChip("Y", value: meal.fat)
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Sil", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Düzenle", systemImage: "pencil")
            }
            .tint(NuvyraColors.accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meal.name), \(meal.calories) kalori, \(meal.portionDescription)")
        .accessibilityHint("Düzenlemek için dokun, silmek için kaydır")
    }

    @ViewBuilder
    private func macroChip(_ label: String, value: Double?) -> some View {
        if let value, value > 0 {
            Text("\(label)\(Int(value))")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NuvyraColors.accent.opacity(0.10), in: Capsule())
                .foregroundStyle(NuvyraColors.accent)
        }
    }
}
