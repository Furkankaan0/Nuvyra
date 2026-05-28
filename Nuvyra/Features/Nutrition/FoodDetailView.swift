import SwiftUI

/// Rich FoodItem detay ekranı — Faz 5 UI zirvesi. Tüm rozet/komponentleri
/// (SourceChip, VerifiedLevelBadge, AllergenPillRow, NutriScoreBadge,
/// NovaGroupBadge, MicronutrientsPanel, ServingSizePicker) tek yerde
/// kompoze eder. Kullanıcı bir `FoodSearchResult` ya da `FoodItem` seçince
/// burası açılır; `onConfirm` callback'i seçilen serving + quantity ile
/// `NutritionValues` döner, çağıran tarafı `MealEntry` yaratır.
struct FoodDetailView: View {
    let item: FoodItem
    let onConfirm: (NutritionValues, ServingSize, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dependencies: DependencyContainer

    @State private var selectedServing: ServingSize
    @State private var quantity: Double = 1.0
    @State private var isFavorite: Bool = false
    @State private var favoriteLoaded: Bool = false

    init(item: FoodItem, onConfirm: @escaping (NutritionValues, ServingSize, Double) -> Void) {
        self.item = item
        self.onConfirm = onConfirm
        _selectedServing = State(initialValue: item.defaultServing)
    }

    private var scaledValues: NutritionValues {
        item.values(for: selectedServing, quantity: quantity)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        header
                        chips
                        if item.showsApproximateBadge {
                            approximateWarning
                        }
                        servingSection
                        macrosCard
                        if let micros = item.micronutrients, micros.hasAnyValue {
                            NuvyraGlassCard {
                                MicronutrientsPanel(micronutrients: micros)
                            }
                        }
                        if !item.allergens.isEmpty {
                            NuvyraGlassCard {
                                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                                    Text("Alerjenler")
                                        .font(NuvyraTypography.section)
                                    AllergenPillRow(allergens: item.allergens)
                                }
                            }
                        }
                        if let ingredients = item.ingredients, !ingredients.isEmpty {
                            NuvyraGlassCard {
                                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                                    Text("İçindekiler")
                                        .font(NuvyraTypography.section)
                                    Text(ingredients)
                                        .font(NuvyraTypography.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !item.additives.isEmpty {
                            NuvyraGlassCard {
                                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                                    Text("Katkı maddeleri")
                                        .font(NuvyraTypography.section)
                                    Text(item.additives.joined(separator: " · "))
                                        .font(NuvyraTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, NuvyraSpacing.md)
                    .padding(.vertical, NuvyraSpacing.lg)
                    .padding(.bottom, 80)
                }

                VStack {
                    Spacer()
                    confirmButton
                }
            }
            .navigationTitle(item.preferredDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
                if item.deterministicRowID != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        favoriteButton
                    }
                }
            }
            .task { await loadFavoriteStatus() }
        }
    }

    private var favoriteButton: some View {
        Button {
            Task { await toggleFavorite() }
        } label: {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                .symbolEffect(.bounce, value: isFavorite)
        }
        .disabled(!favoriteLoaded)
        .accessibilityLabel(isFavorite ? "Favorilerden çıkar" : "Favorilere ekle")
    }

    @MainActor
    private func loadFavoriteStatus() async {
        guard let rowID = item.deterministicRowID else {
            favoriteLoaded = true
            return
        }
        isFavorite = await dependencies.foodRepository.isFavorite(id: rowID)
        favoriteLoaded = true
    }

    @MainActor
    private func toggleFavorite() async {
        guard let rowID = item.deterministicRowID else { return }
        let next = !isFavorite
        isFavorite = next
        await dependencies.foodRepository.setFavorite(id: rowID, next)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.preferredDisplayName)
                .font(NuvyraTypography.title)
                .foregroundStyle(.primary)
            if let brand = item.brand {
                Text(brand)
                    .font(NuvyraTypography.section)
                    .foregroundStyle(.secondary)
            }
            if let category = item.category {
                HStack(spacing: 4) {
                    Image(systemName: category.symbolName)
                    Text(category.displayLabelTR)
                }
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SourceChip(source: item.source)
                VerifiedLevelBadge(level: item.verifiedLevel, confidence: item.confidenceScore)
                if let score = item.nutriScore {
                    NutriScoreBadge(grade: score)
                }
                if let nova = item.novaGroup {
                    NovaGroupBadge(group: nova)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var approximateWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color(red: 0.85, green: 0.62, blue: 0.20))
            VStack(alignment: .leading, spacing: 2) {
                Text("Yaklaşık değer")
                    .font(.system(size: 14, weight: .semibold))
                Text("Bu değerler topluluk verisinden tahmin edilmiştir. Marka/yöntem farkları nedeniyle gerçek değer ±%15 sapabilir.")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(NuvyraSpacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }

    private var servingSection: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Text("Porsiyon")
                    .font(NuvyraTypography.section)
                ServingSizePicker(
                    servings: item.servingSizes,
                    selectedServing: $selectedServing,
                    quantity: $quantity
                )
            }
        }
    }

    private var macrosCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(scaledValues.calories)")
                        .font(NuvyraTypography.metricFont(size: 42))
                        .foregroundStyle(NuvyraColors.accent)
                    Text("kcal")
                        .font(NuvyraTypography.section)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(servingSummary)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                Divider()

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 10) {
                    macroCell("Protein", scaledValues.protein, "g", color: NuvyraColors.accent)
                    macroCell("Karbonhidrat", scaledValues.carbs, "g", color: NuvyraColors.softSand)
                    macroCell("Yağ", scaledValues.fat, "g", color: NuvyraColors.mutedCoral)
                }

                if scaledValues.fiber > 0 || scaledValues.sugar > 0 || scaledValues.sodium > 0 || scaledValues.saturatedFat > 0 {
                    Divider()
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 6) {
                        if scaledValues.fiber > 0 { secondaryCell("Lif", scaledValues.fiber, "g") }
                        if scaledValues.sugar > 0 { secondaryCell("Şeker", scaledValues.sugar, "g") }
                        if scaledValues.saturatedFat > 0 { secondaryCell("Doymuş yağ", scaledValues.saturatedFat, "g") }
                        if scaledValues.sodium > 0 { secondaryCell("Sodyum", scaledValues.sodium, "mg") }
                    }
                }
            }
        }
    }

    private var servingSummary: String {
        let portion = quantity == quantity.rounded()
            ? String(Int(quantity))
            : String(format: "%.1f", quantity)
        return "\(portion) × \(selectedServing.preferredLabel)\n≈ \(Int((selectedServing.grams * quantity).rounded())) g"
    }

    private var confirmButton: some View {
        Button {
            onConfirm(scaledValues, selectedServing, quantity)
            dismiss()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Öğüne ekle · \(scaledValues.calories) kcal")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(NuvyraColors.accent)
        .padding(.horizontal, NuvyraSpacing.md)
        .padding(.bottom, NuvyraSpacing.sm)
    }

    // MARK: - Cells

    private func macroCell(_ label: String, _ value: Double, _ unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(formatted(value))
                .font(NuvyraTypography.metricFont(size: 22))
                .foregroundStyle(color)
            Text("\(label) (\(unit))")
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func secondaryCell(_ label: String, _ value: Double, _ unit: String) -> some View {
        HStack {
            Text(label)
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(formatted(value)) \(unit)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private func formatted(_ value: Double) -> String {
        if value >= 10 || value == value.rounded() {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    FoodDetailView(
        item: FoodItem(
            source: .openFoodFacts,
            externalID: "1234567890123",
            name: "Whole Wheat Biscuit",
            localizedNameTR: "Tam Tahıllı Bisküvi",
            brand: "Nuvyra",
            barcode: "1234567890123",
            category: .bakedGood,
            servingSizes: [.hundredGrams, ServingSize(label: "1 piece", labelTR: "1 adet", grams: 25, isDefault: true)],
            nutritionPer100g: NutritionValues(
                calories: 421,
                protein: 8.2,
                carbs: 63.5,
                fat: 14.1,
                fiber: 5.7,
                sodium: 320,
                sugar: 18.0,
                saturatedFat: 5.5
            ),
            micronutrients: Micronutrients(
                calciumMg: 60,
                ironMg: 2.4,
                magnesiumMg: 38,
                potassiumMg: 240,
                vitaminB1Mg: 0.18,
                vitaminB2Mg: 0.10
            ),
            ingredients: "Tam buğday unu, tereyağı, şeker, yumurta, tuz, kabartma tozu.",
            allergens: [.gluten, .dairy, .egg],
            additives: ["E322", "E500"],
            nutriScore: .c,
            novaGroup: .processed,
            verifiedLevel: .verified,
            confidenceScore: 0.92
        ),
        onConfirm: { _, _, _ in }
    )
    .environmentObject(DependencyContainer.preview())
}
