import SwiftUI

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var calories: Int
    @State private var waterMl: Int
    @State private var steps: Int
    let onSave: (Int, Int, Int) -> Void

    init(profile: UserProfile, onSave: @escaping (Int, Int, Int) -> Void) {
        _calories = State(initialValue: profile.dailyCalorieTarget)
        _waterMl = State(initialValue: profile.dailyWaterTargetMl)
        _steps = State(initialValue: profile.dailyStepTarget)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        NuvyraSectionHeader(
                            title: "Günlük hedefleri düzenle",
                            subtitle: "Hedefler baskı değil, ritmini okumak için nazik referanslardır."
                        )
                        goalPicker(title: "Kalori", value: $calories, range: 1_000...5_000, step: 25, unit: "kcal", icon: "flame.fill")
                        goalPicker(title: "Su", value: $waterMl, range: 1_000...5_000, step: 50, unit: "ml", icon: "drop.fill")
                        goalPicker(title: "Adım", value: $steps, range: 2_000...20_000, step: 250, unit: "adım", icon: "figure.walk")
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle("Hedefler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        onSave(calories, waterMl, steps)
                        dismiss()
                    }
                    .font(.headline.weight(.bold))
                }
            }
        }
    }

    private func goalPicker(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        icon: String
    ) -> some View {
        let values = Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
        return NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Label(title, systemImage: icon)
                    .font(NuvyraTypography.section)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value.wrappedValue.formatted())
                        .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                        .foregroundStyle(NuvyraColors.primaryText(scheme))
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }

                Picker(title, selection: value) {
                    ForEach(values, id: \.self) { item in
                        Text("\(item.formatted()) \(unit)").tag(item)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 122)
                .clipped()
            }
        }
    }
}
