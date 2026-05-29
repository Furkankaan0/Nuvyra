import SwiftData
import SwiftUI

/// Phase 12 — Apple Health'ten beslenme örneklerini içe aktarma akışı.
/// Kullanıcı: tarih aralığı seçer → "Health'ten yükle" → liste gelir →
/// istemediklerinin checkbox'ını kaldırır → "İçe aktar" → seçilenler
/// MealEntry olarak kaydedilir.
struct HealthDietaryImportView: View {
    @ObservedObject var viewModel: NutritionViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    private let rangeOptions: [Int] = [1, 3, 7, 14, 30]

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                List {
                    Section {
                        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                            Text("Apple Health'teki beslenme kayıtlarını içe aktar")
                                .font(NuvyraTypography.section)
                            Text("Diğer uygulamalardan (MyFitnessPal, Lose It! vb.) Health'e yazılan öğünler aşağıda listelenir. Nuvyra'nın kendi yazdığı kayıtlar otomatik filtrelenir.")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                            rangeChips
                        }
                        .listRowBackground(Color.clear)
                    }

                    if viewModel.isImportingFromHealth {
                        Section {
                            HStack {
                                ProgressView()
                                Text("Apple Health taranıyor...")
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }

                    if !viewModel.healthImportSamples.isEmpty {
                        Section {
                            ForEach(viewModel.healthImportSamples) { sample in
                                Button {
                                    viewModel.toggleHealthImportSelection(sample)
                                } label: {
                                    HealthImportRow(
                                        sample: sample,
                                        isSelected: viewModel.healthImportSelection.contains(sample.id)
                                    )
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                            }
                        } header: {
                            HStack {
                                Text("\(viewModel.healthImportSamples.count) kayıt bulundu")
                                Spacer()
                                Button(allSelected ? "Hiçbirini" : "Tümünü") {
                                    if allSelected {
                                        viewModel.healthImportSelection = []
                                    } else {
                                        viewModel.healthImportSelection = Set(viewModel.healthImportSamples.map { $0.id })
                                    }
                                }
                                .font(NuvyraTypography.caption.weight(.semibold))
                                .foregroundStyle(NuvyraColors.accent)
                            }
                        }
                    } else if !viewModel.isImportingFromHealth {
                        Section {
                            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                                Label("Henüz tarama yapmadın", systemImage: "heart.text.square")
                                    .font(NuvyraTypography.section)
                                Text("Üstteki gün aralığını seç ve 'Health'ten yükle' butonuna dokun.")
                                    .font(NuvyraTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)

                VStack {
                    Spacer()
                    actionBar
                }
            }
            .navigationTitle("Health'ten içe aktar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private var rangeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(rangeOptions, id: \.self) { days in
                    Button {
                        viewModel.healthImportRangeDays = days
                    } label: {
                        Text("Son \(days) gün")
                            .font(NuvyraTypography.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(viewModel.healthImportRangeDays == days ? .white : .primary)
                            .background(
                                Capsule().fill(viewModel.healthImportRangeDays == days
                                    ? NuvyraColors.accent
                                    : Color.primary.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: NuvyraSpacing.sm) {
            Button {
                Task { await viewModel.loadHealthDietaryImport(dependencies: dependencies) }
            } label: {
                Label("Health'ten yükle", systemImage: "arrow.down.heart")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(NuvyraColors.accent)
            .disabled(viewModel.isImportingFromHealth)

            Button {
                Task { await viewModel.confirmHealthImport(context: modelContext, dependencies: dependencies) }
            } label: {
                Label("İçe aktar (\(viewModel.healthImportSelection.count))", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(NuvyraColors.accent)
            .disabled(viewModel.healthImportSelection.isEmpty || viewModel.isImportingFromHealth)
        }
        .padding(NuvyraSpacing.md)
        .background(.thinMaterial)
    }

    private var allSelected: Bool {
        !viewModel.healthImportSamples.isEmpty &&
            viewModel.healthImportSelection.count == viewModel.healthImportSamples.count
    }
}

private struct HealthImportRow: View {
    let sample: ImportedDietarySample
    let isSelected: Bool

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateFormat = "dd MMM · HH:mm"
        return df
    }()

    var body: some View {
        HStack(alignment: .top, spacing: NuvyraSpacing.sm) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? NuvyraColors.accent : Color.secondary.opacity(0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text(sample.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "heart.text.square")
                    Text(sample.sourceName)
                    Text("·")
                    Text(Self.dateFormatter.string(from: sample.date))
                    Text("·")
                    Text(sample.inferredMealType.title)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    macroPill("P", value: sample.protein, tint: NuvyraColors.accent)
                    macroPill("K", value: sample.carbs, tint: NuvyraColors.softSand)
                    macroPill("Y", value: sample.fat, tint: NuvyraColors.mutedCoral)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(sample.calories)")
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(NuvyraColors.accent)
                Text("kcal")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sample.name), \(sample.calories) kalori, \(Self.dateFormatter.string(from: sample.date))")
    }

    private func macroPill(_ label: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value > 0 ? "\(Int(value.rounded()))g" : "—")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(value > 0 ? tint : Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(value > 0 ? tint.opacity(0.10) : Color.secondary.opacity(0.05))
        )
    }
}
