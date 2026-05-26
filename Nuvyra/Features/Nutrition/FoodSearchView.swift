import SwiftUI

struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodSearchViewModel()
    var onSelect: (FoodSearchResult) -> Void

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

                            Text("Türkçe karakter ve aksan farkı yoksayılır. Örneğin “seftali” yazınca “Şeftali” bulunur.")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                    }

                    if viewModel.isSearching {
                        Section {
                            HStack {
                                ProgressView()
                                Text("FTS5 indeksi aranıyor...")
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
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

                    Section("Sonuçlar") {
                        if viewModel.results.isEmpty, !viewModel.query.isEmpty, !viewModel.isSearching {
                            Text("Sonuç bulunamadı. Daha kısa bir kelime deneyebilirsin.")
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        }

                        ForEach(viewModel.results) { result in
                            Button {
                                onSelect(result)
                                dismiss()
                            } label: {
                                FoodSearchResultRow(result: result)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityLabel("\(result.name), \(result.servingDescription), \(result.calories) kalori ekle")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Besin ara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

private struct FoodSearchResultRow: View {
    @Environment(\.colorScheme) private var scheme
    let result: FoodSearchResult

    var body: some View {
        HStack(spacing: NuvyraSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NuvyraColors.primaryText(scheme))

                HStack(spacing: NuvyraSpacing.xs) {
                    if let brand = result.brand, !brand.isEmpty {
                        Text(brand)
                    }
                    Text(result.servingDescription)
                    Text("Tahmini değer")
                }
                .font(NuvyraTypography.caption)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }

            Spacer()

            Text("\(result.calories) kcal")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(NuvyraColors.accent)
        }
        .padding(NuvyraSpacing.md)
        .background(NuvyraColors.card(scheme), in: RoundedRectangle(cornerRadius: NuvyraRadius.md, style: .continuous))
    }
}

#Preview {
    FoodSearchView { _ in }
}
