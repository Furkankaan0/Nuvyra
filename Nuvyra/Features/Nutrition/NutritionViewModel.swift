import Combine
import Foundation
import SwiftData

@MainActor
final class NutritionViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var meals: [MealEntry] = []
    @Published var favorites: [MealEntry] = []
    @Published var summary: DailyMealSummary = .empty
    @Published var streak: StreakInsight = .empty
    @Published var selectedMealType: MealType = .breakfast
    @Published var selectedDate: Date = Date()
    @Published var showingAddMeal = false
    @Published var showingCamera = false
    @Published var showingBarcodeScanner = false
    @Published var showingFoodSearch = false
    @Published var editingMeal: MealEntry?
    /// Barcode tarama başarılı olunca burası set olur ve view bunu
    /// `.sheet(item:)` ile `FoodDetailView` olarak açar. Portion picker
    /// sonrası `addFoodSelection` üzerinden öğüne dönüşür.
    @Published var pendingBarcodeItem: FoodItem?

    // Phase 12 — Apple Health dietary import
    @Published var showingHealthImport = false
    @Published var healthImportSamples: [ImportedDietarySample] = []
    @Published var isImportingFromHealth = false
    @Published var healthImportSelection: Set<UUID> = []
    @Published var healthImportRangeDays: Int = 7
    @Published var errorMessage: String?
    @Published var smartMealText = ""
    @Published var estimatedResults: [EstimatedMealResult] = []
    @Published var isEstimating = false
    @Published var actionFeedback: String?

    var sectionedMeals: [(MealType, [MealEntry])] {
        MealType.allCases.map { type in
            (type, meals.filter { $0.mealType == type })
        }
    }

    var isViewingToday: Bool {
        Calendar.nuvyra.isDateInToday(selectedDate)
    }

    func load(context: ModelContext, dependencies: DependencyContainer) {
        do {
            let repository = dependencies.nutritionRepository(context: context)
            meals = try repository.meals(on: selectedDate)
            favorites = try repository.favoriteMeals()
            summary = try repository.dailySummary(on: selectedDate)
            profile = try? dependencies.userRepository(context: context).profile()
            streak = (try? repository.mealStreak(daysBack: 60)) ?? .empty
        } catch {
            errorMessage = "Öğünler yüklenemedi."
        }
    }

    var macroTarget: MacroTarget {
        profile.map(MacroTarget.init(profile:)) ?? .defaultTarget
    }

    func changeDate(to date: Date, context: ModelContext, dependencies: DependencyContainer) {
        selectedDate = date
        load(context: context, dependencies: dependencies)
    }

    func moveDate(by days: Int, context: ModelContext, dependencies: DependencyContainer) {
        guard let next = Calendar.nuvyra.date(byAdding: .day, value: days, to: selectedDate), next <= Date() else { return }
        changeDate(to: next, context: context, dependencies: dependencies)
    }

    func estimateSmartMeal(dependencies: DependencyContainer) async {
        let input = smartMealText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isEstimating = true
        errorMessage = nil
        defer { isEstimating = false }
        do {
            estimatedResults = try await dependencies.foodIntelligenceService.estimateFromText(input, mealType: selectedMealType)
            if estimatedResults.isEmpty {
                errorMessage = "Bu metinden öğün çıkaramadık. Biraz daha açıklayıcı yazabilirsin."
            }
        } catch {
            errorMessage = "Akıllı kayıt şu an hazırlanamadı."
        }
    }

    func addEstimatedResult(_ result: EstimatedMealResult, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
                name: result.name,
                calories: result.calories,
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                portionDescription: result.portion,
                isFavorite: false,
                isVerifiedTurkishFood: result.source == .localTurkishNLP,
                isEstimated: result.isEstimated
            )
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "smart_text", "estimated": "true"]))
            smartMealText = ""
            estimatedResults = []
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Tahmini öğün eklenemedi."
        }
    }

    func addQuickFood(_ food: QuickFood, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
                name: food.name,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                portionDescription: food.portion,
                isFavorite: false,
                isVerifiedTurkishFood: true,
                isEstimated: true
            )
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()
            await dependencies.analytics.track(.mealAdded, payload: AnalyticsPayload(values: ["source": "quick_food", "name": food.name]))
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Öğün eklenemedi."
        }
    }

    /// Phase 6 entry point — `FoodDetailView` kullanıcının seçtiği porsiyon
    /// + miktarı scaled `NutritionValues` ile birlikte yollar; burası onu
    /// `MealEntry`'ye çevirir. Repository tarafında usage frequency artırılır.
    func addFoodSelection(_ selection: FoodSelection, context: ModelContext, dependencies: DependencyContainer) async {
        let item = selection.item
        let values = selection.values
        do {
            let meal = MealEntry(
                date: selectedDate,
                mealType: selectedMealType,
                name: item.preferredDisplayName,
                calories: values.calories,
                protein: values.protein > 0 ? values.protein : nil,
                carbs: values.carbs > 0 ? values.carbs : nil,
                fat: values.fat > 0 ? values.fat : nil,
                portionDescription: selection.portionDescription,
                isFavorite: false,
                isVerifiedTurkishFood: item.verifiedLevel == .verified,
                isEstimated: item.verifiedLevel != .verified,
                fiberGrams: values.fiber > 0 ? values.fiber : nil,
                sodiumMg: values.sodium > 0 ? values.sodium : nil,
                sugarGrams: values.sugar > 0 ? values.sugar : nil,
                saturatedFatGrams: values.saturatedFat > 0 ? values.saturatedFat : nil
            )
            try dependencies.nutritionRepository(context: context).addMeal(meal)
            await dependencies.healthService.saveNutrition(for: meal)
            dependencies.haptics.mealLogged()

            if let rowID = selection.deterministicRowID {
                await dependencies.foodRepository.recordUse(id: rowID)
            }

            await dependencies.analytics.track(
                .mealAdded,
                payload: AnalyticsPayload(values: [
                    "source": "food_detail",
                    "provider": item.source.rawValue,
                    "verified": item.verifiedLevel.rawValue
                ])
            )
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Seçilen besinden öğün eklenemedi."
        }
    }

    /// Phase 6.5 — barkod taramasından gelen `ScannedProduct`'ı rich `FoodItem`'a
    /// yükseltir, repository'ye write-through ile cache eder ve
    /// `pendingBarcodeItem` set ederek `FoodDetailView`'in modal olarak
    /// açılmasını tetikler. Portion picker sonrası `addFoodSelection` öğünü
    /// yaratır — eskiden "100 g - barkod" olarak sabit eklenen meal artık
    /// kullanıcı seçimine göre porsiyonlanır.
    // MARK: - Phase 12: Health dietary import

    /// Health'ten son N gündeki dietary örnekleri çeker, lokal listeyi günceller.
    /// Önceden Nuvyra'nın kendi yazdığı örnekler service tarafında filtrelenir.
    func loadHealthDietaryImport(dependencies: DependencyContainer) async {
        isImportingFromHealth = true
        defer { isImportingFromHealth = false }
        let now = Date()
        let start = Calendar.nuvyra.date(byAdding: .day, value: -healthImportRangeDays, to: now) ?? now
        let samples = await dependencies.healthService.importDietarySamples(start: start, end: now)
        healthImportSamples = samples
        // Yeni listede default olarak tüm örnekleri seçili işaretle.
        healthImportSelection = Set(samples.map { $0.id })
    }

    /// Kullanıcı seçimini onayladığında: seçili örnekleri MealEntry olarak
    /// repository'ye yazar. Bu kayıtlar `isVerifiedTurkishFood = false`,
    /// `isEstimated = false` (Health verisi düzgün makro taşır) işaretlenir.
    func confirmHealthImport(context: ModelContext, dependencies: DependencyContainer) async {
        let selected = healthImportSamples.filter { healthImportSelection.contains($0.id) }
        guard !selected.isEmpty else { return }

        var savedCount = 0
        let repository = dependencies.nutritionRepository(context: context)
        for sample in selected {
            let meal = MealEntry(
                date: sample.date,
                mealType: sample.inferredMealType,
                name: sample.name,
                calories: sample.calories,
                protein: sample.protein > 0 ? sample.protein : nil,
                carbs: sample.carbs > 0 ? sample.carbs : nil,
                fat: sample.fat > 0 ? sample.fat : nil,
                portionDescription: "Health'ten alındı · \(sample.sourceName)",
                isFavorite: false,
                isVerifiedTurkishFood: false,
                isEstimated: false,
                fiberGrams: sample.fiber,
                sodiumMg: sample.sodium,
                sugarGrams: sample.sugar,
                saturatedFatGrams: sample.saturatedFat
            )
            do {
                try repository.addMeal(meal)
                savedCount += 1
            } catch {
                continue
            }
        }

        await dependencies.analytics.track(
            .mealAdded,
            payload: AnalyticsPayload(values: ["source": "health_import", "count": "\(savedCount)"])
        )
        dependencies.haptics.mealLogged()

        showingHealthImport = false
        healthImportSamples = []
        healthImportSelection = []
        flash("\(savedCount) öğün Health'ten içe aktarıldı")
        load(context: context, dependencies: dependencies)
        refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
    }

    func toggleHealthImportSelection(_ sample: ImportedDietarySample) {
        if healthImportSelection.contains(sample.id) {
            healthImportSelection.remove(sample.id)
        } else {
            healthImportSelection.insert(sample.id)
        }
    }

    /// Canlı kameradan seçilen detection için makro tahmini üretir.
    /// `CameraView` bunu doğrudan resolver olarak çağırır → sheet'in `loaded`
    /// state'ine doldurulur. Servis hiç sonuç döndürmezse hata mesajını
    /// sheet'in `.failed` state'i taşır.
    func resolveCameraLabel(_ label: String, dependencies: DependencyContainer) async -> Result<EstimatedMealResult, Error> {
        let query = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return .failure(CameraEstimationError.emptyLabel)
        }
        do {
            let results = try await dependencies.foodIntelligenceService
                .estimateFromText(query, mealType: selectedMealType)
            if let first = results.first {
                return .success(first)
            }
            return .failure(CameraEstimationError.noEstimate(label: query))
        } catch {
            return .failure(error)
        }
    }

    func handleScannedProduct(_ product: ScannedProduct, dependencies: DependencyContainer) async {
        var item = FoodItem.from(scannedProduct: product)

        // Phase 13 — ScannedProduct'ta veriler eksikse (OFF sparse / Türk
        // ürünü OFF'ta tam yok) Gemini ile zenginleştir. İsim "Bilinmeyen
        // Ürün" değil + brand veya bir ipucu varsa AI'ya o ipucuyla sor;
        // yoksa "Barkod 8690…" + makro tahmini iste.
        let needsEnrichment = item.caloriesPer100g == 0
            || (item.proteinPer100g + item.carbsPer100g + item.fatPer100g) == 0
        if needsEnrichment {
            let query = enrichmentQuery(for: product)
            if let enriched = try? await dependencies.foodIntelligenceService
                .estimateFromText(query, mealType: selectedMealType)
                .first {
                item = mergeEnrichment(into: item, from: enriched, originalProduct: product)
            }
        }

        await dependencies.foodRepository.cacheItem(item)
        pendingBarcodeItem = item
    }

    private func enrichmentQuery(for product: ScannedProduct) -> String {
        let isPlaceholderName = product.name == "Bilinmeyen Ürün" || product.name.isEmpty
        let countryHint = BarcodeNormalizer.countryHint(for: product.barcode)
        let countryClause = countryHint.isEmpty ? "" : " (\(countryHint) menşeli)"
        if !isPlaceholderName {
            // Marka varsa onunla beraber daha spesifik
            if let brand = product.brand, !brand.isEmpty {
                return "\(brand) \(product.name)\(countryClause)"
            }
            return "\(product.name)\(countryClause)"
        }
        if let brand = product.brand, !brand.isEmpty {
            return "\(brand) ürünü\(countryClause) — barkod \(product.barcode)"
        }
        if !countryHint.isEmpty {
            return "\(countryHint) gıda ürünü (barkod \(product.barcode)) — bu ülkede yaygın bir gıda yorumu yap"
        }
        return "Gıda ürünü (barkod \(product.barcode)) — yaygın bir yorum yap"
    }

    private func mergeEnrichment(
        into item: FoodItem,
        from estimate: EstimatedMealResult,
        originalProduct: ScannedProduct
    ) -> FoodItem {
        let preferredName = (item.name == "Bilinmeyen Ürün" || item.name.isEmpty)
            ? estimate.name
            : item.name
        let preferredNameTR = item.localizedNameTR == "Bilinmeyen Ürün" || item.localizedNameTR == nil
            ? estimate.name
            : item.localizedNameTR
        let nutrition = NutritionValues(
            calories: estimate.calories,
            protein: estimate.protein,
            carbs: estimate.carbs,
            fat: estimate.fat,
            fiber: estimate.fiber ?? 0,
            sodium: estimate.sodium ?? 0,
            sugar: estimate.sugar ?? 0,
            saturatedFat: estimate.saturatedFat ?? 0
        )
        let servings: [ServingSize] = [
            .hundredGrams,
            ServingSize(
                label: estimate.portion,
                labelTR: estimate.portion,
                grams: estimate.portionGrams,
                isDefault: true
            )
        ]
        return FoodItem(
            id: item.id,
            source: item.source,
            externalID: item.externalID,
            name: preferredName,
            localizedNameTR: preferredNameTR,
            brand: item.brand,
            barcode: originalProduct.barcode,
            imageURL: item.imageURL,
            category: item.category,
            subCategory: item.subCategory,
            servingSizes: servings,
            nutritionPer100g: nutrition,
            micronutrients: item.micronutrients,
            ingredients: item.ingredients,
            allergens: item.allergens,
            additives: item.additives,
            nutriScore: item.nutriScore,
            novaGroup: item.novaGroup,
            // Verified→approximate düş çünkü değerler AI tahmini.
            verifiedLevel: .approximate,
            confidenceScore: max(0.5, estimate.confidence),
            lastUpdated: Date()
        )
    }

    func delete(_ meal: MealEntry, context: ModelContext, dependencies: DependencyContainer) {
        do {
            try dependencies.nutritionRepository(context: context).deleteMeal(meal)
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
        } catch {
            errorMessage = "Öğün silinemedi."
        }
    }

    func startEditing(_ meal: MealEntry) {
        editingMeal = meal
    }

    func copyPreviousDayMeals(context: ModelContext, dependencies: DependencyContainer) async {
        guard let sourceDate = Calendar.nuvyra.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        do {
            let count = try dependencies.nutritionRepository(context: context).copyMeals(from: sourceDate, to: selectedDate)
            let copiedMeals = try dependencies.nutritionRepository(context: context).meals(on: selectedDate)
            for meal in copiedMeals.suffix(count) {
                await dependencies.healthService.saveNutrition(for: meal)
            }
            load(context: context, dependencies: dependencies)
            refreshWidgetIfViewingToday(context: context, dependencies: dependencies)
            flash(count > 0 ? "\(count) öğün kopyalandı" : "Kopyalanacak öğün yok")
        } catch {
            errorMessage = "Öğünler kopyalanamadı."
        }
    }

    func copyMealToToday(_ meal: MealEntry, context: ModelContext, dependencies: DependencyContainer) async {
        do {
            try dependencies.nutritionRepository(context: context).copyMeal(meal, to: Date())
            if isViewingToday {
                load(context: context, dependencies: dependencies)
            }
            refreshWidget(context: context, dependencies: dependencies)
            flash("Öğün bugüne kopyalandı")
        } catch {
            errorMessage = "Öğün bugüne kopyalanamadı."
        }
    }

    private func refreshWidgetIfViewingToday(context: ModelContext, dependencies: DependencyContainer) {
        guard isViewingToday else { return }
        refreshWidget(context: context, dependencies: dependencies)
    }

    private func refreshWidget(context: ModelContext, dependencies: DependencyContainer) {
        Task { @MainActor in
            await NuvyraWidgetSnapshotWriter.writeTodaySnapshot(context: context, healthService: dependencies.healthService)
        }
    }

    private func flash(_ message: String) {
        actionFeedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self?.actionFeedback = nil }
        }
    }
}
