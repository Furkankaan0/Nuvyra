import SwiftUI

struct MealListView: View {
    var meals: [MealEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            NuvyraSectionHeader(title: "Bugünkü öğünler", subtitle: meals.isEmpty ? "İlk öğününü ekleyelim." : "Değerler tahminidir, gerektiğinde düzenlenebilir.")
            if meals.isEmpty {
                NuvyraCard {
                    Label("Henüz öğün yok", systemImage: "fork.knife")
                        .font(NuvyraTypography.section)
                    Text("Manuel ekleyebilir veya hızlı Türk yemeği seçebilirsin.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(meals) { meal in
                    MealCard(meal: meal)
                }
            }
        }
    }
}
