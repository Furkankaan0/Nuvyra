import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [AppSettings]
    @State private var deleteConfirmationShown = false
    @State private var deleteCompletedShown = false
    @State private var exportedFile: ExportedDataFile?
    @State private var exportError: String?

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Ayarlar", subtitle: "Nuvyra sakin, gizlilik oncelikli bir ritim kocudur.")
                    NuvyraCard {
                        Toggle("Bildirimler", isOn: notificationBinding)
                        Text("Su, ogun ve aksam yuruyus hatirlatmalari nazik tutulur.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    NuvyraCard {
                        Text("Veri yonetimi")
                            .font(NuvyraTypography.section)
                        NuvyraSecondaryButton(title: "Verilerimi disa aktar", systemImage: "square.and.arrow.up") { exportData() }
                        NuvyraSecondaryButton(title: "Yerel verilerimi sil", systemImage: "trash") {
                            deleteConfirmationShown = true
                        }
                        Text("CSV export cihazinda olusturulur. Yerel verilerini istedigin zaman bu cihazdan silebilirsin.")
                            .font(NuvyraTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Ayarlar")
        .alert("Yerel verileri sil?", isPresented: $deleteConfirmationShown) {
            Button("Verileri sil", role: .destructive) { deleteLocalData() }
            Button("Vazgec", role: .cancel) {}
        } message: {
            Text("Profil, ogun, su ve yuruyus kayitlari bu cihazdan temizlenir. Satin alma durumun etkilenmez.")
        }
        .alert("Veriler silindi", isPresented: $deleteCompletedShown) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bu cihazdaki yerel Nuvyra kayitlari temizlendi.")
        }
        .alert("Disa aktarim tamamlanamadi", isPresented: exportErrorBinding) {
            Button("Tamam", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(item: $exportedFile) { file in
            NavigationStack {
                VStack(spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "CSV hazir", subtitle: file.url.lastPathComponent)
                    ShareLink(item: file.url) {
                        Label("CSV dosyasini paylas", systemImage: "square.and.arrow.up")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NuvyraColors.accent)
                    Spacer()
                }
                .padding(NuvyraSpacing.lg)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { exportedFile = nil } } }
            }
        }
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
    }

    private func exportData() {
        do {
            exportedFile = try DataExportService(context: modelContext).exportCSV()
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteLocalData() {
        do {
            try LocalDataDeletionService(context: modelContext).deletePersonalData()
            deleteCompletedShown = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var notificationBinding: Binding<Bool> {
        Binding(
            get: { settings.first?.notificationsEnabled ?? false },
            set: { newValue in
                let item: AppSettings
                if let existing = settings.first {
                    item = existing
                } else {
                    item = AppSettings()
                    modelContext.insert(item)
                }
                item.notificationsEnabled = newValue
                item.updatedAt = Date()
                try? modelContext.save()
            }
        )
    }
}
