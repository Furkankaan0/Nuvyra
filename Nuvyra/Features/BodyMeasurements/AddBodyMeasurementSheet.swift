import SwiftData
import SwiftUI

struct AddBodyMeasurementSheet: View {
    enum Mode: Equatable {
        case create
        case edit(WeightLog)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer

    private let mode: Mode

    @State private var date: Date
    @State private var weightKg: Double
    @State private var waist: Double?
    @State private var hip: Double?
    @State private var chest: Double?
    @State private var shoulder: Double?
    @State private var neck: Double?
    @State private var bicep: Double?
    @State private var thigh: Double?
    @State private var bodyFat: Double?
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(mode: Mode = .create, prefilledWeightKg: Double? = nil) {
        self.mode = mode
        switch mode {
        case .create:
            _date = State(initialValue: Date())
            _weightKg = State(initialValue: prefilledWeightKg ?? 75)
            _waist = State(initialValue: nil)
            _hip = State(initialValue: nil)
            _chest = State(initialValue: nil)
            _shoulder = State(initialValue: nil)
            _neck = State(initialValue: nil)
            _bicep = State(initialValue: nil)
            _thigh = State(initialValue: nil)
            _bodyFat = State(initialValue: nil)
        case .edit(let log):
            _date = State(initialValue: log.date)
            _weightKg = State(initialValue: log.weightKg)
            _waist = State(initialValue: log.waistCm)
            _hip = State(initialValue: log.hipCm)
            _chest = State(initialValue: log.chestCm)
            _shoulder = State(initialValue: log.shoulderCm)
            _neck = State(initialValue: log.neckCm)
            _bicep = State(initialValue: log.bicepCm)
            _thigh = State(initialValue: log.thighCm)
            _bodyFat = State(initialValue: log.bodyFatPercent)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        identitySection
                        weightSection
                        circumferenceSection
                        bodyFatSection
                        noteSection
                        if let errorMessage {
                            Text(errorMessage)
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(NuvyraColors.mutedCoral)
                        }
                        ConfirmAddFoodButton(
                            title: isEditing ? "Değişiklikleri kaydet" : "Kaydet",
                            systemImage: isEditing ? "pencil" : "checkmark",
                            isLoading: isSaving,
                            isEnabled: canSave,
                            action: save
                        )
                        Text("Vücut ölçüleri ipucu: tutarlı bir saatte (örn. sabah aç karna), aynı koşulda ölç. Değerler bilgilendirme amaçlıdır.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle(isEditing ? "Ölçümü düzenle" : "Vücut ölçüsü ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                if isEditing, case .edit(let log) = mode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            delete(log)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Sections
    private var identitySection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(title: "Tarih", subtitle: "Hangi gün için kayıt eklendi")
                DatePicker("Tarih", selection: $date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
        }
    }

    private var weightSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Kilo", subtitle: "Birincil takip ekseni")
                NutritionInputField(
                    icon: "scalemass",
                    title: "Kilo",
                    unit: "kg",
                    tint: NuvyraColors.accent,
                    value: $weightKg,
                    allowsFraction: true,
                    range: 30...250
                )
            }
        }
    }

    private var circumferenceSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Çevre ölçüleri", subtitle: "İstediğin alanı doldur, boş bıraktıkların önceki değerini korur")
                MeasurementInputField(icon: "ruler", title: "Bel", unit: "cm", value: $waist, range: 30...200)
                MeasurementInputField(icon: "ruler", title: "Kalça", unit: "cm", value: $hip, range: 30...200)
                MeasurementInputField(icon: "ruler", title: "Göğüs", unit: "cm", value: $chest, range: 30...200)
                MeasurementInputField(icon: "ruler", title: "Omuz", unit: "cm", value: $shoulder, range: 30...200)
                MeasurementInputField(icon: "ruler", title: "Boyun", unit: "cm", value: $neck, range: 20...80)
                MeasurementInputField(icon: "ruler", title: "Pazı", unit: "cm", value: $bicep, range: 15...80)
                MeasurementInputField(icon: "ruler", title: "Uyluk", unit: "cm", value: $thigh, range: 25...100)
            }
        }
    }

    private var bodyFatSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Vücut yağ yüzdesi", subtitle: "Cihaz veya tahmin yöntemiyle ölçtüysen ekle")
                MeasurementInputField(
                    icon: "drop.fill",
                    title: "Vücut yağ",
                    unit: "%",
                    tint: NuvyraColors.mutedCoral,
                    value: $bodyFat,
                    range: 3...60
                )
            }
        }
    }

    private var noteSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(title: "Not", subtitle: "Opsiyonel kısa açıklama")
                TextField("Örn. sabah, antrenman öncesi", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
            }
        }
    }

    // MARK: - Derived
    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var canSave: Bool { weightKg > 0 }

    private var snapshot: BodyMeasurementSnapshot {
        BodyMeasurementSnapshot(
            date: date,
            weightKg: weightKg > 0 ? weightKg : nil,
            waistCm: waist,
            hipCm: hip,
            chestCm: chest,
            shoulderCm: shoulder,
            neckCm: neck,
            bicepCm: bicep,
            thighCm: thigh,
            bodyFatPercent: bodyFat,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Actions
    private func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        let snap = snapshot
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try dependencies.weightRepository(context: modelContext).saveBodyMeasurement(snap)
                dependencies.haptics.mealLogged()
                dismiss()
            } catch {
                errorMessage = "Kayıt başarısız oldu. Tekrar dene."
            }
        }
    }

    private func delete(_ log: WeightLog) {
        Task { @MainActor in
            do {
                try dependencies.weightRepository(context: modelContext).deleteMeasurement(log)
                dismiss()
            } catch {
                errorMessage = "Ölçüm silinemedi."
            }
        }
    }
}

#if DEBUG
#Preview {
    AddBodyMeasurementSheet()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
