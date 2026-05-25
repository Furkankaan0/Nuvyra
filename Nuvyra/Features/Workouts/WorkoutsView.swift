import SwiftData
import SwiftUI

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = WorkoutsViewModel()

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(
                        title: "Egzersizler",
                        subtitle: "Adım dışında koşu, bisiklet, gym ve daha fazlasını takip et."
                    )
                    NuvyraDateNavigator(
                        date: Binding(
                            get: { viewModel.selectedDate },
                            set: { viewModel.changeDate(to: $0, context: modelContext, dependencies: dependencies) }
                        ),
                        title: "Egzersiz günü"
                    )
                    WorkoutSummaryCard(
                        summary: viewModel.summary,
                        label: Calendar.nuvyra.isDateInToday(viewModel.selectedDate) ? "Bugün" : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted)
                    )
                    addButton
                    historySection
                    WeeklyWorkoutChart(totals: viewModel.weeklyCalories)
                    Text("Apple Health'ten gelen kayıtlar otomatik listelenir; manuel girişler düzenlenip silinebilir.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(NuvyraSpacing.lg)
            }
            .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }
        }
        .navigationTitle("Egzersizler")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(context: modelContext, dependencies: dependencies) }
        .sheet(isPresented: $viewModel.showingAdd, onDismiss: { Task { await viewModel.load(context: modelContext, dependencies: dependencies) } }) {
            AddWorkoutSheet(mode: .create)
        }
        .sheet(item: $viewModel.editingLog, onDismiss: { Task { await viewModel.load(context: modelContext, dependencies: dependencies) } }) { log in
            AddWorkoutSheet(mode: .edit(log))
        }
    }

    private var addButton: some View {
        NuvyraPrimaryButton(title: "Egzersiz ekle", systemImage: "plus") {
            viewModel.showingAdd = true
        }
    }

    private var historySection: some View {
        NuvyraCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                NuvyraSectionHeader(
                    title: "Bugünkü egzersizler",
                    subtitle: viewModel.entries.isEmpty ? "Henüz kayıt yok" : "\(viewModel.entries.count) seans"
                )
                if viewModel.entries.isEmpty {
                    Text("Yeni bir egzersiz eklediğinde burada görünecek.")
                        .font(NuvyraTypography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider().padding(.vertical, 2) }
                            WorkoutRow(
                                entry: entry,
                                onEdit: entry.source == .manual ? { viewModel.startEditing(entry, context: modelContext) } : nil,
                                onDelete: entry.source == .manual ? { viewModel.delete(entry, context: modelContext, dependencies: dependencies) } : nil
                            )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { WorkoutsView() }
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
