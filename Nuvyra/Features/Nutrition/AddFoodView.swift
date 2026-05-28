import SwiftData
import SwiftUI
import PhotosUI
import UIKit

/// Premium add / edit food sheet — supports grams / portion / piece units, date,
/// meal type, live macro preview and toggleable favourite. Used by Dashboard,
/// Nutrition and the Today-meals card.
struct AddFoodView: View {
    enum Mode {
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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isLoadingPhoto = false
    @State private var showingCameraCapture = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var lookupResults: [FoodSearchResult] = []
    @State private var selectedLookupResult: FoodSearchResult?
    @State private var isLookingUpNutrition = false
    @State private var lookupMessage: String?
    @State private var lookupTask: Task<Void, Never>?
    @State private var showNutritionAdjustments: Bool

    // Micronutrients (optional)
    @State private var fiber: Double?
    @State private var sodium: Double?
    @State private var sugar: Double?
    @State private var saturatedFat: Double?
    @State private var showMicros: Bool = false

    private let remoteFoodSearchService = RemoteFoodSearchService()
    private let localFoodSearchService = SQLiteFTSFoodSearchService.shared

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let type):
            _name = State(initialValue: "")
            _mealType = State(initialValue: type)
            _unit = State(initialValue: .grams)
            _quantity = State(initialValue: 100)
            _date = State(initialValue: Date())
            _calories = State(initialValue: 0)
            _protein = State(initialValue: 0)
            _carbs = State(initialValue: 0)
            _fat = State(initialValue: 0)
            _isFavorite = State(initialValue: false)
            _photoData = State(initialValue: nil)
            _lookupResults = State(initialValue: [])
            _selectedLookupResult = State(initialValue: nil)
            _isLookingUpNutrition = State(initialValue: false)
            _lookupMessage = State(initialValue: nil)
            _lookupTask = State(initialValue: nil)
            _showNutritionAdjustments = State(initialValue: false)
            _fiber = State(initialValue: nil)
            _sodium = State(initialValue: nil)
            _sugar = State(initialValue: nil)
            _saturatedFat = State(initialValue: nil)
            _showMicros = State(initialValue: false)
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
            _photoData = State(initialValue: meal.photoData)
            _lookupResults = State(initialValue: [])
            _selectedLookupResult = State(initialValue: nil)
            _isLookingUpNutrition = State(initialValue: false)
            _lookupMessage = State(initialValue: nil)
            _lookupTask = State(initialValue: nil)
            _showNutritionAdjustments = State(initialValue: true)
            _fiber = State(initialValue: meal.fiberGrams)
            _sodium = State(initialValue: meal.sodiumMg)
            _sugar = State(initialValue: meal.sugarGrams)
            _saturatedFat = State(initialValue: meal.saturatedFatGrams)
            _showMicros = State(initialValue: meal.hasMicronutrients)
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
                        nutritionLookupSection
                        photoSection
                        portionSection
                        if showNutritionAdjustments {
                            macroSection
                            microSection
                        }
                        if hasNutritionValues {
                            MacroPreviewCard(values: previewValues)
                        }
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
                        Text(footerText)
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
            .onDisappear {
                lookupTask?.cancel()
            }
            .task(id: selectedPhotoItem) {
                await loadSelectedPhoto()
            }
            .sheet(isPresented: $showingCameraCapture) {
                MealCameraCaptureView(photoData: $photoData)
                    .ignoresSafeArea()
            }
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
                    .onChange(of: name) { _, _ in
                        guard !isEditing else { return }
                        scheduleNutritionLookup()
                    }
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

    private var nutritionLookupSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(
                    title: "Besin değerleri",
                    subtitle: isEditing ? "Kaydedilmiş değerleri düzenleyebilirsin" : "Ürün adını yazınca Nuvyra değerleri bulur"
                )

                if trimmedName.count < 3, !isEditing {
                    Label("Ürün, yemek veya marka adını yaz.", systemImage: "magnifyingglass")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }

                if isLookingUpNutrition {
                    HStack(spacing: NuvyraSpacing.sm) {
                        ProgressView()
                        Text("Besin verileri aranıyor...")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let lookupMessage {
                    Label(lookupMessage, systemImage: "exclamationmark.circle")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(NuvyraColors.mutedCoral)
                }

                if let selectedLookupResult {
                    AutoNutritionResultRow(result: selectedLookupResult, isSelected: true)
                }

                let suggestions = lookupResults.filter { $0.id != selectedLookupResult?.id }.prefix(4)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                        Text("Benzer sonuçlar")
                            .font(NuvyraTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(Array(suggestions), id: \.id) { result in
                            Button {
                                applyNutritionResult(result)
                            } label: {
                                AutoNutritionResultRow(result: result, isSelected: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNutritionAdjustments.toggle()
                    }
                } label: {
                    Label(showNutritionAdjustments ? "Değer düzenlemeyi gizle" : "Değerleri düzelt", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(NuvyraColors.accent)
                .accessibilityLabel(showNutritionAdjustments ? "Besin değeri düzenleme alanını gizle" : "Besin değerlerini elle düzelt")
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

    private var photoSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                NuvyraSectionHeader(
                    title: "Öğün fotoğrafı",
                    subtitle: "İstersen bu kaydı görsel bir hafızaya dönüştür."
                )

                HStack(alignment: .center, spacing: NuvyraSpacing.md) {
                    MealPhotoThumbnail(
                        data: photoData,
                        fallbackSystemImage: "camera.macro",
                        size: 84,
                        cornerRadius: NuvyraRadius.lg
                    )

                    VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                        Text(photoData == nil ? "Fotoğraf ekle" : "Fotoğraf hazır")
                            .font(.headline.weight(.semibold))
                        Text(photoData == nil ? "Galeri veya kamera ile öğününü kaydet." : "Bu görsel sadece cihazındaki yemek kaydında saklanır.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: NuvyraSpacing.sm) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("Galeri", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showingCameraCapture = true
                                } label: {
                                    Label("Kamera", systemImage: "camera")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        if isLoadingPhoto {
                            ProgressView("Fotoğraf hazırlanıyor")
                                .font(NuvyraTypography.caption)
                        }
                    }
                }

                if photoData != nil {
                    Button(role: .destructive) {
                        selectedPhotoItem = nil
                        photoData = nil
                    } label: {
                        Label("Fotoğrafı kaldır", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
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

    private var microSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showMicros.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mikro besinler")
                                .font(NuvyraTypography.section)
                            Text(showMicros ? "Boş bıraktıkların önceki kayıt değerlerini korur" : "İsteğe bağlı: lif, sodyum, şeker, doymuş yağ")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: showMicros ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showMicros {
                    MeasurementInputField(icon: "leaf.arrow.circlepath", title: "Lif", unit: "g", value: $fiber, range: 0...100)
                    MeasurementInputField(icon: "globe", title: "Sodyum", unit: "mg", tint: NuvyraColors.mutedCoral, value: $sodium, range: 0...5_000)
                    MeasurementInputField(icon: "cube.fill", title: "Şeker", unit: "g", tint: NuvyraColors.softSand, value: $sugar, range: 0...300)
                    MeasurementInputField(icon: "drop.fill", title: "Doymuş yağ", unit: "g", tint: NuvyraColors.mutedCoral, value: $saturatedFat, range: 0...100)
                }
            }
        }
    }

    // MARK: - Derived state
    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var confirmTitle: String {
        if isEditing { return "Değişiklikleri kaydet" }
        if isLookingUpNutrition { return "Besin aranıyor" }
        return hasNutritionValues ? "Öğünü kaydet" : "Besin değerini bekliyor"
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var resolvedFoodName: String {
        selectedLookupResult?.name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? trimmedName
    }
    private var hasNutritionValues: Bool { calories > 0 || protein > 0 || carbs > 0 || fat > 0 }
    private var canSave: Bool { !trimmedName.isEmpty && quantity > 0 && hasNutritionValues && !isLookingUpNutrition }
    private var footerText: String {
        if isEditing {
            return "Değerleri sadece gerekirse düzelt; kayıt porsiyonuna göre hesaplanır."
        }
        if hasNutritionValues {
            return "Besin değerleri seçilen kaynaktan otomatik geldi; porsiyon miktarını değiştirince hesap güncellenir."
        }
        return "Yalnızca ürün veya yemek adını yaz; kalori ve makrolar otomatik gelsin."
    }

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
            fat: fat * multiplier,
            fiber: (fiber ?? 0) * multiplier,
            sodium: (sodium ?? 0) * multiplier,
            sugar: (sugar ?? 0) * multiplier,
            saturatedFat: (saturatedFat ?? 0) * multiplier
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
    private func scheduleNutritionLookup() {
        lookupTask?.cancel()
        lookupMessage = nil
        selectedLookupResult = nil
        lookupResults = []
        resetNutritionValues()

        let query = trimmedName
        guard query.count >= 3 else {
            isLookingUpNutrition = false
            return
        }

        isLookingUpNutrition = true
        let selectedMealType = mealType
        let foodIntelligenceService = dependencies.foodIntelligenceService
        lookupTask = Task { [remoteFoodSearchService, localFoodSearchService, foodIntelligenceService] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }

            let remoteResults = await remoteFoodSearchService.search(query, limit: 8)
            let estimatedMeals = (try? await foodIntelligenceService.estimateFromText(query, mealType: selectedMealType)) ?? []
            let estimatedResults = Self.makeEstimatedLookupResults(estimatedMeals)
            let localResults: [FoodSearchResult]
            if remoteResults.isEmpty && estimatedResults.isEmpty {
                localResults = (try? await localFoodSearchService.search(query, limit: 4)) ?? []
            } else {
                localResults = []
            }

            guard !Task.isCancelled else { return }
            let results = Self.mergeLookupResults(remoteResults + estimatedResults + localResults)

            await MainActor.run {
                lookupResults = results
                isLookingUpNutrition = false
                if let first = results.first {
                    applyNutritionResult(first)
                } else {
                    lookupMessage = "Besin değeri bulunamadı. Marka veya daha net ürün adı dene."
                }
            }
        }
    }

    private func applyNutritionResult(_ result: FoodSearchResult) {
        selectedLookupResult = result
        calories = Double(result.calories)
        protein = result.protein
        carbs = result.carbs
        fat = result.fat
        fiber = result.fiber
        sodium = nil
        sugar = nil
        saturatedFat = nil
        lookupMessage = nil

        if result.source == .cache || result.source == .estimated {
            unit = .portion
            quantity = 1
        } else {
            unit = .grams
            quantity = 100
        }
    }

    private func resetNutritionValues() {
        guard !isEditing else { return }
        calories = 0
        protein = 0
        carbs = 0
        fat = 0
        fiber = nil
        sodium = nil
        sugar = nil
        saturatedFat = nil
    }

    private static func mergeLookupResults(_ results: [FoodSearchResult]) -> [FoodSearchResult] {
        var seen = Set<String>()
        var merged: [FoodSearchResult] = []

        for result in results {
            let key = result.externalID?.lowercased()
                ?? "\(result.source.rawValue):\(FoodSearchNormalizer.normalized(result.name)):\(result.brand ?? "")"
            guard seen.insert(key).inserted else { continue }
            merged.append(result)
        }

        return merged
    }

    private static func makeEstimatedLookupResults(_ meals: [EstimatedMealResult]) -> [FoodSearchResult] {
        meals.map { meal in
            let externalID = "estimated:\(FoodSearchNormalizer.normalized(meal.name)):\(meal.portion)"
            return FoodSearchResult(
                id: FoodSearchResult.remoteID(source: .estimated, externalID: externalID),
                name: meal.name,
                brand: nil,
                calories: meal.calories,
                servingDescription: meal.portion,
                score: 0,
                protein: meal.protein,
                carbs: meal.carbs,
                fat: meal.fat,
                source: .estimated,
                externalID: externalID,
                isVerified: false
            )
        }
    }

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
                        name: resolvedFoodName,
                        calories: values.calories,
                        protein: values.protein,
                        carbs: values.carbs,
                        fat: values.fat,
                        portionDescription: portion,
                        isFavorite: isFavorite,
                        isVerifiedTurkishFood: selectedLookupResult?.source == .openFoodFacts || selectedLookupResult?.source == .fatSecret,
                        isEstimated: !(selectedLookupResult?.isVerified ?? false),
                        fiberGrams: values.fiber > 0 ? values.fiber : nil,
                        sodiumMg: values.sodium > 0 ? values.sodium : nil,
                        sugarGrams: values.sugar > 0 ? values.sugar : nil,
                        saturatedFatGrams: values.saturatedFat > 0 ? values.saturatedFat : nil,
                        photoData: photoData
                    )
                    try repository.addMeal(meal)
                    await dependencies.healthService.saveNutrition(for: meal)
                    dependencies.haptics.mealLogged()
                    await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "add_food_view", "provider": selectedLookupResult?.source.rawValue ?? "manual_adjusted"]))
                case .edit(let meal):
                    try repository.updateMeal(
                        meal,
                        with: values,
                        name: trimmedName,
                        portion: portion,
                        mealType: mealType,
                        date: date,
                        isFavorite: isFavorite,
                        photoData: photoData
                    )
                    await dependencies.healthService.saveNutrition(for: meal)
                }
                if Calendar.nuvyra.isDateInToday(date) {
                    await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(context: modelContext, healthService: dependencies.healthService)
                }
                dismiss()
            } catch {
                errorMessage = "Kayıt başarısız oldu. Tekrar dene."
            }
        }
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self) else { return }
            photoData = compressPhotoData(data)
        } catch {
            errorMessage = "Fotoğraf eklenemedi. Daha küçük bir görsel deneyebilirsin."
        }
    }

    private func compressPhotoData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let maxSide: CGFloat = 1_400
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / max(longestSide, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.72) ?? data
    }

    private func delete(_ meal: MealEntry) {
        Task { @MainActor in
            do {
                try dependencies.nutritionRepository(context: modelContext).deleteMeal(meal)
                if Calendar.nuvyra.isDateInToday(meal.date) {
                    await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(context: modelContext, healthService: dependencies.healthService)
                }
                dismiss()
            } catch {
                errorMessage = "Öğün silinemedi."
            }
        }
    }
}

private struct AutoNutritionResultRow: View {
    let result: FoodSearchResult
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.md) {
            Image(systemName: isSelected ? "checkmark.seal.fill" : "fork.knife.circle")
                .font(.title3)
                .foregroundStyle(isSelected ? NuvyraColors.accent : .secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: NuvyraSpacing.xs) {
                    if let brand = result.brand, !brand.isEmpty {
                        Text(brand)
                    }
                    Text(result.source.displayLabel)
                    Text(result.servingDescription)
                }
                .font(NuvyraTypography.caption)
                .foregroundStyle(.secondary)

                Text("P \(result.protein.cleanMacro)g  C \(result.carbs.cleanMacro)g  Y \(result.fat.cleanMacro)g")
                    .font(NuvyraTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: NuvyraSpacing.sm)

            Text("\(result.calories) kcal")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(NuvyraColors.accent)
        }
        .padding(NuvyraSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous)
                .fill(isSelected ? NuvyraColors.accent.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.name), \(result.calories) kalori, protein \(result.protein.cleanMacro) gram, karbonhidrat \(result.carbs.cleanMacro) gram, yağ \(result.fat.cleanMacro) gram")
    }
}

private extension Double {
    var cleanMacro: String {
        let rounded = (self * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))"
        }
        return String(format: "%.1f", rounded)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if DEBUG
#Preview("Create") {
    AddFoodView(defaultMealType: .lunch)
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
