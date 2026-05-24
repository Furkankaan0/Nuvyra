import SwiftData
import SwiftUI
import UIKit

struct PrivacyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var deleteConfirmationShown = false
    @State private var deleteCompletedShown = false
    @State private var exportedFile: ExportedDataFile?
    @State private var exportError: String?

    var body: some View {
        ZStack {
            NuvyraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: NuvyraSpacing.lg) {
                    NuvyraSectionHeader(title: "Gizlilik", subtitle: "HealthKit ve uygulama verileri icin sade aciklama.")
                    NuvyraGlassCard {
                        Text("Nuvyra saglik verilerini yalnizca uygulama icindeki hedef ve icgoruleri olusturmak icin kullanir. Saglik verilerin reklam hedefleme icin kullanilmaz.")
                            .font(NuvyraTypography.body)
                            .foregroundStyle(.secondary)
                    }
                    NuvyraCard {
                        Text("KVKK / GDPR hazirligi")
                            .font(NuvyraTypography.section)
                        Text("Verilerini CSV olarak cihazinda olusturabilir ve istedigin kanaldan paylasabilirsin. Yerel verilerini bu cihazdan silebilirsin; saglik verileri reklam hedefleme icin kullanilmaz.")
                            .foregroundStyle(.secondary)
                    }
                    NuvyraSecondaryButton(title: "Health izinlerini yonet", systemImage: "heart.text.square") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    NuvyraSecondaryButton(title: "Verilerimi disa aktar", systemImage: "square.and.arrow.up") {
                        exportData()
                    }
                    NuvyraSecondaryButton(title: "Yerel verilerimi sil", systemImage: "trash") {
                        deleteConfirmationShown = true
                    }
                }
                .padding(NuvyraSpacing.lg)
            }
        }
        .navigationTitle("Gizlilik")
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
}
