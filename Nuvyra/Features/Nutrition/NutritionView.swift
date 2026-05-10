import SwiftData
import SwiftUI

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = NutritionViewModel()
    @State private var showBarcodeUnavailableAlert = false
    @FocusState private var smartFieldFocused: Bool

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NutritionDailySummaryCard(
                        nutrition: viewModel.nutritionSummary,
                        macros: viewModel.macroSummaries
                    )

                    quickActionsRow

                    SmartMealEntryCard(
                        text: $viewModel.smartMealText,
                        results: viewModel.estimatedResults,
                        isEstimating: viewModel.isEstimating,
                        errorMessage: viewModel.errorMessage,
                        focused: $smartFieldFocused,
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

                    mealSections
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Beslenme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showingAddMeal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(NuvyraColors.accent)
                }
                .accessibilityLabel("Öğün ekle")
            }
        }
        .sheet(isPresented: $viewModel.showingAddMeal, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) {
            AddMealView(defaultMealType: viewModel.selectedMealType)
        }
        .sheet(item: $viewModel.editingMeal, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) { meal in
            AddMealView(editing: meal)
        }
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            CameraView { result in
                viewModel.showingCamera = false
                Task { await viewModel.addEstimatedResult(result, context: modelContext, dependencies: dependencies) }
            }
        }
        .sheet(isPresented: $viewModel.showingFoodSearch, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) {
            FoodSearchView { result in
                Task { await viewModel.addFoodSearchResult(result, context: modelContext, dependencies: dependencies) }
            }
        }
        .alert("Barkod tarama yakında", isPresented: $showBarcodeUnavailableAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Barkod tarama modülü ayrı bir entegrasyon olarak hazırlanıyor. Şimdilik manuel ekleme veya akıllı kayıt kullanabilirsin.")
        }
        .alert("Öğünü sil", isPresented: deleteAlertBinding, presenting: viewModel.pendingDeleteMeal) { meal in
            Button("Sil", role: .destructive) {
                viewModel.delete(meal, context: modelContext, dependencies: dependencies)
                viewModel.pendingDeleteMeal = nil
            }
            Button("Vazgeç", role: .cancel) { viewModel.pendingDeleteMeal = nil }
        } message: { meal in
            Text("\"\(meal.name)\" öğünü silinsin mi? Bu işlem geri alınamaz.")
        }
        .task { viewModel.load(context: modelContext, dependencies: dependencies) }
        .onAppear { handle(action: router.pendingNutritionAction) }
        .onChange(of: router.pendingNutritionAction) { _, action in handle(action: action) }
    }

    private var quickActionsRow: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            NuvyraSecondaryButton(title: "Veritabanı", systemImage: "magnifyingglass") {
                viewModel.showingFoodSearch = true
            }
            NuvyraSecondaryButton(title: "Kamera", systemImage: "camera.viewfinder") {
                viewModel.showingCamera = true
            }
        }
    }

    private var mealSections: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
            ForEach(MealType.allCases) { type in
                MealSectionView(
                    mealType: type,
                    meals: viewModel.mealsByType(type),
                    onAdd: {
                        viewModel.selectedMealType = type
                        viewModel.showingAddMeal = true
                    },
                    onEdit: { meal in viewModel.editingMeal = meal },
                    onDelete: { meal in viewModel.pendingDeleteMeal = meal }
                )
            }
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.pendingDeleteMeal != nil },
            set: { isPresented in if !isPresented { viewModel.pendingDeleteMeal = nil } }
        )
    }

    private func handle(action: NutritionQuickAction?) {
        guard let action else { return }
        switch action {
        case .openAddMeal:
            viewModel.showingAddMeal = true
        case .openFoodSearch:
            viewModel.showingFoodSearch = true
        case .openVoiceEntry:
            smartFieldFocused = true
        case .openBarcodeScanner:
            showBarcodeUnavailableAlert = true
        }
        router.pendingNutritionAction = nil
    }
}

#Preview {
    NavigationStack { NutritionView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
        .environmentObject(AppRouter())
}

private struct SmartMealEntryCard: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var text: String
    var results: [EstimatedMealResult]
    var isEstimating: Bool
    var errorMessage: String?
    var focused: FocusState<Bool>.Binding
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
                        Text("Kısa bir açıklama yaz, tahmini değerler oluşsun.")
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
                    .focused(focused)
                    .background(NuvyraColors.card(scheme).opacity(0.72), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                            .stroke(focused.wrappedValue ? NuvyraColors.accent : NuvyraColors.accent.opacity(0.18), lineWidth: focused.wrappedValue ? 1.4 : 1)
                    )
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
