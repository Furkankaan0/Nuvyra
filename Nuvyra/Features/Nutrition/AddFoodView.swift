import SwiftData
import SwiftUI

/// Premium add / edit food sheet — supports grams / portion / piece units, date,
/// meal type, live macro preview and toggleable favourite. Used by Dashboard,
/// Nutrition and the Today-meals card.
struct AddFoodView: View {
    enum Mode: Equatable {
        case create(defaultMealType: MealType)
        case edit(MealEntry)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer

    private let mode: Mode

    @State private var name: String
    @State private var mealType: MealType
    @State private var unit: PortionUnit
    @State private var quantity: Double
    @State private var date: Date
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var isFavorite: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let type):
            _name = State(initialValue: "")
            _mealType = State(initialValue: type)
            _unit = State(initialValue: .portion)
            _quantity = State(initialValue: 1)
            _date = State(initialValue: Date())
            _calories = State(initialValue: 350)
            _protein = State(initialValue: 20)
            _carbs = State(initialValue: 35)
            _fat = State(initialValue: 12)
            _isFavorite = State(initialValue: false)
        case .edit(let meal):
            _name = State(initialValue: meal.name)
            _mealType = State(initialValue: meal.mealType)
            _unit = State(initialValue: .portion)
            _quantity = State(initialValue: 1)
            _date = State(initialValue: meal.date)
            _calories = State(initialValue: Double(meal.calories))
            _protein = State(initialValue: meal.protein ?? 0)
            _carbs = State(initialValue: meal.carbs ?? 0)
            _fat = State(initialValue: meal.fat ?? 0)
            _isFavorite = State(initialValue: meal.isFavorite)
        }
    }

    // MARK: - Convenience initialisers
    init(defaultMealType: MealType = .breakfast) {
        self.init(mode: .create(defaultMealType: defaultMealType))
    }

    init(editing meal: MealEntry) {
        self.init(mode: .edit(meal))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        identitySection
                        portionSection
                        macroSection
                        MacroPreviewCard(values: previewValues)
                        if let errorMessage {
                            Text(errorMessage)
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(NuvyraColors.mutedCoral)
                        }
                        ConfirmAddFoodButton(
                            title: confirmTitle,
                            systemImage: isEditing ? "pencil" : "checkmark",
                            isLoading: isSaving,
                            isEnabled: canSave,
                            action: save
                        )
                        Text("Kalori ve makro değerleri tahminidir; kendi porsiyonuna göre düzenleyebilirsin.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle(isEditing ? "Öğünü düzenle" : "Yemek ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                if isEditing, case .edit(let meal) = mode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            delete(meal)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Sil")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Sections
    private var identitySection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Yemek", subtitle: "Ad, öğün ve tarih")
                TextField("Yemek adı", text: $name)
                    .font(.title3.weight(.semibold))
                    .padding(.vertical, 6)
                Picker("Öğün tipi", selection: $mealType) {
                    ForEach(MealType.allCases) { type in
                        Label(type.title, systemImage: type.systemImage).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                DatePicker("Tarih", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .font(.subheadline)
                Toggle(isOn: $isFavorite) {
                    Label("Favoriye ekle", systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(NuvyraColors.accent)
            }
        }
    }

    private var portionSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Porsiyon", subtitle: "Birim ve miktar")
                Picker("Birim", selection: $unit) {
                    ForEach(PortionUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: unit) { _, newValue in
                    quantity = newValue.defaultQuantity
                }
                NutritionInputField(
                    icon: "scalemass",
                    title: "Miktar",
                    unit: unit.shortLabel,
                    value: $quantity,
                    allowsFraction: unit != .piece,
                    range: 0...5_000
                )
            }
        }
    }

    private var macroSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Besin değerleri", subtitle: "Tahmini değerleri düzenleyebilirsin")
                NutritionInputField(icon: "flame.fill", title: "Kalori", unit: "kcal", tint: NuvyraColors.mutedCoral, value: $calories, allowsFraction: false, range: 0...4_000)
                NutritionInputField(icon: "bolt.heart", title: "Protein", unit: "g", tint: NuvyraColors.mutedCoral, value: $protein, range: 0...400)
                NutritionInputField(icon: "leaf", title: "Karbonhidrat", unit: "g", tint: NuvyraColors.paleLime, value: $carbs, range: 0...500)
                NutritionInputField(icon: "drop.circle", title: "Yağ", unit: "g", tint: NuvyraColors.softSand, value: $fat, range: 0...300)
            }
        }
    }

    // MARK: - Derived state
    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var confirmTitle: String { isEditing ? "Değişiklikleri kaydet" : "Kaydet" }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && quantity > 0 }

    private var previewValues: NutritionValues {
        let multiplier: Double
        switch unit {
        case .grams: multiplier = quantity / 100  // base nutrition values are per 100 g
        case .portion: multiplier = quantity
        case .piece: multiplier = quantity
        }
        return NutritionValues(
            calories: Int((calories * multiplier).rounded()),
            protein: protein * multiplier,
            carbs: carbs * multiplier,
            fat: fat * multiplier
        )
    }

    private var portionDescription: String {
        switch unit {
        case .grams: return "\(quantity.cleanFormatted) g"
        case .portion: return "\(quantity.cleanFormatted) porsiyon"
        case .piece: return "\(Int(quantity)) adet"
        }
    }

    // MARK: - Actions
    private func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        let values = previewValues
        let portion = portionDescription
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let repository = dependencies.nutritionRepository(context: modelContext)
                switch mode {
                case .create:
                    let meal = MealEntry(
                        date: date,
                        mealType: mealType,
                        name: trimmedName,
                        calories: values.calories,
                        protein: values.protein,
                        carbs: values.carbs,
                        fat: values.fat,
                        portionDescription: portion,
                        isFavorite: isFavorite,
                        isVerifiedTurkishFood: false,
                        isEstimated: true
                    )
                    try repository.addMeal(meal)
                    await dependencies.healthService.saveNutrition(for: meal)
                    dependencies.haptics.mealLogged()
                    await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "add_food_view"]))
                case .edit(let meal):
                    try repository.updateMeal(
                        meal,
                        with: values,
                        name: trimmedName,
                        portion: portion,
                        mealType: mealType,
                        date: date,
                        isFavorite: isFavorite
                    )
                    await dependencies.healthService.saveNutrition(for: meal)
                }
                dismiss()
            } catch {
                errorMessage = "Kayıt başarısız oldu. Tekrar dene."
            }
        }
    }

    private func delete(_ meal: MealEntry) {
        Task { @MainActor in
            do {
                try dependencies.nutritionRepository(context: modelContext).deleteMeal(meal)
                dismiss()
            } catch {
                errorMessage = "Öğün silinemedi."
            }
        }
    }
}

#if DEBUG
#Preview("Create") {
    AddFoodView(defaultMealType: .lunch)
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
