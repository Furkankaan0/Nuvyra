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
    @EnvironmentObject private var toastCenter: NuvyraToastCenter

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
    @State private var lookupResults: [FoodItem] = []
    @State private var selectedLookupItem: FoodItem?
    @State private var selectedLookupServing: ServingSize?
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

    // Phase 11 — rich manual entry (kategori + çoklu porsiyon)
    @State private var manualCategory: FoodCategory?
    @State private var manualServings: [ServingSize] = []
    @State private var showManualDetails: Bool = false

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
            _selectedLookupItem = State(initialValue: nil)
            _selectedLookupServing = State(initialValue: nil)
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
            _selectedLookupItem = State(initialValue: nil)
            _selectedLookupServing = State(initialValue: nil)
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
                        if showsManualDetails {
                            manualDetailsSection
                        }
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
            .navigationTitle(String(localized: isEditing ? "addFood.title.edit" : "addFood.title.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "addFood.action.close")) { dismiss() }
                }
                if isEditing, case .edit(let meal) = mode {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            delete(meal)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(String(localized: "addFood.action.delete"))
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

                if let selectedLookupItem {
                    AutoNutritionResultRow(item: selectedLookupItem, isSelected: true)
                }

                let suggestions = lookupResults.filter { $0.id != selectedLookupItem?.id }.prefix(4)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                        Text("Benzer sonuçlar")
                            .font(NuvyraTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(Array(suggestions), id: \.id) { item in
                            Button {
                                applyNutritionItem(item)
                            } label: {
                                AutoNutritionResultRow(item: item, isSelected: false)
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

    /// Phase 11 — Sadece manuel oluşturma akışında (.create mode + lookup
    /// seçili değil) görünür. Kullanıcı kategori atayarak ve çoklu porsiyon
    /// tanımlayarak user-created `FoodItem`'ı zenginleştirir; sonraki
    /// aramalarda kataloğunda doğru ServingSize seçici ile döner.
    private var manualDetailsSection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showManualDetails.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Detaylı manuel ekleme")
                                .font(NuvyraTypography.section)
                            Text(showManualDetails
                                 ? "Kategori ve porsiyon listesini düzenle"
                                 : "Kategori ve kendi porsiyonlarını tanımla")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: showManualDetails ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showManualDetails {
                    categoryPicker
                    Divider()
                    Text("Porsiyonlar")
                        .font(NuvyraTypography.section)
                    Text("Eklediğin porsiyonlar arama sonuçlarında çıkar; ⭐ ile varsayılanı seç.")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                    ManualServingEditor(servings: $manualServings)
                }
            }
        }
    }

    private var categoryPicker: some View {
        HStack {
            Text("Kategori")
                .font(NuvyraTypography.section)
            Spacer()
            Menu {
                ForEach(FoodCategory.allCases) { category in
                    Button {
                        manualCategory = category
                    } label: {
                        Label(category.displayLabelTR, systemImage: category.symbolName)
                    }
                }
                if manualCategory != nil {
                    Divider()
                    Button(role: .destructive) {
                        manualCategory = nil
                    } label: {
                        Label("Kategori seçimini kaldır", systemImage: "xmark.circle")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: manualCategory?.symbolName ?? "square.grid.2x2")
                        .foregroundStyle(NuvyraColors.accent)
                    Text(manualCategory?.displayLabelTR ?? "Kategori seç")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
            }
        }
    }

    // MARK: - Derived state
    private var isEditing: Bool { if case .edit = mode { return true } else { return false } }
    private var showsManualDetails: Bool { !isEditing && selectedLookupItem == nil }
    private var confirmTitle: String {
        if isEditing { return "Değişiklikleri kaydet" }
        if isLookingUpNutrition { return "Besin aranıyor" }
        return hasNutritionValues ? "Öğünü kaydet" : "Besin değerini bekliyor"
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var resolvedFoodName: String {
        selectedLookupItem?.preferredDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? trimmedName
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
        if
            unit == .grams,
            let serving = selectedLookupServing,
            abs(quantity - serving.grams) < 0.01
        {
            return serving.preferredLabel
        }

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
        selectedLookupItem = nil
        selectedLookupServing = nil
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
        let foodRepository = dependencies.foodRepository
        lookupTask = Task { [foodRepository, foodIntelligenceService] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }

            let catalogItems = await foodRepository.searchItems(query: query, limit: 8)
            let estimatedMeals = (try? await foodIntelligenceService.estimateFromText(query, mealType: selectedMealType)) ?? []
            let estimatedItems = Self.makeEstimatedLookupItems(estimatedMeals)

            guard !Task.isCancelled else { return }
            let results = Self.mergeLookupItems(catalogItems + estimatedItems)

            await MainActor.run {
                lookupResults = results
                isLookingUpNutrition = false
                if let first = results.first(where: { $0.hasLookupNutrition }) ?? results.first {
                    applyNutritionItem(first)
                } else {
                    lookupMessage = "Besin değeri bulunamadı. Marka veya daha net ürün adı dene."
                }
            }
        }
    }

    private func applyNutritionItem(_ item: FoodItem) {
        let serving = item.defaultServing
        selectedLookupItem = item
        selectedLookupServing = serving
        calories = Double(item.caloriesPer100g)
        protein = item.proteinPer100g
        carbs = item.carbsPer100g
        fat = item.fatPer100g
        fiber = item.fiberPer100g > 0 ? item.fiberPer100g : nil
        sodium = item.sodiumPer100g > 0 ? item.sodiumPer100g : nil
        sugar = item.sugarPer100g > 0 ? item.sugarPer100g : nil
        saturatedFat = item.saturatedFatPer100g > 0 ? item.saturatedFatPer100g : nil
        lookupMessage = nil

        unit = .grams
        quantity = max(1, serving.grams)

        // Bulunan değerleri kullanıcıya görünür hale getir — gizli kalmasınlar.
        let hasMicros = (fiber ?? 0) > 0 || (sodium ?? 0) > 0 || (sugar ?? 0) > 0 || (saturatedFat ?? 0) > 0
        if calories > 0 || protein > 0 || carbs > 0 || fat > 0 {
            showNutritionAdjustments = true
        }
        if hasMicros {
            showMicros = true
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
        selectedLookupServing = nil
    }

    private static func mergeLookupItems(_ items: [FoodItem]) -> [FoodItem] {
        var seen = Set<String>()
        var merged: [FoodItem] = []

        for item in items {
            let key = item.externalID?.lowercased()
                ?? "\(item.source.rawValue):\(FoodSearchNormalizer.normalized(item.preferredDisplayName)):\(item.brand ?? "")"
            guard seen.insert(key).inserted else { continue }
            merged.append(item)
        }

        return merged
    }

    private static func makeEstimatedLookupItems(_ meals: [EstimatedMealResult]) -> [FoodItem] {
        meals.map { meal in
            let externalID = "estimated:\(FoodSearchNormalizer.normalized(meal.name)):\(meal.portion)"
            // EstimatedMealResult artık per-100g değerleri + gerçek
            // portionGrams taşır → math doğru çalışır.
            let portionServing = ServingSize(
                label: meal.portion,
                labelTR: meal.portion,
                grams: meal.portionGrams,
                isDefault: true
            )
            return FoodItem(
                source: .estimated,
                externalID: externalID,
                name: meal.name,
                localizedNameTR: meal.name,
                category: .localTurkish,
                servingSizes: [.hundredGrams, portionServing],
                nutritionPer100g: NutritionValues(
                    calories: meal.calories,
                    protein: meal.protein,
                    carbs: meal.carbs,
                    fat: meal.fat,
                    fiber: meal.fiber ?? 0,
                    sodium: meal.sodium ?? 0,
                    sugar: meal.sugar ?? 0,
                    saturatedFat: meal.saturatedFat ?? 0
                ),
                verifiedLevel: .approximate,
                confidenceScore: meal.confidence
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
                        isVerifiedTurkishFood: selectedLookupItem?.source == .openFoodFacts || selectedLookupItem?.source == .fatSecret,
                        isEstimated: selectedLookupItem?.verifiedLevel.shouldShowApproximateBadge ?? false,
                        fiberGrams: values.fiber > 0 ? values.fiber : nil,
                        sodiumMg: values.sodium > 0 ? values.sodium : nil,
                        sugarGrams: values.sugar > 0 ? values.sugar : nil,
                        saturatedFatGrams: values.saturatedFat > 0 ? values.saturatedFat : nil,
                        photoData: photoData
                    )
                    try repository.addMeal(meal)
                    await dependencies.healthService.saveNutrition(for: meal)
                    await syncSavedMeal(meal)
                    dependencies.haptics.mealLogged()
                    await syncWithFoodRepository(values: values)
                    await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "add_food_view", "provider": selectedLookupItem?.source.rawValue ?? "manual_adjusted"]))
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
                    await syncSavedMeal(meal)
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

    /// Mirrors semantic meal data to iCloud without making CloudKit a blocker for
    /// the local-first nutrition flow.
    private func syncSavedMeal(_ meal: MealEntry) async {
        do {
            try await dependencies.cloudSyncService.push(meal)
        } catch {
            NuvyraSyncToastRouter.handle(error, centre: toastCenter)
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

    /// Phase 8 — Save sonrası FoodRepository ile senkronizasyon. Lookup'tan
    /// gelen item için `recordUse` (frequency tracking → recents/favorites
    /// sıralaması), manuel `.grams` girişi için `addUserItem` (user-created
    /// catalog'a yazılır, gelecek aramalarda local olarak görünür). Portion
    /// ve piece girişleri için per-100g normalize edemediğimizden cache'lemiyoruz.
    @MainActor
    private func syncWithFoodRepository(values: NutritionValues) async {
        if let lookupItem = selectedLookupItem, let rowID = lookupItem.deterministicRowID {
            await dependencies.foodRepository.recordUse(id: rowID)
            return
        }

        guard hasNutritionValues, !trimmedName.isEmpty, unit == .grams, quantity > 0 else { return }
        let factor = 100 / quantity
        let per100g = NutritionValues(
            calories: Int((Double(values.calories) * factor).rounded()),
            protein: values.protein * factor,
            carbs: values.carbs * factor,
            fat: values.fat * factor,
            fiber: values.fiber * factor,
            sodium: values.sodium * factor,
            sugar: values.sugar * factor,
            saturatedFat: values.saturatedFat * factor
        )

        // Phase 11 — Kullanıcı detaylı manuel girdi yaptıysa onun
        // porsiyonlarını + kategoriyi kullan; aksi halde quantity'den türeyen
        // varsayılan tek porsiyon.
        let resolvedServings: [ServingSize] = manualServings.isEmpty
            ? [.hundredGrams, ServingSize(label: portionDescription, labelTR: portionDescription, grams: quantity, isDefault: true)]
            : ([.hundredGrams] + manualServings)

        let userItem = FoodItem.userCreated(
            name: trimmedName,
            category: manualCategory,
            servingSizes: resolvedServings,
            nutritionPer100g: per100g
        )
        _ = try? await dependencies.foodRepository.addUserItem(userItem)
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

/// Phase 8 — Premium lookup result row. SourceChip + VerifiedLevelBadge ile
/// kullanıcı veri kaynağını ve doğruluk seviyesini anında görür. 3 makro
/// pill her zaman görünür ("—" eksik değer için); kalori varsayılan
/// porsiyona göre ölçeklenir.
private struct AutoNutritionResultRow: View {
    let item: FoodItem
    let isSelected: Bool

    private var serving: ServingSize { item.defaultServing }
    private var scaledValues: NutritionValues { item.values(for: serving, quantity: 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            header
            macroRow
            if !hasAnyMacro && item.caloriesPer100g > 0 {
                Label("Yalnızca kalori bilgisi", systemImage: "info.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.85, green: 0.62, blue: 0.20))
            }
        }
        .padding(NuvyraSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .fill(isSelected ? NuvyraColors.accent.opacity(0.12) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous)
                .stroke(isSelected ? NuvyraColors.accent.opacity(0.55) : Color.clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.preferredDisplayName), \(scaledValues.calories) kalori, \(serving.preferredLabel)")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                FoodImageView(url: item.imageURL, style: .thumbnail)
                if isSelected {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white, NuvyraColors.accent)
                        .background(Circle().fill(.background))
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.preferredDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    SourceChip(source: item.source)
                    if item.showsApproximateBadge {
                        Text("yaklaşık")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(red: 0.85, green: 0.62, blue: 0.20))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.85, green: 0.62, blue: 0.20).opacity(0.15), in: Capsule())
                    }
                }

                if let brand = item.brand, !brand.isEmpty {
                    Text(brand)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: NuvyraSpacing.sm)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(scaledValues.calories)")
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(NuvyraColors.accent)
                Text("kcal · \(serving.preferredLabel)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var macroRow: some View {
        HStack(spacing: 6) {
            macroPill(label: "P", value: scaledValues.protein, tint: NuvyraColors.accent)
            macroPill(label: "K", value: scaledValues.carbs, tint: NuvyraColors.softSand)
            macroPill(label: "Y", value: scaledValues.fat, tint: NuvyraColors.mutedCoral)
        }
    }

    private func macroPill(label: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value > 0 ? "\(value.cleanMacro)g" : "—")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? tint : Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(value > 0 ? tint.opacity(0.10) : Color.secondary.opacity(0.05))
        )
    }

    private var hasAnyMacro: Bool {
        scaledValues.protein > 0 || scaledValues.carbs > 0 || scaledValues.fat > 0
    }
}

private extension FoodItem {
    var hasLookupNutrition: Bool {
        caloriesPer100g > 0
            || proteinPer100g > 0
            || carbsPer100g > 0
            || fatPer100g > 0
            || fiberPer100g > 0
            || sugarPer100g > 0
            || sodiumPer100g > 0
            || saturatedFatPer100g > 0
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
        .environmentObject(NuvyraToastCenter())
}
#endif
