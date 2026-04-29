import SwiftData
import SwiftUI

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = NutritionViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Beslenme", subtitle: "Manuel giriş ve hızlı favorilerle günü sade takip et.")
                    Picker("Öğün tipi", selection: $viewModel.selectedMealType) {
                        ForEach(MealType.allCases) { type in Text(type.title).tag(type) }
                    }
                    .pickerStyle(.segmented)
                    NuvyraPrimaryButton(title: "Manuel öğün ekle", systemImage: "plus") { viewModel.showingAddMeal = true }
                    QuickFoodPicker(selectedMealType: viewModel.selectedMealType) { food in
                        Task { await viewModel.addQuickFood(food, context: modelContext, dependencies: dependencies) }
                    }
                    FavoriteMealsView(favorites: viewModel.favorites)
                    MealListView(meals: viewModel.meals)
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Beslenme")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingAddMeal, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) {
            AddMealView(defaultMealType: viewModel.selectedMealType)
        }
        .task { viewModel.load(context: modelContext, dependencies: dependencies) }
    }
}

#Preview {
    NavigationStack { NutritionView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
