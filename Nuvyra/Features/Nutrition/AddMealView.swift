import SwiftData
import SwiftUI

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @State private var mealType: MealType
    @State private var name = ""
    @State private var calories = 350
    @State private var protein = 20
    @State private var carbs = 35
    @State private var fat = 12
    @State private var portion = "1 porsiyon"
    @State private var isFavorite = false

    init(defaultMealType: MealType = .breakfast) {
        _mealType = State(initialValue: defaultMealType)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                Form {
                    Section("Öğün") {
                        Picker("Öğün tipi", selection: $mealType) {
                            ForEach(MealType.allCases) { type in Text(type.title).tag(type) }
                        }
                        TextField("Yemek adı", text: $name)
                        TextField("Porsiyon", text: $portion)
                    }
                    Section("Tahmini değerler") {
                        Stepper("Kalori: \(calories) kcal", value: $calories, in: 0...2_500, step: 10)
                        Stepper("Protein: \(protein) g", value: $protein, in: 0...200)
                        Stepper("Karbonhidrat: \(carbs) g", value: $carbs, in: 0...300)
                        Stepper("Yağ: \(fat) g", value: $fat, in: 0...200)
                        Toggle("Favoriye ekle", isOn: $isFavorite)
                    }
                    Section {
                        Text("Kalori değerleri tahminidir. Kendi porsiyonuna göre düzenleyebilirsin.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Öğün ekle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }

    private func save() {
        let meal = MealEntry(
            mealType: mealType,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: calories,
            protein: Double(protein),
            carbs: Double(carbs),
            fat: Double(fat),
            portionDescription: portion,
            isFavorite: isFavorite,
            isVerifiedTurkishFood: false,
            isEstimated: true
        )
        do {
            try dependencies.nutritionRepository(context: modelContext).addMeal(meal)
            Task { await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "manual"])) }
            dismiss()
        } catch {}
    }
}
