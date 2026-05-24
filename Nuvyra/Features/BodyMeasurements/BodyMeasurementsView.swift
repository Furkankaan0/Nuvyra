import SwiftData
import SwiftUI

struct BodyMeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = BodyMeasurementsViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "Vücut ölçüleri",
                        subtitle: "Kilo dışında bel, kalça, vücut yağı gibi kompozisyon değişimlerini takip et."
                    )
                    snapshotCard
                    rangeChips
                    metricChips
                    BodyMeasurementTrendCard(metric: viewModel.selectedMetric, logs: viewModel.history)
                    historySection
                    addButton
                    Text("Bu veriler bilgilendirme amaçlıdır; tıbbi tanı veya tedavi yerine geçmez.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable { viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .navigationTitle("Vücut ölçüleri")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(context: modelContext, dependencies: dependencies) }
        .sheet(isPresented: $viewModel.showingAdd, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) {
            AddBodyMeasurementSheet(mode: .create, prefilledWeightKg: viewModel.latest?.weightKg)
        }
        .sheet(item: $viewModel.editingLog, onDismiss: { viewModel.load(context: modelContext, dependencies: dependencies) }) { log in
            AddBodyMeasurementSheet(mode: .edit(log))
        }
    }

    // MARK: - Sections
    @ViewBuilder
    private var snapshotCard: some View {
        if let log = viewModel.latest {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Son ölçüm")
                                .font(NuvyraTypography.caption)
                                .foregroundStyle(.secondary)
                            Text(log.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        Text(String(format: "%.1f kg", log.weightKg))
                            .font(.title.weight(.heavy))
                            .foregroundStyle(NuvyraColors.accent)
                            .contentTransition(.numericText())
                    }
                    if log.hasBodyComposition {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: NuvyraSpacing.sm) {
                            metricCell("Bel", value: log.waistCm, unit: "cm")
                            metricCell("Kalça", value: log.hipCm, unit: "cm")
                            metricCell("Göğüs", value: log.chestCm, unit: "cm")
                            metricCell("Omuz", value: log.shoulderCm, unit: "cm")
                            metricCell("Boyun", value: log.neckCm, unit: "cm")
                            metricCell("Pazı", value: log.bicepCm, unit: "cm")
                            metricCell("Uyluk", value: log.thighCm, unit: "cm")
                            metricCell("Yağ %", value: log.bodyFatPercent, unit: "%")
                            metricCell("Bel/Kalça", value: log.waistToHipRatio, unit: "", fractionDigits: 2)
                        }
                    } else {
                        Text("Henüz çevre ölçüsü eklemedin. Bir kayıt ekleyerek trend'i başlatabilirsin.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            NuvyraGlassCard {
                VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                    Label("Henüz kayıt yok", systemImage: "ruler")
                        .font(NuvyraTypography.section)
                    Text("İlk ölçümünü ekleyerek vücut kompozisyon takibini başlat.")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metricCell(_ title: String, value: Double?, unit: String, fractionDigits: Int = 1) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if let value {
                let formatted = fractionDigits == 0 ? "\(Int(value))" : String(format: "%.\(fractionDigits)f", value)
                Text("\(formatted)\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.primary)
            } else {
                Text("—")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(NuvyraColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: NuvyraRadius.sm, style: .continuous))
    }

    private var rangeChips: some View {
        HStack(spacing: NuvyraSpacing.xs) {
            ForEach(viewModel.ranges, id: \.days) { range in
                NuvyraChip(title: range.label, isSelected: viewModel.selectedDays == range.days) {
                    viewModel.changeRange(days: range.days, context: modelContext, dependencies: dependencies)
                }
            }
            Spacer()
        }
    }

    private var metricChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NuvyraSpacing.xs) {
                ForEach(viewModel.availableMetrics) { metric in
                    NuvyraChip(title: metric.title, isSelected: viewModel.selectedMetric == metric) {
                        viewModel.selectedMetric = metric
                    }
                }
            }
        }
    }

    private var historySection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(title: "Geçmiş", subtitle: viewModel.history.isEmpty ? "Henüz kayıt yok" : "\(viewModel.history.count) kayıt")
                if viewModel.history.isEmpty {
                    Text("İlk ölçümünü eklediğinde burada görünecek.")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.history.reversed().enumerated()), id: \.element.id) { index, log in
                            if index > 0 { Divider().padding(.vertical, 2) }
                            BodyMeasurementRow(
                                log: log,
                                onEdit: { viewModel.startEditing(log) },
                                onDelete: { viewModel.delete(log, context: modelContext, dependencies: dependencies) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var addButton: some View {
        NuvyraPrimaryButton(title: "Ölçüm ekle", systemImage: "plus") {
            viewModel.showingAdd = true
        }
    }
}

#Preview {
    NavigationStack { BodyMeasurementsView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
