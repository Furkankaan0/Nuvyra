import SwiftUI

struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var name: String
    @State private var age: Int
    @State private var gender: Gender
    @State private var heightCm: Int
    @State private var weightKg: Int
    @State private var usesGoalWeight: Bool
    @State private var targetWeightKg: Int
    @State private var activityLevel: ActivityLevel
    @State private var goalType: GoalType
    @State private var goalPace: GoalPace

    let onSave: (String, NutritionGoalCalculationInput) -> Void

    init(profile: UserProfile, onSave: @escaping (String, NutritionGoalCalculationInput) -> Void) {
        let profileName = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        _name = State(initialValue: profileName == "Nuvyra" ? "" : profileName)
        _age = State(initialValue: profile.age)
        _gender = State(initialValue: profile.gender ?? .preferNotToSay)
        _heightCm = State(initialValue: Int(profile.heightCm.rounded()))
        _weightKg = State(initialValue: Int(profile.weightKg.rounded()))
        _usesGoalWeight = State(initialValue: profile.targetWeightKg != nil)
        _targetWeightKg = State(initialValue: Int((profile.targetWeightKg ?? profile.weightKg).rounded()))
        _activityLevel = State(initialValue: profile.activityLevel)
        _goalType = State(initialValue: profile.goalType)
        _goalPace = State(initialValue: profile.goalPace ?? .balanced)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        NuvyraSectionHeader(
                            title: "Profilini güncelle",
                            subtitle: "Kilo, aktivite veya hedef değiştiğinde Nuvyra hedeflerini yeniden hesaplar."
                        )
                        identityCard
                        bodyCard
                        goalCard
                        calculatedPreview
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        onSave(name, input)
                        dismiss()
                    }
                    .font(.headline.weight(.bold))
                }
            }
        }
    }

    private var identityCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Temel bilgiler")
                    .font(NuvyraTypography.section)
                TextField("Ad", text: $name)
                    .textFieldStyle(.roundedBorder)
                Picker("Cinsiyet", selection: $gender) {
                    ForEach(Gender.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                numberStepper(title: "Yaş", value: $age, range: 13...100, unit: "yaş")
            }
        }
    }

    private var bodyCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Vücut ölçüleri")
                    .font(NuvyraTypography.section)
                numberStepper(title: "Boy", value: $heightCm, range: 130...220, unit: "cm")
                numberStepper(title: "Kilo", value: $weightKg, range: 35...220, unit: "kg")
                Toggle("Hedef kilo kullan", isOn: $usesGoalWeight)
                    .tint(NuvyraColors.accent)
                if usesGoalWeight {
                    numberStepper(title: "Hedef kilo", value: $targetWeightKg, range: 35...220, unit: "kg")
                }
            }
        }
    }

    private var goalCard: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Ritim hedefi")
                    .font(NuvyraTypography.section)
                Picker("Hedef", selection: $goalType) {
                    ForEach(GoalType.allCases) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                .pickerStyle(.menu)
                Picker("Aktivite", selection: $activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.menu)
                if goalType.isPaceSensitive {
                    Picker("Tempo", selection: $goalPace) {
                        ForEach(GoalPace.allCases) { pace in
                            Text(pace.title).tag(pace)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var calculatedPreview: some View {
        let targets = NutritionGoalCalculator.calculate(for: input)
        return NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                Label("Yeni hedef önizlemesi", systemImage: "sparkles")
                    .font(NuvyraTypography.section)
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                HStack(spacing: NuvyraSpacing.sm) {
                    profileMetric("Kalori", "\(targets.dailyCalories)", "kcal")
                    profileMetric("Protein", "\(targets.proteinGrams)", "g")
                    profileMetric("Su", "\(targets.waterMl)", "ml")
                    profileMetric("Adım", "\(targets.stepTarget)", "")
                }
            }
        }
    }

    private var input: NutritionGoalCalculationInput {
        NutritionGoalCalculationInput(
            age: age,
            gender: gender,
            heightCm: Double(heightCm),
            weightKg: Double(weightKg),
            targetWeightKg: usesGoalWeight ? Double(targetWeightKg) : nil,
            activityLevel: activityLevel,
            goalType: goalType,
            goalPace: goalPace
        )
    }

    private func numberStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NuvyraColors.accent)
            }
        }
    }

    private func profileMetric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(unit.isEmpty ? value : "\(value) \(unit)")
                .font(.footnote.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(NuvyraColors.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }
}
