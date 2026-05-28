import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodSearchViewModel()
    @State private var selectedItem: FoodItem?
    var onSelect: (FoodSelection) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                List {
                    Section {
                        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                            TextField("Şeftali, mercimek çorbası, simit...", text: $viewModel.query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.headline)
                                .padding(14)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
                                .accessibilityLabel("Besin veritabanı arama metni")
                                .onChange(of: viewModel.query) { _, _ in
                                    viewModel.scheduleSearch()
                                }

                            Text("Yerel kataloga ek olarak Open Food Facts, USDA ve ayarlandıysa FatSecret kaynakları aranır.")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }

                    if viewModel.isSearching {
                        Section {
                            HStack {
                                ProgressView()
                                Text("Geniş gıda veritabanı aranıyor...")
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage, !viewModel.isSearching {
                        Section {
                            NuvyraErrorStateView(
                                title: String(localized: "food.search.error.title"),
                                message: errorMessage,
                                style: .compact,
                                onRetry: {
                                    viewModel.retrySearch()
                                }
                            )
                                .listRowBackground(Color.clear)
                        }
                    }

                    if viewModel.query.isEmpty {
                        if !viewModel.favorites.isEmpty {
                            quickAccessSection(
                                title: "Favoriler",
                                systemImage: "star.fill",
                                items: viewModel.favorites
                            )
                        }
                        if !viewModel.recents.isEmpty {
                            quickAccessSection(
                                title: "Son kullanılanlar",
                                systemImage: "clock.arrow.circlepath",
                                items: viewModel.recents
                            )
                        }
                    }

                    if !viewModel.query.isEmpty {
                        Section("Sonuçlar") {
                            if viewModel.results.isEmpty, !viewModel.isSearching {
                                Text("Sonuç bulunamadı. Daha kısa bir kelime veya marka adı deneyebilirsin.")
                                    .foregroundStyle(.secondary)
                                    .listRowBackground(Color.clear)
                            }

                            ForEach(viewModel.results) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    FoodItemRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .accessibilityLabel("\(item.preferredDisplayName), \(item.caloriesPer100g) kalori 100 gramda, ayrıntıyı aç ve porsiyon seç")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .task { await viewModel.loadInitial() }
            .navigationTitle("Besin ara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(item: $selectedItem, onDismiss: { Task { await viewModel.loadInitial() } }) { item in
                FoodDetailView(item: item) { values, serving, quantity in
                    let selection = FoodSelection(
                        item: item,
                        values: values,
                        serving: serving,
                        quantity: quantity
                    )
                    onSelect(selection)
                    dismiss()
                }
            }
        }
    }

    /// Recents / favorites bloğu — query boşken görünür hızlı erişim.
    @ViewBuilder
    private func quickAccessSection(title: String, systemImage: String, items: [FoodItem]) -> some View {
        Section {
            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    FoodItemRow(item: item)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityLabel("\(item.preferredDisplayName), \(item.caloriesPer100g) kalori 100 gramda")
            }
        } header: {
            Label(title, systemImage: systemImage)
                .font(NuvyraTypography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// Rich `FoodItem` listede gösterilirken her satırın taşıdığı görsel:
/// isim + marka + kaynak chip + 100 g kalori + makro özet + verified rozeti.
private struct FoodItemRow: View {
    @Environment(\.colorScheme) private var scheme
    let item: FoodItem

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.preferredDisplayName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    SourceChip(source: item.source)
                    if item.showsApproximateBadge {
                        Text("yaklaşık")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 0.85, green: 0.62, blue: 0.20))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.85, green: 0.62, blue: 0.20).opacity(0.15), in: Capsule())
                    }
                }

                if let brand = item.brand, !brand.isEmpty {
                    Text(brand)
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(NuvyraColors.secondaryText(scheme))
                }

                if hasMacros {
                    Text("P \(item.proteinPer100g.cleanMacro)g  C \(item.carbsPer100g.cleanMacro)g  Y \(item.fatPer100g.cleanMacro)g")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.caloriesPer100g)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(NuvyraColors.accent)
                Text("kcal / 100 g")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(NuvyraSpacing.md)
        .background(NuvyraColors.card(scheme), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }

    private var hasMacros: Bool {
        item.proteinPer100g > 0 || item.carbsPer100g > 0 || item.fatPer100g > 0
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

#Preview {
    FoodSearchView { _ in }
}
