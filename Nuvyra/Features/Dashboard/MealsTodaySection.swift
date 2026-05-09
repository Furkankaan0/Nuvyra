import SwiftUI

struct MealsTodaySection: View {
    @Environment(\.colorScheme) private var scheme
    var meals: [MealEntry]
    var onAdd: (MealType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraSectionHeader(title: "Bugünkü öğünler", subtitle: "Kalori değerleri tahminidir.")
            VStack(spacing: NuvyraSpacing.sm) {
                ForEach(MealType.allCases) { type in
                    let mealsForType = meals.filter { $0.mealType == type }
                    let totalCalories = mealsForType.reduce(0) { $0 + $1.calories }
                    MealRow(type: type, totalCalories: totalCalories, items: mealsForType, onAdd: { onAdd(type) })
                }
            }
        }
    }
}

private struct MealRow: View {
    @Environment(\.colorScheme) private var scheme
    var type: MealType
    var totalCalories: Int
    var items: [MealEntry]
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack {
                ZStack {
                    Circle()
                        .fill(NuvyraColors.accent.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: type.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(NuvyraTypography.section)
                    Text(items.isEmpty ? "Henüz eklenmedi" : "\(items.count) öğe")
                        .font(.caption)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
                Spacer()
                if items.isEmpty {
                    Button(action: onAdd) {
                        Label("Ekle", systemImage: "plus")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(NuvyraColors.accent.opacity(0.14), in: Capsule())
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("\(totalCalories) kcal")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                }
            }

            if !items.isEmpty {
                Divider().opacity(0.4)
                ForEach(items.prefix(3)) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("• \(item.portionDescription)")
                            .font(.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.calories) kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
                if items.count > 3 {
                    Text("ve \(items.count - 3) öğe daha")
                        .font(.caption)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
            }
        }
        .padding(NuvyraSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NuvyraColors.card(scheme).opacity(0.72), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(NuvyraColors.accent.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }
}
