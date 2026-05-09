import SwiftData
import SwiftUI

struct WaterTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var dependencies: DependencyContainer
    @StateObject private var viewModel = WaterTrackingViewModel()
    @State private var showManualSheet = false
    @State private var showRemindersInfo = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                NuvyraBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                        WaterProgressCard(summary: viewModel.summary)
                        quickAddSection
                        WeeklyWaterChart(totals: viewModel.weeklyTotals, targetMl: viewModel.targetMl)
                        todayLogSection
                        reminderSection
                    }
                    .padding(NuvyraSpacing.lg)
                }
                .refreshable { await viewModel.load(context: modelContext, dependencies: dependencies) }

                if viewModel.showCelebration {
                    WaterCelebrationOverlay {
                        viewModel.dismissCelebration()
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Su takibi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showManualSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(NuvyraColors.accent)
                    }
                    .accessibilityLabel("Manuel ml gir")
                }
            }
            .task {
                await viewModel.load(context: modelContext, dependencies: dependencies)
            }
            .sheet(isPresented: $showManualSheet) {
                ManualWaterEntrySheet(
                    amountText: $viewModel.manualEntryText,
                    errorMessage: viewModel.manualEntryError
                ) {
                    await viewModel.submitManualEntry(context: modelContext, dependencies: dependencies)
                }
            }
            .alert("Hatırlatıcılar", isPresented: $showRemindersInfo) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text("Su hatırlatıcıları öğleden sonra ve akşam saatlerinde nazik bir bildirim gönderir. Daha sonra Profil > Bildirimler bölümünden kapatabilirsin.")
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showCelebration)
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraSectionHeader(title: "Hızlı ekle", subtitle: "Sık tüketilen porsiyonlar.")
            HStack(spacing: NuvyraSpacing.sm) {
                QuickWaterButton(amountMl: 200, systemImage: "drop") {
                    Task { await viewModel.add(amount: 200, context: modelContext, dependencies: dependencies) }
                }
                QuickWaterButton(amountMl: 300, systemImage: "drop.fill") {
                    Task { await viewModel.add(amount: 300, context: modelContext, dependencies: dependencies) }
                }
                QuickWaterButton(amountMl: 500, systemImage: "drop.triangle.fill") {
                    Task { await viewModel.add(amount: 500, context: modelContext, dependencies: dependencies) }
                }
            }
            NuvyraSecondaryButton(title: "Manuel ml gir", systemImage: "square.and.pencil") {
                showManualSheet = true
            }
        }
    }

    @ViewBuilder
    private var todayLogSection: some View {
        VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
            NuvyraSectionHeader(title: "Bugünkü kayıtlar", subtitle: "Son eklediklerin.")
            if viewModel.entries.isEmpty {
                emptyTodayLog
            } else {
                NuvyraGlassCard {
                    VStack(spacing: 0) {
                        ForEach(viewModel.entries) { entry in
                            entryRow(entry)
                            if entry.id != viewModel.entries.last?.id {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: WaterEntry) -> some View {
        HStack(spacing: NuvyraSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.30, green: 0.70, blue: 0.95).opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "drop.fill")
                    .foregroundStyle(Color(red: 0.30, green: 0.70, blue: 0.95))
                    .font(.subheadline.weight(.bold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.amountMl) ml")
                    .font(.subheadline.weight(.bold))
                Text(Self.timeFormatter.string(from: entry.date))
                    .font(.caption)
                    .foregroundStyle(NuvyraColors.secondaryText(scheme))
            }
            Spacer()
            Button(role: .destructive) {
                Task { await viewModel.remove(entry, context: modelContext, dependencies: dependencies) }
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(NuvyraColors.mutedCoral)
                    .font(.subheadline.weight(.semibold))
                    .padding(8)
                    .background(NuvyraColors.mutedCoral.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(entry.amountMl) mililitre girişini sil")
        }
        .padding(.vertical, 6)
    }

    private var emptyTodayLog: some View {
        VStack(spacing: NuvyraSpacing.sm) {
            Image(systemName: "drop.degreesign")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.70, blue: 0.95))
            Text("Bugün henüz su kaydı yok")
                .font(.subheadline.weight(.semibold))
            Text("Hızlı eklemelerle ya da manuel ml ile başlayabilirsin.")
                .font(.caption)
                .foregroundStyle(NuvyraColors.secondaryText(scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(NuvyraSpacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: NuvyraRadius.lg, style: .continuous)
                .stroke(Color(red: 0.30, green: 0.70, blue: 0.95).opacity(0.18))
        )
    }

    private var reminderSection: some View {
        NuvyraGlassCard {
            VStack(alignment: .leading, spacing: NuvyraSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Hatırlatıcılar", systemImage: "bell.badge")
                            .font(NuvyraTypography.section)
                        Text("Gün içinde nazik bildirimler.")
                            .font(.caption)
                            .foregroundStyle(NuvyraColors.secondaryText(scheme))
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.remindersEnabled },
                        set: { newValue in
                            Task { await viewModel.setReminders(enabled: newValue, context: modelContext, dependencies: dependencies) }
                        }
                    ))
                    .labelsHidden()
                    .tint(NuvyraColors.accent)
                }
                Button {
                    showRemindersInfo = true
                } label: {
                    Label("Nasıl çalışır?", systemImage: "info.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NuvyraColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#if DEBUG
#Preview {
    WaterTrackingView()
        .modelContainer(NuvyraModelContainer.preview())
        .environmentObject(DependencyContainer.preview())
}
#endif
