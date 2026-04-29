import SwiftUI

struct QuickFoodPicker: View {
    var selectedMealType: MealType
    var onPick: (QuickFood) -> Void

    private let columns = [GridItem(.adaptive(minimum: 138), spacing: NuvyraSpacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            NuvyraSectionHeader(title: "Hızlı Türk yemekleri", subtitle: "Demo kaloriler tahmini olarak işaretlenir.")
            LazyVGrid(columns: columns, alignment: .leading, spacing: NuvyraSpacing.sm) {
                ForEach(QuickFood.turkishDefaults) { food in
                    Button { onPick(food) } label: {
                        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                            Text(food.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(food.calories) kcal")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(NuvyraSpacing.md)
                        .background(NuvyraColors.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.md))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(food.name), \(food.calories) kalori ekle")
                }
            }
        }
    }
}
