import SwiftData
import SwiftUI

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer

    private let editingMeal: MealEntry?

    @State private var mealType: MealType
    @State private var name: String
    @State private var portionUnit: PortionUnit
    @State private var portionAmount: Double
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @State private var entryDate: Date
    @State private var isFavorite: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    init(defaultMealType: MealType = .breakfast) {
        self.editingMeal = nil
        _mealType = State(initialValue: defaultMealType)
        _name = State(initialValue: "")
        _portionUnit = State(initialValue: .portion)
        _portionAmount = State(initialValue: 1)
        _calories = State(initialValue: 350)
        _protein = State(initialValue: 20)
        _carbs = State(initialValue: 35)
        _fat = State(initialValue: 12)
        _entryDate = State(initialValue: Date())
        _isFavorite = State(initialValue: false)
    }

    init(editing meal: MealEntry) {
        self.editingMeal = meal
        _mealType = State(initialValue: meal.mealType)
        _name = State(initialValue: meal.name)
        let parsed = AddMealView.parsePortion(meal.portionDescription)
        _portionUnit = State(initialValue: parsed.unit)
        _portionAmount = State(initialValue: parsed.amount)
        _calories = State(initialValue: Double(meal.calories))
        _protein = State(initialValue: meal.protein ?? 0)
        _carbs = State(initialValue: meal.carbs ?? 0)
        _fat = State(initialValue: meal.fat ?? 0)
        _entryDate = State(initialValue: meal.date)
        _isFavorite = State(initialValue: meal.isFavorite)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        nameSection
                        mealTypeSection
                        portionSection
                        macrosSection
                        MacroPreviewCard(
                            calories: Int(calories),
                            protein: protein,
                            carbs: carbs,
                            fat: fat
                        )
                        dateSection
                        favoriteSection
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(NuvyraColors.mutedCoral)
                        }
                        ConfirmAddFoodButton(
                            title: editingMeal == nil ? "Öğünü kaydet" : "Değişiklikleri kaydet",
                            systemImage: "checkmark.circle.fill",
                            isEnabled: canSave,
                            isSaving: isSaving,
                            action: save
                        )
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle(editingMeal == nil ? "Öğün ekle" : "Öğünü düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Kapat") { dismiss() } }
            }
            .onAppear {
                // Defer focus until after the sheet's slide-in animation finishes,
                // otherwise the keyboard rises mid-presentation and the sheet drifts.
                guard editingMeal == nil else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    nameFocused = true
                }
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Yemek adı")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            TextField("Örn. Mercimek çorbası", text: $name)
                .focused($nameFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(NuvyraColors.card(scheme).opacity(0.85), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                        .stroke(nameFocused ? NuvyraColors.accent : NuvyraColors.accent.opacity(0.18), lineWidth: nameFocused ? 1.4 : 1)
                )
        }
    }

    private var mealTypeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Öğün tipi")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MealType.allCases) { type in
                        NuvyraChip(title: type.title, isSelected: type == mealType) {
                            mealType = type
                        }
                    }
                }
            }
        }
    }

    private var portionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Porsiyon")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            Picker("", selection: $portionUnit) {
                ForEach(PortionUnit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: portionUnit) { _, newValue in
                // Bridge the amount sensibly when switching unit (e.g., portion 1 → 100 g)
                if newValue == .gram, portionAmount < 5 { portionAmount = 100 }
                if newValue != .gram, portionAmount > 20 { portionAmount = 1 }
            }

            HStack(spacing: 10) {
                Stepper(value: $portionAmount, in: portionRange, step: portionStep) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(portionDisplayAmount)
                            .font(.system(.title2, design: .rounded).weight(.heavy))
                        Text(portionUnit.suffix)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(NuvyraColors.card(scheme).opacity(0.7), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
        }
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tahmini değerler")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)

            NutritionInputField(
                title: "Kalori",
                systemImage: "flame.fill",
                unitSuffix: "kcal",
                tint: NuvyraColors.mutedCoral,
                value: $calories,
                range: 0...3_000,
                step: 10
            )

            HStack(spacing: 8) {
                NutritionInputField(title: "Protein", systemImage: "bolt.heart", unitSuffix: "g", tint: NuvyraColors.mutedCoral, value: $protein, range: 0...300)
                NutritionInputField(title: "Karb", systemImage: "leaf", unitSuffix: "g", tint: NuvyraColors.paleLime, value: $carbs, range: 0...500)
                NutritionInputField(title: "Yağ", systemImage: "drop.triangle", unitSuffix: "g", tint: NuvyraColors.softSand, value: $fat, range: 0...300)
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tarih ve saat")
                .font(.caption.weight(.bold))
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .textCase(.uppercase)
            DatePicker(
                "",
                selection: $entryDate,
                in: ...Date.distantFuture,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var favoriteSection: some View {
        Toggle(isOn: $isFavorite) {
            Label("Favoriye ekle", systemImage: "star.fill")
                .font(.subheadline.weight(.semibold))
        }
        .tint(NuvyraColors.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NuvyraColors.card(scheme).opacity(0.7), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && portionAmount > 0
    }

    private var portionRange: ClosedRange<Double> {
        switch portionUnit {
        case .gram: return 5...2_000
        case .portion: return 0.5...10
        case .piece: return 1...20
        }
    }

    private var portionStep: Double {
        switch portionUnit {
        case .gram: return 5
        case .portion: return 0.5
        case .piece: return 1
        }
    }

    private var portionDisplayAmount: String {
        let intAmount = Int(portionAmount)
        if Double(intAmount) == portionAmount { return "\(intAmount)" }
        return String(format: "%.1f", portionAmount)
    }

    private var portionDescription: String {
        portionUnit.describe(amount: portionAmount)
    }

    private static func parsePortion(_ raw: String) -> (amount: Double, unit: PortionUnit) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased(with: Locale(identifier: "tr_TR"))
        let amountString = trimmed.split(separator: " ").first.map(String.init) ?? "1"
        let normalized = amountString.replacingOccurrences(of: ",", with: ".")
        let amount = Double(normalized) ?? 1
        if lower.contains(" g") || lower.hasSuffix("g") { return (amount, .gram) }
        if lower.contains("adet") { return (amount, .piece) }
        return (amount, .portion)
    }

    // MARK: - Save

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Yemek adı boş olamaz."
            return
        }
        isSaving = true
        errorMessage = nil
        let repository = dependencies.nutritionRepository(context: modelContext)
        do {
            if let meal = editingMeal {
                meal.name = trimmedName
                meal.mealType = mealType
                meal.calories = Int(calories)
                meal.protein = protein
                meal.carbs = carbs
                meal.fat = fat
                meal.portionDescription = portionDescription
                meal.isFavorite = isFavorite
                meal.date = entryDate
                meal.isEstimated = true
                try repository.update(meal)
                Task { await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "edit"])) }
            } else {
                let entry = MealEntry(
                    date: entryDate,
                    mealType: mealType,
                    name: trimmedName,
                    calories: Int(calories),
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    portionDescription: portionDescription,
                    isFavorite: isFavorite,
                    isVerifiedTurkishFood: false,
                    isEstimated: true
                )
                try repository.addMeal(entry)
                Task { await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "manual"])) }
            }
            dependencies.haptics.mealLogged()
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "Kaydedilemedi. Tekrar deneyebilir misin?"
        }
    }
}

#if DEBUG
private enum AddMealPreviewData {
    static let editingMeal: MealEntry = MealEntry(
        mealType: .dinner,
        name: "Izgara tavuk",
        calories: 360,
        protein: 48,
        carbs: 4,
        fat: 14,
        portionDescription: "1 porsiyon",
        isFavorite: true
    )
}

#Preview("Add") {
    AddMealView(defaultMealType: .lunch)
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}

#Preview("Edit") {
    AddMealView(editing: AddMealPreviewData.editingMeal)
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
