import SwiftData
import SwiftUI

struct AddWorkoutSheet: View {
    enum Mode: Equatable {
        case create
        case edit(WorkoutLog)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer

    private let mode: Mode

    @State private var type: WorkoutType
    @State private var date: Date
    @State private var durationMinutes: Double
    @State private var calories: Double
    @State private var distanceKm: Double?
    @State private var note: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didAutoEstimate = false

    init(mode: Mode = .create) {
        self.mode = mode
        switch mode {
        case .create:
            _type = State(initialValue: .running)
            _date = State(initialValue: Date())
            _durationMinutes = State(initialValue: 30)
            _calories = State(initialValue: 0)
            _distanceKm = State(initialValue: nil)
            _note = State(initialValue: "")
        case .edit(let log):
            _type = State(initialValue: log.type)
            _date = State(initialValue: log.date)
            _durationMinutes = State(initialValue: Double(log.durationMinutes))
            _calories = State(initialValue: Double(log.caloriesBurned))
            _distanceKm = State(initialValue: log.distanceKm)
            _note = State(initialValue: log.note ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        typeSection
                        dateAndDurationSection
                        caloriesSection
                        if type.supportsDistance {
                            distanceSection
                        }
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
                        Text("Tahmini kalori, MET (metabolik denge) değerine ve kilonun yaklaşık yüküne göredir. Apple Health ile bağlantı kurarsan otomatik veriler de listelenir.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle(isEditing ? "Egzersizi düzenle" : "Egzersiz ekle")
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
            .onChange(of: type) { _, _ in autoEstimateIfNeeded() }
            .onChange(of: durationMinutes) { _, _ in autoEstimateIfNeeded() }
            .onAppear { autoEstimateIfNeeded() }
        }
    }

    // MARK: - Sections
    private var typeSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(title: "Egzersiz tipi", subtitle: "MET değeri kalori tahmini için kullanılır")
                WorkoutTypePicker(selection: $type)
            }
        }
    }

    private var dateAndDurationSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Tarih & süre", subtitle: nil)
                DatePicker("Başlangıç", selection: $date, in: ...Date())
                    .datePickerStyle(.compact)
                NutritionInputField(
                    icon: "clock.fill",
                    title: "Süre",
                    unit: "dk",
                    tint: NuvyraColors.accent,
                    value: $durationMinutes,
                    allowsFraction: false,
                    range: 5...300
                )
            }
        }
    }

    private var caloriesSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(title: "Kalori", subtitle: "Tahmini değeri istediğin gibi düzenleyebilirsin")
                NutritionInputField(
                    icon: "flame.fill",
                    title: "Yakılan",
                    unit: "kcal",
                    tint: NuvyraColors.mutedCoral,
                    value: $calories,
                    allowsFraction: false,
                    range: 0...3_000
                )
                Text("Tahmin: \(estimateCalories()) kcal — istersen üzerine yaz.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var distanceSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(title: "Mesafe", subtitle: "Opsiyonel — boş bırakabilirsin")
                MeasurementInputField(
                    icon: "map",
                    title: "Mesafe",
                    unit: "km",
                    tint: NuvyraColors.softMint,
                    value: $distanceKm,
                    range: 0...200
                )
            }
        }
    }

    private var noteSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(title: "Not", subtitle: nil)
                TextField("Örn. tempo, antrenör notu", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
            }
        }
    }

    // MARK: - Derived
    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var canSave: Bool { durationMinutes >= 1 }

    private var profileWeight: Double {
        let userRepo = dependencies.userRepository(context: modelContext)
        return (try? userRepo.profile()?.weightKg) ?? 75
    }

    private func estimateCalories() -> Int {
        type.estimateCalories(durationMinutes: Int(durationMinutes), weightKg: profileWeight)
    }

    private func autoEstimateIfNeeded() {
        // Backfill calories with the MET estimate the first time the user lands here.
        // We don't overwrite once they've manually edited the value.
        guard !didAutoEstimate, calories == 0 else { return }
        calories = Double(estimateCalories())
        didAutoEstimate = true
    }

    // MARK: - Actions
    private func save() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        let snap = (type: type, date: date, minutes: Int(durationMinutes), kcal: Int(calories), km: distanceKm, noteValue: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines))
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let repo = dependencies.workoutRepository(context: modelContext)
                switch mode {
                case .create:
                    let log = WorkoutLog(
                        date: snap.date,
                        type: snap.type,
                        durationMinutes: snap.minutes,
                        caloriesBurned: snap.kcal,
                        distanceKm: snap.km,
                        note: snap.noteValue,
                        source: .manual
                    )
                    try repo.add(log)
                case .edit(let log):
                    log.date = snap.date
                    log.type = snap.type
                    log.durationMinutes = snap.minutes
                    log.caloriesBurned = snap.kcal
                    log.distanceKm = snap.km
                    log.note = snap.noteValue
                    try repo.update(log)
                }
                dependencies.haptics.mealLogged()
                dismiss()
            } catch {
                errorMessage = "Kayıt başarısız oldu. Tekrar dene."
            }
        }
    }

    private func delete(_ log: WorkoutLog) {
        Task { @MainActor in
            do {
                try dependencies.workoutRepository(context: modelContext).delete(id: log.id)
                dismiss()
            } catch {
                errorMessage = "Silinemedi."
            }
        }
    }
}

#if DEBUG
#Preview {
    AddWorkoutSheet()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
