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
                    header
                    dateSelector
                    dailyTotalsCard
                    StreakCard(kind: .meal, insight: viewModel.streak)
                    FoodQualityCard(totals: viewModel.summary.totals, target: viewModel.macroTarget)
                    quickActions
                    mealSections
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
                }
                .padding(NuvyraSpacing.lg)
            }

            if let feedback = viewModel.actionFeedback {
                VStack {
                    Spacer()
                    Text(feedback)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(NuvyraColors.accent.opacity(0.92), in: Capsule())
                        .padding(.bottom, NuvyraSpacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(false)
            }
        }
        .navigationTitle("Beslenme")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showingAddMeal, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) {
            AddFoodView(mode: .create(defaultMealType: viewModel.selectedMealType))
        }
        .sheet(item: $viewModel.editingMeal, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) { meal in
            AddFoodView(mode: .edit(meal))
        }
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            CameraView { detection in
                viewModel.smartMealText = detection.label
                viewModel.showingCamera = false
                Task { await viewModel.estimateSmartMeal(dependencies: dependencies) }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showingBarcodeScanner) {
            BarcodeScannerView(viewModel: makeBarcodeScannerViewModel()) { product in
                Task {
                    await viewModel.handleScannedProduct(product, dependencies: dependencies)
                    viewModel.showingBarcodeScanner = false
                }
            }
        }
        .sheet(item: $viewModel.pendingBarcodeItem, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) { item in
            FoodDetailView(item: item) { values, serving, quantity in
                let selection = FoodSelection(item: item, values: values, serving: serving, quantity: quantity)
                Task { await viewModel.addFoodSelection(selection, context: modelContext, dependencies: dependencies) }
            }
        }
        .sheet(isPresented: $viewModel.showingFoodSearch, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) {
            FoodSearchView { selection in
                Task { await viewModel.addFoodSelection(selection, context: modelContext, dependencies: dependencies) }
            }
        }
        .task { viewModel.load(context: modelContext, dependencies: dependencies) }
    }

    private var header: some View {
        NuvyraSectionHeader(
            title: "Beslenme",
            subtitle: "Öğünlerini ekle, düzenle, sil — günlük makroların otomatik güncellensin."
        )
    }

    private var dateSelector: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraDateNavigator(
                date: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.changeDate(to: $0, context: modelContext, dependencies: dependencies) }
                ),
                title: "Öğün tarihi"
            )
            NuvyraSecondaryButton(title: "Önceki günü bu tarihe kopyala", systemImage: "doc.on.doc") {
                Task { await viewModel.copyPreviousDayMeals(context: modelContext, dependencies: dependencies) }
            }
        }
    }

    private var dailyTotalsCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Günlük toplam")
                            .font(NuvyraTypography.section)
                        Text("\(viewModel.summary.mealCount) kayıt")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(viewModel.summary.totals.calories) kcal")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(NuvyraColors.accent)
                        .contentTransition(.numericText())
                }
                HStack(spacing: NuvyraSpacing.sm) {
                    macroTotal("Protein", grams: viewModel.summary.totals.protein, tint: NuvyraColors.mutedCoral)
                    macroTotal("Karb.", grams: viewModel.summary.totals.carbs, tint: NuvyraColors.paleLime)
                    macroTotal("Yağ", grams: viewModel.summary.totals.fat, tint: NuvyraColors.softSand)
                }
            }
        }
    }

    private func macroTotal(_ title: String, grams: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(grams.cleanFormatted) g")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
            NuvyraPrimaryButton(title: "Yemek ekle", systemImage: "plus") {
                viewModel.showingAddMeal = true
            }
            NuvyraSecondaryButton(title: "Ara", systemImage: "magnifyingglass") {
                viewModel.showingFoodSearch = true
            }
            NuvyraSecondaryButton(title: "Barkod", systemImage: "barcode.viewfinder") {
                viewModel.showingBarcodeScanner = true
            }
            NuvyraSecondaryButton(title: "Kamera", systemImage: "camera.viewfinder") {
                viewModel.showingCamera = true
            }
        }
    }

    private func makeBarcodeScannerViewModel() -> BarcodeScannerViewModel {
        let client = HTTPClient()
        return BarcodeScannerViewModel(
            scanner: BarcodeScannerService(),
            api: NutritionAPIService(
                providers: FoodDataProviderFactory.barcodeProviders(client: client),
                diskCache: try? ProductCacheService()
            )
        )
    }

    private var mealSections: some View {
        VStack(spacing: NuvyraSpacing.md) {
            ForEach(viewModel.sectionedMeals, id: \.0) { type, entries in
                MealSectionView(
                    mealType: type,
                    entries: entries,
                    onAdd: {
                        viewModel.selectedMealType = type
                        viewModel.showingAddMeal = true
                    },
                    onEdit: { meal in viewModel.startEditing(meal) },
                    onDelete: { meal in viewModel.delete(meal, context: modelContext, dependencies: dependencies) },
                    onCopyToToday: { meal in
                        Task { await viewModel.copyMealToToday(meal, context: modelContext, dependencies: dependencies) }
                    }
                )
            }
        }
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
                        Text("Cihaz içi Türkçe tahmin katmanı. Barkod ve bulut adapter'ları buraya bağlanır.")
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
