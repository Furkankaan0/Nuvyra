import SwiftUI

struct FavoriteMealsView: View {
    var favorites: [MealEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
            NuvyraSectionHeader(title: "Favoriler", subtitle: favorites.isEmpty ? "Favori öğünlerin burada görünür." : nil)
            ForEach(favorites) { meal in
                MealCard(meal: meal)
            }
        }
    }
}
