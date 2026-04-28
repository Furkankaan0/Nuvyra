import PhotosUI
import SwiftUI

enum MealLoggingMode {
    case tab
    case sheet
}

struct MealLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MealLoggingViewModel()
    var mode: MealLoggingMode = .tab

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    header
                    entryMethods
                    manualForm
                    quickTurkishFoods
                    mealList
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Öğün kaydı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .sheet {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.xs) {
            Text("Öğününü nasıl eklemek istersin?")
                .font(NuvyraTypography.title())
            Text("Fotoğraf ve hızlı seçimler tahmini değer üretir. Her değeri düzenleyebilirsin.")
                .foregroundStyle(.secondary)
        }
    }

    private var entryMethods: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
            ForEach(MealSource.allCases) { source in
                QuickEntryCard(source: source, isSelected: viewModel.selectedSource == source) {
                    viewModel.selectedSource = source
                    if source == .photo { appState.router.presentedSheet = .photoMeal }
                }
            }
        }
    }

    private var manualForm: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                Text("Manuel öğün")
                    .font(NuvyraTypography.sectionTitle())
                TextField("Örn. Mercimek çorbası", text: $viewModel.mealName)
                    .textFieldStyle(.roundedBorder)
                Stepper("Kalori: \(viewModel.calories) kcal", value: $viewModel.calories, in: 1...2_500, step: 10)
                Stepper("Protein: \(viewModel.protein) g", value: $viewModel.protein, in: 0...200)
                Stepper("Karbonhidrat: \(viewModel.carbs) g", value: $viewModel.carbs, in: 0...300)
                Stepper("Yağ: \(viewModel.fat) g", value: $viewModel.fat, in: 0...200)
                NuvyraPrimaryButton(title: "Öğünü kaydet", systemImage: "checkmark") {
                    guard viewModel.canSaveManual else { return }
                    let meal = viewModel.makeManualMeal()
                    Task {
                        await appState.addMeal(meal)
                        viewModel.resetManualForm()
                        if mode == .sheet { dismiss() }
                    }
                }
                .disabled(!viewModel.canSaveManual)
            }
        }
    }

    private var quickTurkishFoods: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Hızlı Türk yemeği seç")
                .font(NuvyraTypography.sectionTitle())
            FlowLayout(spacing: NuvyraSpacing.sm) {
                ForEach(QuickFood.turkishDefaults) { food in
                    NuvyraChip(title: food.name) {
                        Task { await appState.addMeal(food.mealLog) }
                    }
                }
            }
        }
    }

    private var mealList: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            Text("Bugünkü kayıtlar")
                .font(NuvyraTypography.sectionTitle())
            if appState.meals.isEmpty {
                EmptyStateCard(title: "Henüz öğün yok", detail: "İlk kaydı küçük tutabilirsin. Bir çorba bile ritmi başlatır.", systemImage: "fork.knife")
            } else {
                ForEach(appState.meals) { meal in
                    NuvyraMealCard(meal: meal)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await appState.deleteMeal(id: meal.id) }
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}

private struct QuickEntryCard: View {
    var source: MealSource
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Image(systemName: iconName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? NuvyraColor.lightSecondaryAccent : NuvyraColor.lightPrimary)
                    Text(source.title)
                        .font(.subheadline.weight(.semibold))
                    if source == .photo {
                        Text("Tahmini değer")
                            .font(NuvyraTypography.caption())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch source {
        case .manual: "square.and.pencil"
        case .photo: "camera"
        case .barcode: "barcode.viewfinder"
        case .quickTurkishFood: "bolt.heart"
        }
    }
}

struct PhotoMealEstimateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MealLoggingViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        Text("Fotoğrafla öğün kaydı")
                            .font(NuvyraTypography.title())
                        Text("MVP'de bu ekran mock tahmin servisi kullanır. Değerler kesin değildir ve kaydetmeden önce düzenlenebilir.")
                            .foregroundStyle(.secondary)

                        NuvyraGlassCard {
                            VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                                TextField("İpucu: örn. tavuk döner", text: $viewModel.estimateHint)
                                    .textFieldStyle(.roundedBorder)
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    Label(selectedImageData == nil ? "Fotoğraf seç" : "Fotoğraf seçildi", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                NuvyraPrimaryButton(title: "Tahmin oluştur", systemImage: "sparkles", isLoading: viewModel.isEstimating) {
                                    Task {
                                        await appState.environment.analytics.track(AnalyticsEvent(.photoMealStarted))
                                        await viewModel.estimateMeal(imageData: selectedImageData, service: appState.environment.foodEstimationService)
                                        if viewModel.estimate != nil {
                                            await appState.environment.analytics.track(AnalyticsEvent(.photoMealCompleted))
                                        }
                                    }
                                }
                            }
                        }

                        if let estimate = viewModel.estimate {
                            NuvyraGlassCard {
                                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                                    Text(estimate.title)
                                        .font(NuvyraTypography.sectionTitle())
                                    Text("\(estimate.calories) kcal")
                                        .font(NuvyraTypography.metric())
                                    Text(estimate.macros.summary)
                                        .foregroundStyle(.secondary)
                                    Text(estimate.disclaimer)
                                        .font(NuvyraTypography.caption())
                                        .foregroundStyle(.secondary)
                                    NuvyraPrimaryButton(title: "Bu tahmini kaydet", systemImage: "checkmark") {
                                        Task {
                                            await appState.addMeal(estimate.asMealLog)
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }

                        if let error = viewModel.errorMessage {
                            EmptyStateCard(title: "Tahmin oluşturulamadı", detail: error, systemImage: "exclamationmark.triangle")
                        }
                    }
                    .padding(NuvyraSpacing.lg)
                }
            }
            .navigationTitle("Fotoğraf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .task(id: selectedItem) {
            selectedImageData = try? await selectedItem?.loadTransferable(type: Data.self)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    MealLoggingView()
        .environmentObject(AppState.preview())
}


