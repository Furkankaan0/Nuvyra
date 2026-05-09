import SwiftUI

struct FoodLogRow: View {
    @Environment(\.colorScheme) private var scheme
    var meal: MealEntry
    var onEdit: () -> Void
    var onDelete: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: NuvyraSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(NuvyraColors.accent.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: meal.mealType.systemImage)
                        .foregroundStyle(NuvyraColors.accent)
                        .font(.subheadline.weight(.bold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(meal.portionDescription)
                            .font(.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        Text(Self.timeFormatter.string(from: meal.createdAt))
                            .font(.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                        if meal.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(NuvyraColors.softSand)
                        }
                    }

                    if hasMacros {
                        HStack(spacing: 6) {
                            MacroChip(label: "P", value: meal.protein ?? 0, tint: NuvyraColors.mutedCoral)
                            MacroChip(label: "K", value: meal.carbs ?? 0, tint: NuvyraColors.paleLime)
                            MacroChip(label: "Y", value: meal.fat ?? 0, tint: NuvyraColors.softSand)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(meal.calories)")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                    Text("kcal")
                        .font(.caption2)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(NuvyraColors.card(scheme).opacity(0.72), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                    .stroke(NuvyraColors.accent.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: { Label("Düzenle", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Sil", systemImage: "trash") }
        }
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
        .accessibilityLabel("\(meal.name), \(meal.calories) kalori, \(meal.portionDescription). Düzenlemek için dokun.")
        .accessibilityAction(named: "Sil", onDelete)
    }

    private var hasMacros: Bool {
        (meal.protein ?? 0) > 0 || (meal.carbs ?? 0) > 0 || (meal.fat ?? 0) > 0
    }
}

private struct MacroChip: View {
    var label: String
    var value: Double
    var tint: Color

    var body: some View {
        Text("\(label) \(Int(value))g")
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}
