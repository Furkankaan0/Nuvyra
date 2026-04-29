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
                    SmartMealEntryCard(
                        text: $viewModel.smartMealText,
                        results: viewModel.estimatedResults,
                        isEstimating: viewModel.isEstimating,
                        errorMessage: viewModel.errorMessage,
                        onEstimate: {
                            Task { await viewModel.estimateSmartMeal(dependencies: dependencies) }
                        },
                        onAdd: { result in
                            Task { await viewModel.addEstimatedResult(result, context: modelContext, dependencies: dependencies) }
                        }
                    )
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

private struct SmartMealEntryCard: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String
    var results: [EstimatedMealResult]
    var isEstimating: Bool
    var errorMessage: String?
    var onEstimate: () -> Void
    var onAdd: (EstimatedMealResult) -> Void

    var body: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
                        Label("Akıllı kayıt", systemImage: "sparkles")
                            .font(NuvyraTypography.section)
                            .foregroundStyle(NuvyraColors.primaryText(scheme))
                        Text("Şimdilik mock Türkçe NLP kullanır. Gerçek AI ve barkod adapter’ları bu katmana bağlanacak.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    Spacer()
                    Text("Tahmini")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(NuvyraColors.accent.opacity(0.12), in: Capsule())
                }

                TextField("Örn. öğlen mercimek çorbası ve ayran içtim", text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(14)
                    .background(NuvyraColors.card(scheme).opacity(0.72), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                    .accessibilityLabel("Akıllı öğün metni")

                NuvyraSecondaryButton(title: isEstimating ? "Tahmin hazırlanıyor" : "Tahmini oluştur", systemImage: "wand.and.stars", action: onEstimate)
                    .disabled(isEstimating || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(isEstimating ? 0.72 : 1)

                if let errorMessage {
                    Text(errorMessage)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }

                ForEach(results) { result in
                    EstimatedMealResultRow(result: result) {
                        onAdd(result)
                    }
                }
            }
        }
    }
}

private struct EstimatedMealResultRow: View {
    @Environment(\.colorScheme) private var scheme
    var result: EstimatedMealResult
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                    Text("\(result.portion) • \(Int(result.confidence * 100))% güven • Tahmini değer")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }
                Spacer()
                Text("\(result.calories) kcal")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(NuvyraColors.accent)
            }

            HStack(spacing: NuvyraSpacing.sm) {
                MacroPill(title: "P", value: result.protein)
                MacroPill(title: "K", value: result.carbs)
                MacroPill(title: "Y", value: result.fat)
                Spacer()
                Button("Öğüne ekle", action: onAdd)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .tint(NuvyraColors.accent)
            }
        }
        .padding(14)
        .background(NuvyraColors.card(scheme).opacity(0.62), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct MacroPill: View {
    var title: String
    var value: Double

    var body: some View {
        Text("\(title) \(Int(value))g")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(NuvyraColors.accent.opacity(0.10), in: Capsule())
    }
}
